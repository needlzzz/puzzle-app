# Requirements Document

## Introduction

This document specifies a UX overhaul of **Kaley's Puzzle App** to make the jigsaw game more enjoyable and playable for its target audience: **young children using a tablet**. The findings driving this spec come from a UX review of the existing codebase, which found that the web/Android builds use an adult "infinite canvas" mental model (free pan + pinch-zoom, abstract numeric difficulty, a stress-inducing timer, silent feedback, random internet images) that fights against how young children actually play.

**Scope of implementation.** The **web build** (`web/` — vanilla HTML/CSS/JS, no build step) is the reference implementation and the focus of this spec's code work, because it has the most UX gaps, is fully testable here (`node --test web/puzzle-engine.test.js`), and is the canonical source the other platforms port from. The iOS build already implements several of these ideas (piece tray, sounds, splash, edge-sort, lifecycle pause); Android lags. iOS/Android are **convergence targets** — each requirement notes the intended cross-platform behaviour, but the deliverable code lives in the web build. The pure `PuzzleEngine` is shared, so engine additions (edge-piece detection, proportional snap) benefit all platforms.

The guiding principle for every decision: **children can't read well, have low frustration tolerance, have small/imprecise fingers, and are motivated by delight, sound, and choice — not timers and numbers.**

## Glossary

- **Game**: The Kaley's Puzzle web application (`web/app.js` + `web/index.html` + `web/style.css`).
- **Engine**: The pure, platform-agnostic game logic in `web/puzzle-engine.js` (`window.PuzzleEngine`).
- **Board**: The rectangular target area where the completed picture forms.
- **Piece**: A single jigsaw piece (has `col`, `row`, `x`, `y`, `correctX`, `correctY`, `placed`, `groupId`, `path`).
- **Group**: A set of pieces snapped together that move as one unit.
- **Camera**: The pan/zoom transform (`{ x, y, zoom }`) applied to the world when rendering.
- **Content_Bounds**: The world-space rectangle enclosing the board plus all loose pieces.
- **Center_Action**: A user action that resets the camera so the entire Content_Bounds is visible and centered ("fit to screen").
- **Edge_Piece**: A piece whose grid position lies on the outer border of the puzzle (`col === 0 || col === cols-1 || row === 0 || row === rows-1`).
- **Snap_Animation**: A short tween that slides a group from its dropped position to its snapped position rather than teleporting.
- **Held_Piece_Lift**: The visual treatment (scale-up + drop shadow) applied to the group currently being dragged.
- **Progress_Indicator**: A literacy-free visual representation of completion (a filling bar / picture), replacing the textual `X / Y` counter as the primary signal.
- **Milestone_Celebration**: A small confetti/sound burst triggered at intermediate completion thresholds (25%, 50%, 75%) and when all Edge_Pieces are placed.
- **Collection**: A persisted set of animals the player has completed at least once, shown to the child as a reward gallery.
- **Tutorial**: A first-run, non-textual animated demonstration (a moving hand) showing how to drag a piece onto the board.
- **Ghost_Hint**: A faint outline drawn at the correct location of the currently held group while it is being dragged.
- **Curated_Image_Set**: A vetted list of known-animal images (no random, non-animal sources).
- **Resume_State**: A serialized snapshot of an in-progress puzzle stored in localStorage so the child can continue after closing the app.
- **Difficulty_Tier**: A child-readable difficulty option (e.g. "Easy/Medium/Hard" with an emoji and a thumbnail), replacing raw piece-count labels as the primary affordance.

## Requirements

### Requirement 1: Visual, literacy-free difficulty selection

**User Story:** As a young child, I want to choose how hard the puzzle is using pictures and simple words, so that I can start a game without being able to read numbers.

#### Acceptance Criteria

