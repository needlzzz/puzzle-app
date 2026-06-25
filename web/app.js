(function () {
  'use strict';

  // ===== ENGINE / MODULE REFERENCES =====
  const Engine = window.PuzzleEngine;
  const Sound = window.Sound;
  const Store = window.Storage;

  // ===== CONSTANTS =====
  const TAB_SIZE = 0.2;
  const PUZZLE_IMAGE_W = Engine.DEFAULTS.IMAGE_W;
  const PUZZLE_IMAGE_H = Engine.DEFAULTS.IMAGE_H;

  const MIN_ZOOM = 0.2;
  const MAX_ZOOM = 4;
  const SNAP_RATIO = 0.45;       // snap distance as a fraction of piece size
  const MIN_SNAP_SCREEN = 22;    // never let the on-screen catch radius drop below this
  const RESUME_VERSION = 1;

  // Curated, animal-only image set (no random / non-animal sources).
  const CURATED_ANIMALS = [
    { key: 'lion',     name: 'Lion',     emoji: '🦁', unsplashId: 'YozNeHM8MaA', bg: ['#F4A460', '#CD853F', '#DEB887'] },
    { key: 'elephant', name: 'Elephant', emoji: '🐘', unsplashId: 'u_kMWN-BWyU', bg: ['#708090', '#778899', '#B0C4DE'] },
    { key: 'fox',      name: 'Fox',      emoji: '🦊', unsplashId: 'OYGN_PWBf4k', bg: ['#FF8C00', '#FF6347', '#FFD700'] },
    { key: 'dolphin',  name: 'Dolphin',  emoji: '🐬', unsplashId: 'fikJnGPXxJ0', bg: ['#00CED1', '#1E90FF', '#87CEEB'] },
    { key: 'owl',      name: 'Owl',      emoji: '🦉', unsplashId: 'pG-_La1_PDA', bg: ['#2E0854', '#4B0082', '#6A0DAD'] },
    { key: 'penguin',  name: 'Penguin',  emoji: '🐧', unsplashId: 'dY-IU16GvPY', bg: ['#4682B4', '#B0E0E6', '#F0F8FF'] },
    { key: 'tiger',    name: 'Tiger',    emoji: '🐯', unsplashId: 'MCYBfbRVYeU', bg: ['#FF8C00', '#FF4500', '#FFD700'] },
    { key: 'bear',     name: 'Bear',     emoji: '🐻', unsplashId: 'eLiJnXFBisc', bg: ['#228B22', '#2E8B57', '#90EE90'] },
    { key: 'cat',      name: 'Cat',      emoji: '🐱', unsplashId: '75715CVEJhI', bg: ['#FF69B4', '#FFB6C1', '#FFC0CB'] },
    { key: 'wolf',     name: 'Wolf',     emoji: '🐺', unsplashId: 'SIgX-FASxps', bg: ['#2F4F4F', '#696969', '#A9A9A9'] },
  ];

  // Visual, literacy-free difficulty tiers (includes a genuine <=12-piece Easy).
  const DIFFICULTY_TIERS = [
    { key: 'easy',   emoji: '🐣', name: 'Easy',   pieces: 12 },
    { key: 'medium', emoji: '🐥', name: 'Medium', pieces: 20 },
    { key: 'hard',   emoji: '🐔', name: 'Hard',   pieces: 50 },
    { key: 'expert', emoji: '🦅', name: 'Expert', pieces: 100 },
  ];

  // ===== DOM REFS =====
  const startScreen = document.getElementById('start-screen');
  const loadingEl = document.getElementById('loading');
  const gameScreen = document.getElementById('game-screen');
  const canvas = document.getElementById('puzzle-canvas');
  const ctx = canvas.getContext('2d');

  const animalGrid = document.getElementById('animal-grid');
  const difficultyRow = document.getElementById('difficulty-row');
  const startBtn = document.getElementById('start-btn');
  const continueRow = document.getElementById('continue-row');
  const continueBtn = document.getElementById('continue-btn');
  const collectionWrap = document.getElementById('collection-wrap');
  const collectionEl = document.getElementById('collection');
  const replayTutorialBtn = document.getElementById('replay-tutorial-btn');
  const muteToggleStart = document.getElementById('mute-toggle-start');
  const timerToggleStart = document.getElementById('timer-toggle-start');

  const progressFill = document.getElementById('progress-fill');
  const progressEmoji = document.getElementById('progress-emoji');
  const timerEl = document.getElementById('timer');
  const edgesToggle = document.getElementById('edges-toggle');
  const hintToggle = document.getElementById('hint-toggle');
  const muteToggle = document.getElementById('mute-toggle');
  const newPuzzleBtn = document.getElementById('new-puzzle-btn');
  const centerBtn = document.getElementById('center-btn');

  const tutorialLayer = document.getElementById('tutorial-layer');

  const confirmOverlay = document.getElementById('confirm-overlay');
  const confirmCancel = document.getElementById('confirm-cancel');
  const confirmOk = document.getElementById('confirm-ok');

  const winOverlay = document.getElementById('win-overlay');
  const confettiCanvas = document.getElementById('confetti-canvas');
  const confettiCtx = confettiCanvas.getContext('2d');
  const winTimeEl = document.getElementById('win-time');
  const winAgainBtn = document.getElementById('win-again-btn');
  const winChooseBtn = document.getElementById('win-choose-btn');

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
  let puzzleX = 0;
  let puzzleY = 0;
  let currentEdges = null;
  let currentAnimal = null;
  let currentTier = null;

  let showHint = false;
  let edgesHighlight = false;
  let gameActive = false;

  let camera = { x: 0, y: 0, zoom: 1 };

  // Picker selection
  let selectedAnimalKey = null; // animal key OR 'surprise'
  let selectedTierKey = null;

  // Timer
  let timerStart = 0;
  let baseElapsedMs = 0;
  let timerInterval = null;
  let showTimer = false;

  // Tutorial
  let tutorialActive = false;
  let tutorialPiece = null;

  // Interaction
  let dragGroup = null;
  let dragPiece = null;
  let heldGroupId = null;
  let dragOffset = { x: 0, y: 0 };
  let isDragging = false;
  let isPanning = false;
  let lastPanPoint = null;
  let lastPinchDist = null;
  let lastPinchCenter = null;

  // Rendering (on-demand)
  let needsRender = false;
  let rafPending = false;
  const activeAnimations = new Set();
  let cameraAnim = null;
  const snapAnims = [];
  let snapAnimSeq = 0;
  let milestoneParticles = [];

  // Milestones
  const firedMilestones = new Set();

  // Autosave
  let autosaveTimer = null;

  // ===== SMALL HELPERS =====
  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
  function lerp(a, b, t) { return a + (b - a) * t; }
  function easeOutCubic(t) { return 1 - Math.pow(1 - t, 3); }

  // ===== JIGSAW PATH DRAWING (Canvas-specific) =====
  function drawJigsawEdgeDirect(path, len, dir, tx, ty) {
    if (dir === 0) {
      path.lineTo(tx(len, 0), ty(len, 0));
      return;
    }
    const tabH = len * TAB_SIZE * dir;
    const neck = len * 0.5;
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

    const topDir = row === 0 ? 0 : -edges.h[row - 1][col];
    drawJigsawEdgeDirect(path, w, topDir, (x) => x, (x, y) => y);

    const rightDir = col === cols - 1 ? 0 : edges.v[row][col];
    drawJigsawEdgeDirect(path, h, rightDir, (x, y) => w + y, (x) => x);

    const bottomDir = row === rows - 1 ? 0 : edges.h[row][col];
    drawJigsawEdgeDirect(path, w, bottomDir, (x) => w - x, (x, y) => h - y);

    const leftDir = col === 0 ? 0 : -edges.v[row][col - 1];
    drawJigsawEdgeDirect(path, h, leftDir, (x, y) => -y, (x) => h - x);

    path.closePath();
    return path;
  }

  // ===== IMAGE LOADING (curated, animal-only) =====
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

  // Procedural fallback that depicts the CHOSEN animal (never an arbitrary one).
  function generateProceduralFallback(animal) {
    const a = animal || CURATED_ANIMALS[0];
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

  async function loadChosenImage(animal) {
    const W = PUZZLE_IMAGE_W, H = PUZZLE_IMAGE_H;
    const url = `https://images.unsplash.com/photo-${animal.unsplashId}?w=${W}&h=${H}&fit=crop&auto=format&q=70`;
    const img = await tryLoadImage(url, 5000);
    if (img) return img;
    return generateProceduralFallback(animal);
  }

  // ===== COORDINATE TRANSFORMS =====
  function screenToWorld(sx, sy) {
    return Engine.screenToWorld(sx, sy, camera, canvas.width, canvas.height);
  }

  // ===== CAMERA =====
  function computeContentBounds() {
    let minX = puzzleX;
    let minY = puzzleY;
    let maxX = puzzleX + cols * pieceW;
    let maxY = puzzleY + rows * pieceH;
    const tab = TAB_SIZE * Math.max(pieceW, pieceH);
    for (const p of pieces) {
      if (p.x - tab < minX) minX = p.x - tab;
      if (p.y - tab < minY) minY = p.y - tab;
      if (p.x + pieceW + tab > maxX) maxX = p.x + pieceW + tab;
      if (p.y + pieceH + tab > maxY) maxY = p.y + pieceH + tab;
    }
    return { minX, minY, maxX, maxY };
  }

  function computeFitCamera() {
    const b = computeContentBounds();
    const cw = Math.max(1, b.maxX - b.minX);
    const ch = Math.max(1, b.maxY - b.minY);
    const PAD = 0.9;
    let zoom = Math.min(canvas.width / cw, canvas.height / ch) * PAD;
    zoom = clamp(zoom, MIN_ZOOM, MAX_ZOOM);
    return { x: (b.minX + b.maxX) / 2, y: (b.minY + b.maxY) / 2, zoom };
  }

  function fitCameraToContent(animate) {
    const target = computeFitCamera();
    if (!animate) {
      camera.x = target.x;
      camera.y = target.y;
      camera.zoom = target.zoom;
      requestRender();
      return;
    }
    cameraAnim = {
      fromX: camera.x, fromY: camera.y, fromZoom: camera.zoom,
      toX: target.x, toY: target.y, toZoom: target.zoom,
      start: performance.now(), dur: 320,
    };
    activeAnimations.add('camera');
    scheduleFrame();
  }

  function clampCamera() {
    const b = computeContentBounds();
    const halfW = (canvas.width / camera.zoom) / 2;
    const halfH = (canvas.height / camera.zoom) / 2;
    // Keep at least ~20% of the viewport overlapping the content area.
    const marginX = halfW * 0.8;
    const marginY = halfH * 0.8;
    camera.x = clamp(camera.x, b.minX - marginX, b.maxX + marginX);
    camera.y = clamp(camera.y, b.minY - marginY, b.maxY + marginY);
  }

  function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh) {
    return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
  }

  // Scatter loose pieces inside the current viewport, around (not on) the board.
  function scatterInView() {
    const tl = screenToWorld(0, 0);
    const br = screenToWorld(canvas.width, canvas.height);
    const vMinX = tl.x, vMinY = tl.y, vMaxX = br.x, vMaxY = br.y;
    const pad = Math.max(pieceW, pieceH) * 0.5;

    const boardL = puzzleX - pad;
    const boardT = puzzleY - pad;
    const boardW = cols * pieceW + pad * 2;
    const boardH = rows * pieceH + pad * 2;

    const rangeX = Math.max(1, vMaxX - vMinX - 2 * pad - pieceW);
    const rangeY = Math.max(1, vMaxY - vMinY - 2 * pad - pieceH);

    for (const p of pieces) {
      let x = p.x, y = p.y, tries = 0;
      do {
        x = vMinX + pad + Math.random() * rangeX;
        y = vMinY + pad + Math.random() * rangeY;
        tries++;
      } while (tries < 16 && rectsOverlap(x, y, pieceW, pieceH, boardL, boardT, boardW, boardH));
      p.x = x;
      p.y = y;
    }
  }

  // ===== PIECE CREATION =====
  function createPieces(edges) {
    const gs = Engine.createGameState(cols, rows, pieceW, pieceH, puzzleX, puzzleY);
    piecesById = gs.piecesById;
    groups = gs.groups;
    pieces = gs.pieces;
    placedPieces = 0;
    for (const piece of gs.pieces) {
      piece.path = buildPiecePath(piece.col, piece.row, edges);
    }
  }

  // ===== ON-DEMAND RENDERING =====
  function scheduleFrame() {
    if (!rafPending) {
      rafPending = true;
      requestAnimationFrame(frame);
    }
  }

  function requestRender() {
    needsRender = true;
    scheduleFrame();
  }

  function frame() {
    rafPending = false;
    needsRender = false;
    const now = performance.now();

    stepCameraAnim(now);
    stepSnapAnims(now);
    stepMilestoneParticles(now);

    draw(now);

    if (needsRender || activeAnimations.size > 0) {
      scheduleFrame();
    }
  }

  function stepCameraAnim(now) {
    if (!cameraAnim) return;
    const t = Math.min(1, (now - cameraAnim.start) / cameraAnim.dur);
    const e = easeOutCubic(t);
    camera.x = lerp(cameraAnim.fromX, cameraAnim.toX, e);
    camera.y = lerp(cameraAnim.fromY, cameraAnim.toY, e);
    camera.zoom = lerp(cameraAnim.fromZoom, cameraAnim.toZoom, e);
    if (t >= 1) {
      cameraAnim = null;
      activeAnimations.delete('camera');
    }
  }

  function stepSnapAnims(now) {
    for (let i = snapAnims.length - 1; i >= 0; i--) {
      const sa = snapAnims[i];
      const t = Math.min(1, (now - sa.start) / sa.dur);
      const e = easeOutCubic(t);
      for (const a of sa.anims) {
        a.piece.x = lerp(a.fromX, a.toX, e);
        a.piece.y = lerp(a.fromY, a.toY, e);
      }
      if (t >= 1) {
        for (const a of sa.anims) { a.piece.x = a.toX; a.piece.y = a.toY; }
        activeAnimations.delete(sa.token);
        snapAnims.splice(i, 1);
      }
    }
  }

  function startSnapAnimation(group, fromList) {
    const fromMap = {};
    for (const f of fromList) fromMap[f.id] = f;
    const anims = [];
    for (const p of group.pieces) {
      const f = fromMap[p.id];
      if (!f) continue;
      if (Math.abs(f.x - p.x) < 0.5 && Math.abs(f.y - p.y) < 0.5) continue;
      anims.push({ piece: p, fromX: f.x, fromY: f.y, toX: p.x, toY: p.y });
      p.x = f.x;
      p.y = f.y;
    }
    if (anims.length === 0) { requestRender(); return; }
    const token = 'snap:' + (snapAnimSeq++);
    snapAnims.push({ token, anims, start: performance.now(), dur: 180 });
    activeAnimations.add(token);
    scheduleFrame();
  }

  // ===== DRAW =====
  function draw(now) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.save();
    ctx.translate(canvas.width / 2, canvas.height / 2);
    ctx.scale(camera.zoom, camera.zoom);
    ctx.translate(-camera.x, -camera.y);

    // Board outline
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.6)';
    ctx.lineWidth = 2 / camera.zoom;
    ctx.setLineDash([8 / camera.zoom, 6 / camera.zoom]);
    ctx.strokeRect(puzzleX, puzzleY, cols * pieceW, rows * pieceH);
    ctx.setLineDash([]);

    // Full-image hint
    if (showHint && puzzleImage) {
      ctx.globalAlpha = 0.30;
      ctx.drawImage(puzzleImage, puzzleX, puzzleY, cols * pieceW, rows * pieceH);
      ctx.globalAlpha = 1;
    }

    // Grid lines
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.15)';
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

    // Ghost hint (where the held group belongs)
    drawGhostHint();

    // Pieces — placed below, unplaced above
    const sortedPieces = pieces.slice().sort((a, b) => {
      if (a.placed && !b.placed) return -1;
      if (!a.placed && b.placed) return 1;
      return 0;
    });
    for (const piece of sortedPieces) drawPiece(piece, now);

    ctx.restore();

    // Screen-space overlays
    drawMilestoneParticles();
  }

  function drawGhostHint() {
    if (!isDragging || !dragGroup || dragGroup.placed) return;
    ctx.save();
    ctx.globalAlpha = 0.25;
    ctx.strokeStyle = '#ffd166';
    ctx.lineWidth = 2.5 / camera.zoom;
    for (const p of dragGroup.pieces) {
      ctx.save();
      ctx.translate(p.correctX, p.correctY);
      ctx.stroke(p.path);
      ctx.restore();
    }
    ctx.restore();
  }

  function drawPiece(piece, now) {
    const isHeld = heldGroupId !== null && piece.groupId === heldGroupId && !piece.placed;
    const isEdge = edgesHighlight && !piece.placed && Engine.isEdgePiece(piece, cols, rows);

    let scale = 1;
    if (tutorialActive && piece === tutorialPiece && !piece.placed) {
      scale = 1 + 0.10 * (0.5 + 0.5 * Math.sin(now * 0.006));
    } else if (isHeld && dragGroup && dragGroup.pieces.length === 1) {
      scale = 1.06;
    }

    ctx.save();
    ctx.translate(piece.x, piece.y);
    if (scale !== 1) {
      ctx.translate(pieceW / 2, pieceH / 2);
      ctx.scale(scale, scale);
      ctx.translate(-pieceW / 2, -pieceH / 2);
    }

    // Image clipped to the piece shape
    ctx.save();
    ctx.clip(piece.path);
    const totalW = cols * pieceW;
    const totalH = rows * pieceH;
    ctx.drawImage(puzzleImage, 0, 0, PUZZLE_IMAGE_W, PUZZLE_IMAGE_H, -piece.col * pieceW, -piece.row * pieceH, totalW, totalH);
    ctx.restore();

    // Outlines
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

    if (isHeld) {
      ctx.strokeStyle = 'rgba(255,255,255,0.95)';
      ctx.lineWidth = 3 / camera.zoom;
      ctx.stroke(piece.path);
    }

    if (isEdge) {
      ctx.strokeStyle = '#ffd166';
      ctx.lineWidth = 4 / camera.zoom;
      ctx.stroke(piece.path);
    }

    ctx.restore();
  }

  // ===== MILESTONE PARTICLES (drawn in screen space) =====
  const BURST_COLORS = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD', '#FF8C00', '#7B68EE'];

  function spawnBurst(cx, cy) {
    for (let i = 0; i < 36; i++) {
      const ang = (Math.PI * 2 * i) / 36 + Math.random() * 0.3;
      const sp = 4 + Math.random() * 7;
      milestoneParticles.push({
        x: cx, y: cy,
        vx: Math.cos(ang) * sp,
        vy: Math.sin(ang) * sp - 4,
        size: 4 + Math.random() * 6,
        color: BURST_COLORS[Math.floor(Math.random() * BURST_COLORS.length)],
        life: 1,
      });
    }
    activeAnimations.add('milestone');
    scheduleFrame();
  }

  function stepMilestoneParticles() {
    if (milestoneParticles.length === 0) return;
    let alive = false;
    for (const p of milestoneParticles) {
      if (p.life <= 0) continue;
      alive = true;
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.35;
      p.vx *= 0.99;
      p.life -= 0.018;
    }
    if (!alive) {
      milestoneParticles = [];
      activeAnimations.delete('milestone');
    }
  }

  function drawMilestoneParticles() {
    if (milestoneParticles.length === 0) return;
    for (const p of milestoneParticles) {
      if (p.life <= 0) continue;
      ctx.save();
      ctx.globalAlpha = Math.max(0, p.life);
      ctx.fillStyle = p.color;
      ctx.fillRect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size);
      ctx.restore();
    }
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

  // ===== SNAP & GROUP LOGIC =====
  function getGroup(piece) {
    return groups.find((g) => g.id === piece.groupId);
  }

  function getEngineState() {
    return { cols, rows, pieceW, pieceH, piecesById, groups };
  }

  function currentSnapDistance() {
    const base = Math.min(pieceW, pieceH) * SNAP_RATIO;
    const minWorld = MIN_SNAP_SCREEN / camera.zoom;
    return Math.max(base, minWorld);
  }

  function trySnapAndUpdate(movedGroup) {
    const from = movedGroup.pieces.map((p) => ({ id: p.id, x: p.x, y: p.y }));
    const result = Engine.trySnap(movedGroup, getEngineState(), currentSnapDistance());
    if (result.snapped) {
      startSnapAnimation(movedGroup, from);
      Sound.play(result.placedCount > 0 ? 'snap' : 'merge');
      Sound.vibrate(20);
    }
    if (result.placedCount > 0) {
      placedPieces += result.placedCount;
      updateProgress();
      checkMilestones();
      checkWin();
    }
    scheduleAutosave();
    return result.snapped;
  }

  // ===== PROGRESS =====
  function updateProgress() {
    const ratio = totalPieces ? placedPieces / totalPieces : 0;
    const pct = Math.round(ratio * 100);
    progressFill.style.width = pct + '%';
    progressEmoji.style.left = pct + '%';
  }

  // ===== MILESTONES =====
  function allEdgesPlaced() {
    for (const p of pieces) {
      if (Engine.isEdgePiece(p, cols, rows) && !p.placed) return false;
    }
    return true;
  }

  function celebrateMilestone() {
    Sound.play('milestone');
    Sound.vibrate(30);
    spawnBurst(canvas.width / 2, canvas.height * 0.32);
  }

  function checkMilestones() {
    if (totalPieces === 0) return;
    const ratio = placedPieces / totalPieces;
    const thresholds = [['p25', 0.25], ['p50', 0.5], ['p75', 0.75]];
    for (const [key, thr] of thresholds) {
      if (ratio >= thr && ratio < 1 && !firedMilestones.has(key)) {
        firedMilestones.add(key);
        celebrateMilestone();
      }
    }
    if (!firedMilestones.has('edges') && placedPieces < totalPieces && allEdgesPlaced()) {
      firedMilestones.add('edges');
      Sound.play('milestone');
      Sound.vibrate([20, 40, 20]);
      spawnBurst(canvas.width * 0.5, canvas.height * 0.32);
      spawnBurst(canvas.width * 0.3, canvas.height * 0.4);
      spawnBurst(canvas.width * 0.7, canvas.height * 0.4);
    }
  }

  // ===== COLLECTION =====
  function renderCollection() {
    const earned = Store.getCollection();
    if (!earned.length) {
      collectionWrap.classList.add('hidden');
      collectionEl.innerHTML = '';
      return;
    }
    collectionWrap.classList.remove('hidden');
    collectionEl.innerHTML = '';
    for (const key of earned) {
      const animal = CURATED_ANIMALS.find((a) => a.key === key);
      if (!animal) continue;
      const tile = document.createElement('div');
      tile.className = 'collection-tile';
      tile.setAttribute('role', 'listitem');
      tile.title = animal.name;
      tile.textContent = animal.emoji;
      collectionEl.appendChild(tile);
    }
  }

  // ===== TIMER =====
  function getElapsedMs() {
    if (!timerStart) return baseElapsedMs;
    return baseElapsedMs + (Date.now() - timerStart);
  }

  function startTimer() {
    timerStart = Date.now();
    if (timerInterval) clearInterval(timerInterval);
    timerInterval = setInterval(updateTimerDisplay, 1000);
    updateTimerDisplay();
  }

  function stopTimer() {
    if (timerInterval) clearInterval(timerInterval);
    timerInterval = null;
  }

  function updateTimerDisplay() {
    const elapsed = Math.floor(getElapsedMs() / 1000);
    const mins = String(Math.floor(elapsed / 60)).padStart(2, '0');
    const secs = String(elapsed % 60).padStart(2, '0');
    timerEl.textContent = `⏱ ${mins}:${secs}`;
  }

  function applyTimerVisibility() {
    timerEl.classList.toggle('hidden', !showTimer);
  }

  // ===== WIN =====
  function checkWin() {
    if (totalPieces > 0 && placedPieces === totalPieces) {
      gameActive = false;
      stopTimer();
      Store.clearResume();
      if (currentAnimal) Store.addToCollection(currentAnimal.key);
      showWinScreen();
    }
  }

  function showWinScreen() {
    if (showTimer) {
      const elapsed = Math.floor(getElapsedMs() / 1000);
      const mins = Math.floor(elapsed / 60);
      const secs = elapsed % 60;
      winTimeEl.textContent = mins > 0 ? `Time: ${mins}m ${secs}s` : `Time: ${secs}s`;
      winTimeEl.classList.remove('hidden');
    } else {
      winTimeEl.classList.add('hidden');
    }
    winOverlay.classList.remove('hidden');
    confettiCanvas.width = window.innerWidth;
    confettiCanvas.height = window.innerHeight;
    Sound.play('win');
    Sound.vibrate([30, 60, 30]);
    runConfetti();
  }

  // ===== CONFETTI (win) =====
  function runConfetti() {
    const particles = [];
    for (let i = 0; i < 200; i++) {
      particles.push({
        x: confettiCanvas.width / 2 + (Math.random() - 0.5) * 200,
        y: confettiCanvas.height / 2,
        vx: (Math.random() - 0.5) * 16,
        vy: -Math.random() * 18 - 4,
        size: 4 + Math.random() * 8,
        color: BURST_COLORS[Math.floor(Math.random() * BURST_COLORS.length)],
        rotation: Math.random() * 360,
        rotSpeed: (Math.random() - 0.5) * 12,
        gravity: 0.3 + Math.random() * 0.2,
        life: 1,
      });
    }
    let frameCount = 0;
    function animateConfetti() {
      frameCount++;
      confettiCtx.clearRect(0, 0, confettiCanvas.width, confettiCanvas.height);
      let alive = false;
      for (const p of particles) {
        if (p.life <= 0) continue;
        alive = true;
        p.x += p.vx; p.y += p.vy; p.vy += p.gravity; p.vx *= 0.99;
        p.rotation += p.rotSpeed; p.life -= 0.005;
        confettiCtx.save();
        confettiCtx.translate(p.x, p.y);
        confettiCtx.rotate((p.rotation * Math.PI) / 180);
        confettiCtx.globalAlpha = Math.max(0, p.life);
        confettiCtx.fillStyle = p.color;
        confettiCtx.fillRect(-p.size / 2, -p.size / 4, p.size, p.size / 2);
        confettiCtx.restore();
      }
      if (alive && frameCount < 300 && !winOverlay.classList.contains('hidden')) {
        requestAnimationFrame(animateConfetti);
      }
    }
    animateConfetti();
  }

  // ===== TUTORIAL =====
  function startTutorial() {
    const loose = pieces.find((p) => !p.placed);
    tutorialPiece = loose || null;
    tutorialActive = true;
    tutorialLayer.classList.remove('hidden');
    activeAnimations.add('tutorial');
    scheduleFrame();
  }

  function endTutorial() {
    if (!tutorialActive) return;
    tutorialActive = false;
    tutorialPiece = null;
    tutorialLayer.classList.add('hidden');
    activeAnimations.delete('tutorial');
    Store.markTutorialSeen();
    requestRender();
  }

  // ===== AUTOSAVE / RESUME =====
  function serializeResume() {
    return {
      version: RESUME_VERSION,
      animalKey: currentAnimal ? currentAnimal.key : null,
      pieceCount: totalPieces,
      cols, rows, pieceW, pieceH, puzzleX, puzzleY,
      edges: currentEdges,
      placedPieces,
      elapsedMs: getElapsedMs(),
      pieces: pieces.map((p) => ({ id: p.id, x: p.x, y: p.y, placed: p.placed, groupId: p.groupId })),
      groups: groups.map((g) => ({ id: g.id, pieceIds: g.pieces.map((p) => p.id), placed: g.placed })),
    };
  }

  function scheduleAutosave() {
    if (!gameActive) return;
    if (autosaveTimer) return;
    autosaveTimer = setTimeout(() => {
      autosaveTimer = null;
      if (gameActive) Store.saveResume(serializeResume());
    }, 700);
  }

  function isValidResume(state) {
    return (
      state &&
      state.version === RESUME_VERSION &&
      typeof state.cols === 'number' &&
      typeof state.rows === 'number' &&
      Array.isArray(state.pieces) &&
      Array.isArray(state.groups) &&
      state.edges &&
      CURATED_ANIMALS.some((a) => a.key === state.animalKey) &&
      state.placedPieces < state.cols * state.rows
    );
  }

  async function restoreResume(state) {
    const animal = CURATED_ANIMALS.find((a) => a.key === state.animalKey);
    if (!animal) return false;

    loadingEl.classList.remove('hidden');
    puzzleImage = await loadChosenImage(animal);
    loadingEl.classList.add('hidden');

    currentAnimal = animal;
    currentTier = DIFFICULTY_TIERS.find((t) => t.pieces === state.pieceCount) || null;

    cols = state.cols;
    rows = state.rows;
    pieceW = state.pieceW;
    pieceH = state.pieceH;
    puzzleX = state.puzzleX;
    puzzleY = state.puzzleY;
    totalPieces = cols * rows;
    currentEdges = state.edges;

    resizeCanvas();

    const gs = Engine.createGameState(cols, rows, pieceW, pieceH, puzzleX, puzzleY);
    piecesById = gs.piecesById;
    pieces = gs.pieces;
    for (const p of pieces) p.path = buildPiecePath(p.col, p.row, currentEdges);

    for (const sp of state.pieces) {
      const p = piecesById[sp.id];
      if (!p) continue;
      p.x = sp.x;
      p.y = sp.y;
      p.placed = !!sp.placed;
      p.groupId = sp.groupId;
    }

    groups = state.groups.map((g) => ({
      id: g.id,
      placed: !!g.placed,
      pieces: g.pieceIds.map((id) => piecesById[id]).filter(Boolean),
    }));

    placedPieces = state.placedPieces;
    baseElapsedMs = state.elapsedMs || 0;

    firedMilestones.clear();
    // Re-arm milestones already passed so they don't re-fire on resume.
    const ratio = placedPieces / totalPieces;
    if (ratio >= 0.25) firedMilestones.add('p25');
    if (ratio >= 0.5) firedMilestones.add('p50');
    if (ratio >= 0.75) firedMilestones.add('p75');
    if (allEdgesPlaced()) firedMilestones.add('edges');

    showHint = false;
    edgesHighlight = false;
    hintToggle.classList.remove('active');
    edgesToggle.classList.remove('active');

    enterGameScreen();
    fitCameraToContent(false);
    updateProgress();
    applyTimerVisibility();
    timerStart = Date.now();
    if (timerInterval) clearInterval(timerInterval);
    timerInterval = setInterval(updateTimerDisplay, 1000);
    updateTimerDisplay();
    gameActive = true;
    requestRender();
    return true;
  }

  // ===== SCREEN TRANSITIONS =====
  function enterGameScreen() {
    startScreen.classList.add('hidden');
    winOverlay.classList.add('hidden');
    confirmOverlay.classList.add('hidden');
    gameScreen.classList.remove('hidden');
    syncMuteButtons();
  }

  function showStartScreen() {
    gameActive = false;
    stopTimer();
    gameScreen.classList.add('hidden');
    winOverlay.classList.add('hidden');
    confirmOverlay.classList.add('hidden');
    startScreen.classList.remove('hidden');
    loadingEl.classList.add('hidden');
    renderCollection();
    refreshContinueRow();
    syncMuteButtons();
  }

  // ===== GAME START =====
  async function startGame(tier, animalChoice) {
    currentTier = tier;
    const animal =
      animalChoice === 'surprise' || !animalChoice
        ? CURATED_ANIMALS[Math.floor(Math.random() * CURATED_ANIMALS.length)]
        : animalChoice;
    currentAnimal = animal;

    loadingEl.classList.remove('hidden');
    startBtn.disabled = true;

    puzzleImage = await loadChosenImage(animal);

    const grid = Engine.computeGrid(tier.pieces, PUZZLE_IMAGE_W, PUZZLE_IMAGE_H);
    cols = grid.cols;
    rows = grid.rows;
    totalPieces = cols * rows;

    resizeCanvas();

    // Board sized to ~42% of the viewport so there is a ring for loose pieces.
    const maxPuzzleW = canvas.width * 0.42;
    const maxPuzzleH = canvas.height * 0.42;
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

    currentEdges = Engine.generateEdges(rows, cols);
    createPieces(currentEdges);
    scatterInView();

    showHint = false;
    edgesHighlight = false;
    hintToggle.classList.remove('active');
    edgesToggle.classList.remove('active');
    placedPieces = 0;
    firedMilestones.clear();
    updateProgress();

    baseElapsedMs = 0;
    applyTimerVisibility();

    loadingEl.classList.add('hidden');
    enterGameScreen();

    fitCameraToContent(false);
    gameActive = true;
    startTimer();

    Store.saveResume(serializeResume());

    if (!Store.hasSeenTutorial()) {
      startTutorial();
    }

    requestRender();
  }

  // ===== CONFIRM NEW PUZZLE =====
  function confirmNewPuzzle() {
    confirmOverlay.classList.remove('hidden');
  }

  // ===== PICKER UI =====
  function refreshStartButton() {
    startBtn.disabled = !(selectedAnimalKey && selectedTierKey);
  }

  function renderPicker() {
    // Animals
    animalGrid.innerHTML = '';
    for (const animal of CURATED_ANIMALS) {
      const tile = document.createElement('button');
      tile.className = 'animal-tile';
      tile.type = 'button';
      tile.setAttribute('role', 'listitem');
      tile.dataset.animal = animal.key;
      tile.innerHTML = `<span class="emoji">${animal.emoji}</span><span class="label">${animal.name}</span>`;
      tile.addEventListener('click', () => chooseAnimal(animal.key));
      animalGrid.appendChild(tile);
    }
    // Surprise me
    const surprise = document.createElement('button');
    surprise.className = 'animal-tile surprise';
    surprise.type = 'button';
    surprise.setAttribute('role', 'listitem');
    surprise.dataset.animal = 'surprise';
    surprise.innerHTML = `<span class="emoji">🎲</span><span class="label">Surprise</span>`;
    surprise.addEventListener('click', () => chooseAnimal('surprise'));
    animalGrid.appendChild(surprise);

    // Difficulty
    difficultyRow.innerHTML = '';
    for (const tier of DIFFICULTY_TIERS) {
      const tile = document.createElement('button');
      tile.className = 'diff-tile';
      tile.type = 'button';
      tile.setAttribute('role', 'listitem');
      tile.dataset.tier = tier.key;
      tile.innerHTML = `<span class="emoji">${tier.emoji}</span><span class="label">${tier.name}</span>`;
      tile.addEventListener('click', () => chooseDifficulty(tier.key));
      difficultyRow.appendChild(tile);
    }
  }

  function chooseAnimal(key) {
    selectedAnimalKey = key;
    Sound.init();
    for (const tile of animalGrid.querySelectorAll('.animal-tile')) {
      tile.classList.toggle('selected', tile.dataset.animal === key);
    }
    refreshStartButton();
  }

  function chooseDifficulty(key) {
    selectedTierKey = key;
    Sound.init();
    for (const tile of difficultyRow.querySelectorAll('.diff-tile')) {
      tile.classList.toggle('selected', tile.dataset.tier === key);
    }
    refreshStartButton();
  }

  function refreshContinueRow() {
    const resume = Store.loadResume();
    if (isValidResume(resume)) {
      continueRow.classList.remove('hidden');
    } else {
      continueRow.classList.add('hidden');
      if (resume) Store.clearResume();
    }
  }

  // ===== SETTINGS (mute / timer) =====
  function syncMuteButtons() {
    const muted = Sound.isMuted();
    muteToggle.textContent = muted ? '🔇' : '🔊';
    muteToggleStart.textContent = muted ? '🔇 Muted' : '🔊 Sound';
    muteToggleStart.setAttribute('aria-pressed', String(muted));
  }

  function toggleMute() {
    Sound.init();
    Sound.setMuted(!Sound.isMuted());
    syncMuteButtons();
  }

  function syncTimerButton() {
    timerToggleStart.textContent = showTimer ? '⏱ Timer on' : '⏱ Timer off';
    timerToggleStart.setAttribute('aria-pressed', String(showTimer));
  }

  function toggleTimer() {
    showTimer = !showTimer;
    Store.setSettings({ showTimer: showTimer });
    syncTimerButton();
    applyTimerVisibility();
  }

  // ===== INPUT HANDLING =====
  function getPointerPos(e) {
    const rect = canvas.getBoundingClientRect();
    if (e.touches) {
      return {
        x: (e.touches[0].clientX - rect.left) * (canvas.width / rect.width),
        y: (e.touches[0].clientY - rect.top) * (canvas.height / rect.height),
      };
    }
    return {
      x: (e.clientX - rect.left) * (canvas.width / rect.width),
      y: (e.clientY - rect.top) * (canvas.height / rect.height),
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
      center: { x: (x1 + x2) / 2, y: (y1 + y2) / 2 },
    };
  }

  function onPointerDown(e) {
    e.preventDefault();
    if (!gameActive) return;
    Sound.init();

    if (e.touches && e.touches.length === 2) {
      isDragging = false;
      dragGroup = null;
      heldGroupId = null;
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
      heldGroupId = group.id;
      dragOffset.x = world.x - piece.x;
      dragOffset.y = world.y - piece.y;

      const groupPieceIds = new Set(group.pieces.map((p) => p.id));
      const others = pieces.filter((p) => !groupPieceIds.has(p.id));
      const groupPieces = pieces.filter((p) => groupPieceIds.has(p.id));
      pieces = [...others, ...groupPieces];

      activeAnimations.add('drag');
      if (tutorialActive) endTutorial();
      requestRender();
    } else {
      isPanning = true;
      lastPanPoint = pos;
      if (tutorialActive) endTutorial();
    }
  }

  function onPointerMove(e) {
    e.preventDefault();
    if (!gameActive) return;

    if (e.touches && e.touches.length === 2 && isPanning) {
      const pd = getPinchData(e);
      if (lastPinchDist !== null) {
        const zoomDelta = pd.dist / lastPinchDist;
        const newZoom = clamp(camera.zoom * zoomDelta, MIN_ZOOM, MAX_ZOOM);
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
      clampCamera();
      requestRender();
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
      requestRender();
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
        clampCamera();
        requestRender();
      }
    }
  }

  function onPointerUp(e) {
    if (e && e.preventDefault) e.preventDefault();
    if (isDragging && dragGroup && !dragGroup.placed) {
      trySnapAndUpdate(dragGroup);
    }
    isDragging = false;
    dragGroup = null;
    dragPiece = null;
    heldGroupId = null;
    isPanning = false;
    lastPanPoint = null;
    lastPinchDist = null;
    lastPinchCenter = null;
    activeAnimations.delete('drag');
    requestRender();
  }

  function onWheel(e) {
    e.preventDefault();
    if (!gameActive) return;
    const pos = {
      x: e.offsetX * (canvas.width / canvas.clientWidth),
      y: e.offsetY * (canvas.height / canvas.clientHeight),
    };
    const worldBefore = screenToWorld(pos.x, pos.y);
    const zoomFactor = e.deltaY < 0 ? 1.1 : 0.9;
    camera.zoom = clamp(camera.zoom * zoomFactor, MIN_ZOOM, MAX_ZOOM);
    const worldAfter = screenToWorld(pos.x, pos.y);
    camera.x -= (worldAfter.x - worldBefore.x);
    camera.y -= (worldAfter.y - worldBefore.y);
    clampCamera();
    requestRender();
  }

  // ===== CANVAS RESIZE =====
  function resizeCanvas() {
    const dpr = window.devicePixelRatio || 1;
    canvas.width = window.innerWidth * dpr;
    canvas.height = window.innerHeight * dpr;
    canvas.style.width = window.innerWidth + 'px';
    canvas.style.height = window.innerHeight + 'px';
  }

  // ===== EVENT BINDING =====
  function init() {
    // Load persisted settings
    const settings = Store.getSettings();
    showTimer = !!settings.showTimer;
    syncTimerButton();
    syncMuteButtons();
    applyTimerVisibility();

    renderPicker();
    renderCollection();
    refreshContinueRow();

    // Picker / start
    startBtn.addEventListener('click', () => {
      if (!selectedTierKey) return;
      const tier = DIFFICULTY_TIERS.find((t) => t.key === selectedTierKey);
      const animalChoice =
        selectedAnimalKey === 'surprise'
          ? 'surprise'
          : CURATED_ANIMALS.find((a) => a.key === selectedAnimalKey);
      startGame(tier, animalChoice || 'surprise');
    });

    continueBtn.addEventListener('click', () => {
      Sound.init();
      const resume = Store.loadResume();
      if (isValidResume(resume)) {
        restoreResume(resume);
      } else {
        refreshContinueRow();
      }
    });

    replayTutorialBtn.addEventListener('click', () => {
      // Allow tutorial to show again on next puzzle start.
      try { window.localStorage.removeItem('kaley.tutorialSeen'); } catch (e) { /* ignore */ }
    });

    muteToggleStart.addEventListener('click', toggleMute);
    timerToggleStart.addEventListener('click', toggleTimer);

    // In-game toolbar
    edgesToggle.addEventListener('click', () => {
      edgesHighlight = !edgesHighlight;
      edgesToggle.classList.toggle('active', edgesHighlight);
      requestRender();
    });
    hintToggle.addEventListener('click', () => {
      showHint = !showHint;
      hintToggle.classList.toggle('active', showHint);
      requestRender();
    });
    muteToggle.addEventListener('click', toggleMute);
    newPuzzleBtn.addEventListener('click', confirmNewPuzzle);
    centerBtn.addEventListener('click', () => {
      Sound.init();
      fitCameraToContent(true);
    });

    // Confirm overlay
    confirmCancel.addEventListener('click', () => {
      confirmOverlay.classList.add('hidden');
    });
    confirmOk.addEventListener('click', () => {
      confirmOverlay.classList.add('hidden');
      Store.clearResume();
      showStartScreen();
    });

    // Win actions
    winAgainBtn.addEventListener('click', () => {
      if (currentTier) {
        startGame(currentTier, currentAnimal || 'surprise');
      } else {
        showStartScreen();
      }
    });
    winChooseBtn.addEventListener('click', showStartScreen);

    // Canvas input
    canvas.addEventListener('mousedown', onPointerDown);
    canvas.addEventListener('mousemove', onPointerMove);
    canvas.addEventListener('mouseup', onPointerUp);
    canvas.addEventListener('mouseleave', onPointerUp);
    canvas.addEventListener('wheel', onWheel, { passive: false });

    canvas.addEventListener('touchstart', onPointerDown, { passive: false });
    canvas.addEventListener('touchmove', onPointerMove, { passive: false });
    canvas.addEventListener('touchend', onPointerUp, { passive: false });
    canvas.addEventListener('touchcancel', onPointerUp, { passive: false });

    window.addEventListener('resize', () => {
      if (gameActive) {
        resizeCanvas();
        fitCameraToContent(false);
        requestRender();
      }
    });

    // Persist progress when the tab is hidden / closed.
    document.addEventListener('visibilitychange', () => {
      if (document.hidden && gameActive) {
        Store.saveResume(serializeResume());
      }
    });
    window.addEventListener('pagehide', () => {
      if (gameActive) Store.saveResume(serializeResume());
    });
  }

  init();
})();
