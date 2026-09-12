package com.bb.luminapaper

import android.app.WallpaperManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import java.io.File

class AutoChangeReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "AutoChangeReceiver"
        const val PREFS_NAME = "lumina_wallpaper_prefs"
        const val KEY_AUTO_ENABLED = "auto_changer_enabled"
        const val KEY_AUTO_QUEUE = "auto_changer_queue" // pipe-separated file paths or json
        const val KEY_AUTO_INDEX = "auto_changer_index"
        const val KEY_AUTO_TARGET = "auto_changer_target" // "home", "lock", "both"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action == Intent.ACTION_USER_PRESENT) {
            Log.d(TAG, "Screen unlocked (ACTION_USER_PRESENT), checking auto-changer...")
            Thread {
                processAutoChange(context)
            }.start()
        }
    }

    private fun processAutoChange(context: Context) {
        var bitmap: android.graphics.Bitmap? = null
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isEnabled = prefs.getBoolean(KEY_AUTO_ENABLED, false)
            if (!isEnabled) {
                return
            }

            val queueRaw = prefs.getString(KEY_AUTO_QUEUE, null) ?: return
            val paths = queueRaw.split("|||").filter { it.isNotBlank() && File(it).exists() }
            if (paths.isEmpty()) {
                Log.d(TAG, "Auto-changer queue is empty or files no longer exist.")
                return
            }

            val currentIndex = prefs.getInt(KEY_AUTO_INDEX, 0)
            val safeCurrentIndex = if (currentIndex < 0 || currentIndex >= paths.size) 0 else currentIndex
            val nextIndex = (safeCurrentIndex + 1) % paths.size
            val targetPath = paths[nextIndex]
            val targetMode = prefs.getString(KEY_AUTO_TARGET, "both") ?: "both"

            bitmap = BitmapFactory.decodeFile(targetPath)
            if (bitmap == null) {
                Log.w(TAG, "Could not decode wallpaper file: $targetPath")
                prefs.edit().putInt(KEY_AUTO_INDEX, nextIndex).apply()
                return
            }

            val wallpaperManager = WallpaperManager.getInstance(context)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val which = when (targetMode.lowercase()) {
                    "home" -> WallpaperManager.FLAG_SYSTEM
                    "lock" -> WallpaperManager.FLAG_LOCK
                    else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                }
                wallpaperManager.setBitmap(bitmap, null, true, which)
            } else {
                wallpaperManager.setBitmap(bitmap)
            }

            // Update persisted index
            prefs.edit().putInt(KEY_AUTO_INDEX, nextIndex).apply()
            Log.d(TAG, "Successfully changed wallpaper on screen unlock to index $nextIndex: $targetPath")
        } catch (e: OutOfMemoryError) {
            Log.e(TAG, "OutOfMemoryError during auto change wallpaper", e)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to change wallpaper automatically: ${e.message}", e)
        } finally {
            try {
                bitmap?.recycle()
            } catch (re: Exception) {
                Log.w(TAG, "Error recycling auto changer bitmap: ${re.message}")
            }
        }
    }
}