1. THE Game SHALL present at least four Difficulty_Tiers including an "Easy" tier of no more than **12 pieces** (a genuinely easy option for young children) in addition to the existing larger tiers.
2. THE Game SHALL label each Difficulty_Tier with a child-readable name and emoji (e.g. "🐣 Easy") and SHALL NOT rely on a raw piece-count number as the only label.
3. WHEN the child selects a Difficulty_Tier, THE Game SHALL start a puzzle with that tier's piece count.
4. THE Game SHALL render Difficulty_Tier buttons with a touch target of at least **64×64 CSS pixels**.
5. THE steering documentation SHALL be updated so the documented difficulty values match the values actually shipped by the Game.

### Requirement 2: Choosing the picture

**User Story:** As a young child, I want to pick which animal I will build, so that I feel ownership and excitement about the puzzle.

#### Acceptance Criteria

1. THE Game SHALL present a selection of animal choices (thumbnails) before a puzzle begins.
2. WHEN the child taps an animal choice, THE Game SHALL use that specific image as the puzzle picture.
3. THE Game SHALL offer a "Surprise me" option that selects a random animal from the Curated_Image_Set.
4. THE Game SHALL render each animal choice with a touch target of at least **64×64 CSS pixels** and a recognizable thumbnail.

### Requirement 3: Safe, curated, animal-only images

**User Story:** As a parent, I want every puzzle picture to be a vetted animal image, so that my child never sees an unexpected or inappropriate picture.

#### Acceptance Criteria

1. THE Game SHALL source puzzle pictures only from the Curated_Image_Set or the built-in procedural animal fallback.
2. THE Game SHALL NOT use random, non-animal-specific image sources (e.g. generic random-photo services).
3. IF a Curated_Image_Set network image fails to load, THEN THE Game SHALL fall back to the procedural animal image for the same chosen animal without showing an error to the child.
4. THE procedural fallback SHALL depict the chosen animal (emoji + name + themed background) rather than an arbitrary one.

### Requirement 4: First-run tutorial

**User Story:** As a first-time young player, I want the game to show me how to play, so that I can succeed without an adult reading instructions to me.

#### Acceptance Criteria

1. WHEN a puzzle starts for the first time on the device (no Tutorial-seen flag in localStorage), THE Game SHALL display a non-textual animated Tutorial demonstrating dragging a piece onto the Board.
2. WHILE the Tutorial is visible, THE Game SHALL visually emphasize (e.g. pulse) one loose Piece to invite the first interaction.
3. WHEN the child drags any Piece OR taps to dismiss, THE Game SHALL end the Tutorial and SHALL persist a Tutorial-seen flag so it does not show automatically again.
4. THE Game SHALL provide a way to replay the Tutorial from the start screen.

### Requirement 5: Constrained, recoverable camera with a Center action

**User Story:** As a young child, I want to never get lost on an empty screen, so that I can always see my puzzle and pieces.

#### Acceptance Criteria

1. THE Game SHALL ensure that, at the start of a puzzle, the entire Board and all loose Pieces are within the visible viewport (pieces scattered within view, not off-screen).
2. THE Game SHALL constrain panning so that the Camera cannot move the Content_Bounds entirely out of view.
3. THE Game SHALL provide a persistently visible Center_Action control with a touch target of at least **56×56 CSS pixels**.
4. WHEN the child activates the Center_Action, THE Game SHALL animate the Camera so the entire Content_Bounds is visible and centered.
5. WHEN the viewport is resized or the device is rotated mid-game, THE Game SHALL keep the Board and Pieces within view (re-fit if necessary).
6. THE Game SHALL clamp zoom to a range that keeps pieces grabbable and prevents zooming into an empty void.

### Requirement 6: Forgiving snapping for small hands

**User Story:** As a young child with imprecise fingers, I want pieces to snap into place easily, so that I don't get frustrated trying to line them up perfectly.

#### Acceptance Criteria

