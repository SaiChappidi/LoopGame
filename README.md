# LOOP — One more game

## Latest update: original rhythm games

Pulse Run, Cloudroll and Keylight add three new rhythm-driven games with bespoke gameplay, artwork and original synthesized soundtracks. All three have touch and desktop controls, resume-safe music, and a Game music setting.

## Earlier update: focused feed and Cell Garden

Only the current game runs; only current/previous/next are loaded. Resume is limited to the game just left. Small World is replaced by Cell Garden, a CPU cell-eating arena. Swipe right from the left edge for game details and local comments, or use Game info / I on desktop. See docs/FEED_AND_COMMENTS.md for behavior and verification.

Creator Studio's Arena Workshop now lets developers tune a playable arena's world, player, rivals, nutrients, goals and palette. It can package an optional credited/licensed PNG or WebP backdrop and render it in gameplay. The local publishing and identity limits still apply.


## Visual edition · October 2026

The updated source is this project. Run ../Loop-Visual-Edition/Play LOOP.cmd for the packaged Windows build. See art_review/index.html for matched gameplay comparisons, art_review/VERIFICATION.md for checks and limits, and ASSET_CREDITS.md for artwork provenance. All ten catalog games and the creator arena runtime are included.


A native, local-first mini-game platform built with **Godot 4.5.2 Standard (GDScript)**. Nine original 2D games and Skyline Sprint, a procedural 3D runner, share a modular SDK, bounded feed cache, independent gesture routing and persistent sessions. Three rhythm games include original synthesized soundtracks generated from the included source script. Lantern Trail's three hand-painted storybook backgrounds were generated for LOOP; the remaining game visuals are drawn in the project. No paid assets, account or backend are needed.

## Run

**Test the current source:** open this folder's `project.godot` in Godot 4.5.2 and press **F5**. The sibling packaged Windows builds are older exports and need to be re-exported to include these new games and soundtracks. Saves and logs appear in `data`. The bundled official Godot executable is a development runtime, not a size-optimized mobile release.

## Platform edition · 0.3

Menu now includes daily/weekly quests, account XP/levels/streaks, collections, Continue Playing, Surprise Me and separate For You/Trending/New feeds. First-play tutorials pause gameplay. Creator Studio includes local analytics, tutorial A/B assignment and compatibility checks. Settings provides content ratings and local availability controls. Deep links and static preview pages are included. See `docs/PLATFORM_FEATURES.md` for working features and service boundaries, and `docs/MINIGAME_SPEC.md` for the strict mini-game technical contract.

## Immersive edition · 0.2

The game now fills the screen edge to edge, with only the dedicated navigation strip reserved by default. The permanent feed header, description card, social toolbar, and bottom tab bar have been removed from gameplay. A small menu in the upper-right opens Discover, Library, Profile, refresh, and settings. The title and creator link appear near the lower edge; `···` opens like/save/share. These lower controls fade completely and relinquish their touch regions while playing, returning after three seconds without interaction. The menu stays accessible.

Worlds now have atmospheric lighting, fine grain, softer shadows, and consistent typography. The game canvas scales uniformly instead of stretching its geometry to fit a tall phone. Touches use the exact inverse of that visual transform. Native touch UI uses Godot's mouse emulation, which is explicitly excluded from gameplay input to prevent duplicate actions.

To preserve progress, close both builds and copy the older `data/loop-v1.json` into the new `Loop-Platform/data` folder before launching. Do not overwrite a newer save. Legacy 2D runner gameplay resets on upgrade.

