import SwiftUI
import UIKit

/// Horizontally scrollable tray showing unplaced puzzle pieces (bottom 1/4 of screen).
struct PieceTrayView: UIViewRepresentable {
    @ObservedObject var viewModel: PuzzleViewModel
    var boardView: PuzzleBoardUIView?

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> PieceTrayUIView {
        let view = PieceTrayUIView()
        view.viewModel = viewModel
        view.coordinator = context.coordinator
        view.backgroundColor = UIColor(hex: 0x5A4418)
        return view
    }

    func updateUIView(_ uiView: PieceTrayUIView, context: Context) {
        uiView.viewModel = viewModel
        uiView.boardView = boardView
        uiView.coordinator = context.coordinator
        uiView.refreshPieces()
    }

    class Coordinator {
        var viewModel: PuzzleViewModel

        init(viewModel: PuzzleViewModel) {
            self.viewModel = viewModel
        }
    }
}

/// Custom UIView that displays unplaced pieces in a horizontally scrollable tray.
class PieceTrayUIView: UIView, UIGestureRecognizerDelegate {

    var viewModel: PuzzleViewModel?
    var boardView: PuzzleBoardUIView?
    var coordinator: PieceTrayView.Coordinator?

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Drag state
    private var dragImageView: UIImageView?
    private var dragPiece: PuzzleEngine.Piece?
    private var dragGroup: PuzzleEngine.Group?
    private var dragStartPoint: CGPoint = .zero
    private var dragSourceView: UIView?

