# LOOP visual pass — verification

Date: October 3, 2026. Source: outputs/Loop. Playable package: outputs/Loop-Visual-Edition.

## What changed

- Stack Studio: gallery architecture, limestone terrace, material edge detailing, soft contact shadows, placement settling and bounded falling offcuts.
- Skyline Sprint: night-market shopfronts, striped awnings, lanterns, planters, benches, balconies, restrained overhead signage, courier and tram details. Existing 3D simulation retained.
- Small World: miniature garden plaza, paths, planted borders, tiny shops, original SVG citizens, team colors, leader flag and recruitment response.
- Coastline: a projected coastal road, ocean atmosphere, silhouettes, palms, posts and detailed touring cars. The projection is identity in horizontal position at the player's collision line; routed pointer tests verify alignment.
- Chromatic: instrument-like enclosure, precise rails and markings, sculpted moving gates, redundant color/shape symbols, cycle and match feedback.
- Soft Numbers: a ceramic board in a wood-colored tray, inset cells, designed typography, 140 ms tile travel and short merge response. Input updates logical state immediately, including during animation.
- Cell Odyssey / creator arena: cell membranes, organelles, suspended background organisms, readable nutrient/time/size HUD and offscreen entity culling. Creator configuration and saved schema retained. This is a creator runtime; the built-in catalog still contains six games.
- Shared: high-contrast compact HUD plaques, per-game results headings, actual-gameplay thumbnails, tutorial and pause previews, immediate reduced-motion propagation to cached games.

## Validation results

- run_tests.gd: 68 checks, zero failures.
- ui_flow.gd: 57 checks, zero failures. Includes injected touch navigation, gesture ownership, UI click isolation, all navigation-zone positions, switching, menu flows and persistence.
- platform_tests.gd: 49 checks, zero failures. Includes tutorial lifecycle, runner hazards, shield and magnet rules, JSON restore and compatibility checks.
- content_delivery.gd: 4 checks, zero failures. Requires access to Godot's user cache outside the sandbox.
- creator_arena_flow.gd: passed custom configuration validation, movement, save/load, pause/resume and restart.
- visual_contract.gd: 28 checks across seven runtimes; pause freezes state and rejects input, reduced motion freezes the decorative clock, original JSON schema restores exactly, restart reactivates play.
- visual_input.gd: 21 checks. Godot-injected mouse/keyboard events go through the application input router for all seven runtimes; Escape pauses/resumes each. Coastline pointer-to-road alignment and immediate merge results verified.
- session_roundtrip.gd: seven saved sessions restored in a separate Godot process.
- Exported Windows PCK: generated successfully and independently launched with the bundled runtime; its tutorial and gameplay preview rendered in the smoke capture.

Tests used isolated saves. The portable edition starts with a copy of the existing Loop-Platform save; the original file is retained. The shareable ZIP excludes personal save data.

## Visual review

[Open the comparison gallery](index.html). Before/after gameplay was captured using the preserved original gameplay scripts and SDK, seed 812, and identical scripted actions. Detail captures use explicit representative fixtures for hazard readability and developed boards. They are rendered game scenes, not concept images.

Every runtime has active, detail, tutorial, pause and results captures at 480 × 900 and a 1280 × 800 desktop window. The existing portrait aspect ratio is retained: desktop viewport captures are 426 × 800, excluding outer letterbox margins. Game rules and control transforms were not widened or stretched.

Reviewed hazard fixtures show the runner's low barrier, overhead gate and tram, racing traffic/boost, rival crowds and arena cells. Scenery uses draw-only elements and does not own input. Foreground actors remain visually separated from backgrounds.

## Performance configuration and scope

Windows build 26200; CPU reported as AMD64 Family 26 Model 68 Stepping 0, 12 logical processors. GPU: NVIDIA GeForce RTX 5070, driver 610.74. Godot 4.5.2 stable, OpenGL Compatibility, 480 × 900 window, 60 FPS cap; runner retains 2× MSAA in its resolution-capped SubViewport.

60 warmup frames and 120 measured frames per game. Means were 16.675–16.677 ms; p95 ranged 16.710–16.845 ms. This short, capped sample is consistent with 60 FPS on this machine. It does not establish sustained worst-case or mobile performance. Raw per-game values and draw calls are in [performance.json](performance.json).

Small World maximum sampled draw calls fell from 594 to 139 after replacing per-character primitives with original SVG sprites. Cell Odyssey fell from 360 to 172 after offscreen culling. Skyline sampled 644 draw calls and remains the most expensive scene. Static skyline meshes are batched by material, scenery is recycled, and placement debris is bounded to two pieces. Style boxes are cached.

## Remaining limitations

- Native manual play is unverified. The Windows capture tool selected the LOOP window but returned an unrelated application's image, including after refresh. Native input was stopped; the review used Godot-rendered screenshots and injected input events.
- No physical phone/tablet touch, safe-area or mobile GPU testing. Synthetic input tests cover routing and layout logic only.
- Several test and auto-quit paths emit Godot ObjectDB cleanup warnings. Sandboxed headless runs also report certificate-store access errors. These are recorded in logs; offline game assertions and rendered export smoke passed.
- The existing arena gameplay can leave sparse spaces because pellet distribution is unchanged. Existing 3D runner geometry remains stylized and procedural.
- This is a substantial visual pass across all runtimes, not certification that the collection meets a premium commercial release or AAA art benchmark. Human art review, hands-on device QA and sustained performance profiling remain release gates.

## Reproduction

Run the existing Godot 4.5.2 executable with --path pointing at outputs/Loop and --script res://tests/visual_review.gd -- --phase=after for captures. Use --resolution 1280x800 for the desktop window. Run tests/visual_contract.gd with a display/GPU for timing; tests/visual_input.gd and tests/session_roundtrip.gd support headless execution. Run session_roundtrip first with -- --seed, then without it in a fresh process.

Asset provenance: [ASSET_CREDITS.md](../ASSET_CREDITS.md). No paid or downloaded artwork.

## October 9 rhythm-game update

Pulse Run, Cloudroll and Keylight were added after the visual captures and automated results above. The old counts and screenshots in this report describe the earlier seven-game build. The new games have registered scenes, portrait covers, touch/keyboard controls, pause/resume-safe original soundtracks, and input checks in the test sources. The current workspace's bundled Godot executable exits with a native signal-11 crash when running `--script` tests, so these three games still need an interactive Godot run and fresh portrait/desktop capture before visual/runtime verification can be claimed.
