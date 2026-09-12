package com.bb.luminapaper

import android.content.Context
import android.media.MediaPlayer
import android.net.Uri
import android.service.wallpaper.WallpaperService
import android.util.Log
import android.view.SurfaceHolder
import java.io.File

class LiveWallpaperService : WallpaperService() {

    companion object {
        const val TAG = "LiveWallpaperService"
        const val PREFS_NAME = "lumina_wallpaper_prefs"
        const val KEY_VIDEO_PATH = "live_video_path"
    }

    override fun onCreateEngine(): Engine {
        return VideoWallpaperEngine()
    }

    inner class VideoWallpaperEngine : Engine() {
        private var mediaPlayer: MediaPlayer? = null
        private var isVisibleState = false

        override fun onSurfaceCreated(holder: SurfaceHolder) {
            super.onSurfaceCreated(holder)
            startVideo(holder)
        }

        override fun onVisibilityChanged(visible: Boolean) {
            super.onVisibilityChanged(visible)
            isVisibleState = visible
            try {
                if (visible) {
                    mediaPlayer?.start()
                } else {
                    mediaPlayer?.pause()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error toggling visibility: ${e.message}", e)
            }
        }

        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            super.onSurfaceDestroyed(holder)
            releasePlayer()
        }

        override fun onDestroy() {
            super.onDestroy()
            releasePlayer()
        }

        private fun startVideo(holder: SurfaceHolder) {
            releasePlayer()
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val videoPath = prefs.getString(KEY_VIDEO_PATH, null)

            if (videoPath.isNullOrEmpty() || !File(videoPath).exists()) {
                Log.w(TAG, "Video file not found or invalid: $videoPath")
                return
            }

            try {
                mediaPlayer = MediaPlayer().apply {
                    setSurface(holder.surface)
                    setDataSource(applicationContext, Uri.fromFile(File(videoPath)))
                    isLooping = true
                    setVolume(0f, 0f) // Audio muted for zero sound distraction
                    setOnPreparedListener { mp ->
                        mp.isLooping = true
                        if (isVisibleState) {
                            mp.start()
                        }
                    }
                    setOnErrorListener { _, what, extra ->
                        Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                        true
                    }
                    prepareAsync()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize MediaPlayer: ${e.message}", e)
            }
        }

        private fun releasePlayer() {
            synchronized(this) {
                try {
                    mediaPlayer?.apply {
                        if (isPlaying) {
                            stop()
                        }
                        reset()
                        release()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error releasing MediaPlayer: ${e.message}", e)
                } finally {
                    mediaPlayer = null
                }
            }
        }
    }
}