    // Piece thumbnail views
    private var pieceViews: [Int: UIView] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        // Scroll view
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        // Add a long press gesture on the scroll view to pick up pieces
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handlePieceDrag(_:)))
        longPress.minimumPressDuration = 0.2
        longPress.delegate = self
        scrollView.addGestureRecognizer(longPress)

        // Add top border
        let border = UIView()
        border.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        border.translatesAutoresizingMaskIntoConstraints = false
        addSubview(border)
        NSLayoutConstraint.activate([
            border.topAnchor.constraint(equalTo: topAnchor),
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.trailingAnchor.constraint(equalTo: trailingAnchor),
            border.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    // Allow long press to work simultaneously with scroll
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func refreshPieces() {
        guard let vm = viewModel,
              let state = vm.gameState,
              let image = vm.puzzleImage,
              vm.pieceW > 0, vm.pieceH > 0 else { return }

        // Clear old views
        for (_, view) in pieceViews {
            view.removeFromSuperview()
        }
        pieceViews.removeAll()

        let unplaced = vm.getUnplacedPieces()
        guard !unplaced.isEmpty else { return }

        // Calculate thumbnail size to match the board piece size
        let trayHeight = bounds.height
        let trayWidth = bounds.width
        let padding: CGFloat = 8
        let availableHeight = trayHeight - padding * 2

        // Use 1:1 scale with the board pieces (1.4 accounts for tab overflow)
        // If pieces are too tall for the tray, scale down to fit
        let idealThumbH = vm.pieceH * 1.4
        let scale = min(1.0, availableHeight / idealThumbH)
        let thumbW = vm.pieceW * scale * 1.4
        let thumbH = vm.pieceH * scale * 1.4

        // Determine number of rows: stack pieces if they're small enough to fit multiple rows
        let rowCount = max(1, Int(availableHeight / thumbH))
        let rowHeight = availableHeight / CGFloat(rowCount)
        let rowScale = min(scale, (rowHeight - 2) / (vm.pieceH * 1.4))
        let actualThumbW = vm.pieceW * rowScale * 1.4
        let actualThumbH = vm.pieceH * rowScale * 1.4

        // Calculate spacing
        let piecesPerRow = Int(ceil(Double(unplaced.count) / Double(rowCount)))
        let totalPiecesWidth = actualThumbW * CGFloat(piecesPerRow)
        let availableWidth = trayWidth - padding * 2
        let spacing: CGFloat
        if totalPiecesWidth < availableWidth {
            if piecesPerRow > 1 {
                spacing = (availableWidth - totalPiecesWidth) / CGFloat(piecesPerRow - 1)
            } else {
                spacing = 0
            }
        } else {
            spacing = 4
        }

        var xOffset: CGFloat = padding
        var currentRow = 0
        var countInRow = 0

        for piece in unplaced {
            let yOffset = padding + CGFloat(currentRow) * rowHeight + (rowHeight - actualThumbH) / 2
            let pieceView = createPieceThumbnail(piece: piece, image: image, vm: vm, scale: rowScale, thumbW: actualThumbW, thumbH: actualThumbH)
            pieceView.frame = CGRect(x: xOffset, y: yOffset, width: actualThumbW, height: actualThumbH)
            contentView.addSubview(pieceView)
            pieceViews[piece.id] = pieceView

            pieceView.isUserInteractionEnabled = true
            pieceView.tag = piece.id

            countInRow += 1
            if countInRow >= piecesPerRow {
                countInRow = 0
                currentRow += 1
                xOffset = padding
            } else {
                xOffset += actualThumbW + spacing
            }
        }

        // Update content size
        let totalWidth = padding + CGFloat(piecesPerRow) * (actualThumbW + spacing)
        contentView.frame = CGRect(x: 0, y: 0, width: totalWidth, height: trayHeight)
        scrollView.contentSize = CGSize(width: totalWidth, height: trayHeight)
    }

    private func createPieceThumbnail(piece: PuzzleEngine.Piece, image: UIImage, vm: PuzzleViewModel, scale: CGFloat, thumbW: CGFloat, thumbH: CGFloat) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: thumbW, height: thumbH))

        guard let boardView = boardView,
              let path = boardView.piecePaths[piece.id],
              let cgImage = image.cgImage else { return container }

        let totalW = CGFloat(vm.cols) * vm.pieceW
        let totalH = CGFloat(vm.rows) * vm.pieceH

        // Render the piece into an image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: vm.pieceW * 1.4, height: vm.pieceH * 1.4))
        let pieceImage = renderer.image { ctx in
            let context = ctx.cgContext
            // Center the piece path in the thumbnail (offset for tab overflow)
            let offsetX = vm.pieceW * 0.2
            let offsetY = vm.pieceH * 0.2
            context.translateBy(x: offsetX, y: offsetY)

            // Clip and draw
            context.addPath(path)
            context.clip()

            // Draw image using UIImage (handles coordinate system correctly)
            let dstRect = CGRect(x: -CGFloat(piece.col) * vm.pieceW,
                                 y: -CGFloat(piece.row) * vm.pieceH,
                                 width: totalW, height: totalH)
            UIImage(cgImage: cgImage).draw(in: dstRect)

            // Stroke
            context.addPath(path)
            context.setStrokeColor(UIColor(white: 0, alpha: 0.5).cgColor)
            context.setLineWidth(1.0)
            context.strokePath()
        }

        let imageView = UIImageView(image: pieceImage)
        imageView.contentMode = .scaleAspectFit
        imageView.frame = container.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(imageView)

        return container
    }

    // MARK: - Drag from Tray

    @objc private func handlePieceDrag(_ gesture: UILongPressGestureRecognizer) {
        guard let vm = viewModel,
              let state = vm.gameState else { return }

        switch gesture.state {
        case .began:
            // Hit test to find which piece view was pressed
            let pointInContent = gesture.location(in: contentView)
            var hitPieceView: UIView?
            for (pieceId, pView) in pieceViews {
                if pView.frame.contains(pointInContent) {
                    hitPieceView = pView
                    break
                }
            }
            guard let pieceView = hitPieceView else { return }
            let pieceId = pieceView.tag
            guard let piece = state.piecesById[pieceId] else { return }
            let group = state.groups.first { $0.id == piece.groupId }

            dragPiece = piece
            dragGroup = group
            dragSourceView = pieceView
            scrollView.isScrollEnabled = false
            SoundManager.shared.playPickup()

            // Create a floating image of the piece
            if let imageView = pieceView.subviews.first as? UIImageView,
               let image = imageView.image {
                let floatingView = UIImageView(image: image)
                floatingView.frame = CGRect(x: 0, y: 0,
                                            width: vm.pieceW * 1.4,
                                            height: vm.pieceH * 1.4)
                floatingView.alpha = 0.85
                let pointInWindow = gesture.location(in: window)
                floatingView.center = pointInWindow
                window?.addSubview(floatingView)
                dragImageView = floatingView
            }
            pieceView.alpha = 0.3

        case .changed:
            guard let floatingView = dragImageView else { return }
            let pointInWindow = gesture.location(in: window)
            floatingView.center = pointInWindow

            // Update piece position on board if dragging over it
            if let boardView = boardView, let group = dragGroup {
                let pointInBoard = gesture.location(in: boardView)
                if boardView.bounds.contains(pointInBoard) {
                    boardView.updateExternalDrag(group: group, at: pointInBoard)
                }
            }

        case .ended, .cancelled:
            scrollView.isScrollEnabled = true
            dragImageView?.removeFromSuperview()
            dragImageView = nil

            // Check if dropped on board
            if let boardView = boardView, let group = dragGroup {
                let pointInBoard = gesture.location(in: boardView)
                if boardView.bounds.contains(pointInBoard) {
                    boardView.dropPiece(group: group, at: pointInBoard)
                } else {
                    boardView.externalDragPiece = nil
                    boardView.externalDragGroup = nil
                    boardView.setNeedsDisplay()
                }
            }

            // Restore piece view or remove if placed
            if let piece = dragPiece {
                if piece.placed {
                    pieceViews[piece.id]?.removeFromSuperview()
                    pieceViews.removeValue(forKey: piece.id)
                } else {
                    pieceViews[piece.id]?.alpha = 1.0
                }
            }

            dragPiece = nil
            dragGroup = nil
            dragSourceView = nil

        default:
            break
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshPieces()
    }
}
