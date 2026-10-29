package com.mobilecloner.app

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbAccessory
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.Executors

/**
 * Phone-to-phone USB cable link using Android Open Accessory (AOA), the
 * way Smart Switch does it: no tethering, no network.
 *
 * The phone the cable makes USB host finds the other phone, asks it to
 * switch into accessory mode (control requests 51/52/53), waits for it to
 * come back as a Google accessory (18D1:2D00/2D01) and opens its bulk
 * endpoints. The other phone sees an accessory "HK Cloner Link", which
 * opens HK Cloner by itself (accessory_filter.xml) and reads/writes the
 * accessory's file descriptor. Either way Dart gets one byte pipe:
 * incoming bytes and state changes on [EVENTS], writes on [CONTROL].
 */
class UsbLink(private val activity: Activity) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        const val CONTROL = "mobile_cloner/usb_ctl"
        const val EVENTS = "mobile_cloner/usb"
        private const val ACTION_PERMISSION = "com.mobilecloner.app.USB_PERMISSION"
        const val MANUFACTURER = "HK Cloner"
        const val MODEL = "HK Cloner Link"
        private const val GOOGLE_VID = 0x18D1
        private val ACCESSORY_PIDS = setOf(0x2D00, 0x2D01)

        // Reads must take a full 16 KiB: the accessory driver's request size.
        private const val CHUNK = 16384
        private const val WRITE_TIMEOUT_MS = 5000
    }

    private val context: Context = activity.applicationContext
    private val usb = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private val main = Handler(Looper.getMainLooper())
    private val writer = Executors.newSingleThreadExecutor()
    private var sink: EventChannel.EventSink? = null

    private var state = "idle"
    private var role: String? = null
    private var detail: String? = null

    /** Dart asked for the link; attach broadcasts continue the setup. */
    private var active = false
    private var receiverRegistered = false
    private val switchAttempts = HashMap<String, Int>()

    @Volatile private var open = false
    private var connection: UsbDeviceConnection? = null
    private var device: UsbDevice? = null
    private var claimed: UsbInterface? = null
    private var epIn: UsbEndpoint? = null
    private var epOut: UsbEndpoint? = null
    private var accessoryFd: ParcelFileDescriptor? = null
    private var input: FileInputStream? = null
    private var output: FileOutputStream? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                start()
                result.success(stateMap())
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            "state" -> result.success(stateMap())
            "accessoryPresent" -> result.success(ourAccessory() != null)
            "write" -> write(call.arguments as ByteArray, result)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        emitState()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    /**
     * MainActivity forwards USB_ACCESSORY_ATTACHED / USB_DEVICE_ATTACHED
     * launches. The user just chose to open HK Cloner for the cable, so the
     * link starts even if no screen asked for it yet.
     */
    fun onIntent(intent: Intent?) {
        val action = intent?.action ?: return
        if ((action == UsbManager.ACTION_USB_ACCESSORY_ATTACHED || action == UsbManager.ACTION_USB_DEVICE_ATTACHED) && !open) {
            start()
        }
    }

    // --- Setup -------------------------------------------------------------

    private fun start() {
        active = true
        registerReceiver()
        if (open) {
            emitState()
            return
        }
        val accessory = ourAccessory()
        if (accessory != null) {
            if (usb.hasPermission(accessory)) openAccessory(accessory) else requestPermission(accessory)
            return
        }
        val devices = usb.deviceList.values.filter { mightBePhone(it) }
        val dev = devices.firstOrNull { isAccessoryMode(it) } ?: devices.firstOrNull()
        if (dev == null) {
            setState("noDevice", null, "No phone on the cable yet")
            return
        }
        if (!usb.hasPermission(dev)) {
            requestPermission(dev)
            return
        }
        if (isAccessoryMode(dev)) openDevice(dev) else switchToAccessory(dev)
    }

    private fun stop() {
        active = false
        closeLink("idle", null)
        if (receiverRegistered) {
            try {
                context.unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
            }
            receiverRegistered = false
        }
        switchAttempts.clear()
    }

    private fun ourAccessory(): UsbAccessory? =
        usb.accessoryList?.firstOrNull { it.manufacturer == MANUFACTURER && it.model == MODEL }

    private fun isAccessoryMode(d: UsbDevice) = d.vendorId == GOOGLE_VID && d.productId in ACCESSORY_PIDS

    /**
     * Skips headsets, keyboards, sticks, hubs and cameras so plugging one in
     * never asks for USB access. A phone shows MTP/PTP, vendor-specific
     * (ADB, accessory) or no interfaces at all in charge-only mode.
     */
    private fun mightBePhone(d: UsbDevice): Boolean {
        if (isAccessoryMode(d) || d.interfaceCount == 0) return true
        val notPhone = setOf(
            UsbConstants.USB_CLASS_AUDIO,
            UsbConstants.USB_CLASS_HID,
            UsbConstants.USB_CLASS_MASS_STORAGE,
            UsbConstants.USB_CLASS_HUB,
            UsbConstants.USB_CLASS_VIDEO,
            UsbConstants.USB_CLASS_PRINTER,
            UsbConstants.USB_CLASS_WIRELESS_CONTROLLER,
        )
        return (0 until d.interfaceCount).any { d.getInterface(it).interfaceClass !in notPhone }
    }

    private fun permissionIntent(): PendingIntent {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        return PendingIntent.getBroadcast(context, 0, Intent(ACTION_PERMISSION).setPackage(context.packageName), flags)
    }

    private fun requestPermission(d: UsbDevice) {
        setState("permission", "host", "Tap Allow on this phone")
        usb.requestPermission(d, permissionIntent())
    }

    private fun requestPermission(a: UsbAccessory) {
        setState("permission", "accessory", "Tap Allow on this phone")
        usb.requestPermission(a, permissionIntent())
    }

    /** Asks the other phone to come back as an Android accessory. */
    private fun switchToAccessory(d: UsbDevice) {
        val attempts = switchAttempts.getOrDefault(d.deviceName, 0)
        if (attempts >= 2) {
            setState("unsupported", "host", "The device on the cable did not switch to accessory mode")
            return
        }
        switchAttempts[d.deviceName] = attempts + 1
        val conn = usb.openDevice(d)
        if (conn == null) {
            setState("error", "host", "Could not open the USB device")
            return
        }
        try {
            val buf = ByteArray(2)
            val n = conn.controlTransfer(UsbConstants.USB_DIR_IN or UsbConstants.USB_TYPE_VENDOR, 51, 0, 0, buf, 2, 1000)
            val protocol = if (n == 2) (buf[0].toInt() and 0xff) or ((buf[1].toInt() and 0xff) shl 8) else 0
            if (protocol < 1) {
                setState("unsupported", "host", "The device on the cable is not an Android phone that supports accessory mode")
                return
            }
            val strings = listOf(MANUFACTURER, MODEL, "Phone to phone transfer", "1", "https://hishamkhateeb.com", "hkcloner")
            for ((index, s) in strings.withIndex()) {
                val bytes = (s + "\u0000").toByteArray(Charsets.UTF_8)
                conn.controlTransfer(UsbConstants.USB_DIR_OUT or UsbConstants.USB_TYPE_VENDOR, 52, 0, index, bytes, bytes.size, 1000)
            }
            conn.controlTransfer(UsbConstants.USB_DIR_OUT or UsbConstants.USB_TYPE_VENDOR, 53, 0, 0, null, 0, 1000)
        } finally {
            conn.close()
        }
        setState("switching", "host", "Waiting for the other phone. Open HK Cloner there if it asks.")
        // It re-enumerates as 18D1:2D0x; DEVICE_ATTACHED continues, this is a fallback.
        for (delay in listOf(2000L, 5000L, 10000L)) {
            main.postDelayed({ if (active && !open) start() }, delay)
        }
    }

    /** Host side: the other phone in accessory mode. */
    private fun openDevice(d: UsbDevice) {
        val conn = usb.openDevice(d) ?: return setState("error", "host", "Could not open the USB device")
        val iface = d.getInterface(0)
        var inEp: UsbEndpoint? = null
        var outEp: UsbEndpoint? = null
        for (i in 0 until iface.endpointCount) {
            val ep = iface.getEndpoint(i)
            if (ep.type != UsbConstants.USB_ENDPOINT_XFER_BULK) continue
            if (ep.direction == UsbConstants.USB_DIR_IN) inEp = ep else outEp = ep
        }
        if (inEp == null || outEp == null || !conn.claimInterface(iface, true)) {
            conn.close()
            setState("error", "host", "The other phone's accessory link has no data endpoints")
            return
        }
        connection = conn
        device = d
        claimed = iface
        epIn = inEp
        epOut = outEp
        open = true
        setState("connected", "host", null)
        val ep = inEp
        Thread({
            val buf = ByteArray(CHUNK)
            while (open) {
                val n = conn.bulkTransfer(ep, buf, buf.size, 0)
                if (n < 0) break
                if (n > 0) emitData(buf.copyOf(n))
            }
            main.post { if (open) closeLink("detached", "The cable was unplugged") }
        }, "usb-host-reader").start()
    }

    /** Accessory side: the other phone is the USB host. */
    private fun openAccessory(a: UsbAccessory) {
        val fd = usb.openAccessory(a) ?: return setState("error", "accessory", "Could not open the USB accessory")
        accessoryFd = fd
        val inStream = FileInputStream(fd.fileDescriptor)
        input = inStream
        output = FileOutputStream(fd.fileDescriptor)
        open = true
        setState("connected", "accessory", null)
        Thread({
            val buf = ByteArray(CHUNK)
            try {
                while (open) {
                    val n = inStream.read(buf)
                    if (n < 0) break
                    if (n > 0) emitData(buf.copyOf(n))
                }
            } catch (_: Exception) {
            }
            main.post { if (open) closeLink("detached", "The cable was unplugged") }
        }, "usb-accessory-reader").start()
    }

    private fun write(bytes: ByteArray, result: MethodChannel.Result) {
        if (!open) return result.error("closed", "USB link is not connected", null)
        writer.execute {
            try {
                val conn = connection
                val ep = epOut
                if (conn != null && ep != null) {
                    var offset = 0
                    while (offset < bytes.size) {
                        val len = minOf(CHUNK, bytes.size - offset)
                        val n = conn.bulkTransfer(ep, bytes, offset, len, WRITE_TIMEOUT_MS)
                        if (n < 0) throw java.io.IOException("USB write failed")
                        offset += n
                    }
                } else {
                    val out = output ?: throw java.io.IOException("USB link is not connected")
                    out.write(bytes)
                }
                main.post { result.success(null) }
            } catch (e: Exception) {
                main.post {
                    result.error("closed", e.message, null)
                    if (open) closeLink("detached", "The cable was unplugged")
                }
            }
        }
    }

    private fun closeLink(newState: String, why: String?) {
        val wasOpen = open
        open = false
        connection?.let { c ->
            claimed?.let { c.releaseInterface(it) }
            c.close()
        }
        connection = null
        device = null
        claimed = null
        epIn = null
        epOut = null
        try {
            accessoryFd?.close()
        } catch (_: Exception) {
        }
        accessoryFd = null
        input = null
        output = null
        if (wasOpen || state != newState) setState(newState, if (newState == "idle") null else role, why)
    }

    // --- Broadcasts ----------------------------------------------------------

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            when (intent.action) {
                ACTION_PERMISSION -> {
                    val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                    if (granted) start() else setState("denied", role, "USB access was not allowed")
                }
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> if (active && !open) start()
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    @Suppress("DEPRECATION")
                    val gone = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                    if (open && gone != null && gone.deviceName == device?.deviceName) {
                        closeLink("detached", "The cable was unplugged")
                    } else if (!open && active) {
                        setState("noDevice", null, "No phone on the cable yet")
                    }
                }
                UsbManager.ACTION_USB_ACCESSORY_DETACHED -> if (open && accessoryFd != null) {
                    closeLink("detached", "The cable was unplugged")
                }
            }
        }
    }

    private fun registerReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(ACTION_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
            addAction(UsbManager.ACTION_USB_ACCESSORY_DETACHED)
        }
        ContextCompat.registerReceiver(context, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        receiverRegistered = true
    }

    // --- To Dart -------------------------------------------------------------

    private fun stateMap() = mapOf("state" to state, "role" to role, "detail" to detail)

    private fun setState(s: String, r: String?, d: String?) {
        state = s
        role = r
        detail = d
        val snapshot = stateMap()
        main.post { sink?.success(snapshot) }
    }

    private fun emitState() {
        sink?.success(stateMap())
    }

    private fun emitData(bytes: ByteArray) {
        main.post { if (open) sink?.success(bytes) }
    }

    fun dispose() {
        stop()
        writer.shutdown()
    }
}
