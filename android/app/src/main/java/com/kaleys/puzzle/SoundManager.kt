package com.kaleys.puzzle

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator

/**
 * Synthesizes short sound effects (via ToneGenerator — no audio assets needed)
 * and haptic feedback (via Vibrator). All output is gated behind a mute flag,
 * which is persisted through Storage. Mirrors the iOS SoundManager.
 */
class SoundManager(context: Context, private val storage: Storage) {

    private val appContext = context.applicationContext

    var isMuted: Boolean = storage.isMuted
        private set

    private val toneGenerator: ToneGenerator? = try {
        ToneGenerator(AudioManager.STREAM_MUSIC, 70)
    } catch (e: RuntimeException) {
        // ToneGenerator can throw if the audio service is unavailable.
        null
    }

    private val vibrator: Vibrator? =
        appContext.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator

    fun setMuted(muted: Boolean) {
        isMuted = muted
        storage.isMuted = muted
    }

    /** A piece locked into place. */
    fun playSnap() {
        if (isMuted) return
        playTone(ToneGenerator.TONE_PROP_BEEP, 90)
        haptic(20)
    }

    /** A piece picked up / dropped without snapping. */
    fun playDrop() {
        if (isMuted) return
        haptic(12)
    }

    /** Progress milestone reached. */
    fun playMilestone() {
        if (isMuted) return
        playTone(ToneGenerator.TONE_PROP_BEEP2, 120)
        haptic(35)
    }

    /** Puzzle completed. */
    fun playWin() {
        if (isMuted) return
        playTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 250)
        haptic(60)
    }

    fun release() {
        toneGenerator?.release()
    }

    private fun playTone(toneType: Int, durationMs: Int) {
        try {
            toneGenerator?.startTone(toneType, durationMs)
        } catch (e: RuntimeException) {
            // Ignore — sound is non-essential.
        }
    }

    @Suppress("DEPRECATION")
    private fun haptic(durationMs: Long) {
        val v = vibrator ?: return
        if (!v.hasVibrator()) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                v.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                v.vibrate(durationMs)
            }
        } catch (e: Exception) {
            // Ignore — haptics are non-essential.
        }
    }
}
