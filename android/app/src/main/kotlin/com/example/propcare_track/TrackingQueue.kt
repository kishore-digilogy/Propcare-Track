package com.example.propcare_track

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Append-only JSON-lines queue that survives process death.
 *
 * The Flutter side drains this queue, inserts the records into sqflite and then
 * acknowledges the ids. Every record carries a UUID so a replay is idempotent.
 */
object TrackingQueue {
    private const val FILE_NAME = "tracking_queue.jsonl"
    private val lock = Any()

    private fun file(context: Context): File = File(context.filesDir, FILE_NAME)

    fun append(context: Context, record: JSONObject) {
        synchronized(lock) {
            try {
                file(context).appendText(record.toString() + "\n")
            } catch (_: Exception) {
                // A full disk must never take the tracking service down.
            }
        }
    }

    fun read(context: Context): List<JSONObject> = synchronized(lock) {
        val source = file(context)
        if (!source.exists()) return emptyList()
        try {
            source.readLines().mapNotNull { line ->
                if (line.isBlank()) null else runCatching { JSONObject(line) }.getOrNull()
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun pending(context: Context): List<Map<String, Any?>> = read(context).map { toMap(it) }

    fun ack(context: Context, ids: Set<String>) {
        if (ids.isEmpty()) return
        synchronized(lock) {
            val source = file(context)
            if (!source.exists()) return
            try {
                val kept = source.readLines().filter { line ->
                    if (line.isBlank()) return@filter false
                    val record = runCatching { JSONObject(line) }.getOrNull()
                    record == null || record.optString("id") !in ids
                }
                source.writeText(if (kept.isEmpty()) "" else kept.joinToString("\n") + "\n")
            } catch (_: Exception) {
                // Keep the file untouched; the next drain retries.
            }
        }
    }

    fun size(context: Context): Int = read(context).size

    /** StandardMessageCodec only understands plain maps/lists. */
    fun toMap(source: JSONObject): Map<String, Any?> {
        val map = HashMap<String, Any?>()
        val keys = source.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            map[key] = when (val value = source.get(key)) {
                is JSONObject -> toMap(value)
                is JSONArray -> (0 until value.length()).map { index -> value.get(index) }
                JSONObject.NULL -> null
                else -> value
            }
        }
        return map
    }
}
