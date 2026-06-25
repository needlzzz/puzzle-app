# Kaley's Puzzle App — Project Context

## What This Project Is

A jigsaw puzzle game for kids, featuring animal images. The same game is implemented across three platforms (iOS, Android, Web) with a shared core engine design. Named "Kaley's Puzzle" — built as a personal/family project.

## Tech Stack

| Platform | Language | UI Framework | Build System |
|----------|----------|--------------|--------------|
| iOS | Swift | SwiftUI | Xcode (xcodeproj) |
| Android | Kotlin | Custom Canvas View | Gradle (Kotlin DSL) |
| Web | Vanilla JavaScript | HTML5 Canvas | None (no build step) |

## Key Commands

```bash
# Web
open web/index.html              # Run in browser (no server needed)
node --test web/puzzle-engine.test.js  # Run engine unit tests (Node.js test runner)
node --check web/app.js          # Syntax-check the UI layer (no build step to catch errors)

# Android
cd android && ./gradlew assembleDebug  # Build debug APK

# iOS
open ios/KaleysPuzzle.xcodeproj        # Open in Xcode, build from there
```

## Project Structure

```
puzzle-app/
├── web/
│   ├── index.html              # Single-page app shell (start/game/tutorial/confirm/win layers)
│   ├── style.css               # Styles (dark kid-friendly theme, tutorial layer, overlays)
│   ├── app.js                  # UI layer (Canvas rendering, input, camera, image loading, all UX features)
│   ├── sound.js                # window.Sound — Web Audio synthesized SFX (snap/merge/win) + haptics
│   ├── storage.js              # window.Storage — defensive localStorage wrapper (settings/tutorial/collection/resume)
│   ├── puzzle-engine.js        # Pure game logic (shared via CommonJS + browser global)
│   └── puzzle-engine.test.js   # Unit tests (Node.js built-in test runner, 27 tests)
├── ios/
│   ├── KaleysPuzzle.xcodeproj/ # Xcode project
│   └── KaleysPuzzle/
│       ├── KaleysPuzzleApp.swift      # App entry point
│       ├── ContentView.swift          # Main SwiftUI view (start/game/win screens)
│       ├── PuzzleCanvasView.swift     # Puzzle board rendering
│       ├── PieceTrayView.swift        # Scrollable tray of unplaced pieces
│       ├── PuzzleViewModel.swift      # Game state + timer (ObservableObject)
│       ├── PuzzleEngine.swift         # Pure game logic (port of JS engine, incl. isEdgePiece)
│       ├── Animals.swift              # Canonical animal catalog (10 animals + Surprise)
│       ├── Storage.swift              # UserDefaults wrapper (mute/timer/tutorial/collection)
│       ├── AnimalImageLoader.swift    # Loads animal images from asset catalog
│       ├── ConfettiView.swift         # Win celebration animation
│       ├── SoundManager.swift         # Mute-aware SFX + haptics (snap/win/milestone)
│       ├── Assets.xcassets/           # App icon + bundled animal images
│       └── Sounds/                    # Audio files
├── android/
│   └── app/src/main/java/com/kaleys/puzzle/
│       ├── MainActivity.kt            # Activity (picker/game/win/tutorial/confirm screens)
│       ├── PuzzleView.kt              # Custom Canvas view (rendering + input + edge highlight)
│       ├── PuzzleViewModel.kt         # Game state (survives rotation) + milestones
│       ├── PuzzleEngine.kt            # Pure game logic (port of JS engine, incl. isEdgePiece)
│       ├── AnimalImageGenerator.kt    # Procedural animal images + canonical animal catalog
│       ├── Storage.kt                 # SharedPreferences wrapper (mute/timer/tutorial/collection)
│       ├── SoundManager.kt            # Synthesized SFX (ToneGenerator) + haptics (Vibrator)
│       └── ConfettiView.kt            # Win celebration animation
└── .kiro/steering/                    # This file
```

## Architecture Principles

1. **Shared engine design**: All three platforms implement the same `PuzzleEngine` with identical logic — grid computation, edge generation, snap detection, group merging. The JS version is the reference implementation.
2. **Pure logic separation**: `PuzzleEngine` has zero UI or platform dependencies. It operates on plain data structures (pieces, groups, edges) and is fully testable.
3. **Platform-native UI**: Each platform uses its native rendering approach (Canvas 2D on web, custom View + Canvas on Android, SwiftUI + custom drawing on iOS). No cross-platform framework.
4. **No build step for web**: The web version is vanilla HTML/CSS/JS. Open `index.html` directly in a browser.
5. **No external dependencies for game logic**: The engine uses only standard library math. Platform-specific code handles image loading and rendering.

