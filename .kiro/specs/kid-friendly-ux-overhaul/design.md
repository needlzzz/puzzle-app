# Design Document: Kid-Friendly UX Overhaul

## Overview

This document describes the architecture and component design for the UX overhaul defined in `requirements.md`. The work targets the **web reference build** (`web/`), preserving its defining constraints: **no build step, no npm dependencies, directly openable `index.html`, and a pure shared `PuzzleEngine`**.

The overhaul is delivered as:

- Small, focused additions to the pure **Engine** (edge-piece detection; the snap-distance parameter already exists and is simply used).
- Two **new browser modules** loaded as globals (matching the existing `window.PuzzleEngine` pattern): `Sound` and `Storage`.
- Substantial enhancements to the **UI layer** (`app.js`, `index.html`, `style.css`) for difficulty/picture selection, tutorial, camera, snap feel, milestones, collection, progress, edges helper, ghost hint, confirmations, resume, and on-demand rendering.

The iOS and Android builds remain **convergence targets**: the new Engine functions are portable (they already maintain Swift/Kotlin ports), and the UX patterns below describe the intended cross-platform behaviour, but no Swift/Kotlin code is produced in this spec because those toolchains cannot be built or tested in this environment.

## Architecture

```
┌───────────────────────────────────────────────────────────────┐
│  Web Game (web/) — Vanilla HTML/CSS/JS, no build step          │
│                                                                 │
│  index.html  ── shell: start screen, picker, game, win, layers │
│  style.css   ── playful theme, big touch targets, components   │
│                                                                 │
│  app.js (IIFE orchestrator)                                     │
│   ├─ image loading (curated set + procedural fallback)         │
│   ├─ camera (constrain, fit/center, scatter-in-view)           │
│   ├─ render (ON-DEMAND: dirty flag + active-animation set)     │
│   ├─ drag/snap (lift, snap tween, ghost hint)                  │
│   ├─ progress / milestones / collection                        │
│   ├─ tutorial (animated hand) + edges helper                   │
│   └─ resume (serialize/restore in-progress puzzle)             │
│                                                                 │
│  NEW window.Sound    ── Web Audio synth SFX + navigator.vibrate│
│  NEW window.Storage  ── localStorage: settings, collection,    │
│                          tutorial-seen, resume-state            │
│                                                                 │
│  window.PuzzleEngine (web/puzzle-engine.js) — PURE LOGIC        │
│   ├─ computeGrid, screenToWorld, worldToScreen                 │
│   ├─ generateEdges, getNeighbors, createGameState             │
│   ├─ trySnap(…, snapDistance), mergeGroups                     │
│   └─ NEW isEdgePiece(piece, cols, rows)                        │
└───────────────────────────────────────────────────────────────┘
         ▲ shared logic ported to
         │
   iOS (PuzzleEngine.swift) / Android (PuzzleEngine.kt)  ← convergence targets
```

### Script load order (`index.html`)

```
puzzle-engine.js   → window.PuzzleEngine
sound.js           → window.Sound
storage.js         → window.Storage
app.js             → orchestrator (consumes the three globals)
```

## Key Design Decisions

### D1 — Constrained camera + Center action (NOT a full tray rewrite)

The UX review flagged the free pan/pinch camera as the biggest mismatch and floated a "tray" model (as on iOS). On a single HTML canvas, a true tray is a large architectural change (separate scroll region, cross-region drag). Instead the web build keeps the unified canvas but removes the ways a child gets lost:

- **Scatter-in-view**: pieces are scattered inside the current viewport bounds (in world space) at start, guaranteeing everything is visible at `zoom = 1`.
- **Pan clamping**: after every pan/zoom, the camera is clamped so `Content_Bounds` cannot leave the viewport (a margin is allowed but the content always remains partially visible; `fit` always recovers fully).
- **Center action**: a large, always-visible 🎯 button animates the camera to fit `Content_Bounds`.
- **Zoom clamp**: `MIN_ZOOM`/`MAX_ZOOM` tuned so pieces stay grabbable and you cannot zoom into empty void.

This achieves Requirement 5 with far lower risk than a tray rewrite. The tray remains a documented future option.

### D2 — On-demand rendering via dirty flag + active-animation registry

The current `render()` calls `requestAnimationFrame(render)` unconditionally. New model:

- `requestRender()` sets `needsRender = true` and schedules a single RAF if none pending.
- A frame renders once, then re-schedules **only if** `needsRender` is still set OR `activeAnimations.size > 0`.
- Continuous sources (dragging, snap tween, camera tween, confetti, tutorial pulse) register/deregister in `activeAnimations`.
- All state mutations that affect visuals call `requestRender()`.

This satisfies Requirement 15 without changing visible behaviour.

### D3 — Web Audio synthesised SFX (no asset files)

To keep the no-build, offline nature, `Sound` synthesises short tones with `OscillatorNode`/`GainNode` envelopes:

