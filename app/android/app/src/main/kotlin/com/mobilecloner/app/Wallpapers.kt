package com.mobilecloner.app

import android.app.WallpaperManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

/**
 * Home and lock screen wallpapers as image files, and back. Reading needs
 * storage access on API 27-32 and All-files access from API 33; a
 * SecurityException is reported as `error: permission`.
 */
class Wallpapers(private val context: Context) {
    private val wm get() = WallpaperManager.getInstance(context)

    /** Writes `home.*` and, when it differs from home, `lock.*` into [dir]. */
    fun export(dir: String): Map<String, Any?> {
        val out = File(dir).apply { mkdirs() }
        out.listFiles()?.forEach { it.delete() }
        return try {
            val home = copy(WallpaperManager.FLAG_SYSTEM, out, "home") ?: render(wm.drawable, out, "home")
            // Null lock file: the lock screen shows the home wallpaper.
            val lock = copy(WallpaperManager.FLAG_LOCK, out, "lock")
            mapOf("home" to home, "lock" to lock)
        } catch (e: SecurityException) {
            mapOf("error" to "permission")
        }
    }

    /** Sets [home] (on both screens when [lock] is null) and [lock]. */
    fun apply(home: String?, lock: String?): Boolean {
        if (home == null && lock == null) return false
        if (Build.VERSION.SDK_INT < 24) {
            (home ?: lock)?.let { path -> FileInputStream(path).use { wm.setStream(it) } }
            return true
        }
        if (home != null) {
            val which = if (lock == null) WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK else WallpaperManager.FLAG_SYSTEM
            FileInputStream(home).use { wm.setStream(it, null, true, which) }
        }
        if (lock != null) {
            FileInputStream(lock).use { wm.setStream(it, null, true, WallpaperManager.FLAG_LOCK) }
        }
        return true
    }

    private fun copy(which: Int, out: File, name: String): String? {
        if (Build.VERSION.SDK_INT < 24) return null
        val pfd = wm.getWallpaperFile(which) ?: return null
        val tmp = File(out, "$name.tmp")
        pfd.use { FileInputStream(it.fileDescriptor).use { input -> FileOutputStream(tmp).use { o -> input.copyTo(o) } } }
        if (tmp.length() == 0L) {
            tmp.delete()
            return null
        }
        val file = File(out, "$name.${extensionOf(tmp)}")
        tmp.renameTo(file)
        return file.absolutePath
    }

    /** Fallback for wallpapers with no file (built-in default): draw it. */
    private fun render(drawable: Drawable?, out: File, name: String): String? {
        if (drawable == null) return null
        val bitmap = (drawable as? BitmapDrawable)?.bitmap ?: run {
            val w = drawable.intrinsicWidth.takeIf { it > 0 } ?: return null
            val h = drawable.intrinsicHeight.takeIf { it > 0 } ?: return null
            Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).also {
                drawable.setBounds(0, 0, w, h)
                drawable.draw(Canvas(it))
            }
        }
        val file = File(out, "$name.png")
        FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        return file.absolutePath
    }

    private fun extensionOf(file: File): String {
        val head = ByteArray(12)
        val n = FileInputStream(file).use { it.read(head) }
        return when {
            n >= 4 && head[0] == 0x89.toByte() && head[1] == 'P'.code.toByte() -> "png"
            n >= 2 && head[0] == 0xFF.toByte() && head[1] == 0xD8.toByte() -> "jpg"
            n >= 12 && String(head, 0, 4) == "RIFF" && String(head, 8, 4) == "WEBP" -> "webp"
            else -> "img"
        }
    }
}