## Game Mechanics

### Puzzle Flow
1. Player picks an **animal** (10 curated animals + 🎲 Surprise) and a **difficulty tier**
2. An image of the chosen animal is loaded/generated
3. Image is divided into a grid matching the image's 4:3 aspect ratio
4. Pieces are scattered around the puzzle area (web/Android) or placed in a tray (iOS)
5. Player drags pieces onto the board
6. Pieces snap when close to correct position or to a matching neighbor
7. Groups merge and chain-react (snapping one group can trigger further snaps)
8. Win state triggers confetti + Play-Again / Choose-Another options

### Difficulty Tiers
Kid-friendly counts with emoji labels instead of raw numbers. All three platforms now share the same tiers:

| Tier   | Emoji | Pieces |
|--------|-------|--------|
| Easy   | 🐣    | 12     |
| Medium | 🐥    | 20     |
| Hard   | 🐔    | 50     |
| Expert | 🦅    | 100    |

### Core Engine Concepts
- **Grid**: cols × rows computed to match image aspect ratio for the given piece count
- **Edges**: Random +1/-1 values defining tab/blank jigsaw connections between adjacent cells
- **Piece**: Has id, col, row, current x/y, correct x/y, placed flag, groupId
- **Group**: Collection of pieces that have been snapped together (move as one unit)
- **Snap distance**: proportional on web — `max(min(pieceW,pieceH)*0.45, 22px/zoom)` so snapping stays forgiving for small fingers at any zoom (engine default 35px when not overridden)
- **Chain reaction**: After a merge, `trySnap` is called again on the merged group to catch cascading connections
- **Edge pieces**: `isEdgePiece(piece, cols, rows)` flags border pieces — used by the "Edges" helper to highlight the frame. Implemented on all three platforms (web JS, Swift, Kotlin).

### Image Sources
- **Web**: Loads the **chosen** animal from Unsplash → procedural fallback that depicts that same animal (emoji + per-animal gradient). The puzzle image always matches the selected animal, online or offline.
- **iOS**: Bundled animal photos in asset catalog (no network dependency)
- **Android**: Procedurally generated animal images (emoji + gradient, no network)

### Kid-Friendly UX Features
Implemented first on the web (reference), now ported to iOS and Android for feature parity:

- **Animal + difficulty picker**: tile-based start screen, large touch targets, start button enabled only when both chosen
- **First-run tutorial**: animated hand + text overlay on the first puzzle; the layer is `pointer-events: none` so the child's first drag passes through and dismisses it. Replayable from the start screen; seen-state in localStorage
- **Camera constrain + center**: auto-fit camera to content, clamped panning, 🎯 center button re-fits with an eased animation
- **On-demand rendering**: `requestAnimationFrame` is scheduled only when `needsRender` or animations are active (battery-friendly)
- **Snap feel**: 180ms snap-into-place tween, held-piece lift (scale + stroke), snap/merge SFX + haptic pulse
- **Ghost hint**: held single piece shows a faint target outline at its correct position
- **Edges helper**: highlights unplaced border pieces in yellow
- **Milestones**: 25/50/75% + all-edges trigger particle bursts and sound
- **Progress bar**: 🐾 paw fills left→right with completion (no numbers)
- **Collection**: solved animals saved to localStorage and shown on the start screen
- **New-puzzle confirm**: guards against accidental resets
- **Play-Again / Choose-Another**: win screen reuses the same animal+tier or returns to the picker
- **Resume**: in-progress puzzle autosaved (throttled + on visibility/pagehide) and restored via Continue
- **Settings**: mute toggle and optional timer (off by default), both persisted in localStorage

## Platform-Specific Notes

### iOS
- SwiftUI with dark color scheme enforced
- Piece tray is a horizontal scrollable strip below the puzzle board
- Full kid-friendly UX parity: animal + difficulty picker, first-run tutorial, paw progress bar, milestone banners (25/50/75%), Edges/Peek/Center helpers, new-puzzle confirm, Play-Again / Choose-Another, solved-animal collection
- `SoundManager` is mute-aware (snap → light impact, win → success notification, milestone → medium impact); haptics via `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator`
- `Storage` persists mute, optional timer (off by default), tutorial-seen, and collection in `UserDefaults` (`kp_` keys)
- Timer pauses/resumes with app lifecycle; hidden by default, toggleable
- Snap distance is proportional to piece size for better touch UX
- Min SDK: iOS 16+ (SwiftUI features)
- Build/validate: `xcodebuild build -project KaleysPuzzle.xcodeproj -scheme KaleysPuzzle -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`. New `.swift` files must be registered in `project.pbxproj` (PBXBuildFile + PBXFileReference + group children + Sources phase) or they won't compile.

