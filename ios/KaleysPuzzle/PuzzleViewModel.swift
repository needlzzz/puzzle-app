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
    @Published var trayNeedsUpdate: Bool = false

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

    // MARK: - Camera (for the puzzle board area only)

    var cameraX: CGFloat = 0
    var cameraY: CGFloat = 0
    var cameraZoom: CGFloat = 1

    // MARK: - Layout info

    var boardHeight: CGFloat = 0
    var boardWidth: CGFloat = 0

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

    /// Initialize the puzzle layout sized to fit within the board area.
    /// Only called ONCE per game — generates edges and game state.
    func initLayout(canvasW: CGFloat, canvasH: CGFloat) {
        // Prevent double-initialization
        guard gameState == nil else { return }

        boardWidth = canvasW
        boardHeight = canvasH

        let imageAspect = CGFloat(PuzzleEngine.imageW) / CGFloat(PuzzleEngine.imageH)
        // In landscape, use more horizontal space; in portrait, current values are fine
        let isLandscape = canvasW > canvasH
        let maxPuzzleW = canvasW * (isLandscape ? 0.98 : 0.95)
        let maxPuzzleH = canvasH * (isLandscape ? 0.88 : 0.90)

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

        // In landscape, zoom in so the puzzle fills the view (with a small edge visible)
        // Use the smaller of width-fit and height-fit zoom to ensure all edges are visible
        if isLandscape {
            let puzzleActualW = CGFloat(cols) * pieceW
            let puzzleActualH = CGFloat(rows) * pieceH
            let zoomForWidth = (canvasW * 0.96) / puzzleActualW
            let zoomForHeight = (canvasH * 0.92) / puzzleActualH
            cameraZoom = min(zoomForWidth, zoomForHeight)
        } else {
            cameraZoom = 1
        }

        edges = PuzzleEngine.generateEdges(rows: rows, cols: cols)
        gameState = PuzzleEngine.createGameState(cols: cols, rows: rows,
                                                 pieceW: pieceW, pieceH: pieceH,
                                                 puzzleX: puzzleX, puzzleY: puzzleY)

        trayNeedsUpdate.toggle()
    }

    /// Get unplaced pieces for the tray (sorted by id for consistent ordering)
    func getUnplacedPieces() -> [PuzzleEngine.Piece] {
        guard let state = gameState else { return [] }
        return state.pieces.filter { !$0.placed }
    }

    func trySnapGroup(_ group: PuzzleEngine.Group) {
        guard var groups = gameState?.groups,
              let piecesById = gameState?.piecesById else { return }

        // Use a snap distance proportional to piece size for better UX
        let snapDist = max(PuzzleEngine.snapDistance, min(pieceW, pieceH) * 0.5)

        let result = PuzzleEngine.trySnap(movedGroup: group,
                                          cols: cols, rows: rows,
                                          pieceW: pieceW, pieceH: pieceH,
                                          piecesById: piecesById,
                                          groups: &groups,
                                          snapDistance: snapDist)
        gameState?.groups = groups

        if result.placedCount > 0 {
            placedPieces += result.placedCount
            trayNeedsUpdate.toggle() // trigger tray refresh
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
