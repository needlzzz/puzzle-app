# Implementation Plan: Kid-Friendly UX Overhaul

## Overview

Implement the kid-friendly UX overhaul on the **web reference build** (`web/`), keeping the no-build-step constraint and the pure shared `PuzzleEngine`. Work proceeds bottom-up: pure Engine addition (testable first), then the two new browser modules (`sound.js`, `storage.js`), then the HTML/CSS shell, then the `app.js` feature wiring grouped by concern, and finally documentation + test runs.

Each task lists the requirements it satisfies. Checkboxes track progress.

## Tasks

- [x] 1. Engine: edge-piece detection + proportional snap contract
  - [x] 1.1 Add `isEdgePiece(piece, cols, rows)` to `web/puzzle-engine.js`
    - Pure function; export via `module.exports` and `window.PuzzleEngine`
    - _Requirements: 10.1, 16.3_
  - [x] 1.2 Add unit tests in `web/puzzle-engine.test.js`
    - Corners, each border, interior, 1×N, N×1, 1×1 grids
    - Add a `trySnap` case exercising a custom `snapDistance` argument
    - _Requirements: 10.1, 6.1, 16.1, 16.2_
  - [x] 1.3 Run `node --test web/puzzle-engine.test.js` — all green
    - _Requirements: 16.1_

- [x] 2. New module: `web/sound.js` (`window.Sound`)
  - [x] 2.1 Web Audio synth SFX: `snap`, `merge`, `milestone`, `win`
    - Lazy `AudioContext` on first gesture; `init()`, `play(name)`
    - _Requirements: 7.3, 7.5_
  - [x] 2.2 Mute state + haptics
    - `isMuted()/setMuted()` persisted via `Storage`; `vibrate(ms)` guarded
    - No-ops when muted or unsupported
    - _Requirements: 7.3, 7.4_

- [x] 3. New module: `web/storage.js` (`window.Storage`)
  - [x] 3.1 Settings (`muted`, `showTimer`), tutorial-seen flag
    - Defensive JSON parse; try/catch writes
    - _Requirements: 7.4, 9.3, 4.3_
  - [x] 3.2 Collection get/add
    - _Requirements: 8.3, 8.4_
  - [x] 3.3 Resume save/load/clear with corruption tolerance
    - _Requirements: 14.1, 14.4, 14.5_

- [x] 4. HTML shell restructure (`web/index.html`)
  - [x] 4.1 Load `sound.js` + `storage.js` before `app.js`
    - _Requirements: 16.4_
  - [x] 4.2 Start screen: hero, `#continue-row`, `#picker` (animal grid + difficulty tiers), `#collection`, `#start-actions` (replay tutorial, mute, timer)
    - _Requirements: 1, 2, 4.4, 8.4, 9.3, 13.3, 13.4, 14.2_
  - [x] 4.3 Game screen: `#progress-bar`, optional timer, toolbar (Edges, Hint, Mute, New), large `#center-btn`, `#tutorial-layer`
    - _Requirements: 5.3, 7.4, 9.1, 9.2, 10.2, 11.4, 12.1_
  - [x] 4.4 `#confirm-overlay`; win overlay with Play again / Choose another
    - _Requirements: 12.1, 12.3_

- [x] 5. CSS (`web/style.css`)
  - [x] 5.1 Playful palette + design tokens (`--touch-min:56px`, `--touch-choice:64px`)
    - _Requirements: 13.1, 13.2, 13.3_
  - [x] 5.2 Components: animal grid, difficulty tiles, progress bar, center button, collection gallery, confirm overlay, settings toggles
    - _Requirements: 1.4, 2.4, 5.3, 8.4, 9.1, 12.1_
  - [x] 5.3 Tutorial hand keyframes + held-piece/edge visual support
    - _Requirements: 4.1, 4.2_

- [x] 6. `app.js` — picture/difficulty selection + curated images
  - [x] 6.1 `CURATED_ANIMALS` list; remove Picsum + Flickr-random sources
    - _Requirements: 3.1, 3.2_
  - [x] 6.2 `loadChosenImage(animal)` with per-animal procedural fallback
    - _Requirements: 3.3, 3.4_
  - [x] 6.3 Animal grid + "Surprise me" + emoji difficulty tiers (incl. ≤12 Easy)
    - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3_

