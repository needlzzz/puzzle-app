// Pure game logic — no DOM, no Canvas, no side effects.
// Works in both Node (for tests) and browser (for the app).

const DEFAULTS = {
  SNAP_DISTANCE: 35,
  IMAGE_W: 800,
  IMAGE_H: 600,
};

/**
 * Find cols × rows grid that best matches the image aspect ratio
 * while producing exactly `count` cells.
 */
function computeGrid(count, imageW = DEFAULTS.IMAGE_W, imageH = DEFAULTS.IMAGE_H) {
  const aspect = imageW / imageH;
  let bestCols = 1, bestRows = count;
  let bestDiff = Infinity;
  for (let c = 1; c <= count; c++) {
    const r = Math.ceil(count / c);
    if (c * r !== count) continue;
    const gridAspect = c / r;
    const diff = Math.abs(gridAspect - aspect);
    if (diff < bestDiff) {
      bestDiff = diff;
      bestCols = c;
      bestRows = r;
    }
  }
  return { cols: bestCols, rows: bestRows };
}

/**
 * Convert screen coordinates to world coordinates given a camera state.
 */
function screenToWorld(sx, sy, camera, canvasW, canvasH) {
  return {
    x: (sx - canvasW / 2) / camera.zoom + camera.x,
    y: (sy - canvasH / 2) / camera.zoom + camera.y,
  };
}

/**
 * Convert world coordinates to screen coordinates given a camera state.
 */
function worldToScreen(wx, wy, camera, canvasW, canvasH) {
  return {
    x: (wx - camera.x) * camera.zoom + canvasW / 2,
    y: (wy - camera.y) * camera.zoom + canvasH / 2,
  };
}

/**
 * Generate random jigsaw edge directions for a grid.
 * h[r][c] = edge between row r and row r+1 at column c
 * v[r][c] = edge between col c and col c+1 at row r
 * Values: 1 (tab out) or -1 (blank in)
 */
function generateEdges(rows, cols) {
  const edges = { h: [], v: [] };
  for (let r = 0; r < rows - 1; r++) {
    edges.h[r] = [];
    for (let c = 0; c < cols; c++) {
      edges.h[r][c] = Math.random() < 0.5 ? 1 : -1;
    }
  }
  for (let r = 0; r < rows; r++) {
    edges.v[r] = [];
    for (let c = 0; c < cols - 1; c++) {
      edges.v[r][c] = Math.random() < 0.5 ? 1 : -1;
    }
  }
  return edges;
}

/**
 * Get the grid neighbors of a piece (up/down/left/right).
 * Returns array of pieces looked up from piecesById.
 */
function getNeighbors(piece, cols, rows, piecesById) {
  const result = [];
  const { col, row } = piece;
  const id = (r, c) => r * cols + c;
  if (col > 0) result.push(piecesById[id(row, col - 1)]);
  if (col < cols - 1) result.push(piecesById[id(row, col + 1)]);
  if (row > 0) result.push(piecesById[id(row - 1, col)]);
  if (row < rows - 1) result.push(piecesById[id(row + 1, col)]);
  return result;
}

/**
 * Create a game state: pieces, groups, piecesById.
 * Pieces start at their correct positions (caller can scatter them).
 */
function createGameState(cols, rows, pieceW, pieceH, puzzleX, puzzleY) {
  const pieces = [];
  const piecesById = {};
  const groups = [];

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      const id = r * cols + c;
      const correctX = puzzleX + c * pieceW;
      const correctY = puzzleY + r * pieceH;
      const piece = {
        id,
        col: c,
        row: r,
        x: correctX,
        y: correctY,
        correctX,
        correctY,
        placed: false,
        groupId: id,
      };
      pieces.push(piece);
      piecesById[id] = piece;
      groups.push({ id, pieces: [piece], placed: false });
    }
  }
  return { pieces, piecesById, groups };
}

/**
 * Try to snap a moved group to its correct position or to a neighbor group.
 * Returns { snapped, placedCount, mergedInto } describing what happened.
 * Mutates piece positions and group membership in place.
 */
function trySnap(movedGroup, state, snapDistance = DEFAULTS.SNAP_DISTANCE) {
  const { cols, rows, pieceW, pieceH, piecesById, groups } = state;

  for (const piece of movedGroup.pieces) {
    // Check snap to correct position
    const dx = piece.x - piece.correctX;
    const dy = piece.y - piece.correctY;
    if (Math.abs(dx) < snapDistance && Math.abs(dy) < snapDistance) {
      let newlyPlaced = 0;
      for (const gp of movedGroup.pieces) {
        gp.x = gp.correctX;
        gp.y = gp.correctY;
        if (!gp.placed) {
          gp.placed = true;
          newlyPlaced++;
        }
      }
      movedGroup.placed = true;
      return { snapped: true, placedCount: newlyPlaced, mergedInto: null };
    }

    // Check snap to neighbor in different group
    const neighbors = getNeighbors(piece, cols, rows, piecesById);
    for (const neighbor of neighbors) {
      if (neighbor.groupId === piece.groupId) continue;
      const expectedDx = (piece.col - neighbor.col) * pieceW;
      const expectedDy = (piece.row - neighbor.row) * pieceH;
      const actualDx = piece.x - neighbor.x;
      const actualDy = piece.y - neighbor.y;
      if (Math.abs(actualDx - expectedDx) < snapDistance &&
          Math.abs(actualDy - expectedDy) < snapDistance) {
        const snapOffsetX = (neighbor.x + expectedDx) - piece.x;
        const snapOffsetY = (neighbor.y + expectedDy) - piece.y;
        for (const gp of movedGroup.pieces) {
          gp.x += snapOffsetX;
          gp.y += snapOffsetY;
        }
        const neighborGroup = groups.find(g => g.id === neighbor.groupId);
        const mergeResult = mergeGroups(movedGroup, neighborGroup, state, snapDistance);
        return { snapped: true, placedCount: mergeResult.placedCount, mergedInto: movedGroup };
      }
    }
  }
  return { snapped: false, placedCount: 0, mergedInto: null };
}

/**
 * Merge groupB into groupA. Mutates both groups and the state.groups array.
 * Returns { placedCount } — number of newly placed pieces.
 */
function mergeGroups(groupA, groupB, state, snapDistance = DEFAULTS.SNAP_DISTANCE) {
  let placedCount = 0;
  const newId = groupA.id;
  for (const p of groupB.pieces) {
    p.groupId = newId;
    groupA.pieces.push(p);
  }
  if (groupB.placed || groupA.placed) {
    for (const p of groupA.pieces) {
      p.x = p.correctX;
      p.y = p.correctY;
      if (!p.placed) {
        p.placed = true;
        placedCount++;
      }
    }
    groupA.placed = true;
  }
  // Remove groupB from state
  const idx = state.groups.indexOf(groupB);
  if (idx !== -1) state.groups.splice(idx, 1);

  // Chain reaction — try snapping again after merge
  const chainResult = trySnap(groupA, state, snapDistance);
  placedCount += chainResult.placedCount;
  return { placedCount };
}

// ===== Exports =====
// Support both Node (CommonJS) and browser (global)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    DEFAULTS,
    computeGrid,
    screenToWorld,
    worldToScreen,
    generateEdges,
    getNeighbors,
    createGameState,
    trySnap,
    mergeGroups,
  };
} else if (typeof window !== 'undefined') {
  window.PuzzleEngine = {
    DEFAULTS,
    computeGrid,
    screenToWorld,
    worldToScreen,
    generateEdges,
    getNeighbors,
    createGameState,
    trySnap,
    mergeGroups,
  };
}
