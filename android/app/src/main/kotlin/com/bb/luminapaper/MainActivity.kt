package com.bb.luminapaper

import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.bb.luminapaper/wallpaper"
    private val TAG = "MainActivityWallpaper"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setStaticWallpaper" -> {
                    val filePath = call.argument<String>("filePath")
                    val target = call.argument<String>("target") ?: "both"

                    if (filePath.isNullOrEmpty() || !File(filePath).exists()) {
                        result.error("INVALID_FILE", "Wallpaper file does not exist at $filePath", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        var bitmap: android.graphics.Bitmap? = null
                        try {
                            bitmap = BitmapFactory.decodeFile(filePath)
                            if (bitmap == null) {
                                runOnUiThread { result.error("DECODE_ERROR", "Failed to decode image file", null) }
                                return@Thread
                            }

                            val wm = WallpaperManager.getInstance(applicationContext)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                val which = when (target.lowercase()) {
                                    "home" -> WallpaperManager.FLAG_SYSTEM
                                    "lock" -> WallpaperManager.FLAG_LOCK
                                    else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                                }
                                wm.setBitmap(bitmap, null, true, which)
                            } else {
                                wm.setBitmap(bitmap)
                            }

                            runOnUiThread { result.success(true) }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error setting static wallpaper: ${e.message}", e)
                            runOnUiThread { result.error("SET_FAILED", e.message, null) }
                        } finally {
                            try {
                                bitmap?.recycle()
                            } catch (re: Exception) {
                                Log.w(TAG, "Error recycling bitmap: ${re.message}")
                            }
                        }
                    }.start()
                }

                "setLiveWallpaper" -> {
                    val videoPath = call.argument<String>("videoPath")
                    if (videoPath.isNullOrEmpty() || !File(videoPath).exists()) {
                        result.error("INVALID_VIDEO", "Video file does not exist at $videoPath", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val prefs = getSharedPreferences(LiveWallpaperService.PREFS_NAME, Context.MODE_PRIVATE)
                        prefs.edit().putString(LiveWallpaperService.KEY_VIDEO_PATH, videoPath).apply()

                        val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
                            putExtra(
                                WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                                ComponentName(applicationContext, LiveWallpaperService::class.java)
                            )
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error launching Live Wallpaper picker: ${e.message}", e)
                        result.error("LIVE_WALLPAPER_FAILED", e.message, null)
                    }
                }

                "setAutoChangerConfig" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val queue = call.argument<List<String>>("queue") ?: emptyList()
                    val target = call.argument<String>("target") ?: "both"

                    try {
                        val prefs = getSharedPreferences(AutoChangeReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                        val queueJoined = queue.joinToString("|||")

                        prefs.edit()
                            .putBoolean(AutoChangeReceiver.KEY_AUTO_ENABLED, enabled)
                            .putString(AutoChangeReceiver.KEY_AUTO_QUEUE, queueJoined)
                            .putString(AutoChangeReceiver.KEY_AUTO_TARGET, target)
                            .apply()

                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error setting auto changer config: ${e.message}", e)
                        result.error("CONFIG_FAILED", e.message, null)
                    }
                }

                "getAutoChangerConfig" -> {
                    try {
                        val prefs = getSharedPreferences(AutoChangeReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                        val enabled = prefs.getBoolean(AutoChangeReceiver.KEY_AUTO_ENABLED, false)
                        val rawQueue = prefs.getString(AutoChangeReceiver.KEY_AUTO_QUEUE, "") ?: ""
                        val target = prefs.getString(AutoChangeReceiver.KEY_AUTO_TARGET, "both") ?: "both"
                        val currentIndex = prefs.getInt(AutoChangeReceiver.KEY_AUTO_INDEX, 0)

                        val queue = if (rawQueue.isBlank()) emptyList<String>() else rawQueue.split("|||")

                        val map = mapOf(
                            "enabled" to enabled,
                            "queue" to queue,
                            "target" to target,
                            "currentIndex" to currentIndex
                        )
                        result.success(map)
                    } catch (e: Exception) {
                        result.error("GET_CONFIG_FAILED", e.message, null)
                    }
                }

                "isLiveWallpaperActive" -> {
                    try {
                        val wm = WallpaperManager.getInstance(applicationContext)
                        val info = wm.wallpaperInfo
                        val isLive = info != null && info.serviceName == LiveWallpaperService::class.java.name
                        result.success(isLive)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
