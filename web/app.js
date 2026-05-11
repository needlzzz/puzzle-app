(function () {
  'use strict';

  // ===== ENGINE REFERENCE =====
  const Engine = window.PuzzleEngine;

  // ===== CONSTANTS =====
  const TAB_SIZE = 0.2;
  const ANIMAL_KEYWORDS = ['cat', 'dog', 'lion', 'tiger', 'elephant', 'bird', 'fox', 'wolf', 'bear', 'deer', 'horse', 'rabbit', 'owl', 'dolphin', 'penguin'];
  const PUZZLE_IMAGE_W = Engine.DEFAULTS.IMAGE_W;
  const PUZZLE_IMAGE_H = Engine.DEFAULTS.IMAGE_H;

  // ===== DOM REFS =====
  const startScreen = document.getElementById('start-screen');
  const loadingEl = document.getElementById('loading');
  const gameScreen = document.getElementById('game-screen');
  const canvas = document.getElementById('puzzle-canvas');
  const ctx = canvas.getContext('2d');
  const timerEl = document.getElementById('timer');
  const pieceCounterEl = document.getElementById('piece-counter');
  const hintToggle = document.getElementById('hint-toggle');
  const newPuzzleBtn = document.getElementById('new-puzzle-btn');
  const winOverlay = document.getElementById('win-overlay');
  const confettiCanvas = document.getElementById('confetti-canvas');
  const confettiCtx = confettiCanvas.getContext('2d');
  const winTimeEl = document.getElementById('win-time');
  const winPiecesEl = document.getElementById('win-pieces');
  const winNewBtn = document.getElementById('win-new-btn');

  // ===== GAME STATE =====
  let pieces = [];
  let piecesById = {};
  let groups = [];
  let cols = 0;
  let rows = 0;
  let pieceW = 0;
  let pieceH = 0;
  let puzzleImage = null;
  let totalPieces = 0;
  let placedPieces = 0;
  let showHint = false;
  let timerStart = 0;
  let timerInterval = null;
  let gameActive = false;

  let puzzleX = 0;
  let puzzleY = 0;

  let camera = { x: 0, y: 0, zoom: 1 };

  // Interaction state
  let dragGroup = null;
  let dragPiece = null;
  let dragOffset = { x: 0, y: 0 };
  let isDragging = false;
  let isPanning = false;
  let lastPanPoint = null;
  let lastPinchDist = null;
  let lastPinchCenter = null;

  // ===== JIGSAW PATH DRAWING (Canvas-specific, stays here) =====
  // Draw a jigsaw edge directly into the path.
  // For top edge: draws from current point rightward along x-axis for `len` pixels.
  // For other edges, caller provides transform functions to rotate/translate coordinates.
  function drawJigsawEdgeDirect(path, len, dir, tx, ty) {
    if (dir === 0) {
      path.lineTo(tx(len, 0), ty(len, 0));
      return;
    }
    const tabH = len * TAB_SIZE * dir;
    const neck = len * 0.35;
    const neckW = len * 0.1;
    const tabW = len * 0.14;

    path.lineTo(tx(neck - neckW, 0), ty(neck - neckW, 0));
    path.bezierCurveTo(
      tx(neck - neckW, 0), ty(neck - neckW, 0),
      tx(neck - neckW * 1.2, -tabH * 0.4), ty(neck - neckW * 1.2, -tabH * 0.4),
      tx(neck - tabW, -tabH * 0.8), ty(neck - tabW, -tabH * 0.8)
    );
    path.bezierCurveTo(
      tx(neck - tabW * 1.6, -tabH * 1.2), ty(neck - tabW * 1.6, -tabH * 1.2),
      tx(neck + neckW + tabW * 0.6, -tabH * 1.2), ty(neck + neckW + tabW * 0.6, -tabH * 1.2),
      tx(neck + tabW, -tabH * 0.8), ty(neck + tabW, -tabH * 0.8)
    );
    path.bezierCurveTo(
      tx(neck + neckW * 1.2, -tabH * 0.4), ty(neck + neckW * 1.2, -tabH * 0.4),
      tx(neck + neckW, 0), ty(neck + neckW, 0),
      tx(neck + neckW, 0), ty(neck + neckW, 0)
    );
    path.lineTo(tx(len, 0), ty(len, 0));
  }

  function buildPiecePath(col, row, edges) {
    const path = new Path2D();
    const w = pieceW;
    const h = pieceH;

    path.moveTo(0, 0);

    // Top edge: left to right, y=0
    const topDir = row === 0 ? 0 : -edges.h[row - 1][col];
    drawJigsawEdgeDirect(path, w, topDir,
      (x, y) => x,
      (x, y) => y
    );

    // Right edge: top to bottom, x=w (rotate 90°: x→y, y→-x, then translate by (w,0))
    const rightDir = col === cols - 1 ? 0 : edges.v[row][col];
    drawJigsawEdgeDirect(path, h, rightDir,
      (x, y) => w + y,
      (x, y) => x
    );

    // Bottom edge: right to left, y=h (rotate 180°: x→-x, y→-y, then translate by (w,h))
    const bottomDir = row === rows - 1 ? 0 : edges.h[row][col];
    drawJigsawEdgeDirect(path, w, bottomDir,
      (x, y) => w - x,
      (x, y) => h - y
    );

    // Left edge: bottom to top, x=0 (rotate 270°: x→-y, y→x, then translate by (0,h))
    const leftDir = col === 0 ? 0 : -edges.v[row][col - 1];
    drawJigsawEdgeDirect(path, h, leftDir,
      (x, y) => -y,
      (x, y) => h - x
    );

    path.closePath();
    return path;
  }

  // ===== PIECE CREATION =====
  function createPieces(edges) {
    const gs = Engine.createGameState(cols, rows, pieceW, pieceH, puzzleX, puzzleY);
    piecesById = gs.piecesById;
    groups = gs.groups;
    placedPieces = 0;

    const margin = Math.max(pieceW, pieceH) * 1.5;

    // Add paths and scatter positions
    for (const piece of gs.pieces) {
      piece.path = buildPiecePath(piece.col, piece.row, edges);

      // Scatter around the puzzle area
      const side = Math.floor(Math.random() * 4);
      switch (side) {
        case 0:
          piece.x = puzzleX - margin - Math.random() * margin * 2;
          piece.y = puzzleY + Math.random() * (rows * pieceH);
          break;
        case 1:
          piece.x = puzzleX + cols * pieceW + margin + Math.random() * margin * 2;
          piece.y = puzzleY + Math.random() * (rows * pieceH);
          break;
        case 2:
          piece.x = puzzleX + Math.random() * (cols * pieceW);
          piece.y = puzzleY - margin - Math.random() * margin * 2;
          break;
        case 3:
          piece.x = puzzleX + Math.random() * (cols * pieceW);
          piece.y = puzzleY + rows * pieceH + margin + Math.random() * margin * 2;
          break;
      }
    }
    pieces = gs.pieces;
  }

  // ===== IMAGE LOADING =====
  // Multiple image sources tried in order. Each returns real animal photos.
  // Unsplash photo IDs known to be animals (free to use under Unsplash license)
  const UNSPLASH_ANIMAL_IDS = [
    'YozNeHM8MaA',  // lion
    'u_kMWN-BWyU',  // elephant
    'OYGN_PWBf4k',  // fox
    'fikJnGPXxJ0',  // dolphin
    'pG-_La1_PDA',  // owl
    'dY-IU16GvPY',  // penguin
    'MCYBfbRVYeU',  // tiger
    'eLiJnXFBisc',  // bear
    '75715CVEJhI',  // cat
    'SIgX-FASxps',  // wolf
  ];

  // Try loading an image from a URL with timeout and CORS check
  function tryLoadImage(url, timeoutMs) {
    return new Promise((resolve) => {
      const img = new Image();
      img.crossOrigin = 'anonymous';
      let done = false;

      const fail = () => { if (!done) { done = true; resolve(null); } };
      const timer = setTimeout(fail, timeoutMs);

      img.onload = () => {
        if (done) return;
        clearTimeout(timer);
        // Verify not tainted
        try {
          const tc = document.createElement('canvas');
          tc.width = 1; tc.height = 1;
          const tctx = tc.getContext('2d');
          tctx.drawImage(img, 0, 0);
          tctx.getImageData(0, 0, 1, 1);
          done = true;
          resolve(img);
        } catch (e) {
          fail();
        }
      };
      img.onerror = () => { clearTimeout(timer); fail(); };
      img.src = url;
    });
  }

  // Procedural fallback — only used if ALL network sources fail
  function generateProceduralFallback() {
    const animals = [
      { name: 'Lion',     emoji: '🦁', bg: ['#F4A460','#CD853F','#DEB887'] },
      { name: 'Elephant', emoji: '🐘', bg: ['#708090','#778899','#B0C4DE'] },
      { name: 'Fox',      emoji: '🦊', bg: ['#FF8C00','#FF6347','#FFD700'] },
      { name: 'Dolphin',  emoji: '🐬', bg: ['#00CED1','#1E90FF','#87CEEB'] },
      { name: 'Owl',      emoji: '🦉', bg: ['#2E0854','#4B0082','#6A0DAD'] },
      { name: 'Penguin',  emoji: '🐧', bg: ['#4682B4','#B0E0E6','#F0F8FF'] },
      { name: 'Tiger',    emoji: '🐯', bg: ['#FF8C00','#FF4500','#FFD700'] },
      { name: 'Bear',     emoji: '🐻', bg: ['#228B22','#2E8B57','#90EE90'] },
      { name: 'Cat',      emoji: '🐱', bg: ['#FF69B4','#FFB6C1','#FFC0CB'] },
      { name: 'Wolf',     emoji: '🐺', bg: ['#2F4F4F','#696969','#A9A9A9'] },
    ];
    const a = animals[Math.floor(Math.random() * animals.length)];
    const c = document.createElement('canvas');
    c.width = PUZZLE_IMAGE_W; c.height = PUZZLE_IMAGE_H;
    const cx = c.getContext('2d');
    const W = PUZZLE_IMAGE_W, H = PUZZLE_IMAGE_H;

    const grad = cx.createLinearGradient(0, 0, W, H);
    grad.addColorStop(0, a.bg[0]); grad.addColorStop(0.5, a.bg[1]); grad.addColorStop(1, a.bg[2]);
    cx.fillStyle = grad; cx.fillRect(0, 0, W, H);

    for (let i = 0; i < 25; i++) {
      cx.beginPath();
      cx.arc((W * 0.1) + ((i * 131) % (W * 0.8)), (H * 0.1) + ((i * 97) % (H * 0.8)), 30 + (i * 47 % 70), 0, Math.PI * 2);
      cx.fillStyle = `hsla(${(i * 40) % 360}, 60%, 65%, 0.2)`;
      cx.fill();
    }

    cx.font = `${Math.min(W, H) * 0.35}px sans-serif`;
    cx.textAlign = 'center'; cx.textBaseline = 'middle';
    cx.fillText(a.emoji, W / 2, H * 0.42);
    cx.fillStyle = 'rgba(255,255,255,0.9)';
    cx.font = `bold ${H * 0.08}px sans-serif`;
    cx.fillText(a.name, W / 2, H * 0.78);

    return c;
  }

  async function loadAnimalImage() {
    const W = PUZZLE_IMAGE_W, H = PUZZLE_IMAGE_H;

    // Source 1: Unsplash direct (most reliable, real photos)
    const unsplashId = UNSPLASH_ANIMAL_IDS[Math.floor(Math.random() * UNSPLASH_ANIMAL_IDS.length)];
    const unsplashUrl = `https://images.unsplash.com/photo-${unsplashId}?w=${W}&h=${H}&fit=crop&auto=format&q=70`;
    const img1 = await tryLoadImage(unsplashUrl, 5000);
    if (img1) return img1;

    // Source 2: Lorem Flickr (keyword-based animal photos)
    const keyword = ANIMAL_KEYWORDS[Math.floor(Math.random() * ANIMAL_KEYWORDS.length)];
    const flickrUrl = `https://loremflickr.com/${W}/${H}/${keyword}`;
    const img2 = await tryLoadImage(flickrUrl, 5000);
    if (img2) return img2;

    // Source 3: Picsum (random high-quality photos, not animal-specific but real)
    const picsumId = 10 + Math.floor(Math.random() * 200);
    const picsumUrl = `https://picsum.photos/id/${picsumId}/${W}/${H}`;
    const img3 = await tryLoadImage(picsumUrl, 5000);
    if (img3) return img3;

    // Last resort: procedural fallback
    return generateProceduralFallback();
  }

  // ===== COORDINATE TRANSFORMS (delegate to engine) =====
  function screenToWorld(sx, sy) {
    return Engine.screenToWorld(sx, sy, camera, canvas.width, canvas.height);
  }

  // ===== RENDERING =====
  function render() {
    if (!gameActive) return;

    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.save();

    ctx.translate(canvas.width / 2, canvas.height / 2);
    ctx.scale(camera.zoom, camera.zoom);
    ctx.translate(-camera.x, -camera.y);

    // Puzzle outline (always visible)
    ctx.strokeStyle = 'rgba(255, 248, 231, 0.6)';
    ctx.lineWidth = 2 / camera.zoom;
    ctx.setLineDash([8 / camera.zoom, 6 / camera.zoom]);
    ctx.strokeRect(puzzleX, puzzleY, cols * pieceW, rows * pieceH);
    ctx.setLineDash([]);

    // Hint image
    if (showHint) {
      ctx.globalAlpha = 0.18;
      ctx.drawImage(puzzleImage, puzzleX, puzzleY, cols * pieceW, rows * pieceH);
      ctx.globalAlpha = 1;
    }

    // Grid lines
    ctx.strokeStyle = 'rgba(255, 248, 231, 0.15)';
    ctx.lineWidth = 1 / camera.zoom;
    for (let c = 1; c < cols; c++) {
      ctx.beginPath();
      ctx.moveTo(puzzleX + c * pieceW, puzzleY);
      ctx.lineTo(puzzleX + c * pieceW, puzzleY + rows * pieceH);
      ctx.stroke();
    }
    for (let r = 1; r < rows; r++) {
      ctx.beginPath();
      ctx.moveTo(puzzleX, puzzleY + r * pieceH);
      ctx.lineTo(puzzleX + cols * pieceW, puzzleY + r * pieceH);
      ctx.stroke();
    }

    // Pieces — placed below, unplaced above
    const sortedPieces = [...pieces].sort((a, b) => {
      if (a.placed && !b.placed) return -1;
      if (!a.placed && b.placed) return 1;
      return 0;
    });
    for (const piece of sortedPieces) drawPiece(piece);

    ctx.restore();
    requestAnimationFrame(render);
  }

  function drawPiece(piece) {
    ctx.save();
    ctx.translate(piece.x, piece.y);

    ctx.save();
    ctx.clip(piece.path);
    const totalW = cols * pieceW;
    const totalH = rows * pieceH;
    ctx.drawImage(puzzleImage, 0, 0, PUZZLE_IMAGE_W, PUZZLE_IMAGE_H, -piece.col * pieceW, -piece.row * pieceH, totalW, totalH);
    ctx.restore();

    ctx.strokeStyle = piece.placed ? 'rgba(255,255,255,0.3)' : 'rgba(0,0,0,0.5)';
    ctx.lineWidth = piece.placed ? 0.5 : 1.2;
    ctx.stroke(piece.path);

    if (!piece.placed) {
      ctx.strokeStyle = 'rgba(0,0,0,0.15)';
      ctx.lineWidth = 3;
      ctx.stroke(piece.path);
      ctx.strokeStyle = 'rgba(0,0,0,0.5)';
      ctx.lineWidth = 1.2;
      ctx.stroke(piece.path);
    }

    ctx.restore();
  }

  // ===== HIT TESTING =====
  function hitTestPiece(worldX, worldY) {
    for (let i = pieces.length - 1; i >= 0; i--) {
      const p = pieces[i];
      if (p.placed) continue;
      const localX = worldX - p.x;
      const localY = worldY - p.y;
      ctx.save();
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      const inside = ctx.isPointInPath(p.path, localX, localY);
      ctx.restore();
      if (inside) return p;
    }
    return null;
  }

  // ===== SNAP & GROUP LOGIC (delegates to engine) =====
  function getGroup(piece) {
    return groups.find(g => g.id === piece.groupId);
  }

  function getEngineState() {
    return { cols, rows, pieceW, pieceH, piecesById, groups };
  }

  function trySnapAndUpdate(movedGroup) {
    const result = Engine.trySnap(movedGroup, getEngineState());
    if (result.placedCount > 0) {
      placedPieces += result.placedCount;
      updatePieceCounter();
      checkWin();
    }
    return result.snapped;
  }

  // ===== INPUT HANDLING =====
  function getPointerPos(e) {
    const rect = canvas.getBoundingClientRect();
    if (e.touches) {
      return {
        x: (e.touches[0].clientX - rect.left) * (canvas.width / rect.width),
        y: (e.touches[0].clientY - rect.top) * (canvas.height / rect.height)
      };
    }
    return {
      x: (e.clientX - rect.left) * (canvas.width / rect.width),
      y: (e.clientY - rect.top) * (canvas.height / rect.height)
    };
  }

  function getPinchData(e) {
    const rect = canvas.getBoundingClientRect();
    const t1 = e.touches[0], t2 = e.touches[1];
    const x1 = (t1.clientX - rect.left) * (canvas.width / rect.width);
    const y1 = (t1.clientY - rect.top) * (canvas.height / rect.height);
    const x2 = (t2.clientX - rect.left) * (canvas.width / rect.width);
    const y2 = (t2.clientY - rect.top) * (canvas.height / rect.height);
    return {
      dist: Math.hypot(x2 - x1, y2 - y1),
      center: { x: (x1 + x2) / 2, y: (y1 + y2) / 2 }
    };
  }

  function onPointerDown(e) {
    e.preventDefault();
    if (!gameActive) return;

    if (e.touches && e.touches.length === 2) {
      isDragging = false;
      dragGroup = null;
      isPanning = true;
      const pd = getPinchData(e);
      lastPinchDist = pd.dist;
      lastPinchCenter = pd.center;
      return;
    }

    const pos = getPointerPos(e);
    const world = screenToWorld(pos.x, pos.y);
    const piece = hitTestPiece(world.x, world.y);

    if (piece) {
      isDragging = true;
      const group = getGroup(piece);
      dragGroup = group;
      dragPiece = piece;
      dragOffset.x = world.x - piece.x;
      dragOffset.y = world.y - piece.y;

      const groupPieceIds = new Set(group.pieces.map(p => p.id));
      const others = pieces.filter(p => !groupPieceIds.has(p.id));
      const groupPieces = pieces.filter(p => groupPieceIds.has(p.id));
      pieces = [...others, ...groupPieces];
    } else {
      isPanning = true;
      lastPanPoint = pos;
    }
  }

  function onPointerMove(e) {
    e.preventDefault();
    if (!gameActive) return;

    if (e.touches && e.touches.length === 2 && isPanning) {
      const pd = getPinchData(e);
      if (lastPinchDist !== null) {
        const zoomDelta = pd.dist / lastPinchDist;
        const newZoom = Math.max(0.3, Math.min(5, camera.zoom * zoomDelta));
        const worldBefore = screenToWorld(pd.center.x, pd.center.y);
        camera.zoom = newZoom;
        const worldAfter = screenToWorld(pd.center.x, pd.center.y);
        camera.x -= (worldAfter.x - worldBefore.x);
        camera.y -= (worldAfter.y - worldBefore.y);
      }
      if (lastPinchCenter !== null) {
        const dx = (pd.center.x - lastPinchCenter.x) / camera.zoom;
        const dy = (pd.center.y - lastPinchCenter.y) / camera.zoom;
        camera.x -= dx;
        camera.y -= dy;
      }
      lastPinchDist = pd.dist;
      lastPinchCenter = pd.center;
      return;
    }

    if (isDragging && dragGroup && dragPiece) {
      const pos = getPointerPos(e);
      const world = screenToWorld(pos.x, pos.y);
      const baseDx = (world.x - dragOffset.x) - dragPiece.x;
      const baseDy = (world.y - dragOffset.y) - dragPiece.y;
      for (const p of dragGroup.pieces) {
        p.x += baseDx;
        p.y += baseDy;
      }
      return;
    }

    if (isPanning && !isDragging) {
      const pos = getPointerPos(e);
      if (lastPanPoint) {
        const dx = (pos.x - lastPanPoint.x) / camera.zoom;
        const dy = (pos.y - lastPanPoint.y) / camera.zoom;
        camera.x -= dx;
        camera.y -= dy;
        lastPanPoint = pos;
      }
    }
  }

  function onPointerUp(e) {
    e.preventDefault();
    if (isDragging && dragGroup && !dragGroup.placed) {
      trySnapAndUpdate(dragGroup);
    }
    isDragging = false;
    dragGroup = null;
    dragPiece = null;
    isPanning = false;
    lastPanPoint = null;
    lastPinchDist = null;
    lastPinchCenter = null;
  }

  function onWheel(e) {
    e.preventDefault();
    if (!gameActive) return;
    const pos = {
      x: e.offsetX * (canvas.width / canvas.clientWidth),
      y: e.offsetY * (canvas.height / canvas.clientHeight)
    };
    const worldBefore = screenToWorld(pos.x, pos.y);
    const zoomFactor = e.deltaY < 0 ? 1.1 : 0.9;
    camera.zoom = Math.max(0.3, Math.min(5, camera.zoom * zoomFactor));
    const worldAfter = screenToWorld(pos.x, pos.y);
    camera.x -= (worldAfter.x - worldBefore.x);
    camera.y -= (worldAfter.y - worldBefore.y);
  }

  // ===== TIMER =====
  function startTimer() {
    timerStart = Date.now();
    timerInterval = setInterval(updateTimer, 1000);
    updateTimer();
  }

  function stopTimer() {
    clearInterval(timerInterval);
    timerInterval = null;
  }

  function updateTimer() {
    const elapsed = Math.floor((Date.now() - timerStart) / 1000);
    const mins = String(Math.floor(elapsed / 60)).padStart(2, '0');
    const secs = String(elapsed % 60).padStart(2, '0');
    timerEl.textContent = `⏱ ${mins}:${secs}`;
  }

  function getElapsedString() {
    const elapsed = Math.floor((Date.now() - timerStart) / 1000);
    const mins = Math.floor(elapsed / 60);
    const secs = elapsed % 60;
    if (mins > 0) return `${mins}m ${secs}s`;
    return `${secs}s`;
  }

  function updatePieceCounter() {
    pieceCounterEl.textContent = `${placedPieces} / ${totalPieces}`;
  }

  // ===== WIN STATE =====
  function checkWin() {
    if (placedPieces === totalPieces) {
      gameActive = false;
      stopTimer();
      showWinScreen();
    }
  }

  function showWinScreen() {
    winTimeEl.textContent = `Time: ${getElapsedString()}`;
    winPiecesEl.textContent = `Pieces: ${totalPieces}`;
    winOverlay.classList.remove('hidden');
    confettiCanvas.width = window.innerWidth;
    confettiCanvas.height = window.innerHeight;
    runConfetti();
  }

  // ===== CONFETTI =====
  function runConfetti() {
    const particles = [];
    const colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD', '#FF8C00', '#7B68EE'];
    for (let i = 0; i < 200; i++) {
      particles.push({
        x: confettiCanvas.width / 2 + (Math.random() - 0.5) * 200,
        y: confettiCanvas.height / 2,
        vx: (Math.random() - 0.5) * 16,
        vy: -Math.random() * 18 - 4,
        size: 4 + Math.random() * 8,
        color: colors[Math.floor(Math.random() * colors.length)],
        rotation: Math.random() * 360,
        rotSpeed: (Math.random() - 0.5) * 12,
        gravity: 0.3 + Math.random() * 0.2,
        life: 1
      });
    }
    let frame = 0;
    function animateConfetti() {
      frame++;
      confettiCtx.clearRect(0, 0, confettiCanvas.width, confettiCanvas.height);
      let alive = false;
      for (const p of particles) {
        if (p.life <= 0) continue;
        alive = true;
        p.x += p.vx; p.y += p.vy; p.vy += p.gravity; p.vx *= 0.99;
        p.rotation += p.rotSpeed; p.life -= 0.005;
        confettiCtx.save();
        confettiCtx.translate(p.x, p.y);
        confettiCtx.rotate(p.rotation * Math.PI / 180);
        confettiCtx.globalAlpha = Math.max(0, p.life);
        confettiCtx.fillStyle = p.color;
        confettiCtx.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2);
        confettiCtx.restore();
      }
      if (alive && frame < 300) requestAnimationFrame(animateConfetti);
    }
    animateConfetti();
  }

  // ===== CANVAS RESIZE =====
  function resizeCanvas() {
    const dpr = window.devicePixelRatio || 1;
    canvas.width = window.innerWidth * dpr;
    canvas.height = window.innerHeight * dpr;
    canvas.style.width = window.innerWidth + 'px';
    canvas.style.height = window.innerHeight + 'px';
  }

  // ===== GAME INIT =====
  async function startGame(pieceCount) {
    loadingEl.classList.remove('hidden');
    document.querySelectorAll('.diff-btn').forEach(b => b.disabled = true);

    puzzleImage = await loadAnimalImage();

    const grid = Engine.computeGrid(pieceCount, PUZZLE_IMAGE_W, PUZZLE_IMAGE_H);
    cols = grid.cols;
    rows = grid.rows;
    totalPieces = cols * rows;

    resizeCanvas();

    const maxPuzzleW = canvas.width * 0.5;
    const maxPuzzleH = canvas.height * 0.5;
    const imageAspect = PUZZLE_IMAGE_W / PUZZLE_IMAGE_H;

    let puzzleTotalW, puzzleTotalH;
    if (maxPuzzleW / maxPuzzleH > imageAspect) {
      puzzleTotalH = maxPuzzleH;
      puzzleTotalW = maxPuzzleH * imageAspect;
    } else {
      puzzleTotalW = maxPuzzleW;
      puzzleTotalH = maxPuzzleW / imageAspect;
    }
    pieceW = puzzleTotalW / cols;
    pieceH = puzzleTotalH / rows;

    puzzleX = (canvas.width / 2) - (cols * pieceW / 2);
    puzzleY = (canvas.height / 2) - (rows * pieceH / 2);

    camera = { x: canvas.width / 2, y: canvas.height / 2, zoom: 1 };

    const edges = Engine.generateEdges(rows, cols);
    createPieces(edges);

    showHint = false;
    hintToggle.classList.remove('active');
    placedPieces = 0;
    updatePieceCounter();

    startScreen.classList.add('hidden');
    gameScreen.classList.remove('hidden');
    winOverlay.classList.add('hidden');

    gameActive = true;
    startTimer();
    requestAnimationFrame(render);
  }

  function resetToStart() {
    gameActive = false;
    stopTimer();
    gameScreen.classList.add('hidden');
    winOverlay.classList.add('hidden');
    startScreen.classList.remove('hidden');
    loadingEl.classList.add('hidden');
    document.querySelectorAll('.diff-btn').forEach(b => b.disabled = false);
  }

  // ===== EVENT BINDING =====
  document.querySelectorAll('.diff-btn').forEach(btn => {
    btn.addEventListener('click', () => startGame(parseInt(btn.dataset.pieces, 10)));
  });

  hintToggle.addEventListener('click', () => {
    showHint = !showHint;
    hintToggle.classList.toggle('active', showHint);
  });

  newPuzzleBtn.addEventListener('click', resetToStart);
  winNewBtn.addEventListener('click', resetToStart);

  canvas.addEventListener('mousedown', onPointerDown);
  canvas.addEventListener('mousemove', onPointerMove);
  canvas.addEventListener('mouseup', onPointerUp);
  canvas.addEventListener('mouseleave', onPointerUp);
  canvas.addEventListener('wheel', onWheel, { passive: false });

  canvas.addEventListener('touchstart', onPointerDown, { passive: false });
  canvas.addEventListener('touchmove', onPointerMove, { passive: false });
  canvas.addEventListener('touchend', onPointerUp, { passive: false });
  canvas.addEventListener('touchcancel', onPointerUp, { passive: false });

  window.addEventListener('resize', () => { if (gameActive) resizeCanvas(); });

})();
