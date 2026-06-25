import AVFoundation
import UIKit

/// Manages puzzle sound effects and haptics.
/// Honors the global mute setting and adds gentle haptic feedback so the
/// experience stays delightful even with the sound off.
final class SoundManager {
    static let shared = SoundManager()

    private var players: [String: AVAudioPlayer] = [:]
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notify = UINotificationFeedbackGenerator()

    /// Mirrors the persisted mute flag; read once at launch, kept in sync by the UI.
    var isMuted: Bool = Storage.isMuted

    private init() {
        prepareSound("snap")
        prepareSound("pickup")
        prepareSound("win")
        prepareSound("drop")
    }

    private func prepareSound(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.volume = 0.6
            players[name] = player
        } catch {
            print("Failed to load sound: \(name)")
        }
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        Storage.isMuted = muted
    }

    func playSnap() {
        play("snap")
        impactLight.impactOccurred()
    }

    func playPickup() {
        play("pickup")
    }

    func playWin() {
        play("win")
        notify.notificationOccurred(.success)
    }

    func playDrop() {
        play("drop")
    }

    /// Played when the child crosses a progress milestone (25%/50%/75%/edges done).
    func playMilestone() {
        play("snap")
        impactMedium.impactOccurred()
    }

    private func play(_ name: String) {
        guard !isMuted, let player = players[name] else { return }
        player.currentTime = 0
        player.play()
    }
}