### Android
- Single Activity architecture
- Custom `PuzzleView` extends `View` for Canvas-based rendering; edge pieces highlighted (teal) when the Edges helper is on
- `PuzzleViewModel` survives configuration changes (rotation) and tracks fired milestones
- Pieces scattered around puzzle area (same as web)
- Jigsaw paths drawn with `Path` + bezier curves
- Full kid-friendly UX parity: animal grid (`GridLayout`, built programmatically in `MainActivity`) + difficulty tiles, first-run tutorial overlay, paw progress (`ProgressBar`), milestone banner, Edges/Peek/Center, confirm-new overlay, Play-Again / Choose-Another, solved-animal collection
- No audio assets — SFX synthesized via `ToneGenerator`, haptics via `Vibrator`/`VibrationEffect` (`SoundManager`)
- `Storage` persists mute, optional timer (off by default), tutorial-seen, and collection in `SharedPreferences` (`kp_` keys)
- The animal catalog is canonical in `AnimalImageGenerator` (`animals` list + `SURPRISE_KEY`); `MainActivity` builds the picker from it
- Min SDK: 26 (Android 8.0), Target SDK: 36
- Dependencies: AndroidX Core, AppCompat, Material, Lifecycle ViewModel
- **Unverified build**: no local `kotlinc`/`gradle` toolchain available, so Android changes are written to mirror existing patterns but have not been compiled. Verify with `./gradlew assembleDebug` on a machine with the Android toolchain.

### Web (reference implementation)
- IIFE pattern, no modules in the app layer (engine uses CommonJS for Node tests)
- Browser-global wiring: `window.PuzzleEngine`, `window.Sound`, `window.Storage`; script load order is `puzzle-engine.js → sound.js → storage.js → app.js`
- Camera system: pan (drag empty space), zoom (scroll wheel / pinch), clamped + auto-fit + center button
- Touch support: single-finger drag, two-finger pinch-to-zoom + pan
- Images loaded with CORS + taint check (canvas security); procedural fallback depicts the chosen animal
- On-demand `requestAnimationFrame` loop (renders only when dirty or animating)
- SFX synthesized via Web Audio (`sound.js`) — no asset files; `Sound.init()` lazily on first user gesture
- Persistence via `storage.js` localStorage wrapper (settings, tutorial-seen, collection, resume)
- Confetti rendered on a separate overlay canvas; milestone particles drawn on the main canvas

## Testing

- **Web engine**: `node --test web/puzzle-engine.test.js` — uses Node.js built-in test runner (`node:test` + `node:assert/strict`), 27 tests
- **Web UI**: `node --check web/app.js` for syntax; manual/Playwright browser smoke testing for the UX flows (no build step)
- **iOS/Android**: No automated tests — manual testing only
- Tests cover: grid computation, coordinate transforms, snap detection, group merging, neighbor lookup, edge generation, edge-piece detection

## Important Conventions

- The puzzle image is always 800×600 (4:3 aspect ratio) conceptually
- Piece IDs are computed as `row * cols + col`
- Group IDs start equal to the first piece's ID in that group
- When groups merge, groupB's pieces get groupA's ID, and groupB is removed from the list
- Edge values: `+1` = tab protrudes outward, `-1` = blank (indent)
- The web version is the reference implementation — iOS and Android are ports that now have full UX feature parity
- **Persistence**: settings (mute, optional timer), tutorial-seen flag, and the solved-animal collection are persisted on all three platforms (web localStorage `kaley.*`; iOS `UserDefaults` `kp_`; Android `SharedPreferences` `kp_`). The in-progress **resume** snapshot is web-only — native apps retain an active game across rotation via their ViewModel but intentionally do **not** persist across app kills (deferred).
- No multiplayer, no leaderboards, no accounts
- Target audience: young children who can't read well, have low frustration tolerance, small/imprecise fingers, and are motivated by delight, sound, and choice — not timers and numbers
- Tutorial layer must stay `pointer-events: none` so the instructional overlay never blocks the drag it is teaching