- `snap` — short rising blip.
- `merge` — two-note happy interval.
- `milestone` — quick arpeggio.
- `win` — longer celebratory arpeggio.
- Haptics via `navigator.vibrate(ms)` where supported (no-op otherwise).
- The `AudioContext` is created lazily on first user gesture (browser autoplay policy) and resumed on demand.

### D4 — Curated, animal-only images

`loadAnimalImage()` is refactored to a **named** curated set (`{ key, name, emoji, unsplashId, bg }[]`). The picture picker selects a specific entry; "Surprise me" picks randomly. The non-animal `Picsum` source and the random Flickr-keyword source are removed. On network failure the procedural fallback renders **the chosen animal** (its emoji/name/palette), satisfying Requirement 3.

## Components and Interfaces

### 1. Engine addition (`web/puzzle-engine.js`)

```javascript
/**
 * True iff the piece sits on the outer border of the grid.
 * Pure; no side effects. Ported to Swift/Kotlin as the convergence target.
 */
function isEdgePiece(piece, cols, rows) {
  return piece.col === 0 || piece.col === cols - 1 ||
         piece.row === 0 || piece.row === rows - 1;
}
// exported in both module.exports and window.PuzzleEngine
```

The snap-distance parameter already exists: `trySnap(movedGroup, state, snapDistance)`. The Game computes `snapDistance = clamp(min(pieceW, pieceH) * SNAP_RATIO, MIN_SNAP_WORLD, …)` and passes it (Requirement 6).

### 2. `window.Sound` (`web/sound.js`)

```javascript
window.Sound = {
  init(),                 // lazily create/resume AudioContext (call on first gesture)
  isMuted(): boolean,
  setMuted(bool),         // persists via Storage
  play(name),             // 'snap' | 'merge' | 'milestone' | 'win'
  vibrate(ms),            // navigator.vibrate guard
};
```

- Reads initial mute state from `Storage.getSettings().muted`.
- All `play()` calls are no-ops while muted or before `init()`.

### 3. `window.Storage` (`web/storage.js`)

A thin, defensive localStorage wrapper. All reads tolerate missing/corrupt JSON (Requirement 14.5).

```javascript
window.Storage = {
  // settings: { muted:boolean, showTimer:boolean }
  getSettings(): Settings,
  setSettings(partial),

  // tutorial
  hasSeenTutorial(): boolean,
  markTutorialSeen(),

  // collection: string[] of animal keys
  getCollection(): string[],
  addToCollection(animalKey),

  // resume
  saveResume(state): void,     // throttled by caller
  loadResume(): ResumeState | null,
  clearResume(): void,
};
```

```javascript
/** @typedef ResumeState
 *  { version, animalKey, pieceCount, cols, rows,
 *    pieceW, pieceH, puzzleX, puzzleY,
 *    edges, placedPieces, elapsedMs,
 *    pieces: [{ id, x, y, placed, groupId }],
 *    groups: [{ id, pieceIds:number[], placed }] }
 */
```

Storage keys (namespaced): `kaley.settings`, `kaley.tutorialSeen`, `kaley.collection`, `kaley.resume`.

### 4. UI layer (`web/app.js`) — new/changed responsibilities

| Area | Function(s) | Notes |
|------|-------------|-------|
| Picture+difficulty select | `renderPickerScreen()`, `chooseAnimal()`, `chooseDifficulty()` | Two-step or combined selection; emoji tiers; "Surprise me" |
| Curated images | `CURATED_ANIMALS`, `loadChosenImage(animal)` | Replaces Unsplash-random/Flickr/Picsum chain |
| Camera | `computeContentBounds()`, `fitCameraToContent(animate)`, `clampCamera()`, `scatterInView()` | D1 |
| Render | `requestRender()`, `renderFrame()`, `activeAnimations` set | D2 |
| Drag feel | `liftScaleFor(group)`, draw held group scaled | Requirement 7.1 |
| Snap tween | `startSnapAnimation(group, fromPositions)` | Requirement 7.2 |
| Ghost hint | `drawGhostHint(group)` | Requirement 11 |
| Edges helper | `edgesHighlight` flag + per-piece edge stroke using `Engine.isEdgePiece` | Requirement 10 |
| Progress | `updateProgress()` → fill bar width | Requirement 9 |
| Milestones | `checkMilestones()` with a `firedMilestones` Set | Requirement 8 |
| Collection | on win → `Storage.addToCollection`; `renderCollection()` on start | Requirement 8 |
| Tutorial | `startTutorial()`, animated hand layer, pulse target | Requirement 4 |
| New confirm | `confirmNewPuzzle()` modal | Requirement 12 |
| Win actions | `playAgain()`, `chooseAnother()` | Requirement 12 |
| Resume | `serializeResume()`, `restoreResume(state)`, throttled autosave | Requirement 14 |
| Settings | mute toggle, timer toggle wired to `Storage` + `Sound` | Requirements 7, 9 |

