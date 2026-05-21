import UIKit

/// Loads animal images from network sources with procedural fallback.
/// Port of the web app's image loading strategy.
enum AnimalImageLoader {

    private static let unsplashAnimalIDs = [
        "YozNeHM8MaA",  // lion
        "u_kMWN-BWyU",  // elephant
        "OYGN_PWBf4k",  // fox
        "fikJnGPXxJ0",  // dolphin
        "pG-_La1_PDA",  // owl
        "dY-IU16GvPY",  // penguin
        "MCYBfbRVYeU",  // tiger
        "eLiJnXFBisc",  // bear
        "75715CVEJhI",  // cat
        "SIgX-FASxps",  // wolf
    ]

    private static let animalKeywords = [
        "cat", "dog", "lion", "tiger", "elephant", "bird", "fox",
        "wolf", "bear", "deer", "horse", "rabbit", "owl", "dolphin", "penguin"
    ]

    /// Try loading from bundled images first (instant), then network sources.
    static func loadImage() async -> UIImage {
        // Source 1: Bundled animal images (instant, no network needed)
        if let img = loadBundledImage() {
            return img
        }

        let w = PuzzleEngine.imageW
        let h = PuzzleEngine.imageH

        // Source 2: Unsplash
        let unsplashId = unsplashAnimalIDs.randomElement()!
        let unsplashURL = "https://images.unsplash.com/photo-\(unsplashId)?w=\(w)&h=\(h)&fit=crop&auto=format&q=70"
        if let img = await tryLoadImage(from: unsplashURL, timeout: 3) {
            return img
        }

        // Source 3: Lorem Flickr
        let keyword = animalKeywords.randomElement()!
        let flickrURL = "https://loremflickr.com/\(w)/\(h)/\(keyword)"
        if let img = await tryLoadImage(from: flickrURL, timeout: 3) {
            return img
        }

        // Source 4: Picsum
        let picsumId = Int.random(in: 10...209)
        let picsumURL = "https://picsum.photos/id/\(picsumId)/\(w)/\(h)"
        if let img = await tryLoadImage(from: picsumURL, timeout: 3) {
            return img
        }

        // Last resort: procedural fallback
        return generateProceduralImage()
    }

    // MARK: - Bundled Images

    /// Dynamically counts how many animal_N images are available in the asset catalog.
    /// Tries indices starting from 1 until it finds a gap.
    private static var bundledImageCount: Int = {
        var count = 0
        for i in 1...100 {
            if UIImage(named: "user-uploaded-pictures/animal_\(i)") != nil ||
               UIImage(named: "animal_\(i)") != nil {
                count = i
            } else {
                break
            }
        }
        return count
    }()

    /// Load a random bundled animal image from the asset catalog.
    /// Tries random indices until it finds one that exists, or gives up.
    /// Automatically center-crops to 4:3 aspect ratio.
    static func loadBundledImage() -> UIImage? {
        var indices = Array(1...bundledImageCount)
        indices.shuffle()
        for index in indices {
            // Try with namespace prefix
            if let img = UIImage(named: "user-uploaded-pictures/animal_\(index)") {
                return cropTo4x3(img)
            }
            // Try without namespace prefix
            if let img = UIImage(named: "animal_\(index)") {
                return cropTo4x3(img)
            }
        }
        return nil
    }

    // MARK: - Center Crop to 4:3

