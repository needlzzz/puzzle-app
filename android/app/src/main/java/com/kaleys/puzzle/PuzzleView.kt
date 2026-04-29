package com.kaleys.puzzle

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.MotionEvent
import android.view.View
import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min

/**
 * Custom View that renders the jigsaw puzzle board and handles touch input.
 * Delegates game state to PuzzleViewModel.
 */
class PuzzleView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    companion object {
        private const val TAB_SIZE = 0.2f
        private const val MIN_ZOOM = 0.3f
        private const val MAX_ZOOM = 5f
    }

    // Set by MainActivity after ViewModel is ready
    var viewModel: PuzzleViewModel? = null
    var onPiecePlaced: (() -> Unit)? = null
    var onPuzzleComplete: (() -> Unit)? = null

    // Paints
    private val outlinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = Color.argb(153, 255, 248, 231)
    }
    private val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = Color.argb(38, 255, 248, 231)
    }
    private val hintPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        alpha = 46 // ~0.18
    }
    private val piecePaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val pieceStrokePlaced = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = Color.argb(77, 255, 255, 255)
        strokeWidth = 0.5f
    }
    private val pieceStrokeUnplaced = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = Color.argb(128, 0, 0, 0)
        strokeWidth = 1.2f
    }
    private val pieceShadowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        color = Color.argb(38, 0, 0, 0)
        strokeWidth = 3f
    }

    // Cached piece paths (built once per game)
    private val piecePaths = mutableMapOf<Int, Path>()

    // Interaction state
    private var dragGroup: PuzzleEngine.Group? = null
    private var dragPiece: PuzzleEngine.Piece? = null
    private var dragOffsetX = 0f
    private var dragOffsetY = 0f
    private var isDragging = false
    private var isPanning = false
    private var lastPanX = 0f
    private var lastPanY = 0f
    private var lastPinchDist = 0f
    private var lastPinchCenterX = 0f
    private var lastPinchCenterY = 0f

    fun buildPiecePaths() {
        piecePaths.clear()
        val vm = viewModel ?: return
        val edges = vm.edges ?: return
        val state = vm.gameState ?: return

        for (piece in state.pieces) {
            piecePaths[piece.id] = buildPiecePath(piece.col, piece.row, edges, vm)
        }
    }

    private fun buildPiecePath(
        col: Int, row: Int,
        edges: PuzzleEngine.Edges,
        vm: PuzzleViewModel
    ): Path {
        val path = Path()
        val w = vm.pieceW
        val h = vm.pieceH

        path.moveTo(0f, 0f)

        // Top edge
        val topDir = if (row == 0) 0 else -edges.h[row - 1][col]
        drawJigsawEdge(path, w, topDir,
            tx = { x, y -> x }, ty = { x, y -> y })

        // Right edge
        val rightDir = if (col == vm.cols - 1) 0 else edges.v[row][col]
        drawJigsawEdge(path, h, rightDir,
            tx = { x, y -> w + y }, ty = { x, y -> x })

        // Bottom edge
        val bottomDir = if (row == vm.rows - 1) 0 else edges.h[row][col]
        drawJigsawEdge(path, w, bottomDir,
            tx = { x, y -> w - x }, ty = { x, y -> h - y })

        // Left edge
        val leftDir = if (col == 0) 0 else -edges.v[row][col - 1]
        drawJigsawEdge(path, h, leftDir,
            tx = { x, y -> -y }, ty = { x, y -> h - x })

        path.close()
        return path
    }

    private inline fun drawJigsawEdge(
        path: Path, len: Float, dir: Int,
        tx: (Float, Float) -> Float,
        ty: (Float, Float) -> Float
    ) {
        if (dir == 0) {
            path.lineTo(tx(len, 0f), ty(len, 0f))
            return
        }
        val tabH = len * TAB_SIZE * dir
        val neck = len * 0.35f
        val neckW = len * 0.1f
        val tabW = len * 0.14f

        path.lineTo(tx(neck - neckW, 0f), ty(neck - neckW, 0f))
        path.cubicTo(
            tx(neck - neckW, 0f), ty(neck - neckW, 0f),
            tx(neck - neckW * 1.2f, -tabH * 0.4f), ty(neck - neckW * 1.2f, -tabH * 0.4f),
            tx(neck - tabW, -tabH * 0.8f), ty(neck - tabW, -tabH * 0.8f)
        )
        path.cubicTo(
            tx(neck - tabW * 1.6f, -tabH * 1.2f), ty(neck - tabW * 1.6f, -tabH * 1.2f),
            tx(neck + neckW + tabW * 0.6f, -tabH * 1.2f), ty(neck + neckW + tabW * 0.6f, -tabH * 1.2f),
            tx(neck + tabW, -tabH * 0.8f), ty(neck + tabW, -tabH * 0.8f)
        )
        path.cubicTo(
            tx(neck + neckW * 1.2f, -tabH * 0.4f), ty(neck + neckW * 1.2f, -tabH * 0.4f),
            tx(neck + neckW, 0f), ty(neck + neckW, 0f),
            tx(neck + neckW, 0f), ty(neck + neckW, 0f)
        )
        path.lineTo(tx(len, 0f), ty(len, 0f))
    }

    // ===== COORDINATE TRANSFORMS =====

    private fun screenToWorld(sx: Float, sy: Float): Pair<Float, Float> {
        val vm = viewModel ?: return Pair(sx, sy)
        return PuzzleEngine.screenToWorld(
            sx, sy, vm.cameraX, vm.cameraY, vm.cameraZoom,
            width.toFloat(), height.toFloat()
        )
    }

    // ===== RENDERING =====

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val vm = viewModel ?: return
        if (!vm.gameActive) return
        val state = vm.gameState ?: return
        val image = vm.puzzleImage ?: return

        canvas.save()
        canvas.translate(width / 2f, height / 2f)
        canvas.scale(vm.cameraZoom, vm.cameraZoom)
        canvas.translate(-vm.cameraX, -vm.cameraY)

        val totalW = vm.cols * vm.pieceW
        val totalH = vm.rows * vm.pieceH

        // Puzzle outline
        outlinePaint.strokeWidth = 2f / vm.cameraZoom
        outlinePaint.pathEffect = DashPathEffect(
            floatArrayOf(8f / vm.cameraZoom, 6f / vm.cameraZoom), 0f
        )
        canvas.drawRect(vm.puzzleX, vm.puzzleY, vm.puzzleX + totalW, vm.puzzleY + totalH, outlinePaint)
        outlinePaint.pathEffect = null

        // Hint image
        if (vm.showHint) {
            canvas.drawBitmap(
                image,
                Rect(0, 0, image.width, image.height),
                RectF(vm.puzzleX, vm.puzzleY, vm.puzzleX + totalW, vm.puzzleY + totalH),
                hintPaint
            )
        }

        // Grid lines
        gridPaint.strokeWidth = 1f / vm.cameraZoom
        for (c in 1 until vm.cols) {
            val x = vm.puzzleX + c * vm.pieceW
            canvas.drawLine(x, vm.puzzleY, x, vm.puzzleY + totalH, gridPaint)
        }
        for (r in 1 until vm.rows) {
            val y = vm.puzzleY + r * vm.pieceH
            canvas.drawLine(vm.puzzleX, y, vm.puzzleX + totalW, y, gridPaint)
        }

        // Sort: placed pieces below, unplaced above
        val sorted = state.pieces.sortedBy { if (it.placed) 0 else 1 }
        for (piece in sorted) {
            drawPiece(canvas, piece, image, vm)
        }

        canvas.restore()
        invalidate() // continuous rendering
    }

    private fun drawPiece(
        canvas: Canvas,
        piece: PuzzleEngine.Piece,
        image: Bitmap,
        vm: PuzzleViewModel
    ) {
        val path = piecePaths[piece.id] ?: return
        val totalW = vm.cols * vm.pieceW
        val totalH = vm.rows * vm.pieceH

        canvas.save()
        canvas.translate(piece.x, piece.y)

        // Clip to piece shape and draw image
        canvas.save()
        canvas.clipPath(path)
        val srcRect = Rect(0, 0, image.width, image.height)
        val dstRect = RectF(
            -piece.col * vm.pieceW,
            -piece.row * vm.pieceH,
            -piece.col * vm.pieceW + totalW,
            -piece.row * vm.pieceH + totalH
        )
        canvas.drawBitmap(image, srcRect, dstRect, piecePaint)
        canvas.restore()

        // Stroke
        if (piece.placed) {
            canvas.drawPath(path, pieceStrokePlaced)
        } else {
            canvas.drawPath(path, pieceShadowPaint)
            canvas.drawPath(path, pieceStrokeUnplaced)
        }

        canvas.restore()
    }

    // ===== HIT TESTING =====

    private fun hitTestPiece(worldX: Float, worldY: Float): PuzzleEngine.Piece? {
        val state = viewModel?.gameState ?: return null
        // Iterate in reverse to hit top pieces first
        for (i in state.pieces.indices.reversed()) {
            val p = state.pieces[i]
            if (p.placed) continue
            val localX = worldX - p.x
            val localY = worldY - p.y
            val path = piecePaths[p.id] ?: continue
            val bounds = RectF()
            path.computeBounds(bounds, true)
            if (bounds.contains(localX, localY)) {
                // More precise: use Region
                val region = Region()
                val clip = Region(
                    bounds.left.toInt() - 1, bounds.top.toInt() - 1,
                    bounds.right.toInt() + 1, bounds.bottom.toInt() + 1
                )
                region.setPath(path, clip)
                if (region.contains(localX.toInt(), localY.toInt())) {
                    return p
                }
            }
        }
        return null
    }

    // ===== TOUCH HANDLING =====

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val vm = viewModel ?: return false
        if (!vm.gameActive) return false

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> onPointerDown(event)
            MotionEvent.ACTION_POINTER_DOWN -> {
                if (event.pointerCount == 2) onPinchStart(event)
            }
            MotionEvent.ACTION_MOVE -> {
                if (event.pointerCount == 2 && isPanning) {
                    onPinchMove(event)
                } else if (isDragging) {
                    onDragMove(event)
                } else if (isPanning) {
                    onPanMove(event)
                }
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> onPointerUp()
            MotionEvent.ACTION_POINTER_UP -> {
                // If we were pinching and one finger lifts, stop pinching
                isPanning = false
                lastPinchDist = 0f
            }
        }
        return true
    }

    private fun onPointerDown(event: MotionEvent) {
        val (worldX, worldY) = screenToWorld(event.x, event.y)
        val piece = hitTestPiece(worldX, worldY)

        if (piece != null) {
            val vm = viewModel ?: return
            val state = vm.gameState ?: return
            isDragging = true
            val group = state.groups.find { it.id == piece.groupId }
            dragGroup = group
            dragPiece = piece
            dragOffsetX = worldX - piece.x
            dragOffsetY = worldY - piece.y

            // Bring group pieces to top of render order
            if (group != null) {
                val groupIds = group.pieces.map { it.id }.toSet()
                val others = state.pieces.filter { it.id !in groupIds }
                val groupPieces = state.pieces.filter { it.id in groupIds }
                state.pieces.clear()
                state.pieces.addAll(others)
                state.pieces.addAll(groupPieces)
            }
        } else {
            isPanning = true
            lastPanX = event.x
            lastPanY = event.y
        }
    }

    private fun onDragMove(event: MotionEvent) {
        val vm = viewModel ?: return
        val group = dragGroup ?: return
        val piece = dragPiece ?: return
        val (worldX, worldY) = screenToWorld(event.x, event.y)
        val dx = (worldX - dragOffsetX) - piece.x
        val dy = (worldY - dragOffsetY) - piece.y
        for (p in group.pieces) {
            p.x += dx
            p.y += dy
        }
    }

    private fun onPanMove(event: MotionEvent) {
        val vm = viewModel ?: return
        val dx = (event.x - lastPanX) / vm.cameraZoom
        val dy = (event.y - lastPanY) / vm.cameraZoom
        vm.cameraX -= dx
        vm.cameraY -= dy
        lastPanX = event.x
        lastPanY = event.y
    }

    private fun onPinchStart(event: MotionEvent) {
        isDragging = false
        dragGroup = null
        isPanning = true
        lastPinchDist = pinchDistance(event)
        lastPinchCenterX = (event.getX(0) + event.getX(1)) / 2f
        lastPinchCenterY = (event.getY(0) + event.getY(1)) / 2f
    }

    private fun onPinchMove(event: MotionEvent) {
        if (event.pointerCount < 2) return
        val vm = viewModel ?: return
        val dist = pinchDistance(event)
        val cx = (event.getX(0) + event.getX(1)) / 2f
        val cy = (event.getY(0) + event.getY(1)) / 2f

        if (lastPinchDist > 0f) {
            val zoomDelta = dist / lastPinchDist
            val newZoom = (vm.cameraZoom * zoomDelta).coerceIn(MIN_ZOOM, MAX_ZOOM)
            val worldBefore = screenToWorld(cx, cy)
            vm.cameraZoom = newZoom
            val worldAfter = screenToWorld(cx, cy)
            vm.cameraX -= (worldAfter.first - worldBefore.first)
            vm.cameraY -= (worldAfter.second - worldBefore.second)
        }

        // Pan with pinch center
        val dx = (cx - lastPinchCenterX) / vm.cameraZoom
        val dy = (cy - lastPinchCenterY) / vm.cameraZoom
        vm.cameraX -= dx
        vm.cameraY -= dy

        lastPinchDist = dist
        lastPinchCenterX = cx
        lastPinchCenterY = cy
    }

    private fun onPointerUp() {
        if (isDragging && dragGroup != null) {
            trySnapGroup()
        }
        isDragging = false
        dragGroup = null
        dragPiece = null
        isPanning = false
        lastPinchDist = 0f
    }

    private fun trySnapGroup() {
        val vm = viewModel ?: return
        val state = vm.gameState ?: return
        val group = dragGroup ?: return
        if (group.placed) return

        val result = PuzzleEngine.trySnap(
            group, vm.cols, vm.rows, vm.pieceW, vm.pieceH,
            state.piecesById, state.groups
        )
        if (result.placedCount > 0) {
            vm.placedPieces += result.placedCount
            onPiecePlaced?.invoke()
            if (vm.placedPieces >= vm.totalPieces) {
                vm.gameActive = false
                onPuzzleComplete?.invoke()
            }
        }
    }

    private fun pinchDistance(event: MotionEvent): Float {
        if (event.pointerCount < 2) return 0f
        return hypot(
            (event.getX(1) - event.getX(0)).toDouble(),
            (event.getY(1) - event.getY(0)).toDouble()
        ).toFloat()
    }
}
