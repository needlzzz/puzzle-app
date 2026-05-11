import SwiftUI
import UIKit

/// UIViewRepresentable wrapper for the Core Graphics puzzle canvas.
struct PuzzleCanvasView: UIViewRepresentable {
    @ObservedObject var viewModel: PuzzleViewModel

    func makeUIView(context: Context) -> PuzzleCanvasUIView {
        let view = PuzzleCanvasUIView()
        view.viewModel = viewModel
        view.backgroundColor = UIColor(hex: 0x7A5E22)
        view.isMultipleTouchEnabled = true
        return view
    }

    func updateUIView(_ uiView: PuzzleCanvasUIView, context: Context) {
        uiView.viewModel = viewModel
        uiView.setNeedsDisplay()
    }
}

/// Custom UIView that renders the jigsaw puzzle and handles touch input.
class PuzzleCanvasUIView: UIView {

    private let tabSize: CGFloat = 0.2
    private let minZoom: CGFloat = 0.3
    private let maxZoom: CGFloat = 5.0

    var viewModel: PuzzleViewModel? {
        didSet { buildPiecePaths() }
    }

    // Cached piece paths
    private var piecePaths: [Int: CGPath] = [:]

    // Interaction state
    private var dragGroup: PuzzleEngine.Group?
    private var dragPiece: PuzzleEngine.Piece?
    private var dragOffsetX: CGFloat = 0
    private var dragOffsetY: CGFloat = 0
    private var isDragging = false
    private var isPanning = false
    private var lastPanPoint: CGPoint = .zero
    private var lastPinchDist: CGFloat = 0
    private var lastPinchCenter: CGPoint = .zero

