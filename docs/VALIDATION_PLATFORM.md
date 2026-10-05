# Platform edition validation

Godot 4.5.2 Standard, Windows x64, compatibility renderer. All automated runs use isolated workspace saves rather than player data.

- Core regression suite: 69 assertions covering SDK, navigation ownership, six games, persistence, cache bounds, publication and corrupt-save recovery.
- Native UI suite: 56 assertions covering real touch/mouse routing, immersive layout, creator controls, page/modal flows, drafts and persistence.
- Platform suite: 49 assertions covering exact XP/quest awards and idempotence, calendar rollover, tutorials, paused/game-over accounting, links, interpolated lanes, jump/slide/shield/magnet/tram collision, instant replay, 3D pause/resume, snapshot serialization, independent feed sorting, disabled/rated content, six compatibility reports, oversized/unsupported/unregistered rejection, collections, all new sheets, stable A/B assignment and unavailable service behavior.
- Separate-process persistence test: writes a save, starts another process and checks navigation, library, score and runner snapshot.
- Actual GPU screenshots: all six games, immersive interaction, Discover, Settings and Quests. These are rendered by the app, not design mockups.

Desktop runner benchmark: 300 measured frames after 60 warm-up frames, 480×856 gameplay rendered at up to 1080 pixels tall, 60 FPS cap, NVIDIA GeForce RTX 5070, OpenGL compatibility. Mean frame interval 16.679 ms, p95 16.708 ms, 489 draw calls at the sampled frame. Static geometry batching reduced the earlier sampled 1,973 calls. Invulnerability was enabled to keep the benchmark running. This checks one short desktop scene, not mobile certification, production thermal behavior, worst-case complexity or minimum hardware.

The local publication audit checks source/scene plus declared package budget, metadata, input profile, lifecycle, JSON round-trip equivalence, 120 ticks of CPU timing, tracked allocations and save size. Numeric JSON comparisons tolerate int/float conversion and floating-point roundoff. Failed checks keep a listing unpublished. Only the bundled scene allowlist is executable.

Test commands from the project directory:

```text
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/ui_flow.gd
godot --headless --path . --script res://tests/platform_tests.gd
godot --headless --path . --script res://tests/audit.gd
godot --path . --script res://tests/capture.gd
godot --path . --script res://tests/render_benchmark.gd
```

Set `LOOP_SAVE_PATH` to a fresh writable test file before UI/platform runs. Tests must not point at a player's real save. Capture/benchmark need a graphics device; headless results do not measure GPU performance.

Known test-environment diagnostics: the Windows sandbox denies reading the system certificate store, and some short process exits report ObjectDB references. No network functions are used. Neither diagnostic is presented as proof of memory-leak freedom; long-session device profiling remains required. Protocol registration scripts are delivered for opt-in use and have not been executed against the user's registry. Web preview pages are local static files, not deployed URLs.
