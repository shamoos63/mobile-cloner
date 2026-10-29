package com.mobilecloner.app

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Installed apps for "Apps": listing the user's apps with their APK files
 * (base + splits), icons, and installing received apps with a
 * PackageInstaller session (one per app, so split APKs install together).
 * Android asks the user to confirm every install; only the app moves, its
 * data stays on the old phone.
 */
class Apps(private val activity: Activity) {
    companion object {
        private const val ACTION_INSTALL_STATUS = "com.mobilecloner.app.INSTALL_STATUS"
        private const val TAG = "HKCloner.Apps"
    }

    private val context: Context = activity.applicationContext
    private val pm: PackageManager = context.packageManager
    private val main = Handler(Looper.getMainLooper())

    /** The install waiting for its final status; one at a time. */
    private var pending: MethodChannel.Result? = null
    private var pendingSession = -1
    private var pendingPackage: String? = null
    private var pendingVersion = 0L
    private var awaitingUser = false
    private var receiverRegistered = false

    // --- Listing -------------------------------------------------------------

    /**
     * Third-party apps the user installed and can open: no system apps (not
     * even updated ones such as Chrome or Samsung's apps), no HK Cloner, and
     * nothing without a launcher icon (overlays, plugins, services).
     */
    fun list(): List<Map<String, Any?>> {
        @Suppress("DEPRECATION")
        val packages = pm.getInstalledPackages(0)
        val apps = packages.mapNotNull { info -> describe(info) }
        Log.i(TAG, "listApps: ${apps.size} of ${packages.size} packages")
        return apps
    }

    private fun describe(info: PackageInfo): Map<String, Any?>? {
        val app = info.applicationInfo ?: return null
        val system = app.flags and (ApplicationInfo.FLAG_SYSTEM or ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
        if (system || info.packageName == context.packageName) return null
        if (pm.getLaunchIntentForPackage(info.packageName) == null) return null
        val paths = listOfNotNull(app.sourceDir) + (app.splitSourceDirs?.toList() ?: emptyList())
        val files = paths.map { File(it) }
        val readable = files.isNotEmpty() && files.all { it.canRead() }
        @Suppress("DEPRECATION")
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong()
        return mapOf(
            "package" to info.packageName,
            "label" to app.loadLabel(pm).toString(),
            "versionName" to (info.versionName ?: ""),
            "versionCode" to versionCode,
            "minSdk" to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) app.minSdkVersion else null),
            "apks" to paths,
            "size" to files.sumOf { it.length() },
            "readable" to readable,
        )
    }

    /** Launcher icon as PNG, [sizePx] square. */
    fun icon(pkg: String, sizePx: Int): ByteArray? = try {
        val drawable = pm.getApplicationIcon(pkg)
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        drawable.setBounds(0, 0, sizePx, sizePx)
        drawable.draw(Canvas(bitmap))
        ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        }
    } catch (e: Exception) {
        Log.w(TAG, "icon of $pkg", e)
        null
    }

    /** Installed versionCode of [pkg], or null. */
    fun installedVersion(pkg: String): Long? = try {
        @Suppress("DEPRECATION")
        val info = pm.getPackageInfo(pkg, 0)
        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else info.versionCode.toLong()
    } catch (_: PackageManager.NameNotFoundException) {
        null
    }

    // --- Installing ----------------------------------------------------------

    /** Android 8+: "Install unknown apps" for HK Cloner. Older: always asked per install. */
    fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || pm.canRequestPackageInstalls()

    fun openInstallSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}"))
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }
        activity.startActivity(intent)
    }

    /**
     * Installs one app from [paths] (base first). Answers `installed`,
     * `canceled`, or `failed:<message>` once Android reports the result.
     */
    fun install(paths: List<String>, pkg: String?, versionCode: Long, result: MethodChannel.Result) {
        if (pending != null) return result.error("busy", "Another install is running", null)
        Thread({
            try {
                val installer = pm.packageInstaller
                val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
                val id = installer.createSession(params)
                installer.openSession(id).use { session ->
                    for (path in paths) {
                        val file = File(path)
                        session.openWrite(file.name, 0, file.length()).use { out ->
                            file.inputStream().use { it.copyTo(out, 1 shl 20) }
                            session.fsync(out)
                        }
                    }
                    main.post {
                        registerReceiver()
                        pending = result
                        pendingSession = id
                        pendingPackage = pkg
                        pendingVersion = versionCode
                        awaitingUser = false
                        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
                        val status = PendingIntent.getBroadcast(
                            context, id, Intent(ACTION_INSTALL_STATUS).setPackage(context.packageName), flags,
                        )
                        try {
                            installer.openSession(id).use { it.commit(status.intentSender) }
                        } catch (e: Exception) {
                            finish("failed:${e.message}")
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "install of $paths failed before commit", e)
                main.post { result.success("failed:${e.message}") }
            }
        }, "app-install").start()
    }

    /**
     * Back in HK Cloner after Android's confirm screen. The install may still
     * be running (newer Android closes the dialog right away), and some
     * versions send no status when the user backs out. So: watch the
     * session; once it is gone without a status, the app's installed version
     * says what happened. A session left waiting a minute counts as canceled.
     */
    fun onResume() {
        if (!awaitingUser || pending == null) return
        watch(pendingSession, 0)
    }

    private fun watch(session: Int, seconds: Int) {
        main.postDelayed({
            if (!awaitingUser || pending == null || pendingSession != session) return@postDelayed
            val info = pm.packageInstaller.getSessionInfo(session)
            when {
                info == null -> {
                    val have = pendingPackage?.let { installedVersion(it) }
                    finish(if (have != null && have >= pendingVersion) "installed" else "canceled")
                }
                // Still copying or installing: keep waiting (big apps take a while).
                info.isActive && seconds < 300 -> watch(session, seconds + 1)
                seconds < 60 -> watch(session, seconds + 1)
                else -> {
                    try {
                        pm.packageInstaller.abandonSession(session)
                    } catch (_: Exception) {
                    }
                    finish("canceled")
                }
            }
        }, 1000)
    }

    private fun finish(outcome: String) {
        Log.i(TAG, "install session $pendingSession: $outcome")
        val r = pending ?: return
        pending = null
        pendingSession = -1
        pendingPackage = null
        awaitingUser = false
        r.success(outcome)
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
            Log.i(TAG, "install status $status ${intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)}")
            when (status) {
                PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                    @Suppress("DEPRECATION")
                    val confirm = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT) ?: return finish("failed:no confirm screen")
                    awaitingUser = true
                    activity.startActivity(confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                }
                PackageInstaller.STATUS_SUCCESS -> finish("installed")
                PackageInstaller.STATUS_FAILURE_ABORTED -> finish("canceled")
                else -> finish("failed:${intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: "status $status"}")
            }
        }
    }

    private fun registerReceiver() {
        if (receiverRegistered) return
        ContextCompat.registerReceiver(context, receiver, IntentFilter(ACTION_INSTALL_STATUS), ContextCompat.RECEIVER_NOT_EXPORTED)
        receiverRegistered = true
    }

    fun dispose() {
        if (receiverRegistered) {
            try {
                context.unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
            }
            receiverRegistered = false
        }
    }
}