    // Display link for smooth rendering during drag
    private var displayLink: CADisplayLink?
    private var needsRender = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        contentMode = .redraw
        // Add pinch gesture
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let vm = viewModel else { return }
        if vm.gameState == nil && vm.gameActive {
            vm.initLayout(canvasW: bounds.width, canvasH: bounds.height)
            buildPiecePaths()
            setNeedsDisplay()
        }
    }

    // MARK: - Path Building

    func buildPiecePaths() {
        piecePaths.removeAll()
        guard let vm = viewModel,
              let edges = vm.edges,
              let state = vm.gameState else { return }

        for piece in state.pieces {
            piecePaths[piece.id] = buildPiecePath(col: piece.col, row: piece.row, edges: edges, vm: vm)
        }
    }

    private func buildPiecePath(col: Int, row: Int, edges: PuzzleEngine.Edges, vm: PuzzleViewModel) -> CGPath {
        let path = CGMutablePath()
        let w = vm.pieceW
        let h = vm.pieceH

        path.move(to: .zero)

        // Top edge
        let topDir = row == 0 ? 0 : -edges.h[row - 1][col]
        drawJigsawEdge(path: path, len: w, dir: topDir,
                       tx: { x, _ in x }, ty: { _, y in y })

        // Right edge
        let rightDir = col == vm.cols - 1 ? 0 : edges.v[row][col]
        drawJigsawEdge(path: path, len: h, dir: rightDir,
                       tx: { x, y in w + y }, ty: { x, _ in x })

        // Bottom edge
        let bottomDir = row == vm.rows - 1 ? 0 : edges.h[row][col]
        drawJigsawEdge(path: path, len: w, dir: bottomDir,
                       tx: { x, _ in w - x }, ty: { _, y in h - y })

        // Left edge
        let leftDir = col == 0 ? 0 : -edges.v[row][col - 1]
        drawJigsawEdge(path: path, len: h, dir: leftDir,
                       tx: { _, y in -y }, ty: { x, _ in h - x })

        path.closeSubpath()
        return path
    }

    private func drawJigsawEdge(path: CGMutablePath, len: CGFloat, dir: Int,
                                tx: (CGFloat, CGFloat) -> CGFloat,
                                ty: (CGFloat, CGFloat) -> CGFloat) {
        if dir == 0 {
            path.addLine(to: CGPoint(x: tx(len, 0), y: ty(len, 0)))
            return
        }
        let tabH = len * tabSize * CGFloat(dir)
        let neck = len * 0.35
        let neckW = len * 0.1
        let tabW = len * 0.14

        path.addLine(to: CGPoint(x: tx(neck - neckW, 0), y: ty(neck - neckW, 0)))
        path.addCurve(
            to: CGPoint(x: tx(neck - tabW, -tabH * 0.8), y: ty(neck - tabW, -tabH * 0.8)),
            control1: CGPoint(x: tx(neck - neckW, 0), y: ty(neck - neckW, 0)),
            control2: CGPoint(x: tx(neck - neckW * 1.2, -tabH * 0.4), y: ty(neck - neckW * 1.2, -tabH * 0.4))
        )
        path.addCurve(
            to: CGPoint(x: tx(neck + tabW, -tabH * 0.8), y: ty(neck + tabW, -tabH * 0.8)),
            control1: CGPoint(x: tx(neck - tabW * 1.6, -tabH * 1.2), y: ty(neck - tabW * 1.6, -tabH * 1.2)),
            control2: CGPoint(x: tx(neck + neckW + tabW * 0.6, -tabH * 1.2), y: ty(neck + neckW + tabW * 0.6, -tabH * 1.2))
        )
        path.addCurve(
            to: CGPoint(x: tx(neck + neckW, 0), y: ty(neck + neckW, 0)),
            control1: CGPoint(x: tx(neck + neckW * 1.2, -tabH * 0.4), y: ty(neck + neckW * 1.2, -tabH * 0.4)),
            control2: CGPoint(x: tx(neck + neckW, 0), y: ty(neck + neckW, 0))
        )
        path.addLine(to: CGPoint(x: tx(len, 0), y: ty(len, 0)))
    }

    // MARK: - Coordinate Transforms

    private func screenToWorld(_ point: CGPoint) -> CGPoint {
        guard let vm = viewModel else { return point }
        return PuzzleEngine.screenToWorld(sx: point.x, sy: point.y,
                                          cameraX: vm.cameraX, cameraY: vm.cameraY,
                                          cameraZoom: vm.cameraZoom,
                                          canvasW: bounds.width, canvasH: bounds.height)
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(),
              let vm = viewModel,
              vm.gameActive || vm.screen == .win,
              let state = vm.gameState,
              let image = vm.puzzleImage?.cgImage else { return }

        let canvasW = bounds.width
        let canvasH = bounds.height

        // Background
        ctx.setFillColor(UIColor(hex: 0x7A5E22).cgColor)
        ctx.fill(bounds)

        ctx.saveGState()
        ctx.translateBy(x: canvasW / 2, y: canvasH / 2)
        ctx.scaleBy(x: vm.cameraZoom, y: vm.cameraZoom)
        ctx.translateBy(x: -vm.cameraX, y: -vm.cameraY)

        let totalW = CGFloat(vm.cols) * vm.pieceW
        let totalH = CGFloat(vm.rows) * vm.pieceH

        // Puzzle outline (dashed)
        ctx.setStrokeColor(UIColor(white: 1, alpha: 0.6).cgColor)
        ctx.setLineWidth(2 / vm.cameraZoom)
        ctx.setLineDash(phase: 0, lengths: [8 / vm.cameraZoom, 6 / vm.cameraZoom])
        ctx.stroke(CGRect(x: vm.puzzleX, y: vm.puzzleY, width: totalW, height: totalH))
        ctx.setLineDash(phase: 0, lengths: [])

        // Hint image
        if vm.showHint {
            ctx.saveGState()
            ctx.setAlpha(0.18)
            // Core Graphics draws images flipped, so we need to flip
            ctx.saveGState()
            ctx.translateBy(x: vm.puzzleX, y: vm.puzzleY + totalH)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: totalW, height: totalH))
            ctx.restoreGState()
            ctx.restoreGState()
        }

        // Grid lines
        ctx.setStrokeColor(UIColor(white: 1, alpha: 0.15).cgColor)
        ctx.setLineWidth(1 / vm.cameraZoom)
        for c in 1..<vm.cols {
            let x = vm.puzzleX + CGFloat(c) * vm.pieceW
            ctx.move(to: CGPoint(x: x, y: vm.puzzleY))
            ctx.addLine(to: CGPoint(x: x, y: vm.puzzleY + totalH))
            ctx.strokePath()
        }
        for r in 1..<vm.rows {
            let y = vm.puzzleY + CGFloat(r) * vm.pieceH
            ctx.move(to: CGPoint(x: vm.puzzleX, y: y))
            ctx.addLine(to: CGPoint(x: vm.puzzleX + totalW, y: y))
            ctx.strokePath()
        }

        // Sort: placed below, unplaced above
        let sorted = state.pieces.sorted { a, b in
            if a.placed && !b.placed { return true }
            if !a.placed && b.placed { return false }
            return false
        }

        for piece in sorted {
            drawPiece(ctx: ctx, piece: piece, image: image, vm: vm, totalW: totalW, totalH: totalH)
        }

        ctx.restoreGState()
    }

    private func drawPiece(ctx: CGContext, piece: PuzzleEngine.Piece,
                           image: CGImage, vm: PuzzleViewModel,
                           totalW: CGFloat, totalH: CGFloat) {
        guard let path = piecePaths[piece.id] else { return }

        ctx.saveGState()
        ctx.translateBy(x: piece.x, y: piece.y)

        // Clip to piece shape and draw image
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()

        // Draw image (flipped for Core Graphics coordinate system)
        ctx.saveGState()
        let dstRect = CGRect(x: -CGFloat(piece.col) * vm.pieceW,
                             y: -CGFloat(piece.row) * vm.pieceH,
                             width: totalW, height: totalH)
        ctx.translateBy(x: dstRect.origin.x, y: dstRect.origin.y + dstRect.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(image, in: CGRect(origin: .zero, size: dstRect.size))
        ctx.restoreGState()

        ctx.restoreGState()

        // Stroke
        ctx.addPath(path)
        if piece.placed {
            ctx.setStrokeColor(UIColor(white: 1, alpha: 0.3).cgColor)
            ctx.setLineWidth(0.5)
        } else {
            // Shadow stroke
            ctx.setStrokeColor(UIColor(white: 0, alpha: 0.15).cgColor)
            ctx.setLineWidth(3)
            ctx.strokePath()
            ctx.addPath(path)
            ctx.setStrokeColor(UIColor(white: 0, alpha: 0.5).cgColor)
            ctx.setLineWidth(1.2)
        }
        ctx.strokePath()

        ctx.restoreGState()
    }

    // MARK: - Hit Testing

    private func hitTestPiece(worldPoint: CGPoint) -> PuzzleEngine.Piece? {
        guard let state = viewModel?.gameState else { return nil }
        for piece in state.pieces.reversed() {
            if piece.placed { continue }
            guard let path = piecePaths[piece.id] else { continue }
            let localPoint = CGPoint(x: worldPoint.x - piece.x, y: worldPoint.y - piece.y)
            if path.contains(localPoint) {
                return piece
            }
        }
        return nil
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let vm = viewModel, vm.gameActive else { return }
        guard let touch = touches.first else { return }

        let point = touch.location(in: self)

        // Check for multi-touch (pinch handled by gesture recognizer)
        if let allTouches = event?.allTouches, allTouches.count >= 2 {
            isDragging = false
            dragGroup = nil
            isPanning = true
            return
        }

        let worldPoint = screenToWorld(point)
        let piece = hitTestPiece(worldPoint: worldPoint)

        if let piece = piece {
            isDragging = true
            let group = viewModel?.gameState?.groups.first { $0.id == piece.groupId }
            dragGroup = group
            dragPiece = piece
            dragOffsetX = worldPoint.x - piece.x
            dragOffsetY = worldPoint.y - piece.y

            // Bring group to top
            if let group = group, let state = vm.gameState {
                let groupIds = Set(group.pieces.map { $0.id })
                let others = state.pieces.filter { !groupIds.contains($0.id) }
                let groupPieces = state.pieces.filter { groupIds.contains($0.id) }
                state.pieces.removeAll()
                state.pieces.append(contentsOf: others)
                state.pieces.append(contentsOf: groupPieces)
            }
            startDisplayLink()
        } else {
            isPanning = true
            lastPanPoint = point
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let vm = viewModel, vm.gameActive else { return }
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        if isDragging, let group = dragGroup, let piece = dragPiece {
            let worldPoint = screenToWorld(point)
            let dx = (worldPoint.x - dragOffsetX) - piece.x
            let dy = (worldPoint.y - dragOffsetY) - piece.y
            for p in group.pieces {
                p.x += dx
                p.y += dy
            }
            needsRender = true
        } else if isPanning {
            let dx = (point.x - lastPanPoint.x) / vm.cameraZoom
            let dy = (point.y - lastPanPoint.y) / vm.cameraZoom
            vm.cameraX -= dx
            vm.cameraY -= dy
            lastPanPoint = point
            setNeedsDisplay()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDragging, let group = dragGroup, !group.placed {
            viewModel?.trySnapGroup(group)
        }
        cleanup()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cleanup()
    }

    private func cleanup() {
        isDragging = false
        dragGroup = nil
        dragPiece = nil
        isPanning = false
        stopDisplayLink()
        setNeedsDisplay()
    }

    // MARK: - Pinch Gesture

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let vm = viewModel, vm.gameActive else { return }

        let center = gesture.location(in: self)

        switch gesture.state {
        case .changed:
            let worldBefore = screenToWorld(center)
            let newZoom = max(minZoom, min(maxZoom, vm.cameraZoom * gesture.scale))
            vm.cameraZoom = newZoom
            let worldAfter = screenToWorld(center)
            vm.cameraX -= (worldAfter.x - worldBefore.x)
            vm.cameraY -= (worldAfter.y - worldBefore.y)
            gesture.scale = 1
            setNeedsDisplay()
        default:
            break
        }
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        needsRender = false
    }

    @objc private func displayLinkFired() {
        if needsRender {
            needsRender = false
            setNeedsDisplay()
        }
    }
}