**Source project:** download [Godot 4.5.2 Standard](https://godotengine.org/download/archive/4.5.2-stable/), import `project.godot`, and press **F6** with `app/main.tscn` open, or **F5** to run the main project. Godot 4.5.2 is the tested version. Do not use Godot 3.

Command line from this project directory:

```text
godot --editor --path .
godot --path .
```

On a phone, use a matching Godot Android/iOS export template and the relevant platform SDK/signing setup. The source uses portrait layout, touch events, compatibility rendering, safe-area insets, and a 60 FPS cap. **Android/iOS binaries, store signing, device profiling, and device certification are not included or verified.**

## Play

- **Stack Studio:** tap or Space to place a block. Overlap keeps the tower alive; perfect placement preserves its width.
- **Skyline Sprint:** a 3D night-market runner. Swipe left/right for lanes, up to vault barriers, down to slide under gates. Dodge trams, collect coins, magnets and shields. Desktop arrows also work.
- **Cell Garden:** drag or use arrows to steer your cell, collect nutrients, grow, and avoid larger CPU rivals.
- **Coastline:** drag to steer, or use left/right. Collect gold B boosts for speed and temporary collision protection.
- **Soft Numbers:** swipe or use arrows to merge identical tiles. A tile merges only once per move.
- **Prism Stack:** rotate, hold and place falling shapes. Swipe to move/drop or use the keyboard.
- **Lantern Trail:** hold the left/right arrows to walk; release to stop. Jump with ↑ or the right touch control across three chapters.

At game over, tap to restart. Pausing and leaving preserve the session. A short first-play tutorial pauses a new game until dismissed; subsequent visits resume directly.

## Feed navigation

The default is **Swipe Zone**, a black strip below gameplay. Start a swipe inside it: upward goes next, downward goes previous. A touch that starts in the game remains game-owned even if it crosses the zone. A touch that starts in the zone never reaches the game.

Open the menu button at the upper right to configure:

- **Navigation method:** Swipe Zone, Buttons, or Swipe Zone + Buttons.
- **Position:** Bottom, Top, Left, or Right. All positions use vertical swipes.
- Thickness, edge padding, opacity, indicator visibility, sensitivity, minimum distance, and minimum velocity.
- Button size and left/right placement.

Choose **Buttons** to completely remove the zone and show compact previous/next arrows in the upper edge. Combined mode offers both. Only the actual button rectangles reserve input; the score HUD moves away from left-side buttons. Page Up/Page Down navigate the feed on desktop. Arrow keys remain gameplay controls.

The strip shows direction and threshold progress, and short swipes cancel. Transitions fade gently, respect reduced motion, and optionally trigger haptics. At either boundary the feed stays put. The top refresh button builds a new recommendation mix.

## What's implemented

- Ten genuinely playable games, each in its own registered scene and script.
- Common SDK lifecycle, per-game input profiles, safe gameplay rectangle, score/event reporting, restart and JSON snapshots.
- Current + previous + next + one additional upcoming game cache, threaded adjacent resource preload, eviction, five-second checkpoints, background pause, and restoration on revisit.
- Persistent navigation preferences, settings, likes, favorites, follows, recent games, profile, achievements, scores, and sessions.
- For You, searchable/category-filtered Discover, Library collections, editable local Profile, game details, maker profiles, local sharing identifiers, and local/demo leaderboards.
- Local weighted recommendations with exploration and recent-game suppression; no duplicates within a feed.
- Analytics repository, bounded event history, high-score tracking, and local creator statistics.
- **Creator Studio:** editable drafts, bundled package selection, previews, local publication into Discover/For You, private/unlisted states, version snapshots, unpublishing, and listing rollback.
- Report submission, a local review queue, and resolving reports.
- Device-local privacy/data export, clear-game-session confirmation, diagnostics, reduced motion, UI sound and haptic toggles.
- Explicit service contracts for future authentication, notifications, challenges, ads, purchases, event synchronization, verification, and revenue accounts. Unconnected services return unavailable results rather than pretending to succeed.

## Honest scope

This is a working **native MVP**, not a production user-generated-content service. All ten catalog entries launch as playable games; Skyline Sprint uses the existing 3D engine, and the other games are 2D. Pulse Run, Cloudroll and Keylight have original local soundtracks that can be toggled in Comfort & Sound. There is no online multiplayer. There are no fake extra games.

Community engagement numbers and leaderboard opponents are clearly labeled seed/demo data. Profiles, follows, publication, reports, and analytics remain on the current device. `loop://game/<id>` links are copyable identifiers; operating-system deep-link registration and a public share-link resolver are future integrations.

Creator Studio publishes local remixes of trusted bundled game packages. Importing arbitrary executable packages, public upload/storage, moderation enforcement, remote identity, payments, ads, push notifications, friends, live multiplayer, and real revenue processing are not implemented. The service contracts intentionally expose this distinction.

Godot GDScript is **not a security sandbox**. Bundled scenes follow a communication contract, but a malicious script could still access the application tree. Do not distribute an arbitrary-code upload feature using this implementation. A public UGC edition needs a constrained declarative format, validated sandbox/runtime boundary, signed packages, moderation, and platform-policy review. Metadata and load failures have recovery controls; engine crashes or arbitrary GDScript runtime faults cannot be caught like isolated processes.

The target is smooth 60 FPS gameplay. Automated desktop tests and actual OpenGL rendering were performed; battery usage, memory behavior over hours, touch latency, 60 FPS on specific phones, notches, haptic hardware, and mobile lifecycle behavior still need device testing. The included cache bounds the number of active scene objects, not all of Godot's internal resource caching. The tiny procedural games use bounded entity lists rather than a generalized pool.

## Project structure

```text
app/                 Native shell, visual tokens, procedural covers
core/navigation.gd   Pointer-origin ownership and swipe thresholds
core/feed.gd         Lifecycle, active game, cache, resource preload
core/repository.gd   Replaceable platform repository contract
core/store.gd        JSON persistence, catalog, recommendations, analytics
core/service_contracts.gd  Explicit future service seams
sdk/mini_game.gd     Game lifecycle, snapshots, events, logical drawing helpers
sdk/template.gd      Copyable minimal game implementation
games/               Ten independent Control scenes and game scripts
data/games.json      Catalog metadata, input profiles, package references
assets/              Original LOOP icon
tests/               Navigation, mechanics, UI flow, restart, rendering checks
docs/                Architecture and SDK guide
```

UI composition is native Godot Controls. Art is procedural CanvasItem drawing, so the source has almost no asset download overhead. Only the active game processes frames; inactive scenes stop their update loops. The SDK uses a 400 × 480 logical canvas mapped into the usable rectangle, independent of the shell's 480 × 900 portrait reference.

## State and repositories

The default save is `user://loop-v1.json`. Godot resolves this to its per-application user-data directory. The Windows launcher instead sets `LOOP_SAVE_PATH` to its adjacent `data/loop-v1.json`, making that package portable. Tests can override the same variable without touching real progress.

Writes use a temporary file and rename. Unreadable JSON is retained as `.corrupt` and defaults are restored. The SDK checks required snapshot fields and their basic types before loading; this is integrity protection, not hostile-data validation. A future schema migration should preserve the versioned `schema` field. Session data is written every five seconds, on game changes, on app suspension, and on normal close. A force-kill can lose the last checkpoint interval.

`PlatformRepository` is the local-facing contract. `LocalStore` is its working implementation. A server adapter should hydrate local state, enqueue write commands, and synchronize asynchronously; it must not block gameplay on HTTP responses. Do not put backend credentials inside games. See [architecture](docs/ARCHITECTURE.md).

## Add a game

1. Copy `sdk/template.gd` to `games/my_game.gd`.
2. Create a Control scene at `games/my_game.tscn` and attach that script.
3. Implement `reset_state`, `tick`, `handle_action`, and `_draw`. Keep snapshots JSON-safe.
4. Add an entry in `data/games.json` with a unique ID, complete metadata, truthful input profile, and the scene path.
5. Import/run. The feed discovers the catalog entry automatically; no switch statement in the shell needs editing.

See the [SDK guide](docs/GAME_SDK.md) for the full lifecycle, allowed event names, input ownership, safe-area behavior, and template.

## Tests

Run from a writable project checkout using Godot 4.5.2. The core tests use and remove `tests/test-state.json`; never point tests at a read-only exported pack.

```text
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/ui_flow.gd
godot --headless --path . --script res://tests/persistence_process.gd -- --seed
godot --headless --path . --script res://tests/persistence_process.gd
```

Set `LOOP_SAVE_PATH` to a disposable test file before UI/restart tests: those tests intentionally exercise and change data. Headless tests inject touch events through the viewport input pipeline. The UI test uses real button callbacks and verifies layout bounds, but it is not a substitute for human playtesting on iOS/Android. `tests/capture.gd` captures actual rendered screens when run with a graphical renderer and an existing adjacent `screenshots` directory.

See [validation notes](docs/VALIDATION.md) for the completed checks and remaining platform validation.

The client includes a content-addressed HTTPS fetch/cache foundation with integrity verification and LRU eviction. It is not connected to a deployed catalog/CDN. Arena Studio is the first creator runtime: it runs a fresh data-authored solo cell arena with no per-game script downloads. See `docs/ROBLOX_STYLE_RUNTIME.md` for the delivery, backend, and rollout architecture needed for a one-install, tap-to-play creator platform.
