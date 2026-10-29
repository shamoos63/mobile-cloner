package com.mobilecloner.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var bridge: AndroidBridge? = null
    private var usbLink: UsbLink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val b = AndroidBridge(this)
        bridge = b
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AndroidBridge.CHANNEL)
            .setMethodCallHandler(b)
        val usb = UsbLink(this)
        usbLink = usb
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UsbLink.CONTROL).setMethodCallHandler(usb)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, UsbLink.EVENTS).setStreamHandler(usb)
    }

    // Keep the newest launch intent so Dart can read `cloner_link` on resume
    // (the computer re-opens the app with it when the cable is plugged in).
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Plugged into another phone running HK Cloner (accessory_filter.xml).
        usbLink?.onIntent(intent)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        bridge?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        bridge?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onResume() {
        super.onResume()
        bridge?.onResume()
    }

    override fun onDestroy() {
        usbLink?.dispose()
        bridge?.dispose()
        super.onDestroy()
    }
}