1. THE Engine SHALL accept a configurable snap distance and THE Game SHALL pass a snap distance proportional to the current Piece size (not a fixed 35 world-pixels).
2. THE effective on-screen catch radius SHALL NOT shrink below a usable minimum when the puzzle is zoomed out.
3. WHEN a dragged Piece or Group is released within the snap distance of its correct position or a matching neighbor, THE Game SHALL snap it, exactly as the current Engine contract specifies.

### Requirement 7: Satisfying snap feel (animation, lift, sound, haptics)

**User Story:** As a young child, I want placing a piece to look and feel rewarding, so that I want to keep playing.

#### Acceptance Criteria

1. WHEN the child picks up a Group, THE Game SHALL apply a Held_Piece_Lift (scale-up and/or drop shadow) so the selected Group is visually distinct.
2. WHEN a Group snaps into place, THE Game SHALL play a Snap_Animation that slides the Group to its target position rather than teleporting instantly.
3. WHEN a Group snaps into place, THE Game SHALL play a short positive sound effect and (on supporting devices) a brief haptic vibration.
4. THE Game SHALL provide a mute control, and THE Game SHALL persist the muted/unmuted preference in localStorage.
5. THE sound effects SHALL be generated without requiring external audio asset files (e.g. via the Web Audio API) to preserve the no-build-step, offline-capable nature of the web build.

### Requirement 8: Milestone celebrations and a collection reward

**User Story:** As a young child, I want frequent little celebrations and a collection of animals I've finished, so that I stay engaged and feel a sense of progress beyond a single puzzle.

#### Acceptance Criteria

1. WHEN cumulative placement first crosses 25%, 50%, and 75% completion, THE Game SHALL trigger a Milestone_Celebration (small confetti burst + sound).
2. WHEN all Edge_Pieces become placed, THE Game SHALL trigger a Milestone_Celebration distinct from percentage milestones.
3. WHEN a puzzle is completed, THE Game SHALL add the completed animal to the persisted Collection.
4. THE Game SHALL display the Collection to the child (e.g. on the start screen) as a gallery of earned animals.
5. Each Milestone_Celebration SHALL trigger at most once per puzzle instance.

### Requirement 9: Literacy-free progress, optional timer

**User Story:** As a young child, I want to see how much of the puzzle is done with a picture, and not be pressured by a clock, so that the game feels relaxed and understandable.

#### Acceptance Criteria

1. THE Game SHALL display a Progress_Indicator that conveys completion without requiring reading (e.g. a filling bar).
2. THE Game SHALL hide the elapsed-time Timer by default.
3. THE Game SHALL provide a setting to re-enable the Timer, and SHALL persist that setting in localStorage.
4. THE Progress_Indicator SHALL update whenever the placed-piece count changes.

### Requirement 10: Edge-pieces helper

**User Story:** As a young child, I want help finding the border pieces, so that I can use the common "do the edges first" strategy.

#### Acceptance Criteria

1. THE Engine SHALL expose a pure function that determines whether a given piece is an Edge_Piece.
2. THE Game SHALL provide a toggle that visually highlights all unplaced Edge_Pieces.
3. WHEN the highlight toggle is active, THE Game SHALL distinguish unplaced Edge_Pieces from interior pieces (e.g. a colored outline or glow).
4. WHEN the highlight toggle is inactive, THE Game SHALL render pieces without the edge highlight.

### Requirement 11: Per-piece ghost hint

**User Story:** As a young child who is stuck, I want a gentle hint showing where my piece goes, so that I can keep making progress without an adult solving it for me.

#### Acceptance Criteria

1. WHILE a Group is being dragged AND the hint feature is enabled, THE Game SHALL draw a Ghost_Hint outline at the correct destination of the held Group.
2. THE Ghost_Hint SHALL be visually subtle (faint outline) so it guides without dominating the picture.
3. WHEN no Group is being dragged, THE Game SHALL NOT draw any Ghost_Hint.
4. THE existing full-image Hint overlay SHALL remain available and independently toggleable.