    /// Center-crops any image to 4:3 aspect ratio (landscape).
    /// If the image is already 4:3, returns it unchanged.
    private static func cropTo4x3(_ image: UIImage) -> UIImage {
        let targetAspect: CGFloat = 4.0 / 3.0
        let imageW = image.size.width
        let imageH = image.size.height
        let imageAspect = imageW / imageH

        // Already close enough to 4:3
        if abs(imageAspect - targetAspect) < 0.01 {
            return image
        }

        let cropRect: CGRect
        if imageAspect > targetAspect {
            // Image is wider than 4:3 — crop sides
            let newW = imageH * targetAspect
            let xOffset = (imageW - newW) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newW, height: imageH)
        } else {
            // Image is taller than 4:3 — crop top/bottom
            let newH = imageW / targetAspect
            let yOffset = (imageH - newH) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: imageW, height: newH)
        }

        // CGImage crop uses pixel coordinates, account for scale
        let scale = image.scale
        let pixelRect = CGRect(x: cropRect.origin.x * scale,
                               y: cropRect.origin.y * scale,
                               width: cropRect.width * scale,
                               height: cropRect.height * scale)

        guard let cgImage = image.cgImage?.cropping(to: pixelRect) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: image.imageOrientation)
    }

    private static func tryLoadImage(from urlString: String, timeout: TimeInterval) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }
            return cropTo4x3(image)
        } catch {
            return nil
        }
    }

    // MARK: - Procedural Fallback

    private struct Animal {
        let name: String
        let emoji: String
        let colors: [UIColor]
    }

    private static let animals: [Animal] = [
        Animal(name: "Lion", emoji: "🦁", colors: [UIColor(hex: 0xF4A460), UIColor(hex: 0xCD853F), UIColor(hex: 0xDEB887)]),
        Animal(name: "Elephant", emoji: "🐘", colors: [UIColor(hex: 0x708090), UIColor(hex: 0x778899), UIColor(hex: 0xB0C4DE)]),
        Animal(name: "Fox", emoji: "🦊", colors: [UIColor(hex: 0xFF8C00), UIColor(hex: 0xFF6347), UIColor(hex: 0xFFD700)]),
        Animal(name: "Dolphin", emoji: "🐬", colors: [UIColor(hex: 0x00CED1), UIColor(hex: 0x1E90FF), UIColor(hex: 0x87CEEB)]),
        Animal(name: "Owl", emoji: "🦉", colors: [UIColor(hex: 0x2E0854), UIColor(hex: 0x4B0082), UIColor(hex: 0x6A0DAD)]),
        Animal(name: "Penguin", emoji: "🐧", colors: [UIColor(hex: 0x4682B4), UIColor(hex: 0xB0E0E6), UIColor(hex: 0xF0F8FF)]),
        Animal(name: "Tiger", emoji: "🐯", colors: [UIColor(hex: 0xFF8C00), UIColor(hex: 0xFF4500), UIColor(hex: 0xFFD700)]),
        Animal(name: "Bear", emoji: "🐻", colors: [UIColor(hex: 0x228B22), UIColor(hex: 0x2E8B57), UIColor(hex: 0x90EE90)]),
        Animal(name: "Cat", emoji: "🐱", colors: [UIColor(hex: 0xFF69B4), UIColor(hex: 0xFFB6C1), UIColor(hex: 0xFFC0CB)]),
        Animal(name: "Wolf", emoji: "🐺", colors: [UIColor(hex: 0x2F4F4F), UIColor(hex: 0x696969), UIColor(hex: 0xA9A9A9)]),
    ]

    static func generateProceduralImage() -> UIImage {
        let w = CGFloat(PuzzleEngine.imageW)
        let h = CGFloat(PuzzleEngine.imageH)
        let animal = animals.randomElement()!

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        return renderer.image { ctx in
            let context = ctx.cgContext

            // Gradient background
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let cgColors = animal.colors.map { $0.cgColor } as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: [0, 0.5, 1]) {
                context.drawLinearGradient(gradient,
                                           start: .zero,
                                           end: CGPoint(x: w, y: h),
                                           options: [])
            }

            // Decorative circles
            for i in 0..<25 {
                let cx = w * 0.1 + CGFloat((i * 131) % Int(w * 0.8))
                let cy = h * 0.1 + CGFloat((i * 97) % Int(h * 0.8))
                let radius = 30 + CGFloat(i * 47 % 70)
                let hue = CGFloat((i * 40) % 360) / 360.0
                let color = UIColor(hue: hue, saturation: 0.6, brightness: 0.65, alpha: 0.2)
                context.setFillColor(color.cgColor)
                context.fillEllipse(in: CGRect(x: cx - radius, y: cy - radius,
                                               width: radius * 2, height: radius * 2))
            }

            // Emoji
            let emojiSize = min(w, h) * 0.35
            let emojiFont = UIFont.systemFont(ofSize: emojiSize)
            let emojiAttr: [NSAttributedString.Key: Any] = [
                .font: emojiFont
            ]
            let emojiStr = animal.emoji as NSString
            let emojiRect = emojiStr.size(withAttributes: emojiAttr)
            let emojiX = (w - emojiRect.width) / 2
            let emojiY = h * 0.42 - emojiRect.height / 2
            emojiStr.draw(at: CGPoint(x: emojiX, y: emojiY), withAttributes: emojiAttr)

            // Name
            let nameFont = UIFont.boldSystemFont(ofSize: h * 0.08)
            let nameAttr: [NSAttributedString.Key: Any] = [
                .font: nameFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            let nameStr = animal.name as NSString
            let nameRect = nameStr.size(withAttributes: nameAttr)
            let nameX = (w - nameRect.width) / 2
            let nameY = h * 0.78 - nameRect.height / 2
            nameStr.draw(at: CGPoint(x: nameX, y: nameY), withAttributes: nameAttr)
        }
    }
}

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
