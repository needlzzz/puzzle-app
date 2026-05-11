import SwiftUI
import Combine

/// Holds puzzle game state. Published properties drive SwiftUI updates.
@MainActor
final class PuzzleViewModel: ObservableObject {

    enum Screen {
        case start
        case game
        case win
    }

    // MARK: - Published State

    @Published var screen: Screen = .start
    @Published var placedPieces: Int = 0
    @Published var totalPieces: Int = 0
    @Published var showHint: Bool = false
    @Published var timerString: String = "⏱ 00:00"
    @Published var isLoading: Bool = false
    @Published var puzzleImage: UIImage?

    // MARK: - Game Configuration

    var cols: Int = 0
    var rows: Int = 0
    var pieceW: CGFloat = 0
    var pieceH: CGFloat = 0
    var puzzleX: CGFloat = 0
    var puzzleY: CGFloat = 0

    // MARK: - Game State

    var gameState: PuzzleEngine.GameState?
    var edges: PuzzleEngine.Edges?
    var gameActive: Bool = false

    // MARK: - Camera

    var cameraX: CGFloat = 0
    var cameraY: CGFloat = 0
    var cameraZoom: CGFloat = 1

    // MARK: - Timer

    private var timerStartDate: Date = Date()
    private var elapsedBeforePause: TimeInterval = 0
    private var timerCancellable: AnyCancellable?

    // MARK: - Game Lifecycle

    func startNewGame(pieceCount: Int) async {
        isLoading = true
        screen = .game

        // Load image
        let image = await AnimalImageLoader.loadImage()
        puzzleImage = image

        let grid = PuzzleEngine.computeGrid(count: pieceCount)
        cols = grid.cols
        rows = grid.rows
        totalPieces = cols * rows
        placedPieces = 0
        showHint = false
        gameActive = true
        isLoading = false

        timerStartDate = Date()
        elapsedBeforePause = 0
        startTimer()
    }

    func initLayout(canvasW: CGFloat, canvasH: CGFloat) {
        let imageAspect = CGFloat(PuzzleEngine.imageW) / CGFloat(PuzzleEngine.imageH)
        let maxPuzzleW = canvasW * 0.5
        let maxPuzzleH = canvasH * 0.5

        let puzzleTotalW: CGFloat
        let puzzleTotalH: CGFloat
        if maxPuzzleW / maxPuzzleH > imageAspect {
            puzzleTotalH = maxPuzzleH
            puzzleTotalW = maxPuzzleH * imageAspect
        } else {
            puzzleTotalW = maxPuzzleW
            puzzleTotalH = maxPuzzleW / imageAspect
        }
        pieceW = puzzleTotalW / CGFloat(cols)
        pieceH = puzzleTotalH / CGFloat(rows)
        puzzleX = (canvasW / 2) - (CGFloat(cols) * pieceW / 2)
        puzzleY = (canvasH / 2) - (CGFloat(rows) * pieceH / 2)

        cameraX = canvasW / 2
        cameraY = canvasH / 2
        cameraZoom = 1

        edges = PuzzleEngine.generateEdges(rows: rows, cols: cols)
        gameState = PuzzleEngine.createGameState(cols: cols, rows: rows,
                                                 pieceW: pieceW, pieceH: pieceH,
                                                 puzzleX: puzzleX, puzzleY: puzzleY)

        // Scatter pieces around the puzzle area
        let margin = max(pieceW, pieceH) * 1.5
        gameState?.pieces.forEach { piece in
            let side = Int.random(in: 0...3)
            switch side {
            case 0:
                piece.x = puzzleX - margin - CGFloat.random(in: 0...(margin * 2))
                piece.y = puzzleY + CGFloat.random(in: 0...(CGFloat(rows) * pieceH))
            case 1:
                piece.x = puzzleX + CGFloat(cols) * pieceW + margin + CGFloat.random(in: 0...(margin * 2))
                piece.y = puzzleY + CGFloat.random(in: 0...(CGFloat(rows) * pieceH))
            case 2:
                piece.x = puzzleX + CGFloat.random(in: 0...(CGFloat(cols) * pieceW))
                piece.y = puzzleY - margin - CGFloat.random(in: 0...(margin * 2))
            default:
                piece.x = puzzleX + CGFloat.random(in: 0...(CGFloat(cols) * pieceW))
                piece.y = puzzleY + CGFloat(rows) * pieceH + margin + CGFloat.random(in: 0...(margin * 2))
            }
        }
    }

    func trySnapGroup(_ group: PuzzleEngine.Group) {
        guard var groups = gameState?.groups,
              let piecesById = gameState?.piecesById else { return }

        let result = PuzzleEngine.trySnap(movedGroup: group,
                                          cols: cols, rows: rows,
                                          pieceW: pieceW, pieceH: pieceH,
                                          piecesById: piecesById,
                                          groups: &groups)
        gameState?.groups = groups

        if result.placedCount > 0 {
            placedPieces += result.placedCount
            if placedPieces >= totalPieces {
                gameActive = false
                stopTimer()
                screen = .win
            }
        }
    }

    func resetToStart() {
        gameActive = false
        stopTimer()
        puzzleImage = nil
        gameState = nil
        edges = nil
        screen = .start
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timerStartDate = Date()
        updateTimerString()
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateTimerString()
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        if gameActive {
            elapsedBeforePause = getElapsed()
        }
    }

    private func getElapsed() -> TimeInterval {
        if gameActive {
            return elapsedBeforePause + Date().timeIntervalSince(timerStartDate)
        }
        return elapsedBeforePause
    }

    private func updateTimerString() {
        let total = Int(getElapsed())
        let mins = String(format: "%02d", total / 60)
        let secs = String(format: "%02d", total % 60)
        timerString = "⏱ \(mins):\(secs)"
    }

    func getElapsedString() -> String {
        let total = Int(getElapsed())
        let mins = total / 60
        let secs = total % 60
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }

    func onPause() {
        if gameActive {
            elapsedBeforePause = getElapsed()
            timerCancellable?.cancel()
            timerCancellable = nil
        }
    }

    func onResume() {
        if gameActive {
            timerStartDate = Date()
            startTimer()
        }
    }
}
