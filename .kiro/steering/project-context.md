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

# Android
cd android && ./gradlew assembleDebug  # Build debug APK

# iOS
open ios/KaleysPuzzle.xcodeproj        # Open in Xcode, build from there
```

## Project Structure

```
puzzle-app/
├── web/
│   ├── index.html              # Single-page app shell
│   ├── style.css               # Styles
│   ├── app.js                  # UI layer (Canvas rendering, input handling, image loading)
│   ├── puzzle-engine.js        # Pure game logic (shared via CommonJS + browser global)
│   └── puzzle-engine.test.js   # Unit tests (Node.js built-in test runner)
├── ios/
│   ├── KaleysPuzzle.xcodeproj/ # Xcode project
│   └── KaleysPuzzle/
│       ├── KaleysPuzzleApp.swift      # App entry point
│       ├── ContentView.swift          # Main SwiftUI view (start/game/win screens)
│       ├── PuzzleCanvasView.swift     # Puzzle board rendering
│       ├── PieceTrayView.swift        # Scrollable tray of unplaced pieces
│       ├── PuzzleViewModel.swift      # Game state + timer (ObservableObject)
│       ├── PuzzleEngine.swift         # Pure game logic (port of JS engine)
│       ├── AnimalImageLoader.swift    # Loads animal images from asset catalog
│       ├── ConfettiView.swift         # Win celebration animation
│       ├── SoundManager.swift         # Sound effects (snap, drop, win)
│       ├── Assets.xcassets/           # App icon + bundled animal images
│       └── Sounds/                    # Audio files
├── android/
│   └── app/src/main/java/com/kaleys/puzzle/
│       ├── MainActivity.kt            # Activity (start/game/win screens)
│       ├── PuzzleView.kt              # Custom Canvas view (rendering + input)
│       ├── PuzzleViewModel.kt         # Game state (survives rotation)
│       ├── PuzzleEngine.kt            # Pure game logic (port of JS engine)
│       ├── AnimalImageGenerator.kt    # Procedural animal image generation
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
1. Player selects difficulty (piece count: 50, 100, 150, or 200)
2. An animal image is loaded/generated
3. Image is divided into a grid matching the image's 4:3 aspect ratio
4. Pieces are scattered around the puzzle area (web/Android) or placed in a tray (iOS)
5. Player drags pieces onto the board
6. Pieces snap when close to correct position or to a matching neighbor
7. Groups merge and chain-react (snapping one group can trigger further snaps)
8. Win state triggers confetti + elapsed time display

### Core Engine Concepts
- **Grid**: cols × rows computed to match image aspect ratio for the given piece count
- **Edges**: Random +1/-1 values defining tab/blank jigsaw connections between adjacent cells
- **Piece**: Has id, col, row, current x/y, correct x/y, placed flag, groupId
- **Group**: Collection of pieces that have been snapped together (move as one unit)
- **Snap distance**: 35px default — if a piece is within this distance of its target, it snaps
- **Chain reaction**: After a merge, `trySnap` is called again on the merged group to catch cascading connections

### Image Sources
- **Web**: Tries Unsplash → Lorem Flickr → Picsum → procedural fallback (emoji + gradient)
- **iOS**: Bundled animal photos in asset catalog (no network dependency)
- **Android**: Procedurally generated animal images (emoji + gradient, no network)

## Platform-Specific Notes

### iOS
- SwiftUI with dark color scheme enforced
- Piece tray is a horizontal scrollable strip below the puzzle board
- Sound effects on snap, drop, and win
- Timer pauses/resumes with app lifecycle
- Snap distance is proportional to piece size for better touch UX
- Min SDK: iOS 16+ (SwiftUI features)

### Android
- Single Activity architecture
- Custom `PuzzleView` extends `View` for Canvas-based rendering
- `PuzzleViewModel` survives configuration changes (rotation)
- Pieces scattered around puzzle area (same as web)
- Jigsaw paths drawn with `Path` + bezier curves
- Min SDK: 26 (Android 8.0), Target SDK: 36
- Dependencies: AndroidX Core, AppCompat, Material, Lifecycle ViewModel

### Web
- IIFE pattern, no modules in the app layer (engine uses CommonJS for Node tests)
- Camera system: pan (drag empty space), zoom (scroll wheel / pinch)
- Touch support: single-finger drag, two-finger pinch-to-zoom + pan
- Images loaded with CORS + taint check (canvas security)
- Confetti rendered on a separate overlay canvas

## Testing

- **Web engine**: `node --test web/puzzle-engine.test.js` — uses Node.js built-in test runner (`node:test` + `node:assert/strict`)
- **iOS/Android**: No automated tests — manual testing only
- Tests cover: grid computation, coordinate transforms, snap detection, group merging, neighbor lookup, edge generation

## Important Conventions

- The puzzle image is always 800×600 (4:3 aspect ratio) conceptually
- Piece IDs are computed as `row * cols + col`
- Group IDs start equal to the first piece's ID in that group
- When groups merge, groupB's pieces get groupA's ID, and groupB is removed from the list
- Edge values: `+1` = tab protrudes outward, `-1` = blank (indent)
- The web version is the reference implementation — iOS and Android are ports
- No persistence: game state is lost on app close (intentional for v1)
- No multiplayer, no leaderboards, no accounts
- Target audience: young children (simple UI, large touch targets, celebratory feedback)
