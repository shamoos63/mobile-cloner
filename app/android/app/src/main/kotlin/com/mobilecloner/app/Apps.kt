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
    }

    private val context: Context = activity.applicationContext
    private val pm: PackageManager = context.packageManager
    private val main = Handler(Looper.getMainLooper())

    /** The install waiting for its final status; one at a time. */
    private var pending: MethodChannel.Result? = null
    private var pendingSession = -1
    private var awaitingUser = false
    private var receiverRegistered = false

    // --- Listing -------------------------------------------------------------

    /** User-installed apps (and updated system apps), not HK Cloner itself. */
    fun list(): List<Map<String, Any?>> {
        @Suppress("DEPRECATION")
        val packages = pm.getInstalledPackages(0)
        return packages.mapNotNull { info -> describe(info) }
    }

    private fun describe(info: PackageInfo): Map<String, Any?>? {
        val app = info.applicationInfo ?: return null
        val system = app.flags and ApplicationInfo.FLAG_SYSTEM != 0
        val updated = app.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP != 0
        if ((system && !updated) || info.packageName == context.packageName) return null
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
    } catch (_: PackageManager.NameNotFoundException) {
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
    fun install(paths: List<String>, result: MethodChannel.Result) {
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
                main.post { result.success("failed:${e.message}") }
            }
        }, "app-install").start()
    }

    /**
     * Back in HK Cloner after Android's confirm screen. Some Android
     * versions send no status when the user backs out of it, so a confirm
     * that never reports counts as canceled.
     */
    fun onResume() {
        if (!awaitingUser || pending == null) return
        val session = pendingSession
        main.postDelayed({
            if (awaitingUser && pending != null && pendingSession == session) {
                try {
                    pm.packageInstaller.abandonSession(session)
                } catch (_: Exception) {
                }
                finish("canceled")
            }
        }, 4000)
    }

    private fun finish(outcome: String) {
        val r = pending ?: return
        pending = null
        pendingSession = -1
        awaitingUser = false
        r.success(outcome)
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            when (val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
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
