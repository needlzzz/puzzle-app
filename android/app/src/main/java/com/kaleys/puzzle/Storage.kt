package com.kaleys.puzzle

import android.content.Context
import android.content.SharedPreferences

/**
 * Lightweight persistent settings + collection storage backed by
 * SharedPreferences. Mirrors the iOS Storage helper.
 */
class Storage(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    var isMuted: Boolean
        get() = prefs.getBoolean(KEY_MUTED, false)
        set(value) = prefs.edit().putBoolean(KEY_MUTED, value).apply()

    /** The timer is hidden by default for a calmer, pressure-free experience. */
    var showTimer: Boolean
        get() = prefs.getBoolean(KEY_SHOW_TIMER, false)
        set(value) = prefs.edit().putBoolean(KEY_SHOW_TIMER, value).apply()

    var tutorialSeen: Boolean
        get() = prefs.getBoolean(KEY_TUTORIAL_SEEN, false)
        set(value) = prefs.edit().putBoolean(KEY_TUTORIAL_SEEN, value).apply()

    fun collection(): MutableSet<String> {
        // Defensive copy — SharedPreferences returns an immutable/shared set.
        return HashSet(prefs.getStringSet(KEY_COLLECTION, emptySet()) ?: emptySet())
    }

    fun addToCollection(key: String) {
        if (key.isEmpty() || key == AnimalImageGenerator.SURPRISE_KEY) return
        val current = collection()
        current.add(key)
        prefs.edit().putStringSet(KEY_COLLECTION, current).apply()
    }

    fun isCollected(key: String): Boolean = collection().contains(key)

    companion object {
        private const val PREFS = "kaleys_puzzle_prefs"
        private const val KEY_MUTED = "kp_muted"
        private const val KEY_SHOW_TIMER = "kp_show_timer"
        private const val KEY_TUTORIAL_SEEN = "kp_tutorial_seen"
        private const val KEY_COLLECTION = "kp_collection"
    }
}