### 5. HTML structure (`web/index.html`)

New/!changed regions:

```
#start-screen
  ├─ hero (logo, "Made with love by your PAPA")
  ├─ #continue-row        (shown only if resume exists) → "▶ Continue"
  ├─ #picker
  │    ├─ #animal-grid    (curated thumbnails + "🎲 Surprise me")
  │    └─ #difficulty-row (emoji tiers, ≥64px targets)
  ├─ #collection          (earned-animals gallery)
  └─ #start-actions       (🔁 Replay tutorial, ⚙ settings: mute, timer)

#game-screen
  ├─ canvas#puzzle-canvas
  ├─ #ui-bar (compact): #progress-bar, ⏱(optional), 🧩 Edges, 🖼 Hint, 🔇 Mute, 🔄 New
  ├─ #center-btn (🎯, large, fixed)
  └─ #tutorial-layer (animated hand + scrim)  [hidden by default]

#confirm-overlay  (🔄 New confirmation)   [hidden]
#win-overlay
  ├─ confetti-canvas
  └─ #win-content: 🎉 + Progress_Indicator full + 🔁 Play again / 🐾 Choose another
```

### 6. CSS (`web/style.css`)

- Brighter, playful palette layered over the existing dark board (board stays dark so the image pops; chrome becomes colorful/rounded).
- `--touch-min: 56px`, `--touch-choice: 64px` custom properties enforced on controls.
- New component styles: animal grid, difficulty tiles, progress bar, center button, tutorial hand keyframes, collection gallery, confirm overlay, settings toggles.
- Keep `@media (max-width:600px)` plus add tablet-oriented sizing.

## Data Models

### Curated animal entry

```javascript
{ key:'lion', name:'Lion', emoji:'🦁',
  unsplashId:'YozNeHM8MaA', bg:['#F4A460','#CD853F','#DEB887'] }
```

### Animation registry entry

`activeAnimations` is a `Set<string>` of tokens like `'drag'`, `'snap:<groupId>'`, `'camera'`, `'confetti'`, `'tutorial'`. Frame loop continues while non-empty.

### Milestone tracking

`firedMilestones: Set<'p25'|'p50'|'p75'|'edges'>` reset per puzzle (Requirement 8.5).

## Rendering pipeline (on-demand)

```
state change ──► requestRender()
                   │ needsRender = true
                   │ if !rafPending: rafPending = true; requestAnimationFrame(frame)
                   ▼
                 frame():
                   rafPending = false
                   step animations (snap tweens, camera tween, tutorial, confetti)
                   draw world (board, hint, ghost, grid, pieces[, edge highlight])
                   if needsRender || activeAnimations.size>0:
                       needsRender for tweens stays set by the tween stepper
                       schedule next frame
```

Drag sets `activeAnimations.add('drag')` on pointer-down and removes it on pointer-up; each pointer-move also calls `requestRender()`.

## Camera math

```
contentBounds = union(board rect, every piece's bbox)
fit: zoom = clamp( min(viewW/contentW, viewH/contentH) * PAD, MIN_ZOOM, MAX_ZOOM )
     camera.{x,y} = center of contentBounds
clamp after pan/zoom: ensure contentBounds∩viewport area ≥ threshold; otherwise nudge camera back
```

`fitCameraToContent(animate=true)` registers a `'camera'` animation that lerps `camera` to the target over ~300ms.

## Error Handling

- Image load failure → procedural fallback for the **chosen** animal (Req 3.3); never surfaces an error to the child.
- `Sound.init()` failure (no Web Audio) → all `play()` become silent no-ops.
- `navigator.vibrate` absent → no-op.
- Corrupt `Storage` values → caught, treated as absent; `clearResume()` on parse error (Req 14.5).
- All Storage writes wrapped in try/catch (private-mode / quota) and fail silently.

## Testing Strategy

- **Engine unit tests** (`web/puzzle-engine.test.js`, `node --test`):
  - Keep all existing tests passing (Req 16.1).
  - Add `isEdgePiece` cases: corners, top/bottom/left/right borders true; interior false; 1×N and N×1 grids; 1×1 grid (all edges).
  - (Optional) parametrize a snap test with a custom `snapDistance` to lock the proportional-snap contract.
- **Manual/board behaviour** (no DOM test harness in repo): camera fit/clamp, scatter-in-view, snap tween, milestones, resume round-trip, tutorial gating verified by opening `web/index.html`.
- Engine remains pure and DOM-free (Req 16.3); web build remains directly openable (Req 16.4).

## Out of Scope / Convergence Notes

- iOS/Android code changes (the patterns above are the target; `isEdgePiece` should be ported).
- True bottom **tray** model on web (documented future alternative to D1).
- Accounts, leaderboards, multiplayer, server persistence.
