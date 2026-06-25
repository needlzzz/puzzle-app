package com.kaleys.puzzle

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.GridLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {

    private val vm: PuzzleViewModel by viewModels()

    private lateinit var storage: Storage
    private lateinit var soundManager: SoundManager

    // Views
    private lateinit var startScreen: View
    private lateinit var gameScreen: View
    private lateinit var winOverlay: View
    private lateinit var tutorialOverlay: View
    private lateinit var confirmOverlay: View
    private lateinit var puzzleView: PuzzleView
    private lateinit var confettiView: ConfettiView
    private lateinit var timerText: TextView
    private lateinit var progressBar: ProgressBar
    private lateinit var milestoneBanner: TextView
    private lateinit var animalGrid: GridLayout
    private lateinit var collectionLabel: TextView
    private lateinit var collectionEmojis: TextView
    private lateinit var muteBtn: Button
    private lateinit var timerBtn: Button
    private lateinit var winAnimalEmoji: TextView
    private lateinit var winAnimalName: TextView
    private lateinit var winTimeText: TextView

    private val animalTiles = mutableMapOf<String, Button>()

    private val handler = Handler(Looper.getMainLooper())
    private var timerRunnable: Runnable? = null
    private var milestoneRunnable: Runnable? = null
    private var lastPieceCount: Int = 20

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        storage = Storage(this)
        soundManager = SoundManager(this, storage)

        setContentView(R.layout.activity_main)
        bindViews()
        buildAnimalGrid()
        refreshCollection()
        setupButtons()
        updateSettingButtons()

        // If game was active before rotation, restore it
        if (vm.initialized && vm.gameActive) {
            showGameScreen()
            puzzleView.post { restoreGame() }
        } else if (vm.initialized && !vm.gameActive && vm.placedPieces >= vm.totalPieces && vm.totalPieces > 0) {
            // Was on win screen
            showGameScreen()
            puzzleView.post { restoreGame() }
            showWinScreen()
        } else {
            maybeShowTutorial()
        }
    }

    private fun bindViews() {
        startScreen = findViewById(R.id.startScreen)
        gameScreen = findViewById(R.id.gameScreen)
        winOverlay = findViewById(R.id.winOverlay)
        tutorialOverlay = findViewById(R.id.tutorialOverlay)
        confirmOverlay = findViewById(R.id.confirmOverlay)
        puzzleView = findViewById(R.id.puzzleView)
        confettiView = findViewById(R.id.confettiView)
        timerText = findViewById(R.id.timer)
        progressBar = findViewById(R.id.progressBar)
        milestoneBanner = findViewById(R.id.milestoneBanner)
        animalGrid = findViewById(R.id.animalGrid)
        collectionLabel = findViewById(R.id.collectionLabel)
        collectionEmojis = findViewById(R.id.collectionEmojis)
        muteBtn = findViewById(R.id.muteBtn)
        timerBtn = findViewById(R.id.timerBtn)
        winAnimalEmoji = findViewById(R.id.winAnimalEmoji)
        winAnimalName = findViewById(R.id.winAnimalName)
        winTimeText = findViewById(R.id.winTime)
    }

    // ===== Animal picker =====

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun buildAnimalGrid() {
        animalGrid.removeAllViews()
        animalTiles.clear()

        // Surprise tile first
        addAnimalTile(AnimalImageGenerator.SURPRISE_KEY, "🎲")

        // Then the 10 curated animals
        for (animal in AnimalImageGenerator.animals) {
            addAnimalTile(animal.key, animal.emoji)
        }
        updateTileHighlights()
    }

    private fun addAnimalTile(key: String, emoji: String) {
        val tile = Button(this).apply {
            text = emoji
            textSize = 26f
            setPadding(0, 0, 0, 0)
            isAllCaps = false
            setOnClickListener {
                vm.selectedAnimalKey = key
                updateTileHighlights()
            }
        }
        val params = GridLayout.LayoutParams().apply {
            width = dp(70)
            height = dp(70)
            setMargins(dp(4), dp(4), dp(4), dp(4))
        }
        tile.layoutParams = params
        animalGrid.addView(tile)
        animalTiles[key] = tile
    }

    private fun updateTileHighlights() {
        for ((key, tile) in animalTiles) {
            val selected = key == vm.selectedAnimalKey
            tile.setBackgroundColor(
                ContextCompat.getColor(
                    this,
                    if (selected) R.color.accent_teal_dim else R.color.btn_bg
                )
            )
            val collected = key != AnimalImageGenerator.SURPRISE_KEY && storage.isCollected(key)
            val emoji = if (key == AnimalImageGenerator.SURPRISE_KEY) {
                "🎲"
            } else {
                AnimalImageGenerator.animalForKey(key).emoji
            }
            tile.text = if (collected) "$emoji\n⭐" else emoji
        }
    }

    private fun refreshCollection() {
        val collected = storage.collection()
        if (collected.isEmpty()) {
            collectionLabel.visibility = View.GONE
            collectionEmojis.visibility = View.GONE
            return
        }
        val emojis = AnimalImageGenerator.animals
            .filter { collected.contains(it.key) }
            .joinToString(" ") { it.emoji }
        collectionLabel.visibility = View.VISIBLE
        collectionEmojis.visibility = View.VISIBLE
        collectionEmojis.text = emojis
    }

    // ===== Buttons =====

    private fun setupButtons() {
        val tierMap = mapOf(
            R.id.btnTiny to 12,
            R.id.btnSmall to 20,
            R.id.btnMedium to 50,
            R.id.btnBig to 100
        )
        for ((id, count) in tierMap) {
            findViewById<Button>(id).setOnClickListener { startGame(count) }
        }

        findViewById<Button>(R.id.edgesBtn).setOnClickListener {
            vm.showEdges = !vm.showEdges
            puzzleView.invalidate()
        }
        findViewById<Button>(R.id.hintBtn).setOnClickListener {
            vm.showHint = !vm.showHint
            puzzleView.invalidate()
        }
        findViewById<Button>(R.id.centerBtn).setOnClickListener {
            puzzleView.recenter()
        }
        findViewById<Button>(R.id.newBtn).setOnClickListener {
            confirmOverlay.visibility = View.VISIBLE
        }

        // Settings
        muteBtn.setOnClickListener {
            soundManager.setMuted(!soundManager.isMuted)
            updateSettingButtons()
        }
        timerBtn.setOnClickListener {
            storage.showTimer = !storage.showTimer
            updateSettingButtons()
            updateTimerVisibility()
        }
        findViewById<Button>(R.id.howToBtn).setOnClickListener { showTutorial() }

        // Tutorial
        findViewById<Button>(R.id.letsGoBtn).setOnClickListener { dismissTutorial() }

        // Confirm new puzzle
        findViewById<Button>(R.id.keepPlayingBtn).setOnClickListener {
            confirmOverlay.visibility = View.GONE
        }
        findViewById<Button>(R.id.confirmNewBtn).setOnClickListener {
            confirmOverlay.visibility = View.GONE
            resetToStart()
        }

        // Win overlay
        findViewById<Button>(R.id.playAgainBtn).setOnClickListener { playAgain() }
        findViewById<Button>(R.id.chooseAnotherBtn).setOnClickListener { resetToStart() }
    }

    private fun updateSettingButtons() {
        muteBtn.setText(if (soundManager.isMuted) R.string.sound_off else R.string.sound_on)
        timerBtn.setText(if (storage.showTimer) R.string.timer_on else R.string.timer_off)
    }

    private fun updateTimerVisibility() {
        timerText.visibility = if (storage.showTimer) View.VISIBLE else View.GONE
    }

    // ===== Tutorial =====

    private fun maybeShowTutorial() {
        if (!storage.tutorialSeen) showTutorial()
    }

    private fun showTutorial() {
        tutorialOverlay.visibility = View.VISIBLE
    }

    private fun dismissTutorial() {
        storage.tutorialSeen = true
        tutorialOverlay.visibility = View.GONE
    }

    // ===== Game flow =====

    private fun startGame(pieceCount: Int) {
        lastPieceCount = pieceCount
        vm.startNewGame(pieceCount)
        launchGame()
    }

    private fun playAgain() {
        vm.startNewGame(lastPieceCount, vm.activeAnimalKey)
        launchGame()
    }

    private fun launchGame() {
        showGameScreen()
        confettiView.stop()
        winOverlay.visibility = View.GONE
        milestoneBanner.visibility = View.GONE
        updateTimerVisibility()

        puzzleView.post {
            val w = puzzleView.width.toFloat()
            val h = puzzleView.height.toFloat()
            if (w <= 0 || h <= 0) return@post

            vm.initLayout(w, h)
            wireUpPuzzleView()
            updateProgress()
            startTimer()
        }
    }

    private fun restoreGame() {
        val w = puzzleView.width.toFloat()
        val h = puzzleView.height.toFloat()
        if (w <= 0 || h <= 0) return

        wireUpPuzzleView()
        updateProgress()
        updateTimerVisibility()
        if (vm.gameActive) {
            startTimer()
        }
    }

    private fun wireUpPuzzleView() {
        puzzleView.viewModel = vm
        puzzleView.buildPiecePaths()
        puzzleView.onPiecePlaced = {
            updateProgress()
            checkMilestone()
        }
        puzzleView.onSnap = { soundManager.playSnap() }
        puzzleView.onPickUp = { soundManager.playDrop() }
        puzzleView.onPuzzleComplete = {
            stopTimer()
            soundManager.playWin()
            onPuzzleWon()
        }
        puzzleView.invalidate()
    }

    private fun onPuzzleWon() {
        storage.addToCollection(vm.activeAnimalKey)
        refreshCollection()
        updateTileHighlights()
        showWinScreen()
    }

    private fun checkMilestone() {
        val threshold = vm.checkMilestone() ?: return
        val text = when (threshold) {
            25 -> "Great start! 🌟"
            50 -> "Halfway there! 🎉"
            75 -> "Almost done! 💪"
            else -> return
        }
        milestoneBanner.text = text
        milestoneBanner.visibility = View.VISIBLE
        milestoneRunnable?.let { handler.removeCallbacks(it) }
        val r = Runnable { milestoneBanner.visibility = View.GONE }
        milestoneRunnable = r
        handler.postDelayed(r, 1600)
    }

    private fun showGameScreen() {
        startScreen.visibility = View.GONE
        gameScreen.visibility = View.VISIBLE
        winOverlay.visibility = View.GONE
    }

    private fun showWinScreen() {
        val animal = vm.activeAnimal
        winAnimalEmoji.text = animal.emoji
        winAnimalName.text = "You finished the ${animal.name}!"
        if (storage.showTimer) {
            winTimeText.visibility = View.VISIBLE
            winTimeText.text = "Time: ${vm.getElapsedString()}"
        } else {
            winTimeText.visibility = View.GONE
        }
        winOverlay.visibility = View.VISIBLE
        confettiView.post { confettiView.start() }
    }

    private fun resetToStart() {
        vm.gameActive = false
        vm.initialized = false
        stopTimer()
        confettiView.stop()
        milestoneBanner.visibility = View.GONE
        puzzleView.viewModel = null
        gameScreen.visibility = View.GONE
        winOverlay.visibility = View.GONE
        startScreen.visibility = View.VISIBLE
        refreshCollection()
        updateTileHighlights()
    }

    // ===== Timer =====

    private fun startTimer() {
        stopTimer()
        if (!storage.showTimer) return
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

    private fun updateProgress() {
        progressBar.progress = (vm.progress * 100).toInt()
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
        soundManager.release()
    }
}
