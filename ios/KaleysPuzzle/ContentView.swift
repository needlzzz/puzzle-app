import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PuzzleViewModel()

    var body: some View {
        ZStack {
            // Wood background
            LinearGradient(
                colors: [
                    Color(hex: 0x8B6914),
                    Color(hex: 0xA0782C),
                    Color(hex: 0x6B4F1D),
                    Color(hex: 0x9E7B2F),
                    Color(hex: 0x7A5E22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch viewModel.screen {
            case .start:
                StartScreenView(viewModel: viewModel)
            case .game:
                GameScreenView(viewModel: viewModel)
            case .win:
                GameScreenView(viewModel: viewModel)
                WinOverlayView(viewModel: viewModel)
            }
        }
        .statusBarHidden(viewModel.screen != .start)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            viewModel.onPause()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewModel.onResume()
        }
    }
}

// MARK: - Start Screen

struct StartScreenView: View {
    @ObservedObject var viewModel: PuzzleViewModel

    private let difficulties = [
        (label: "20 pieces", count: 20),
        (label: "50 pieces", count: 50),
        (label: "100 pieces", count: 100),
        (label: "150 pieces", count: 150),
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("🧩 Kaley's Puzzle App")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(Color(hex: 0xFFF8E7))
                .shadow(color: .black.opacity(0.5), radius: 6, x: 2, y: 2)

            Text("Made with love by your PAPA ❤️")
                .font(.system(size: 16))
                .italic()
                .foregroundColor(Color(hex: 0xFFD7A8))

            Spacer().frame(height: 20)

            Text("Choose your difficulty")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: 0xE8D5A3))

            HStack(spacing: 12) {
                ForEach(difficulties, id: \.count) { diff in
                    DifficultyButton(label: diff.label) {
                        Task {
                            await viewModel.startNewGame(pieceCount: diff.count)
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }

            if viewModel.isLoading {
                VStack(spacing: 12) {
                    Text("Loading animal image...")
                        .foregroundColor(Color(hex: 0xFFF8E7))
                    ProgressView()
                        .tint(Color(hex: 0xFFF8E7))
                }
                .padding(.top, 16)
            }
        }
        .padding(24)
    }
}

struct DifficultyButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: 0xFFF8E7))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(hex: 0xFFF8E7).opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: 0xFFF8E7), lineWidth: 2)
                )
        }
    }
}

// MARK: - Game Screen

struct GameScreenView: View {
    @ObservedObject var viewModel: PuzzleViewModel

    var body: some View {
        ZStack {
            PuzzleCanvasView(viewModel: viewModel)
                .ignoresSafeArea()

            // UI Bar
            VStack {
                HStack(spacing: 16) {
                    Text(viewModel.timerString)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color(hex: 0xFFF8E7))

                    Text("\(viewModel.placedPieces) / \(viewModel.totalPieces)")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color(hex: 0xFFF8E7))

                    BarButton(label: "🖼 Hint", isActive: viewModel.showHint) {
                        viewModel.showHint.toggle()
                    }

                    BarButton(label: "🔄 New", isActive: false) {
                        viewModel.resetToStart()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.8))
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
                .padding(.top, 12)

                Spacer()
            }
        }
    }
}

struct BarButton: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: 0xFFF8E7))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(hex: 0xFFF8E7).opacity(isActive ? 0.35 : 0.1))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: 0xFFF8E7).opacity(isActive ? 1 : 0.4), lineWidth: 1)
                )
        }
    }
}

// MARK: - Win Overlay

struct WinOverlayView: View {
    @ObservedObject var viewModel: PuzzleViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            ConfettiOverlay(isActive: true)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 16) {
                Text("🎉 Puzzle Complete!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: 0xFFF8E7))

                Text("Time: \(viewModel.getElapsedString())")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: 0xE8D5A3))

                Text("Pieces: \(viewModel.totalPieces)")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: 0xE8D5A3))

                Button {
                    viewModel.resetToStart()
                } label: {
                    Text("New Puzzle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: 0xFFF8E7))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color(hex: 0xFFF8E7).opacity(0.15))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: 0xFFF8E7), lineWidth: 2)
                        )
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
            .background(Color(red: 40/255, green: 30/255, blue: 10/255).opacity(0.85))
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(hex: 0xFFF8E7).opacity(0.3), lineWidth: 2)
            )
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ContentView()
}
