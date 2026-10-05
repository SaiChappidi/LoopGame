# Validation — October 2, 2026 · Immersive edition

Engine: Godot 4.5.2 Standard, Windows x86_64. Gameplay rendered with the OpenGL compatibility renderer. Tests use isolated save files in a writable workspace.

## Automated results

- **69 core/SDK checks passed.** Catalog validation, unsupported versions, six scene implementations, state round trips, pause/resume, game mechanics, cache eviction, local publication/unpublication, corruption recovery, and all eight requested navigation scenarios.
- **56 app/UI checks passed in the immersive edition.** Touch events injected through Godot's viewport input pipeline, real social and navigation button callbacks, Library reopening, Discover search, score saving, right-side zone navigation, button-only and combined modes, safe areas on all four edges, page/modal construction, local versioned draft creation, and persistence. New checks verify at least 94% default gameplay coverage, absence of the feed tab bar, actual overlay mouse clicks, no duplicate gameplay from touch-emulated mouse events, and removing/restoring metadata hit regions when fading.
- **Separate-process restart check passed.** Process 1 wrote navigation settings, a saved game, a high score, and runner progress; process 2 instantiated a new application and restored all of them.
- **Packed-runtime smoke test passed.** The exported PCK launched with the bundled official Windows engine and ran for 360 frames. The five-second checkpoint contained live stack gameplay state, score, elapsed playtime, and lifecycle events.
- Actual rendered captures were generated for all six games, Discover, and Settings. The main feed, Discover, and Settings were visually inspected; the bottom-control overlap found on the initial feed was corrected and asserted in the UI suite.

## The eight navigation scenarios

1. Stack game → upward bottom-zone swipe → runner.
2. Runner → upward gameplay swipe → jump, unchanged feed index.
3. Runner → upward zone swipe → crowd game, no jump dispatched.
4. Downward zone swipe → previous game, preserved runner distance and active resume.
5. Move zone to Right → safe area moves and right-side vertical swipe navigates.
6. Buttons mode → no zone → Next and Previous work.
7. Combined mode → both methods work and both controls are present.
8. Persist/reload navigation mode, position, thickness, and opacity.

Additional checks cover short-swipe cancellation, gesture-origin ownership across zone boundaries, and bounded loaded-game count. The UI tests assert that rebuilding social controls cannot progressively shrink the game safe area.

## Limits of this validation

These are programmatic desktop checks, not a claim of manual physical-device playtesting. Multi-hour memory/battery profiling, app suspension by mobile OSes, safe-area behavior on actual notched devices, real haptics, iOS/Android exports, store signing, accessibility audits, and 60 FPS on individual phone models remain unverified.

The restricted test host could not create Godot's default AppData ancestor directory and could not read its system certificate store. Test saves/logs were therefore routed into the writable workspace. Save persistence was exercised through the same FileAccess/rename repository code. No game network feature depends on certificates. Some SceneTree test harness exits reported retained ObjectDB references; the packed main-scene smoke run and graphical capture runs did not report that warning. This is not a completed long-session leak audit.

The distributed Windows launcher uses its adjacent `data` folder for game saves and logs. It contains no test profile or pre-populated personal progress.
