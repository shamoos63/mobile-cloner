package com.mobilecloner.app

import android.Manifest
import android.accounts.AccountManager
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.provider.ContactsContract
import android.provider.DocumentsContract
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Everything the Flutter side needs from Android that no plugin covers on
 * API 23+: SAF access to the WhatsApp folder, All-files access, local-only
 * hotspot + joining it from a QR code, tethering settings, system vCard
 * export/import, account names, battery, foreground service.
 */
class AndroidBridge(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL = "mobile_cloner/android"
        private const val REQ_PERMISSIONS = 7001
        private const val REQ_PICK_TREE = 7002
        private const val REQ_CHOOSE_ACCOUNT = 7003
        private const val GOOGLE_SWITCH_PACKAGE = "com.google.android.apps.restore"
    }

    private val context: Context = activity.applicationContext
    private val saf = SafStore(context)
    private val io = Executors.newCachedThreadPool()
    private val main = Handler(Looper.getMainLooper())
    private val pending = HashMap<Int, MethodChannel.Result>()
    private var permissionNames: List<String> = emptyList()
    private var hotspotReservation: WifiManager.LocalOnlyHotspotReservation? = null
    private var joinedNetworkCallback: ConnectivityManager.NetworkCallback? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "deviceInfo" -> result.success(
                    mapOf(
                        "sdkInt" to Build.VERSION.SDK_INT,
                        "release" to Build.VERSION.RELEASE,
                        "manufacturer" to Build.MANUFACTURER,
                        "model" to Build.MODEL,
                        "storageRoot" to Environment.getExternalStorageDirectory().absolutePath,
                    ),
                )
                "takeLaunchLink" -> {
                    val link = activity.intent?.getStringExtra("cloner_link")
                    activity.intent?.removeExtra("cloner_link")
                    result.success(link)
                }
                "battery" -> result.success(battery())
                "freeBytes" -> result.success(StatFs(Environment.getExternalStorageDirectory().path).availableBytes)
                "requestPermissions" -> requestPermissions(call.argument<List<String>>("permissions") ?: emptyList(), result)
                "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                "requestAllFilesAccess" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        startSafely(
                            Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:${context.packageName}")),
                            Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION),
                        )
                    }
                    result.success(null)
                }
                "isPackageInstalled" -> result.success(isInstalled(call.argument<String>("package")!!))
                "launchPackage" -> result.success(launch(call.argument<String>("package")!!))
                "openTetherSettings" -> {
                    startSafely(
                        Intent().setClassName("com.android.settings", "com.android.settings.TetherSettings"),
                        Intent(Settings.ACTION_WIRELESS_SETTINGS),
                    )
                    result.success(null)
                }
                "openWifiSettings" -> {
                    startSafely(Intent(Settings.ACTION_WIFI_SETTINGS))
                    result.success(null)
                }
                "openAddGoogleAccount" -> {
                    startSafely(
                        Intent(Settings.ACTION_ADD_ACCOUNT).putExtra(Settings.EXTRA_ACCOUNT_TYPES, arrayOf("com.google")),
                        Intent(Settings.ACTION_SYNC_SETTINGS),
                    )
                    result.success(null)
                }
                "openGoogleSwitch" -> result.success(launch(GOOGLE_SWITCH_PACKAGE))
                "accounts" -> accounts(result)
                "startLocalHotspot" -> startLocalHotspot(result)
                "stopLocalHotspot" -> {
                    hotspotReservation?.close()
                    hotspotReservation = null
                    result.success(null)
                }
                "joinWifi" -> joinWifi(call.argument<String>("ssid")!!, call.argument<String>("password"), result)
                "keepScreenOn" -> {
                    val on = call.argument<Boolean>("on") == true
                    activity.runOnUiThread {
                        if (on) activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        else activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                "serviceUpdate" -> {
                    val intent = Intent(context, TransferService::class.java)
                        .putExtra(TransferService.EXTRA_TITLE, call.argument<String>("title"))
                        .putExtra(TransferService.EXTRA_TEXT, call.argument<String>("text"))
                        .putExtra(TransferService.EXTRA_PROGRESS, call.argument<Int>("progress") ?: -1)
                    ContextCompat.startForegroundService(context, intent)
                    result.success(null)
                }
                "serviceStop" -> {
                    context.startService(Intent(context, TransferService::class.java).setAction(TransferService.ACTION_STOP))
                    result.success(null)
                }
                "alert" -> {
                    TransferService.alert(context, call.argument<String>("title") ?: "", call.argument<String>("text") ?: "")
                    result.success(null)
                }
                "scanMedia" -> {
                    val paths = call.argument<List<String>>("paths") ?: emptyList()
                    MediaScannerConnection.scanFile(context, paths.toTypedArray(), null, null)
                    result.success(null)
                }
                "exportContacts" -> background(result) { exportContacts(call.argument<String>("path")!!) }
                "importVcf" -> result.success(importVcf(call.argument<String>("path")!!))

                // Storage Access Framework
                "safPickTree" -> pickTree(call.argument<String>("initialPath"), result)
                "safTrees" -> result.success(saf.persistedTrees())
                "safList" -> background(result) {
                    saf.list(Uri.parse(call.argument<String>("tree")!!), call.argument<String>("sub"))
                }
                "safOpenRead" -> background(result) {
                    saf.openRead(Uri.parse(call.argument<String>("uri")!!), (call.argument<Number>("offset") ?: 0).toLong())
                }
                "safRead" -> background(result) { saf.read(call.argument<Int>("handle")!!, call.argument<Int>("max") ?: (1 shl 20)) }
                "safCloseRead" -> {
                    saf.closeRead(call.argument<Int>("handle")!!)
                    result.success(null)
                }
                "safPartialSize" -> background(result) {
                    saf.partialSize(Uri.parse(call.argument<String>("tree")!!), call.argument<String>("rel")!!)
                }
                "safOpenWrite" -> background(result) {
                    saf.openWrite(Uri.parse(call.argument<String>("tree")!!), call.argument<String>("rel")!!, call.argument<Boolean>("append") == true)
                }
                "safWrite" -> background(result) {
                    saf.write(call.argument<Int>("handle")!!, call.argument<ByteArray>("bytes")!!)
                    null
                }
                "safCloseWrite" -> background(result) {
                    saf.closeWrite(call.argument<Int>("handle")!!)
                    null
                }
                "safCommit" -> background(result) {
                    saf.commit(Uri.parse(call.argument<String>("tree")!!), call.argument<String>("rel")!!)
                    null
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("bridge", e.message, null)
        }
    }

    private fun <T> background(result: MethodChannel.Result, block: () -> T) {
        io.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("bridge", e.message ?: e.javaClass.simpleName, null) }
            }
        }
    }

    private fun startSafely(vararg intents: Intent): Boolean {
        for (intent in intents) {
            try {
                activity.startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
            } catch (_: SecurityException) {
            }
        }
        return false
    }

    private fun battery(): Map<String, Any?> {
        val status = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = status?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = status?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val plugged = status?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        return mapOf(
            "level" to if (level >= 0 && scale > 0) level * 100 / scale else null,
            "charging" to (plugged != 0),
        )
    }

    private fun hasAllFilesAccess(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) Environment.isExternalStorageManager()
        else ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED

    private fun isInstalled(pkg: String): Boolean = try {
        context.packageManager.getPackageInfo(pkg, 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    private fun launch(pkg: String): Boolean {
        val intent = context.packageManager.getLaunchIntentForPackage(pkg) ?: return false
        return startSafely(intent)
    }

    // --- Permissions -------------------------------------------------------

    private fun requestPermissions(names: List<String>, result: MethodChannel.Result) {
        val needed = names.filter { ContextCompat.checkSelfPermission(context, it) != PackageManager.PERMISSION_GRANTED }
        if (needed.isEmpty()) {
            result.success(names.associateWith { true })
            return
        }
        if (pending.containsKey(REQ_PERMISSIONS)) {
            result.error("busy", "Permission request already running", null)
            return
        }
        pending[REQ_PERMISSIONS] = result
        permissionNames = names
        activity.requestPermissions(needed.toTypedArray(), REQ_PERMISSIONS)
    }

    fun onRequestPermissionsResult(requestCode: Int, @Suppress("UNUSED_PARAMETER") grantResults: IntArray) {
        if (requestCode != REQ_PERMISSIONS) return
        val result = pending.remove(REQ_PERMISSIONS) ?: return
        result.success(
            permissionNames.associateWith {
                ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
            },
        )
    }

    // --- SAF ---------------------------------------------------------------

    private fun pickTree(initialPath: String?, result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION,
        )
        if (initialPath != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val docId = "primary:" + initialPath.trim('/')
            val uri = DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", docId)
            intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, uri)
        }
        pending[REQ_PICK_TREE] = result
        @Suppress("DEPRECATION")
        activity.startActivityForResult(intent, REQ_PICK_TREE)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        when (requestCode) {
            REQ_PICK_TREE -> {
                val result = pending.remove(requestCode) ?: return
                val uri = data?.data
                if (resultCode != Activity.RESULT_OK || uri == null) {
                    result.success(null)
                    return
                }
                val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                try {
                    context.contentResolver.takePersistableUriPermission(uri, flags)
                } catch (_: SecurityException) {
                    context.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                result.success(mapOf("uri" to uri.toString(), "basePath" to saf.basePath(uri)))
            }
            REQ_CHOOSE_ACCOUNT -> {
                val result = pending.remove(requestCode) ?: return
                val name = data?.getStringExtra(AccountManager.KEY_ACCOUNT_NAME)
                val type = data?.getStringExtra(AccountManager.KEY_ACCOUNT_TYPE)
                result.success(if (resultCode == Activity.RESULT_OK && name != null) listOf(mapOf("name" to name, "type" to type)) else emptyList<Any>())
            }
        }
    }

    // --- Accounts ------------------------------------------------------------

    /**
     * API 23-25: lists every account (GET_ACCOUNTS). API 26+: Android hides
     * other apps' accounts, so the user picks one in the system chooser;
     * call again to add more.
     */
    private fun accounts(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            val list = AccountManager.get(context).accounts.map { mapOf("name" to it.name, "type" to it.type) }
            result.success(list)
            return
        }
        val intent = AccountManager.newChooseAccountIntent(null, null, null, null, null, null, null)
        pending[REQ_CHOOSE_ACCOUNT] = result
        @Suppress("DEPRECATION")
        activity.startActivityForResult(intent, REQ_CHOOSE_ACCOUNT)
    }

    // --- Hotspot / Wi-Fi -------------------------------------------------------

    /** Opens a local-only hotspot (API 26+) and returns its credentials for the QR code. */
    private fun startLocalHotspot(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            result.success(null)
            return
        }
        val wifi = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
        try {
            wifi.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(reservation: WifiManager.LocalOnlyHotspotReservation) {
                    hotspotReservation = reservation
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        val config = reservation.softApConfiguration
                        result.success(mapOf("ssid" to config.ssid, "password" to config.passphrase))
                    } else {
                        @Suppress("DEPRECATION")
                        val config: WifiConfiguration? = reservation.wifiConfiguration
                        @Suppress("DEPRECATION")
                        result.success(mapOf("ssid" to config?.SSID, "password" to config?.preSharedKey))
                    }
                }

                override fun onFailed(reason: Int) {
                    result.error("hotspot", "Hotspot failed ($reason)", null)
                }
            }, main)
        } catch (e: SecurityException) {
            result.error("hotspot", e.message, null)
        }
    }

    /** Joins the peer's hotspot from QR credentials and routes our sockets over it. */
    private fun joinWifi(ssid: String, password: String?, result: MethodChannel.Result) {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val specifier = WifiNetworkSpecifier.Builder().setSsid(ssid).apply {
                if (!password.isNullOrEmpty()) setWpa2Passphrase(password)
            }.build()
            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .setNetworkSpecifier(specifier)
                .build()
            joinedNetworkCallback?.let { runCatching { cm.unregisterNetworkCallback(it) } }
            var answered = false
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    cm.bindProcessToNetwork(network)
                    main.post { if (!answered) { answered = true; result.success(true) } }
                }

                override fun onUnavailable() {
                    main.post { if (!answered) { answered = true; result.success(false) } }
                }
            }
            joinedNetworkCallback = callback
            cm.requestNetwork(request, callback, 60_000)
        } else {
            @Suppress("DEPRECATION")
            val wifi = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
            @Suppress("DEPRECATION")
            val config = WifiConfiguration().apply {
                SSID = "\"$ssid\""
                if (password.isNullOrEmpty()) allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE)
                else preSharedKey = "\"$password\""
            }
            @Suppress("DEPRECATION")
            val id = wifi.addNetwork(config)
            @Suppress("DEPRECATION")
            val ok = id != -1 && wifi.disconnect() && wifi.enableNetwork(id, true) && wifi.reconnect()
            result.success(ok)
        }
    }

    // --- Contacts ------------------------------------------------------------

    /** Exports all contacts with the system's own vCard exporter. Returns the count. */
    private fun exportContacts(path: String): Int {
        val resolver = context.contentResolver
        val keys = ArrayList<String>()
        resolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            arrayOf(ContactsContract.Contacts.LOOKUP_KEY),
            null, null, null,
        )?.use { c ->
            while (c.moveToNext()) c.getString(0)?.let { keys.add(it) }
        }
        val out = File(path)
        out.parentFile?.mkdirs()
        out.outputStream().use { sink ->
            // Batches keep the multi-vCard URI under length limits.
            for (batch in keys.chunked(100)) {
                val uri = Uri.withAppendedPath(ContactsContract.Contacts.CONTENT_MULTI_VCARD_URI, Uri.encode(batch.joinToString(":")))
                try {
                    resolver.openInputStream(uri)?.use { it.copyTo(sink) }
                } catch (_: Exception) {
                    // Fall back one by one so a single broken contact doesn't drop the batch.
                    for (key in batch) {
                        val single = Uri.withAppendedPath(ContactsContract.Contacts.CONTENT_VCARD_URI, key)
                        runCatching { resolver.openInputStream(single)?.use { it.copyTo(sink) } }
                    }
                }
            }
        }
        return keys.size
    }

    /** Hands a .vcf to the system Contacts app, which imports it. */
    private fun importVcf(path: String): Boolean {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", File(path))
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "text/x-vcard")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return startSafely(intent)
    }

    fun dispose() {
        saf.dispose()
        hotspotReservation?.close()
        io.shutdown()
    }
}