### Requirement 12: Safe "New puzzle" with confirmation, and fast replay

**User Story:** As a young child (and the parent watching), I want to not lose my puzzle by an accidental tap, and to easily start again when I win, so that progress isn't destroyed and replaying is effortless.

#### Acceptance Criteria

1. WHEN the child activates the "New puzzle" control mid-game, THE Game SHALL require a confirmation before discarding the current puzzle.
2. WHEN the confirmation is dismissed/cancelled, THE Game SHALL keep the current puzzle exactly as it was.
3. WHEN a puzzle is completed, THE Game SHALL offer a one-tap "Play again" that starts a new puzzle and a separate "Choose another" that returns to picture/difficulty selection.
4. The "Play again" action SHALL reuse the just-played Difficulty_Tier.

### Requirement 13: Bigger, clearer touch targets and a playful start screen

**User Story:** As a young child, I want big, friendly buttons and an inviting start screen, so that the game is easy to operate and fun to look at.

#### Acceptance Criteria

1. THE Game SHALL render all primary interactive controls (difficulty, animal choices, in-game toolbar buttons, win-screen buttons) with a minimum touch target of **56×56 CSS pixels** (64×64 for start-screen choices per Requirements 1 and 2).
2. THE in-game toolbar controls SHALL be spaced so adjacent targets do not overlap and are individually tappable by a small finger.
3. THE start screen SHALL use a child-friendly, visually inviting presentation (color, imagery) rather than dense grey text on a near-black background.
4. THE Game SHALL keep the personalized "Made with love by your PAPA" sentiment present on the start screen.

### Requirement 14: Resume an in-progress puzzle

**User Story:** As a young child who gets interrupted, I want to come back to my puzzle where I left off, so that I don't have to start over and get upset.

#### Acceptance Criteria

1. WHILE a puzzle is in progress, THE Game SHALL persist a Resume_State (chosen image identity, difficulty, piece positions, group membership, placed flags, elapsed time) to localStorage.
2. WHEN the Game launches and a valid Resume_State exists, THE Game SHALL offer the child a way to continue the saved puzzle.
3. WHEN the child chooses to continue, THE Game SHALL restore the puzzle to the saved state (piece positions, groups, placed pieces, progress).
4. WHEN a puzzle is completed OR the child explicitly starts a new puzzle, THE Game SHALL clear the Resume_State.
5. IF the Resume_State is missing or corrupt, THEN THE Game SHALL ignore it and present the normal start screen without error.

### Requirement 15: Battery-conscious on-demand rendering

**User Story:** As a tablet user (and parent watching battery), I want the game to not burn power when nothing is moving, so that play sessions last longer.

#### Acceptance Criteria

1. THE Game SHALL render frames on demand — when the view is dirty (input, animation, or state change) — rather than running an unconditional continuous render loop while idle.
2. WHILE an animation is active (Snap_Animation, Milestone_Celebration, Tutorial, Camera transition, dragging), THE Game SHALL continue requesting frames until the animation completes.
3. WHEN no animation is active and no input is occurring, THE Game SHALL stop scheduling new frames.
4. The on-demand rendering change SHALL NOT alter the visible behaviour of dragging, snapping, or celebrations.

### Requirement 16: Preserve correctness and tests

**User Story:** As a maintainer, I want the existing engine guarantees to remain valid, so that the overhaul does not regress core puzzle logic.

#### Acceptance Criteria

1. THE existing Engine unit tests SHALL continue to pass unchanged in intent (grid computation, coordinate transforms, snap detection, group merge, neighbor lookup, edge generation).
2. THE new Engine function for Edge_Piece detection SHALL be covered by unit tests.
3. THE Engine SHALL remain free of DOM, Canvas, and platform dependencies (pure logic, runnable under `node --test`).
4. THE web build SHALL remain a no-build-step, directly-openable application (`open web/index.html`).
