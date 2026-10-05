# LOOP mini-game technical specification — 1.1

This is the submission contract for LOOP's local publishing lab. The desktop build accepts `.zip`/`.loopgame` packages containing JSON declarations and optional PNG/WebP assets. They are checked and versioned by the Airlock, but uploaded code is never run: playable content is mapped to one of six reviewed built-in Godot scenes. `data/technical_spec.json` is the machine-readable budget file used by the local compatibility checker. This is not a remote production service or an arbitrary-code sandbox.

## Package and asset budgets

- Maximum complete game package: **15 MiB**, including every author asset and dependency. Shared engine/platform assets are excluded only when already installed.
- Maximum initial download: **2 MiB**. Essential playable content must fit here; later downloads must never block navigation or interrupt a run.
- Immutable manifest fields: game ID, version, SDK version, scene/entry point, title, description, developer ID, categories, input flags, author-declared content rating, publication/update dates, expected session seconds, full package bytes, initial bytes, save schema, asset/license inventory, and content hash in a production submission.
- Built-in package declarations reserve 128 KiB each for procedural code and scenes; source size is measured as a lower bound. A production uploader must calculate actual compressed and expanded asset/dependency sizes. Author claims cannot substitute for server measurements.
- Reject path traversal, symlinks outside the package, native extensions, executables, undeclared dependencies and unsigned package replacements in the production ingestion boundary.

## Rendering and performance

- Portrait only: 9:16, 9:19.5, 9:20 and 3:4. The platform supplies the actual safe rectangle; no hard-coded full-device input bounds.
- Target **60 FPS** on the supported-device matrix. Per-game simulation p95 ≤ **4 ms**; cold CPU initialization ≤ **1,000 ms**; warm transition target ≤ **150 ms**; peak incremental game memory ≤ **96 MiB**; snapshot ≤ **64 KiB** UTF-8 JSON.
- These are per-game budgets, not a promise that the entire development runtime fits in 96 MiB. Shared engine, platform, driver and OS allocations are separate. Mobile testing must also account for GPU textures, render targets and peak memory rather than only tracked CPU allocations.
- Stop simulation, audio and render-target updates when paused, hidden or backgrounded. Do not run timers outside platform lifecycle control. Release scene resources on eviction. Reduced-motion settings must disable optional camera motion and particles.
- The local checker exercises 120 simulation ticks, records p95 CPU time, CPU initialization, tracked allocation delta and save size. It tests pause/resume and JSON round trips. It does **not** certify GPU frame rate, warm-load latency, peak resident memory, long-session leaks, OS-native crashes or device compatibility.
- Before public publication, run isolated replay tests on low/mid/high supported mobile devices at every aspect ratio, include thermal and memory-pressure runs, airplane mode, background/restore, interrupted download and repeated navigation. Require measured results, not just manifest promises.

## Lifecycle contract

Implement `initialize_game(metadata)`, `start_game()`, `pause_game()`, `resume_game()`, `restart_game()`, `end_game(completed=false)`, `save_state()`, `load_state(snapshot)`, `destroy_game()`, `get_score()`, `get_game_metadata()`, `get_input_profile()` and `report_event(name,payload)`. Extend `MiniGame` in this trusted Godot edition.

Initialization must not start a run or consume user input. Start begins a fresh attempt. Resume preserves a saved attempt. Pause is repeatable and stops processing. Restart clears the attempt but never account XP or platform settings. End marks game-over/completion and reports the final score once. Destroy relinquishes every owned resource. Errors must not navigate the feed or close the application.

The feed owns instances, prefetch, save/checkpoint, eviction and visibility. Mini-games must not manipulate the scene root or platform chrome. The platform owns universal pause, settings, exit, replay, first-play tutorial, links and creator navigation.

## Input

Declare every supported flag. v1 supports tap, hold, drag, four directional swipes and keyboard alternatives. Tilt, multi-touch and virtual joystick controls are not accepted by the current specification.

Pointer ownership locks at gesture start. A gesture beginning in the navigation strip remains platform-owned. A gesture beginning in the gameplay rectangle remains game-owned even if it crosses the strip. UI controls own only their visible hit regions; hidden creator controls release them. Games receive local normalized coordinates and actions through `receive_input`, never by reading global input independently. Desktop arrows mirror runner swipes; space/tap replays after a loss. Esc pauses consistently.

## State and APIs

All persistent gameplay is JSON-compatible: dictionaries with string keys, finite numbers, strings, booleans, arrays and null. No objects, resource handles, file paths to external files, credentials or personal data. Authors must validate nested structures and supply migration/reset behavior for incompatible versions. Skyline Sprint resets legacy 2D-runner snapshots while preserving account data.

Permitted capabilities are own-scene rendering, platform-routed input, deterministic/random simulation, bounded state and SDK event reporting. Storage, network, clipboard, account identity, purchases, ads and links belong to platform adapters. Games must not access filesystem, process launch, native extensions, device permissions, arbitrary network or another game's state.

The local source-token lint flags several forbidden APIs. **Lint is not a security boundary** and can be bypassed by arbitrary code. Public GDScript uploads remain disabled. A public platform needs an isolated process/container/device test runner and a restricted execution runtime or capability-based declarative game format. Do not run an unknown submission just to inspect it in the host application.

## Save and cloud envelope

For the future cloud adapter, use `{user_id, game_id, package_version, save_schema, device_id, revision, parent_revision, updated_at, checksum, state}`. Authenticate ownership server-side. Deduplicate revision writes; require matching parent revisions; retain conflicts and ask the player which branch to keep. Never silently overwrite a more recent branch. Snapshot migration belongs to a reviewed package version. Account XP needs server-authoritative events before it can be competitive.

The current app saves locally. `PlatformServices.sync_cloud_saves` explicitly returns unavailable; it does not simulate successful synchronization.

## Publication gates

Local publication checks metadata, supported inputs, trusted scene registration, package/initial-size budgets, source-token lint, lifecycle, simulation timing, tracked allocations and state serialization. A failing check leaves the listing a draft. Passing checks publish only a remix of an existing bundled package to this device.

Public publication additionally requires authenticated creator ownership, signed immutable packages, verified dependency inventory, isolated crash/performance testing, malware scans, asset fingerprinting, content/rating review and reviewer sign-off. Neither automated visual matching nor token lint proves copyright ownership or safety. These service gates fail closed in this edition.
