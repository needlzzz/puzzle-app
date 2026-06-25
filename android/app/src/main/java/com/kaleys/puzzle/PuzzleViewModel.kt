package com.kaleys.puzzle

import android.graphics.Bitmap
import androidx.lifecycle.ViewModel

/**
 * Holds puzzle game state across configuration changes (rotation).
 * Does NOT persist across app kills (by design — v1 decision).
 */
class PuzzleViewModel : ViewModel() {

    // Game configuration
    var cols: Int = 0
    var rows: Int = 0
    var pieceW: Float = 0f
    var pieceH: Float = 0f
    var puzzleX: Float = 0f
    var puzzleY: Float = 0f
    var totalPieces: Int = 0

    // Game state
    var gameState: PuzzleEngine.GameState? = null
    var edges: PuzzleEngine.Edges? = null
    var puzzleImage: Bitmap? = null
    var placedPieces: Int = 0
    var gameActive: Boolean = false
    var showHint: Boolean = false
    var showEdges: Boolean = false

    // Chosen animal for this game ("surprise" picks randomly each game)
    var selectedAnimalKey: String = AnimalImageGenerator.SURPRISE_KEY
    var activeAnimalKey: String = AnimalImageGenerator.SURPRISE_KEY

    // Milestone celebration tracking (25% / 50% / 75%)
    private val firedMilestones: MutableSet<Int> = mutableSetOf()

    // Timer
    var timerStartMs: Long = 0L
    var elapsedBeforePauseMs: Long = 0L

    // Camera
    var cameraX: Float = 0f
    var cameraY: Float = 0f
    var cameraZoom: Float = 1f

    // Track if game was initialized (to distinguish fresh start from rotation)
    var initialized: Boolean = false

    fun startNewGame(pieceCount: Int, animalKey: String = selectedAnimalKey) {
        val grid = PuzzleEngine.computeGrid(pieceCount)
        cols = grid.cols
        rows = grid.rows
        totalPieces = cols * rows
        val resolvedKey = if (animalKey == AnimalImageGenerator.SURPRISE_KEY) {
            AnimalImageGenerator.animalForKey(null).key
        } else {
            animalKey
        }
        activeAnimalKey = resolvedKey
        puzzleImage?.recycle()
        puzzleImage = AnimalImageGenerator.generate(resolvedKey)
        placedPieces = 0
        showHint = false
        showEdges = false
        gameActive = true
        firedMilestones.clear()
        timerStartMs = System.currentTimeMillis()
        elapsedBeforePauseMs = 0L
        initialized = true
    }

    val activeAnimal: AnimalImageGenerator.Animal
        get() = AnimalImageGenerator.animalForKey(activeAnimalKey)

    /** Fraction of pieces placed, 0f..1f. */
    val progress: Float
        get() = if (totalPieces > 0) placedPieces.toFloat() / totalPieces else 0f

    /**
     * Returns a milestone celebration message if a new 25/50/75% threshold was
     * just crossed, otherwise null. Each milestone fires at most once per game.
     */
    fun checkMilestone(): Int? {
        if (totalPieces <= 0) return null
        val pct = (placedPieces * 100) / totalPieces
        for (threshold in intArrayOf(75, 50, 25)) {
            if (pct >= threshold && !firedMilestones.contains(threshold)) {
                firedMilestones.add(threshold)
                return threshold
            }
        }
        return null
    }

    fun initLayout(canvasW: Float, canvasH: Float) {
        val imageAspect = PuzzleEngine.IMAGE_W.toFloat() / PuzzleEngine.IMAGE_H.toFloat()
        val maxPuzzleW = canvasW * 0.5f
        val maxPuzzleH = canvasH * 0.5f

        val puzzleTotalW: Float
        val puzzleTotalH: Float
        if (maxPuzzleW / maxPuzzleH > imageAspect) {
            puzzleTotalH = maxPuzzleH
            puzzleTotalW = maxPuzzleH * imageAspect
        } else {
            puzzleTotalW = maxPuzzleW
            puzzleTotalH = maxPuzzleW / imageAspect
        }
        pieceW = puzzleTotalW / cols
        pieceH = puzzleTotalH / rows
        puzzleX = (canvasW / 2f) - (cols * pieceW / 2f)
        puzzleY = (canvasH / 2f) - (rows * pieceH / 2f)

        cameraX = canvasW / 2f
        cameraY = canvasH / 2f
        cameraZoom = 1f

        edges = PuzzleEngine.generateEdges(rows, cols)
        gameState = PuzzleEngine.createGameState(cols, rows, pieceW, pieceH, puzzleX, puzzleY)

        // Scatter pieces around the puzzle area
        val margin = maxOf(pieceW, pieceH) * 1.5f
        gameState?.pieces?.forEach { piece ->
            when ((Math.random() * 4).toInt()) {
                0 -> {
                    piece.x = puzzleX - margin - (Math.random() * margin * 2).toFloat()
                    piece.y = puzzleY + (Math.random() * rows * pieceH).toFloat()
                }
                1 -> {
                    piece.x = puzzleX + cols * pieceW + margin + (Math.random() * margin * 2).toFloat()
                    piece.y = puzzleY + (Math.random() * rows * pieceH).toFloat()
                }
                2 -> {
                    piece.x = puzzleX + (Math.random() * cols * pieceW).toFloat()
                    piece.y = puzzleY - margin - (Math.random() * margin * 2).toFloat()
                }
                3 -> {
                    piece.x = puzzleX + (Math.random() * cols * pieceW).toFloat()
                    piece.y = puzzleY + rows * pieceH + margin + (Math.random() * margin * 2).toFloat()
                }
            }
        }
    }

    fun getElapsedMs(): Long {
        return if (gameActive) {
            elapsedBeforePauseMs + (System.currentTimeMillis() - timerStartMs)
        } else {
            elapsedBeforePauseMs
        }
    }

    fun getElapsedString(): String {
        val totalSec = (getElapsedMs() / 1000).toInt()
        val mins = totalSec / 60
        val secs = totalSec % 60
        return if (mins > 0) "${mins}m ${secs}s" else "${secs}s"
    }

    fun getTimerString(): String {
        val totalSec = (getElapsedMs() / 1000).toInt()
        val mins = (totalSec / 60).toString().padStart(2, '0')
        val secs = (totalSec % 60).toString().padStart(2, '0')
        return "⏱ $mins:$secs"
    }

    override fun onCleared() {
        super.onCleared()
        puzzleImage?.recycle()
        puzzleImage = null
    }
}
