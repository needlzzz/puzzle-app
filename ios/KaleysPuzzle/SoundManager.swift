import AVFoundation

/// Manages puzzle sound effects.
final class SoundManager {
    static let shared = SoundManager()

    private var players: [String: AVAudioPlayer] = [:]

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

    func playSnap() {
        play("snap")
    }

    func playPickup() {
        play("pickup")
    }

    func playWin() {
        play("win")
    }

    func playDrop() {
        play("drop")
    }

    private func play(_ name: String) {
        guard let player = players[name] else { return }
        player.currentTime = 0
        player.play()
    }
}
