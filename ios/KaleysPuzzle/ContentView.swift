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

                // Global overlays
                if viewModel.showConfirmNew {
                    ConfirmNewOverlayView(viewModel: viewModel)
                        .transition(.opacity)
                }
                if viewModel.showTutorial {
                    TutorialOverlayView(viewModel: viewModel)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showTutorial)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showConfirmNew)
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

    // Kid-friendly emoji difficulty tiers (chick → eagle).
    private let difficulties = [
        (emoji: "🐣", label: "Tiny", count: 12),
        (emoji: "🐥", label: "Small", count: 20),
        (emoji: "🐔", label: "Medium", count: 50),
        (emoji: "🦅", label: "Big", count: 100),
    ]

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("🧩 Kaley's Puzzle App")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Made with love by your PAPA ❤️")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .italic()
                    .foregroundColor(Color(hex: 0xBBBBBB))

                // Animal picker
                Text("Pick an animal")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: 0xDDDDDD))
                    .padding(.top, 6)

                LazyVGrid(columns: columns, spacing: 12) {
                    AnimalTile(emoji: "🎲", name: "Surprise",
                               isSelected: viewModel.selectedAnimalKey == Animals.surpriseKey,
                               isCollected: false) {
                        viewModel.selectedAnimalKey = Animals.surpriseKey
                    }
                    ForEach(Animals.all) { animal in
                        AnimalTile(emoji: animal.emoji, name: animal.name,
                                   isSelected: viewModel.selectedAnimalKey == animal.key,
                                   isCollected: viewModel.collection.contains(animal.key)) {
                            viewModel.selectedAnimalKey = animal.key
                        }
                    }
                }
                .padding(.horizontal, 4)

                // Difficulty picker
                Text("How big?")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: 0xDDDDDD))
                    .padding(.top, 6)

                HStack(spacing: 12) {
                    ForEach(difficulties, id: \.count) { diff in
                        DifficultyButton(emoji: diff.emoji, label: diff.label) {
                            Task {
                                await viewModel.startNewGame(pieceCount: diff.count,
                                                             animalKey: viewModel.selectedAnimalKey)
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }

                // Settings row
                HStack(spacing: 16) {
                    SettingChip(icon: viewModel.isMuted ? "🔇" : "🔊",
                                label: viewModel.isMuted ? "Sound off" : "Sound on") {
                        viewModel.toggleMute()
                    }
                    SettingChip(icon: "⏱",
                                label: viewModel.showTimer ? "Timer on" : "Timer off") {
                        viewModel.toggleShowTimer()
                    }
                    SettingChip(icon: "❓", label: "How to play") {
                        viewModel.replayTutorial()
                    }
                }
                .padding(.top, 8)

                // Collection summary
                if !viewModel.collection.isEmpty {
                    VStack(spacing: 6) {
                        Text("Your animals ⭐\(viewModel.collection.count)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: 0x999999))
                        Text(collectedEmojis)
                            .font(.system(size: 24))
                    }
                    .padding(.top, 8)
                }

                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        Text("Finding your animal…")
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
        .onAppear {
            viewModel.showTutorialIfFirstRun()
        }
    }

    private var collectedEmojis: String {
        Animals.all
            .filter { viewModel.collection.contains($0.key) }
            .map { $0.emoji }
            .joined(separator: " ")
    }
}

struct AnimalTile: View {
    let emoji: String
    let name: String
    let isSelected: Bool
    let isCollected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Text(emoji)
                        .font(.system(size: 36))
                    if isCollected {
                        Text("⭐")
                            .font(.system(size: 14))
                            .offset(x: 8, y: -6)
                    }
                }
                Text(name)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 76, height: 76)
            .background(Color.white.opacity(isSelected ? 0.22 : 0.07))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color(hex: 0x00D4AA) : Color.white.opacity(0.25),
                            lineWidth: isSelected ? 2.5 : 1)
            )
        }
    }
}

struct SettingChip: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(icon).font(.system(size: 20))
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: 0xBBBBBB))
            }
        }
    }
}

