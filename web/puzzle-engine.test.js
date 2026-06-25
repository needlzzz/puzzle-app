const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  computeGrid,
  screenToWorld,
  worldToScreen,
  generateEdges,
  getNeighbors,
  isEdgePiece,
  createGameState,
  trySnap,
  mergeGroups,
  DEFAULTS,
} = require('./puzzle-engine.js');

// ===== 1. Grid computation =====
describe('computeGrid', () => {
  it('produces exactly the requested piece count', () => {
    for (const count of [50, 100, 150, 200]) {
      const { cols, rows } = computeGrid(count);
      assert.equal(cols * rows, count, `${count} pieces: got ${cols}x${rows}=${cols * rows}`);
    }
  });

  it('grid aspect ratio approximates the image aspect ratio (4:3)', () => {
    const imageAspect = 800 / 600; // 1.333...
    for (const count of [50, 100, 150, 200]) {
      const { cols, rows } = computeGrid(count);
      const gridAspect = cols / rows;
      // Should be within 50% of the image aspect — generous but catches wildly wrong grids
      assert.ok(
        gridAspect > imageAspect * 0.5 && gridAspect < imageAspect * 2,
        `${count} pieces: grid aspect ${gridAspect.toFixed(2)} too far from image aspect ${imageAspect.toFixed(2)}`
      );
    }
  });

  it('cols >= rows for landscape image', () => {
    for (const count of [50, 100, 150, 200]) {
      const { cols, rows } = computeGrid(count);
      assert.ok(cols >= rows, `${count} pieces: expected cols(${cols}) >= rows(${rows}) for landscape`);
    }
  });
});


// ===== 2. Coordinate transforms =====
describe('screenToWorld / worldToScreen', () => {
  it('are inverses of each other at default zoom', () => {
    const camera = { x: 500, y: 400, zoom: 1 };
    const canvasW = 1000, canvasH = 800;
    const screen = { x: 300, y: 200 };

    const world = screenToWorld(screen.x, screen.y, camera, canvasW, canvasH);
    const back = worldToScreen(world.x, world.y, camera, canvasW, canvasH);

    assert.ok(Math.abs(back.x - screen.x) < 0.001, `x roundtrip: ${back.x} != ${screen.x}`);
    assert.ok(Math.abs(back.y - screen.y) < 0.001, `y roundtrip: ${back.y} != ${screen.y}`);
  });

  it('are inverses at non-default zoom', () => {
    const camera = { x: 200, y: 150, zoom: 2.5 };
    const canvasW = 1920, canvasH = 1080;
    const screen = { x: 750, y: 400 };

    const world = screenToWorld(screen.x, screen.y, camera, canvasW, canvasH);
    const back = worldToScreen(world.x, world.y, camera, canvasW, canvasH);

    assert.ok(Math.abs(back.x - screen.x) < 0.001);
    assert.ok(Math.abs(back.y - screen.y) < 0.001);
  });

  it('canvas center maps to camera position', () => {
    const camera = { x: 123, y: 456, zoom: 1.5 };
    const canvasW = 800, canvasH = 600;

    const world = screenToWorld(canvasW / 2, canvasH / 2, camera, canvasW, canvasH);
    assert.ok(Math.abs(world.x - camera.x) < 0.001);
    assert.ok(Math.abs(world.y - camera.y) < 0.001);
  });
});


// ===== 3. Snap detection =====
describe('trySnap', () => {
  function makeState(cols, rows) {
    const pieceW = 100, pieceH = 75;
    const puzzleX = 0, puzzleY = 0;
    const gs = createGameState(cols, rows, pieceW, pieceH, puzzleX, puzzleY);
    return { ...gs, cols, rows, pieceW, pieceH };
  }

  it('snaps a piece to its correct position when within threshold', () => {
    const state = makeState(3, 2);
    const piece = state.piecesById[0]; // top-left piece
    // Move it slightly off from correct position (within snap distance)
    piece.x = piece.correctX + 20;
    piece.y = piece.correctY - 15;

    const group = state.groups.find(g => g.id === piece.groupId);
    const result = trySnap(group, state);

    assert.equal(result.snapped, true);
    assert.equal(piece.x, piece.correctX);
    assert.equal(piece.y, piece.correctY);
    assert.equal(piece.placed, true);
  });

  it('does not snap when piece is outside threshold', () => {
    const state = makeState(3, 2);
    const piece = state.piecesById[0];
    piece.x = piece.correctX + 100; // way outside snap distance
    piece.y = piece.correctY + 100;

    const group = state.groups.find(g => g.id === piece.groupId);
    const result = trySnap(group, state);

    assert.equal(result.snapped, false);
    assert.equal(piece.placed, false);
  });

  it('snaps two neighboring pieces together when close enough', () => {
    const state = makeState(3, 2);
    const pieceA = state.piecesById[0]; // col=0, row=0
    const pieceB = state.piecesById[1]; // col=1, row=0

    // Move both far from correct position, but at correct relative offset
    pieceA.x = 500;
    pieceA.y = 500;
    pieceB.x = 500 + state.pieceW + 10; // slightly off from perfect alignment
    pieceB.y = 500 + 5;

    const groupA = state.groups.find(g => g.id === pieceA.groupId);
    const result = trySnap(groupA, state);

    assert.equal(result.snapped, true);
    // After snap, both should be in the same group
    assert.equal(pieceA.groupId, pieceB.groupId);
  });

  it('snapping to correct position marks all group pieces as placed', () => {
    const state = makeState(2, 2);
    const piece0 = state.piecesById[0]; // col=0, row=0
    const piece1 = state.piecesById[1]; // col=1, row=0

    // Manually merge them into one group first
    piece1.groupId = piece0.groupId;
    const group0 = state.groups.find(g => g.id === piece0.groupId);
    const group1 = state.groups.find(g => g.id === piece1.id);
    group0.pieces.push(piece1);
    state.groups = state.groups.filter(g => g.id !== piece1.id);

    // Move group near correct position
    piece0.x = piece0.correctX + 10;
    piece0.y = piece0.correctY + 10;
    piece1.x = piece1.correctX + 10;
    piece1.y = piece1.correctY + 10;

    const result = trySnap(group0, state);

    assert.equal(result.snapped, true);
    assert.equal(piece0.placed, true);
    assert.equal(piece1.placed, true);
    assert.equal(piece0.x, piece0.correctX);
    assert.equal(piece1.x, piece1.correctX);
  });
});


