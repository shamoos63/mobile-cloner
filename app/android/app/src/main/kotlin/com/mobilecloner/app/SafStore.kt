package com.mobilecloner.app

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import androidx.documentfile.provider.DocumentFile
import java.io.InputStream
import java.io.OutputStream
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger

/**
 * Storage Access Framework helpers. On Android 11+ the WhatsApp folder in
 * Android/media belongs to WhatsApp, so the user grants us that folder (or
 * Android/media) once through the system picker and we read/write through
 * document URIs. Streams are exposed to Dart as integer handles read and
 * written in chunks.
 */
class SafStore(private val context: Context) {
    private val readers = ConcurrentHashMap<Int, InputStream>()
    private val writers = ConcurrentHashMap<Int, OutputStream>()
    private val nextHandle = AtomicInteger(1)

    /** Directory cache: "<tree>|<relDir>" -> document. */
    private val dirCache = ConcurrentHashMap<String, DocumentFile>()

    /** Path the tree points at, relative to shared storage, e.g. "Android/media". */
    fun basePath(treeUri: Uri): String {
        val docId = DocumentsContract.getTreeDocumentId(treeUri)
        val colon = docId.indexOf(':')
        return if (colon >= 0) docId.substring(colon + 1).trim('/') else ""
    }

    fun persistedTrees(): List<Map<String, Any>> =
        context.contentResolver.persistedUriPermissions
            .filter { it.isReadPermission }
            .map {
                mapOf(
                    "uri" to it.uri.toString(),
                    "basePath" to basePath(it.uri),
                    "writable" to it.isWritePermission,
                )
            }

    /** Recursive listing: rel path (from the tree root), size, mtime, uri. */
    fun list(treeUri: Uri, subPath: String?): List<Map<String, Any>> {
        val root = DocumentFile.fromTreeUri(context, treeUri) ?: return emptyList()
        val start = if (subPath.isNullOrEmpty()) root else findDir(root, subPath, create = false) ?: return emptyList()
        val out = ArrayList<Map<String, Any>>()
        walk(start, subPath?.trim('/') ?: "", out)
        return out
    }

    private fun walk(dir: DocumentFile, prefix: String, out: MutableList<Map<String, Any>>) {
        for (child in dir.listFiles()) {
            val name = child.name ?: continue
            val rel = if (prefix.isEmpty()) name else "$prefix/$name"
            if (child.isDirectory) {
                walk(child, rel, out)
            } else {
                out.add(
                    mapOf(
                        "rel" to rel,
                        "size" to child.length(),
                        "modified" to child.lastModified(),
                        "uri" to child.uri.toString(),
                    ),
                )
            }
        }
    }

    fun openRead(uri: Uri, offset: Long): Int {
        val input = context.contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Cannot open $uri")
        var toSkip = offset
        while (toSkip > 0) {
            val skipped = input.skip(toSkip)
            if (skipped <= 0) break
            toSkip -= skipped
        }
        val handle = nextHandle.getAndIncrement()
        readers[handle] = input
        return handle
    }

    /** Returns up to [max] bytes, or null at end of file. */
    fun read(handle: Int, max: Int): ByteArray? {
        val input = readers[handle] ?: return null
        val buffer = ByteArray(max)
        var filled = 0
        while (filled < max) {
            val n = input.read(buffer, filled, max - filled)
            if (n < 0) break
            filled += n
        }
        if (filled == 0) return null
        return if (filled == max) buffer else buffer.copyOf(filled)
    }

    fun closeRead(handle: Int) {
        readers.remove(handle)?.close()
    }

    /** Size of "<relPath>.part" if a previous transfer left one. */
    fun partialSize(treeUri: Uri, relPath: String): Long {
        val root = DocumentFile.fromTreeUri(context, treeUri) ?: return 0
        val (dirPath, name) = split(relPath)
        val dir = if (dirPath.isEmpty()) root else findDir(root, dirPath, create = false) ?: return 0
        return dir.findFile("$name.part")?.length() ?: 0
    }

    /** Opens "<relPath>.part" for writing, creating folders as needed. */
    fun openWrite(treeUri: Uri, relPath: String, append: Boolean): Int {
        val root = DocumentFile.fromTreeUri(context, treeUri)
            ?: throw IllegalStateException("No access to $treeUri")
        val (dirPath, name) = split(relPath)
        val dir = if (dirPath.isEmpty()) root else findDir(root, dirPath, create = true)
            ?: throw IllegalStateException("Cannot create $dirPath")
        val partName = "$name.part"
        val part = dir.findFile(partName) ?: dir.createFile("application/octet-stream", partName)
            ?: throw IllegalStateException("Cannot create $partName")
        val mode = if (append) "wa" else "wt"
        val output = context.contentResolver.openOutputStream(part.uri, mode)
            ?: throw IllegalStateException("Cannot write $partName")
        val handle = nextHandle.getAndIncrement()
        writers[handle] = output
        return handle
    }

    fun write(handle: Int, bytes: ByteArray) {
        val output = writers[handle] ?: throw IllegalStateException("Writer $handle closed")
        output.write(bytes)
    }

    fun closeWrite(handle: Int) {
        writers.remove(handle)?.let {
            it.flush()
            it.close()
        }
    }

    /** Renames "<relPath>.part" to its final name, replacing any old file. */
    fun commit(treeUri: Uri, relPath: String) {
        val root = DocumentFile.fromTreeUri(context, treeUri) ?: return
        val (dirPath, name) = split(relPath)
        val dir = if (dirPath.isEmpty()) root else findDir(root, dirPath, create = false) ?: return
        dir.findFile(name)?.delete()
        val part = dir.findFile("$name.part") ?: throw IllegalStateException("Missing $name.part")
        if (!part.renameTo(name)) throw IllegalStateException("Cannot rename $name.part")
    }

    private fun split(relPath: String): Pair<String, String> {
        val clean = relPath.trim('/')
        val slash = clean.lastIndexOf('/')
        return if (slash < 0) "" to clean else clean.substring(0, slash) to clean.substring(slash + 1)
    }

    private fun findDir(root: DocumentFile, relDir: String, create: Boolean): DocumentFile? {
        val key = "${root.uri}|$relDir"
        dirCache[key]?.let { return it }
        var current = root
        var path = ""
        for (segment in relDir.trim('/').split('/')) {
            if (segment.isEmpty()) continue
            path = if (path.isEmpty()) segment else "$path/$segment"
            val cached = dirCache["${root.uri}|$path"]
            current = cached
                ?: current.findFile(segment)?.takeIf { it.isDirectory }
                ?: (if (create) current.createDirectory(segment) else null)
                ?: return null
            dirCache["${root.uri}|$path"] = current
        }
        return current
    }

    fun dispose() {
        readers.values.forEach { runCatching { it.close() } }
        writers.values.forEach { runCatching { it.close() } }
        readers.clear()
        writers.clear()
    }
}