struct DifficultyButton: View {
    let emoji: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji).font(.system(size: 30))
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 70, height: 78)
            .background(Color.white.opacity(0.08))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
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
                        HStack(spacing: 14) {
                            if viewModel.showTimer {
                                Text(viewModel.timerString)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            PawProgressBar(progress: viewModel.progress)
                                .frame(width: 120)

                            BarButton(label: "🧩 Edges", isActive: viewModel.traySortMode == .edgesFirst) {
                                viewModel.toggleTraySortMode()
                            }

                            BarButton(label: "🖼 Peek", isActive: viewModel.showHint) {
                                viewModel.showHint.toggle()
                            }

                            BarButton(label: "🔄 New", isActive: false) {
                                viewModel.requestNewPuzzle()
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color(hex: 0x1E1E1E).opacity(0.9))
                        .clipShape(Capsule())
                        .padding(.top, 8)

                        // Milestone celebration banner
                        if let text = viewModel.milestoneText {
                            Text(text)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(Color(hex: 0x00D4AA).opacity(0.9))
                                .clipShape(Capsule())
                                .padding(.top, 8)
                                .transition(.scale.combined(with: .opacity))
                        }

                        Spacer()
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: viewModel.milestoneText)
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

            VStack(spacing: 14) {
                Text(viewModel.activeAnimal.emoji)
                    .font(.system(size: 64))

                Text("You did it! 🎉")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("You finished the \(viewModel.activeAnimal.name)!")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: 0xBBBBBB))

                if viewModel.showTimer {
                    Text("Time: \(viewModel.getElapsedString())")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: 0x999999))
                }

                VStack(spacing: 10) {
                    Button {
                        Task { await viewModel.playAgain() }
                    } label: {
                        WinButtonLabel(text: "🔁 Play again", filled: true)
                    }

                    Button {
                        viewModel.resetToStart()
                    } label: {
                        WinButtonLabel(text: "🐾 Choose another", filled: false)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 50)
            .padding(.vertical, 36)
            .background(Color(hex: 0x1E1E1E).opacity(0.95))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

struct WinButtonLabel: View {
    let text: String
    let filled: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(filled ? Color(hex: 0x00D4AA).opacity(0.85) : Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(filled ? 0.0 : 0.5), lineWidth: 1.5)
            )
    }
}

// MARK: - Paw Progress Bar

struct PawProgressBar: View {
    let progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(Color(hex: 0x00D4AA))
                    .frame(width: max(8, geo.size.width * min(1, max(0, progress))))
                Text("🐾")
                    .font(.system(size: 14))
                    .offset(x: max(0, min(geo.size.width - 16, geo.size.width * progress - 8)))
            }
        }
        .frame(height: 16)
    }
}

// MARK: - Tutorial Overlay

struct TutorialOverlayView: View {
    @ObservedObject var viewModel: PuzzleViewModel

    private let steps = [
        ("👆", "Drag a piece from the bottom onto the picture."),
        ("🧩", "When it's close to the right spot, it snaps in!"),
        ("🖼", "Tap Peek to see the whole picture."),
        ("🎉", "Fill the picture to win. Have fun, Kaley!"),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("How to play")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                ForEach(steps, id: \.1) { step in
                    HStack(spacing: 14) {
                        Text(step.0).font(.system(size: 30))
                        Text(step.1)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: 0xDDDDDD))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }

                Button {
                    viewModel.dismissTutorial()
                } label: {
                    Text("Let's go! 🚀")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: 0x00D4AA).opacity(0.9))
                        .cornerRadius(14)
                }
                .padding(.top, 8)
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(Color(hex: 0x1E1E1E))
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .padding(24)
        }
    }
}

// MARK: - Confirm New Overlay

struct ConfirmNewOverlayView: View {
    @ObservedObject var viewModel: PuzzleViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("🧩").font(.system(size: 44))
                Text("Start a new puzzle?")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("This puzzle will go away.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: 0xBBBBBB))

                HStack(spacing: 12) {
                    Button {
                        viewModel.cancelNewPuzzle()
                    } label: {
                        WinButtonLabel(text: "Keep playing", filled: false)
                    }
                    Button {
                        viewModel.confirmNewPuzzle()
                    } label: {
                        WinButtonLabel(text: "New puzzle", filled: true)
                    }
                }
                .padding(.top, 8)
            }
            .padding(28)
            .frame(maxWidth: 360)
            .background(Color(hex: 0x1E1E1E))
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .padding(24)
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
