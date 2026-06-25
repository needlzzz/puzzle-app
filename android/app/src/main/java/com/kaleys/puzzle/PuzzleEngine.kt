package com.kaleys.puzzle

import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.roundToInt
import kotlin.random.Random

/**
 * Pure game logic — no Android UI, no Canvas, no side effects.
 * Direct port of puzzle-engine.js.
 */
object PuzzleEngine {

    const val SNAP_DISTANCE = 35f
    const val IMAGE_W = 800
    const val IMAGE_H = 600

    data class Grid(val cols: Int, val rows: Int)

    data class Edges(
        val h: Array<IntArray>,  // h[r][c] = edge between row r and row r+1
        val v: Array<IntArray>   // v[r][c] = edge between col c and col c+1
    )

    data class Piece(
        val id: Int,
        val col: Int,
        val row: Int,
        var x: Float,
        var y: Float,
        val correctX: Float,
        val correctY: Float,
        var placed: Boolean = false,
        var groupId: Int
    )

    data class Group(
        val id: Int,
        val pieces: MutableList<Piece>,
        var placed: Boolean = false
    )

    data class GameState(
        val pieces: MutableList<Piece>,
        val piecesById: MutableMap<Int, Piece>,
        val groups: MutableList<Group>
    )

    data class SnapResult(
        val snapped: Boolean,
        val placedCount: Int,
        val mergedInto: Group?
    )

    /**
     * Find cols × rows grid that best matches the image aspect ratio
     * while producing exactly [count] cells.
     */
    fun computeGrid(count: Int, imageW: Int = IMAGE_W, imageH: Int = IMAGE_H): Grid {
        val aspect = imageW.toFloat() / imageH.toFloat()
        var bestCols = 1
        var bestRows = count
        var bestDiff = Float.MAX_VALUE

        for (c in 1..count) {
            val r = ceil(count.toFloat() / c).toInt()
            if (c * r != count) continue
            val gridAspect = c.toFloat() / r.toFloat()
            val diff = abs(gridAspect - aspect)
            if (diff < bestDiff) {
                bestDiff = diff
                bestCols = c
                bestRows = r
            }
        }
        return Grid(bestCols, bestRows)
    }

    /**
     * Convert screen coordinates to world coordinates given a camera state.
     */
    fun screenToWorld(
        sx: Float, sy: Float,
        cameraX: Float, cameraY: Float, cameraZoom: Float,
        canvasW: Float, canvasH: Float
    ): Pair<Float, Float> {
        val wx = (sx - canvasW / 2f) / cameraZoom + cameraX
        val wy = (sy - canvasH / 2f) / cameraZoom + cameraY
        return Pair(wx, wy)
    }

    /**
     * Generate random jigsaw edge directions for a grid.
     * Values: 1 (tab out) or -1 (blank in)
     */
    fun generateEdges(rows: Int, cols: Int): Edges {
        val h = Array(rows - 1) { IntArray(cols) { if (Random.nextBoolean()) 1 else -1 } }
        val v = Array(rows) { IntArray(cols - 1) { if (Random.nextBoolean()) 1 else -1 } }
        return Edges(h, v)
    }

    /**
     * Whether a piece sits on the border of the puzzle grid (edge or corner).
     * Convergence target shared with puzzle-engine.js / PuzzleEngine.swift.
     */
    fun isEdgePiece(piece: Piece, cols: Int, rows: Int): Boolean {
        return piece.row == 0 || piece.row == rows - 1 ||
               piece.col == 0 || piece.col == cols - 1
    }

    /**
     * Get the grid neighbors of a piece (up/down/left/right).
     */
    fun getNeighbors(piece: Piece, cols: Int, rows: Int, piecesById: Map<Int, Piece>): List<Piece> {
        val result = mutableListOf<Piece>()
        val (_, col, row) = piece
        fun id(r: Int, c: Int) = r * cols + c

        if (col > 0) piecesById[id(row, col - 1)]?.let { result.add(it) }
        if (col < cols - 1) piecesById[id(row, col + 1)]?.let { result.add(it) }
        if (row > 0) piecesById[id(row - 1, col)]?.let { result.add(it) }
        if (row < rows - 1) piecesById[id(row + 1, col)]?.let { result.add(it) }
        return result
    }