// ===== 4. Group merging =====
describe('mergeGroups', () => {
  function makeState(cols, rows) {
    const pieceW = 100, pieceH = 75;
    const gs = createGameState(cols, rows, pieceW, pieceH, 0, 0);
    return { ...gs, cols, rows, pieceW, pieceH };
  }

  it('merging two groups puts all pieces under one groupId', () => {
    const state = makeState(3, 2);
    const piece0 = state.piecesById[0];
    const piece1 = state.piecesById[1];
    const groupA = state.groups.find(g => g.id === piece0.groupId);
    const groupB = state.groups.find(g => g.id === piece1.groupId);

    // Move pieces to correct relative positions
    piece0.x = 500; piece0.y = 500;
    piece1.x = 500 + state.pieceW; piece1.y = 500;

    const initialGroupCount = state.groups.length;
    mergeGroups(groupA, groupB, state);

    assert.equal(piece0.groupId, piece1.groupId);
    assert.equal(groupA.pieces.length, 2);
    assert.equal(state.groups.length, initialGroupCount - 1);
    assert.ok(!state.groups.includes(groupB));
  });

  it('merging with a placed group places all pieces at correct positions', () => {
    const state = makeState(2, 2);
    const piece0 = state.piecesById[0];
    const piece1 = state.piecesById[1];
    const groupA = state.groups.find(g => g.id === piece0.groupId);
    const groupB = state.groups.find(g => g.id === piece1.groupId);

    // Mark groupB as placed
    groupB.placed = true;
    piece1.placed = true;
    piece1.x = piece1.correctX;
    piece1.y = piece1.correctY;

    // groupA is not placed
    piece0.x = 999; piece0.y = 999;

    mergeGroups(groupA, groupB, state);

    assert.equal(piece0.placed, true);
    assert.equal(piece0.x, piece0.correctX);
    assert.equal(piece0.y, piece0.correctY);
    assert.equal(groupA.placed, true);
  });
});


// ===== 5. Neighbor lookup =====
describe('getNeighbors', () => {
  function makeState(cols, rows) {
    const gs = createGameState(cols, rows, 100, 75, 0, 0);
    return { ...gs, cols, rows };
  }

  it('corner piece has exactly 2 neighbors', () => {
    const state = makeState(4, 3);
    const topLeft = state.piecesById[0]; // col=0, row=0
    const neighbors = getNeighbors(topLeft, state.cols, state.rows, state.piecesById);
    assert.equal(neighbors.length, 2);
  });

  it('edge piece (non-corner) has exactly 3 neighbors', () => {
    const state = makeState(4, 3);
    // col=1, row=0 — top edge, not corner
    const topEdge = state.piecesById[1];
    const neighbors = getNeighbors(topEdge, state.cols, state.rows, state.piecesById);
    assert.equal(neighbors.length, 3);
  });

  it('interior piece has exactly 4 neighbors', () => {
    const state = makeState(4, 3);
    // col=1, row=1 — interior
    const interior = state.piecesById[1 * 4 + 1];
    const neighbors = getNeighbors(interior, state.cols, state.rows, state.piecesById);
    assert.equal(neighbors.length, 4);
  });

  it('returns the correct neighbor pieces', () => {
    const state = makeState(3, 3);
    // Center piece: col=1, row=1, id=4
    const center = state.piecesById[4];
    const neighbors = getNeighbors(center, state.cols, state.rows, state.piecesById);
    const neighborIds = neighbors.map(n => n.id).sort();
    // left=3, right=5, up=1, down=7
    assert.deepEqual(neighborIds, [1, 3, 5, 7]);
  });
});


