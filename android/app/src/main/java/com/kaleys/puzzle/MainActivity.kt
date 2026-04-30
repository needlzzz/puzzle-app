package com.kaleys.puzzle

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    private val vm: PuzzleViewModel by viewModels()

    // Views
    private lateinit var startScreen: View
    private lateinit var gameScreen: View
    private lateinit var winOverlay: View
    private lateinit var puzzleView: PuzzleView
    private lateinit var confettiView: ConfettiView
    private lateinit var timerText: TextView
    private lateinit var pieceCounterText: TextView
    private lateinit var hintBtn: Button
    private lateinit var winTimeText: TextView
    private lateinit var winPiecesText: TextView

    private val handler = Handler(Looper.getMainLooper())
    private var timerRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContentView(R.layout.activity_main)
        bindViews()
        setupButtons()

        // If game was active before rotation, restore it
        if (vm.initialized && vm.gameActive) {
            showGameScreen()
            puzzleView.post { restoreGame() }
        } else if (vm.initialized && !vm.gameActive && vm.placedPieces >= vm.totalPieces && vm.totalPieces > 0) {
            // Was on win screen
            showGameScreen()
            puzzleView.post { restoreGame() }
            showWinScreen()
        }
    }

    private fun bindViews() {
        startScreen = findViewById(R.id.startScreen)
        gameScreen = findViewById(R.id.gameScreen)
        winOverlay = findViewById(R.id.winOverlay)
        puzzleView = findViewById(R.id.puzzleView)
        confettiView = findViewById(R.id.confettiView)
        timerText = findViewById(R.id.timer)
        pieceCounterText = findViewById(R.id.pieceCounter)
        hintBtn = findViewById(R.id.hintBtn)
        winTimeText = findViewById(R.id.winTime)
        winPiecesText = findViewById(R.id.winPieces)
    }

    private fun setupButtons() {
        val difficultyMap = mapOf(
            R.id.btn20 to 20,
            R.id.btn50 to 50,
            R.id.btn100 to 100,
            R.id.btn150 to 150
        )
        for ((id, count) in difficultyMap) {
            findViewById<Button>(id).setOnClickListener { startGame(count) }
        }

        hintBtn.setOnClickListener {
            vm.showHint = !vm.showHint
            hintBtn.alpha = if (vm.showHint) 1f else 0.7f
            puzzleView.invalidate()
        }

        findViewById<Button>(R.id.newBtn).setOnClickListener { resetToStart() }
        findViewById<Button>(R.id.winNewBtn).setOnClickListener { resetToStart() }
    }

    private fun startGame(pieceCount: Int) {
        vm.startNewGame(pieceCount)

        showGameScreen()

        // Wait for layout to get actual dimensions
        puzzleView.post {
            val w = puzzleView.width.toFloat()
            val h = puzzleView.height.toFloat()
            if (w <= 0 || h <= 0) return@post

            vm.initLayout(w, h)
            wireUpPuzzleView()
            updatePieceCounter()
            startTimer()
        }
    }

    private fun restoreGame() {
        val w = puzzleView.width.toFloat()
        val h = puzzleView.height.toFloat()
        if (w <= 0 || h <= 0) return

        // Paths need rebuilding after rotation (they aren't serializable)
        wireUpPuzzleView()
        updatePieceCounter()
        if (vm.gameActive) {
            startTimer()
        }
    }

    private fun wireUpPuzzleView() {
        puzzleView.viewModel = vm
        puzzleView.buildPiecePaths()
        puzzleView.onPiecePlaced = {
            updatePieceCounter()
        }
        puzzleView.onPuzzleComplete = {
            stopTimer()
            showWinScreen()
        }
        puzzleView.invalidate()
    }

    private fun showGameScreen() {
        startScreen.visibility = View.GONE
        gameScreen.visibility = View.VISIBLE
        winOverlay.visibility = View.GONE
    }

    private fun showWinScreen() {
        winTimeText.text = "Time: ${vm.getElapsedString()}"
        winPiecesText.text = "Pieces: ${vm.totalPieces}"
        winOverlay.visibility = View.VISIBLE
        confettiView.post { confettiView.start() }
    }

    private fun resetToStart() {
        vm.gameActive = false
        vm.initialized = false
        stopTimer()
        confettiView.stop()
        puzzleView.viewModel = null
        gameScreen.visibility = View.GONE
        winOverlay.visibility = View.GONE
        startScreen.visibility = View.VISIBLE
    }

    private fun startTimer() {
        stopTimer()
        val runnable = object : Runnable {
            override fun run() {
                if (vm.gameActive) {
                    timerText.text = vm.getTimerString()
                    handler.postDelayed(this, 1000)
                }
            }
        }
        timerRunnable = runnable
        handler.post(runnable)
    }

    private fun stopTimer() {
        timerRunnable?.let { handler.removeCallbacks(it) }
        timerRunnable = null
        if (vm.gameActive) {
            vm.elapsedBeforePauseMs = vm.getElapsedMs()
        }
    }

    private fun updatePieceCounter() {
        pieceCounterText.text = "${vm.placedPieces} / ${vm.totalPieces}"
    }

    override fun onPause() {
        super.onPause()
        if (vm.gameActive) {
            vm.elapsedBeforePauseMs = vm.getElapsedMs()
        }
    }

    override fun onResume() {
        super.onResume()
        if (vm.gameActive) {
            vm.timerStartMs = System.currentTimeMillis()
            startTimer()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopTimer()
    }
}