    /**
     * Create a game state: pieces, groups, piecesById.
     * Pieces start at their correct positions (caller scatters them).
     */
    fun createGameState(
        cols: Int, rows: Int,
        pieceW: Float, pieceH: Float,
        puzzleX: Float, puzzleY: Float
    ): GameState {
        val pieces = mutableListOf<Piece>()
        val piecesById = mutableMapOf<Int, Piece>()
        val groups = mutableListOf<Group>()

        for (r in 0 until rows) {
            for (c in 0 until cols) {
                val id = r * cols + c
                val correctX = puzzleX + c * pieceW
                val correctY = puzzleY + r * pieceH
                val piece = Piece(id, c, r, correctX, correctY, correctX, correctY, false, id)
                pieces.add(piece)
                piecesById[id] = piece
                groups.add(Group(id, mutableListOf(piece), false))
            }
        }
        return GameState(pieces, piecesById, groups)
    }

    /**
     * Try to snap a moved group to its correct position or to a neighbor group.
     */
    fun trySnap(
        movedGroup: Group,
        cols: Int, rows: Int,
        pieceW: Float, pieceH: Float,
        piecesById: Map<Int, Piece>,
        groups: MutableList<Group>,
        snapDistance: Float = SNAP_DISTANCE
    ): SnapResult {
        for (piece in movedGroup.pieces) {
            // Check snap to correct position
            val dx = piece.x - piece.correctX
            val dy = piece.y - piece.correctY
            if (abs(dx) < snapDistance && abs(dy) < snapDistance) {
                var newlyPlaced = 0
                for (gp in movedGroup.pieces) {
                    gp.x = gp.correctX
                    gp.y = gp.correctY
                    if (!gp.placed) {
                        gp.placed = true
                        newlyPlaced++
                    }
                }
                movedGroup.placed = true
                return SnapResult(true, newlyPlaced, null)
            }

            // Check snap to neighbor in different group
            val neighbors = getNeighbors(piece, cols, rows, piecesById)
            for (neighbor in neighbors) {
                if (neighbor.groupId == piece.groupId) continue
                val expectedDx = (piece.col - neighbor.col) * pieceW
                val expectedDy = (piece.row - neighbor.row) * pieceH
                val actualDx = piece.x - neighbor.x
                val actualDy = piece.y - neighbor.y
                if (abs(actualDx - expectedDx) < snapDistance &&
                    abs(actualDy - expectedDy) < snapDistance
                ) {
                    val snapOffsetX = (neighbor.x + expectedDx) - piece.x
                    val snapOffsetY = (neighbor.y + expectedDy) - piece.y
                    for (gp in movedGroup.pieces) {
                        gp.x += snapOffsetX
                        gp.y += snapOffsetY
                    }
                    val neighborGroup = groups.find { it.id == neighbor.groupId } ?: continue
                    val mergeResult = mergeGroups(
                        movedGroup, neighborGroup,
                        cols, rows, pieceW, pieceH, piecesById, groups, snapDistance
                    )
                    return SnapResult(true, mergeResult, movedGroup)
                }
            }
        }
        return SnapResult(false, 0, null)
    }

    /**
     * Merge groupB into groupA. Returns number of newly placed pieces.
     */
    fun mergeGroups(
        groupA: Group, groupB: Group,
        cols: Int, rows: Int,
        pieceW: Float, pieceH: Float,
        piecesById: Map<Int, Piece>,
        groups: MutableList<Group>,
        snapDistance: Float = SNAP_DISTANCE
    ): Int {
        var placedCount = 0
        val newId = groupA.id
        for (p in groupB.pieces) {
            p.groupId = newId
            groupA.pieces.add(p)
        }
        if (groupB.placed || groupA.placed) {
            for (p in groupA.pieces) {
                p.x = p.correctX
                p.y = p.correctY
                if (!p.placed) {
                    p.placed = true
                    placedCount++
                }
            }
            groupA.placed = true
        }
        groups.remove(groupB)

        // Chain reaction
        val chainResult = trySnap(
            groupA, cols, rows, pieceW, pieceH, piecesById, groups, snapDistance
        )
        placedCount += chainResult.placedCount
        return placedCount
    }
}