- [x] 7. `app.js` — camera: scatter-in-view, clamp, center/fit
  - [x] 7.1 `scatterInView()` so all pieces start visible
    - _Requirements: 5.1_
  - [x] 7.2 `computeContentBounds()`, `clampCamera()`, zoom clamp
    - _Requirements: 5.2, 5.6_
  - [x] 7.3 `fitCameraToContent(animate)` + `#center-btn` wiring + re-fit on resize
    - _Requirements: 5.3, 5.4, 5.5_

- [x] 8. `app.js` — on-demand rendering
  - [x] 8.1 `requestRender()` + `activeAnimations` set; convert `render()` loop
    - _Requirements: 15.1, 15.2, 15.3, 15.4_
  - [x] 8.2 Register drag/camera/confetti/tutorial/snap animations; `requestRender()` on every state mutation
    - _Requirements: 15.2, 15.4_

- [x] 9. `app.js` — snap feel: lift, tween, sound, haptics, proportional snap
  - [x] 9.1 Held-group lift (scale + shadow) in `drawPiece`/group draw
    - _Requirements: 7.1_
  - [x] 9.2 `startSnapAnimation()` tween from drop → target
    - _Requirements: 7.2_
  - [x] 9.3 Play `snap`/`merge` sound + `vibrate` on snap; pass proportional `snapDistance` to `Engine.trySnap`
    - _Requirements: 6.1, 6.2, 6.3, 7.3_

- [x] 10. `app.js` — progress, milestones, collection, timer toggle
  - [x] 10.1 Progress bar fill on placement change; hide timer by default + setting
    - _Requirements: 9.1, 9.2, 9.3, 9.4_
  - [x] 10.2 `checkMilestones()` (25/50/75% + all edges) with once-per-puzzle `firedMilestones`
    - _Requirements: 8.1, 8.2, 8.5_
  - [x] 10.3 On win: add animal to collection; render collection gallery on start
    - _Requirements: 8.3, 8.4_

- [x] 11. `app.js` — edges helper + ghost hint
  - [x] 11.1 Edges-highlight toggle using `Engine.isEdgePiece`
    - _Requirements: 10.2, 10.3, 10.4_
  - [x] 11.2 `drawGhostHint()` while dragging when hint enabled; keep full-image hint independent
    - _Requirements: 11.1, 11.2, 11.3, 11.4_

- [x] 12. `app.js` — tutorial (first run + replay)
  - [x] 12.1 First-run gating via `Storage.hasSeenTutorial()`; animated hand + pulsed target piece
    - _Requirements: 4.1, 4.2_
  - [x] 12.2 Dismiss on drag/tap → `markTutorialSeen()`; replay from start screen
    - _Requirements: 4.3, 4.4_

- [x] 13. `app.js` — safe New + fast replay
  - [x] 13.1 `#confirm-overlay` gating "New" mid-game; cancel preserves puzzle
    - _Requirements: 12.1, 12.2_
  - [x] 13.2 Win actions: `playAgain()` (reuse tier) + `chooseAnother()`
    - _Requirements: 12.3, 12.4_

- [x] 14. `app.js` — resume in-progress puzzle
  - [x] 14.1 Throttled `serializeResume()` autosave during play
    - _Requirements: 14.1_
  - [x] 14.2 Start-screen "Continue" when valid resume exists; `restoreResume()`
    - _Requirements: 14.2, 14.3_
  - [x] 14.3 Clear resume on win / new puzzle; ignore corrupt resume
    - _Requirements: 14.4, 14.5_

- [x] 15. Documentation + verification
  - [x] 15.1 Update `.kiro/steering/project-context.md` (difficulty values, new web features, new files, convergence note for `isEdgePiece`)
    - _Requirements: 1.5_
  - [x] 15.2 Re-run `node --test web/puzzle-engine.test.js`; sanity-open `web/index.html`
    - _Requirements: 16.1, 16.4_