// ===== 6. Edge generation =====
describe('generateEdges', () => {
  it('produces correct number of horizontal edges', () => {
    const edges = generateEdges(4, 5);
    // h edges: (rows-1) rows, each with cols entries
    assert.equal(edges.h.length, 3);
    for (const row of edges.h) {
      assert.equal(row.length, 5);
    }
  });

  it('produces correct number of vertical edges', () => {
    const edges = generateEdges(4, 5);
    // v edges: rows rows, each with (cols-1) entries
    assert.equal(edges.v.length, 4);
    for (const row of edges.v) {
      assert.equal(row.length, 4);
    }
  });

  it('all edge values are either 1 or -1', () => {
    const edges = generateEdges(5, 6);
    for (const row of edges.h) {
      for (const val of row) {
        assert.ok(val === 1 || val === -1, `unexpected h edge value: ${val}`);
      }
    }
    for (const row of edges.v) {
      for (const val of row) {
        assert.ok(val === 1 || val === -1, `unexpected v edge value: ${val}`);
      }
    }
  });

  it('1x1 grid has no inner edges', () => {
    const edges = generateEdges(1, 1);
    assert.equal(edges.h.length, 0);
    assert.equal(edges.v.length, 1);
    assert.equal(edges.v[0].length, 0);
  });
});


// ===== 7. Edge-piece detection (edges-first helper) =====
describe('isEdgePiece', () => {
  it('marks all four corners of a grid as edges', () => {
    const cols = 5, rows = 4;
    const corners = [
      { col: 0, row: 0 },
      { col: cols - 1, row: 0 },
      { col: 0, row: rows - 1 },
      { col: cols - 1, row: rows - 1 },
    ];
    for (const c of corners) {
      assert.ok(isEdgePiece(c, cols, rows), `corner ${c.col},${c.row} should be an edge`);
    }
  });

  it('marks each outer border position as an edge', () => {
    const cols = 5, rows = 4;
    for (let col = 0; col < cols; col++) {
      assert.ok(isEdgePiece({ col, row: 0 }, cols, rows), `top ${col}`);
      assert.ok(isEdgePiece({ col, row: rows - 1 }, cols, rows), `bottom ${col}`);
    }
    for (let row = 0; row < rows; row++) {
      assert.ok(isEdgePiece({ col: 0, row }, cols, rows), `left ${row}`);
      assert.ok(isEdgePiece({ col: cols - 1, row }, cols, rows), `right ${row}`);
    }
  });

  it('does not mark interior pieces as edges', () => {
    const cols = 5, rows = 4;
    for (let col = 1; col < cols - 1; col++) {
      for (let row = 1; row < rows - 1; row++) {
        assert.ok(!isEdgePiece({ col, row }, cols, rows), `interior ${col},${row} should not be an edge`);
      }
    }
  });

  it('treats every piece of a single-row grid as an edge', () => {
    const cols = 6, rows = 1;
    for (let col = 0; col < cols; col++) {
      assert.ok(isEdgePiece({ col, row: 0 }, cols, rows), `1xN col ${col}`);
    }
  });

  it('treats every piece of a single-column grid as an edge', () => {
    const cols = 1, rows = 6;
    for (let row = 0; row < rows; row++) {
      assert.ok(isEdgePiece({ col: 0, row }, cols, rows), `Nx1 row ${row}`);
    }
  });

  it('treats the only piece of a 1x1 grid as an edge', () => {
    assert.ok(isEdgePiece({ col: 0, row: 0 }, 1, 1));
  });
});


// ===== 8. Custom snap distance (proportional snapping for small hands) =====
describe('trySnap with custom snapDistance', () => {
  it('snaps to correct position when within the supplied distance but not the default', () => {
    // Default SNAP_DISTANCE is 35; place a piece 60px away and use a 70px snap distance.
    const cols = 2, rows = 1, pieceW = 200, pieceH = 200;
    const gs = createGameState(cols, rows, pieceW, pieceH, 0, 0);
    const state = { cols, rows, pieceW, pieceH, piecesById: gs.piecesById, groups: gs.groups };
    const piece = gs.piecesById[0];
    const group = gs.groups.find((g) => g.id === piece.groupId);

    // Move 60px off — outside default (35) but inside custom (70)
    piece.x = piece.correctX + 60;
    piece.y = piece.correctY;

    const tooTight = trySnap(group, state, 35);
    assert.equal(tooTight.snapped, false, 'should not snap with a 35px tolerance');

    const forgiving = trySnap(group, state, 70);
    assert.equal(forgiving.snapped, true, 'should snap with a 70px tolerance');
    assert.equal(piece.x, piece.correctX);
    assert.equal(piece.y, piece.correctY);
  });
});

