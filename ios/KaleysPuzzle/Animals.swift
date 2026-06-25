import UIKit

/// Curated animal catalog shared by the picker UI and the image loader.
/// Mirrors `CURATED_ANIMALS` in the web reference build.
enum Animals {

    struct Animal: Identifiable {
        let key: String
        let name: String
        let emoji: String
        /// Unsplash photo id used to fetch a real photo of this animal.
        let unsplashId: String
        /// Three gradient colors used by the procedural fallback for this animal.
        let colors: [UIColor]

        var id: String { key }
    }

    /// The 10 curated animals, in display order.
    static let all: [Animal] = [
        Animal(key: "lion", name: "Lion", emoji: "🦁", unsplashId: "YozNeHM8MaA",
               colors: [UIColor(hex: 0xF4A460), UIColor(hex: 0xCD853F), UIColor(hex: 0xDEB887)]),
        Animal(key: "elephant", name: "Elephant", emoji: "🐘", unsplashId: "u_kMWN-BWyU",
               colors: [UIColor(hex: 0x708090), UIColor(hex: 0x778899), UIColor(hex: 0xB0C4DE)]),
        Animal(key: "fox", name: "Fox", emoji: "🦊", unsplashId: "OYGN_PWBf4k",
               colors: [UIColor(hex: 0xFF8C00), UIColor(hex: 0xFF6347), UIColor(hex: 0xFFD700)]),
        Animal(key: "dolphin", name: "Dolphin", emoji: "🐬", unsplashId: "fikJnGPXxJ0",
               colors: [UIColor(hex: 0x00CED1), UIColor(hex: 0x1E90FF), UIColor(hex: 0x87CEEB)]),
        Animal(key: "owl", name: "Owl", emoji: "🦉", unsplashId: "pG-_La1_PDA",
               colors: [UIColor(hex: 0x2E0854), UIColor(hex: 0x4B0082), UIColor(hex: 0x6A0DAD)]),
        Animal(key: "penguin", name: "Penguin", emoji: "🐧", unsplashId: "dY-IU16GvPY",
               colors: [UIColor(hex: 0x4682B4), UIColor(hex: 0xB0E0E6), UIColor(hex: 0xF0F8FF)]),
        Animal(key: "tiger", name: "Tiger", emoji: "🐯", unsplashId: "MCYBfbRVYeU",
               colors: [UIColor(hex: 0xFF8C00), UIColor(hex: 0xFF4500), UIColor(hex: 0xFFD700)]),
        Animal(key: "bear", name: "Bear", emoji: "🐻", unsplashId: "eLiJnXFBisc",
               colors: [UIColor(hex: 0x228B22), UIColor(hex: 0x2E8B57), UIColor(hex: 0x90EE90)]),
        Animal(key: "cat", name: "Cat", emoji: "🐱", unsplashId: "75715CVEJhI",
               colors: [UIColor(hex: 0xFF69B4), UIColor(hex: 0xFFB6C1), UIColor(hex: 0xFFC0CB)]),
        Animal(key: "wolf", name: "Wolf", emoji: "🐺", unsplashId: "SIgX-FASxps",
               colors: [UIColor(hex: 0x2F4F4F), UIColor(hex: 0x696969), UIColor(hex: 0xA9A9A9)]),
    ]

    /// Special "Surprise me" tile key.
    static let surpriseKey = "surprise"

    static func animal(forKey key: String) -> Animal {
        return all.first(where: { $0.key == key }) ?? all.randomElement()!
    }

    /// Resolve a chosen key (possibly "surprise") to a concrete animal.
    static func resolve(_ key: String) -> Animal {
        if key == surpriseKey { return all.randomElement()! }
        return animal(forKey: key)
    }
}
