import SwiftUI

/// Confetti particle animation view using CADisplayLink.
struct ConfettiOverlay: UIViewRepresentable {
    let isActive: Bool

    func makeUIView(context: Context) -> ConfettiUIView {
        let view = ConfettiUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: ConfettiUIView, context: Context) {
        if isActive && !uiView.isRunning {
            uiView.start()
        } else if !isActive && uiView.isRunning {
            uiView.stop()
        }
    }
}

class ConfettiUIView: UIView {

    private struct Particle {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        let size: CGFloat
        let color: UIColor
        var rotation: CGFloat
        let rotSpeed: CGFloat
        let gravity: CGFloat
        var life: CGFloat
    }

    private var particles: [Particle] = []
    private var displayLink: CADisplayLink?
    private var frame_count = 0
    private(set) var isRunning = false

    private let colors: [UIColor] = [
        UIColor(hex: 0xFF6B6B),
        UIColor(hex: 0x4ECDC4),
        UIColor(hex: 0x45B7D1),
        UIColor(hex: 0x96CEB4),
        UIColor(hex: 0xFFEAA7),
        UIColor(hex: 0xDDA0DD),
        UIColor(hex: 0xFF8C00),
        UIColor(hex: 0x7B68EE),
    ]

    func start() {
        particles.removeAll()
        frame_count = 0
        isRunning = true

        let cx = bounds.width / 2
        let cy = bounds.height / 2

        for _ in 0..<200 {
            particles.append(Particle(
                x: cx + CGFloat.random(in: -100...100),
                y: cy,
                vx: CGFloat.random(in: -8...8),
                vy: -CGFloat.random(in: 4...22),
                size: CGFloat.random(in: 4...12),
                color: colors.randomElement()!,
                rotation: CGFloat.random(in: 0...360),
                rotSpeed: CGFloat.random(in: -6...6),
                gravity: CGFloat.random(in: 0.3...0.5),
                life: 1.0
            ))
        }

        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
        particles.removeAll()
        setNeedsDisplay()
    }

    @objc private func tick() {
        frame_count += 1
        var alive = false

        for i in particles.indices {
            guard particles[i].life > 0 else { continue }
            alive = true
            particles[i].x += particles[i].vx
            particles[i].y += particles[i].vy
            particles[i].vy += particles[i].gravity
            particles[i].vx *= 0.99
            particles[i].rotation += particles[i].rotSpeed
            particles[i].life -= 0.005
        }

        if !alive || frame_count >= 300 {
            stop()
            return
        }

        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), isRunning else { return }

        for p in particles {
            guard p.life > 0 else { continue }
            ctx.saveGState()
            ctx.translateBy(x: p.x, y: p.y)
            ctx.rotate(by: p.rotation * .pi / 180)
            ctx.setAlpha(max(0, p.life))
            ctx.setFillColor(p.color.cgColor)
            ctx.fill(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2))
            ctx.restoreGState()
        }
    }
}
