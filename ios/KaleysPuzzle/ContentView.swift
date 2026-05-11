import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PuzzleViewModel()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            // Dark background
            Color(hex: 0x121212)
                .ignoresSafeArea()

            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
            } else {
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

// MARK: - Splash Screen

struct SplashView: View {
    let onFinished: () -> Void

    @State private var showHey = false
    @State private var showMessage = false
    @State private var showEmoji = false

    var body: some View {
        VStack(spacing: 24) {
            if showEmoji {
                Text("🧩")
                    .font(.system(size: 64))
                    .transition(.scale.combined(with: .opacity))
            }

            if showHey {
                Text("Hey Kaley!")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showMessage {
                Text("Get ready for some puzzle fun!")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: 0xBBBBBB))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
                showEmoji = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.7)) {
                showHey = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.2)) {
                showMessage = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                onFinished()
            }
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
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Made with love by your PAPA ❤️")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .italic()
                .foregroundColor(Color(hex: 0xBBBBBB))

            Spacer().frame(height: 20)

            Text("Choose your difficulty")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: 0x999999))

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
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: 0xBBBBBB))
                    ProgressView()
                        .tint(.white)
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
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
        }
    }
}

// MARK: - Game Screen

struct GameScreenView: View {
    @ObservedObject var viewModel: PuzzleViewModel
    @State private var boardView: PuzzleBoardUIView?

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Puzzle board area (3/4 of screen)
                ZStack {
                    PuzzleBoardRepresentable(viewModel: viewModel, boardViewBinding: $boardView)

                    // UI Bar overlay
                    VStack {
                        HStack(spacing: 16) {
                            Text(viewModel.timerString)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white)

                            Text("\(viewModel.placedPieces) / \(viewModel.totalPieces)")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white)

                            BarButton(label: "🖼 Hint", isActive: viewModel.showHint) {
                                viewModel.showHint.toggle()
                            }

                            BarButton(label: "🔄 New", isActive: false) {
                                viewModel.resetToStart()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color(hex: 0x1E1E1E).opacity(0.9))
                        .clipShape(Capsule())
                        .padding(.top, 8)

                        Spacer()
                    }
                }
                .frame(height: geo.size.height * 0.75)

                // Piece tray (bottom 1/4)
                PieceTrayRepresentable(viewModel: viewModel, boardView: boardView)
                    .frame(height: geo.size.height * 0.25)
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}

/// Wrapper that exposes the underlying PuzzleBoardUIView reference
struct PuzzleBoardRepresentable: UIViewRepresentable {
    @ObservedObject var viewModel: PuzzleViewModel
    @Binding var boardViewBinding: PuzzleBoardUIView?

    func makeUIView(context: Context) -> PuzzleBoardUIView {
        let view = PuzzleBoardUIView()
        view.viewModel = viewModel
        view.backgroundColor = UIColor(hex: 0x1A1A1A)
        view.isMultipleTouchEnabled = true
        DispatchQueue.main.async {
            boardViewBinding = view
        }
        return view
    }

    func updateUIView(_ uiView: PuzzleBoardUIView, context: Context) {
        uiView.viewModel = viewModel
        uiView.initializeIfNeeded()
        uiView.setNeedsDisplay()
    }
}

/// Wrapper for the piece tray
struct PieceTrayRepresentable: UIViewRepresentable {
    @ObservedObject var viewModel: PuzzleViewModel
    var boardView: PuzzleBoardUIView?

    func makeUIView(context: Context) -> PieceTrayUIView {
        let view = PieceTrayUIView()
        view.viewModel = viewModel
        view.boardView = boardView
        view.backgroundColor = UIColor(hex: 0x0F0F0F)
        return view
    }

    func updateUIView(_ uiView: PieceTrayUIView, context: Context) {
        uiView.viewModel = viewModel
        uiView.boardView = boardView
        uiView.refreshPieces()
    }
}

struct BarButton: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(isActive ? 0.25 : 0.08))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(isActive ? 0.8 : 0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Win Overlay

struct WinOverlayView: View {
    @ObservedObject var viewModel: PuzzleViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            ConfettiOverlay(isActive: true)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 16) {
                Text("🎉 Puzzle Complete!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Time: \(viewModel.getElapsedString())")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: 0xBBBBBB))

                Text("Pieces: \(viewModel.totalPieces)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: 0xBBBBBB))

                Button {
                    viewModel.resetToStart()
                } label: {
                    Text("New Puzzle")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                        )
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 40)
            .background(Color(hex: 0x1E1E1E).opacity(0.95))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
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
