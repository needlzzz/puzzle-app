import Foundation

/// Lightweight persistence for kid-friendly settings, the first-run tutorial
/// flag, and the solved-animal collection. Backed by UserDefaults.
/// Mirrors `storage.js` in the web reference build and `Storage.kt` on Android.
enum Storage {

    private static let defaults = UserDefaults.standard

    private enum Keys {
        static let muted = "kp_muted"
        static let showTimer = "kp_showTimer"
        static let tutorialSeen = "kp_tutorialSeen"
        static let collection = "kp_collection"
    }

    // MARK: - Settings

    static var isMuted: Bool {
        get { defaults.bool(forKey: Keys.muted) }
        set { defaults.set(newValue, forKey: Keys.muted) }
    }

    /// The timer is hidden by default for a calmer, pressure-free experience.
    static var showTimer: Bool {
        get {
            if defaults.object(forKey: Keys.showTimer) == nil { return false }
            return defaults.bool(forKey: Keys.showTimer)
        }
        set { defaults.set(newValue, forKey: Keys.showTimer) }
    }

    // MARK: - Tutorial

    static var tutorialSeen: Bool {
        get { defaults.bool(forKey: Keys.tutorialSeen) }
        set { defaults.set(newValue, forKey: Keys.tutorialSeen) }
    }

    // MARK: - Collection

    /// Set of animal keys the child has completed at least once.
    static func collection() -> Set<String> {
        let arr = defaults.array(forKey: Keys.collection) as? [String] ?? []
        return Set(arr)
    }

    static func addToCollection(_ animalKey: String) {
        var set = collection()
        set.insert(animalKey)
        defaults.set(Array(set), forKey: Keys.collection)
    }

    static func isCollected(_ animalKey: String) -> Bool {
        return collection().contains(animalKey)
    }
}
