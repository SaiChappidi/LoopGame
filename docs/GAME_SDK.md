# Mini-Game SDK v1

## Contract

Every registered scene has a `Control` root with a script inheriting `MiniGame`. The platform validates the scene reference, supported minimum platform version, metadata types, and input profile before catalog admission. The SDK contract is a code-organization boundary for trusted content, not a sandbox.

Lifecycle:

```text
instantiate → initialize_game(metadata) → [load_state(snapshot)]
  → start_game() or resume_game()
  → receive_input(action, logical_point) / tick(delta)
  → pause_game() → save_state()
  → resume_game() … or destroy_game()
```

The shell owns lifecycle transitions. Preloaded games are hidden and do not process. Returning to a game with `supports_resume=false` restarts it. A snapshot loaded from disk counts as an existing session. Game-over state is also resumable; a tap starts a fresh attempt.

Methods: `initialize_game`, `start_game`, `pause_game`, `resume_game`, `restart_game`, `end_game`, `save_state`, `load_state`, `destroy_game`, `get_score`, `get_game_metadata`, `get_input_profile`, `set_safe_area`, and `report_event`.

## Implementing a game

```gdscript
extends MiniGame

func reset_state() -> void:
    state = {"score": 0, "over": false}

func tick(delta: float) -> void:
    # Game simulation only. The base clamps long frame deltas.
    pass

func handle_action(action: String, point: Vector2) -> void:
    if action == "tap":
        state.score += 1

func _draw() -> void:
    begin_draw(Color("18233a"))
    draw_circle(Vector2(200, 240), 60, accent)
    hud("TAP TO SCORE")
```

Keep **all resumable values** in `state`, using strings, numbers, booleans, arrays, and dictionaries. Encode vectors as numeric x/y fields. Do not put Node references, textures, Callables, or timers in the snapshot. Use `tick` to update state. Do not implement autonomous `_input` or global event interception; use the SDK's routed actions. If a game needs audio, stop its players during `pause_game` and restart only during resume; the current sample games have no background audio.

The base emits score changes once when the integer score changes, renders the restart state, and disables processing on pause. Call `end_game(true)` for completion, or `end_game()` for a failed attempt. `tick` is not called after game over.

## Input

Routed actions are `press`, `drag`, `release`, `tap`, `left`, `right`, `up`, and `down`. Positions are normalized into the SDK's 400 × 480 drawing space. The swipe direction is classified when a game-owned pointer is released. A drag receives continuous movement as well as its release classification; games should use only the declared actions relevant to their mechanic.

Each pointer ID is owned by the zone or game from press to release. This is stronger than merely checking where a release occurs. Relayout and modal transitions clear pending pointers. Feed thresholds and velocity requirements never change a game's gesture thresholds. No full-screen feed swipe mode is offered.

Input profile flags in catalog entries:

```text
usesTap, usesHold, usesDrag,
usesSwipeUp, usesSwipeDown, usesSwipeLeft, usesSwipeRight,
usesMultiTouch, usesTilt, usesVirtualJoystick, usesKeyboard
```

SDK v1 has simultaneous pointer ownership in the router but action callbacks do not expose pointer IDs. None of the six sample games declares multi-touch. A future multi-touch/tilt/joystick game must extend the SDK callback contract first; changing a metadata flag alone does not add those capabilities.

## Safe area

`set_safe_area(Rect2)` receives the usable rectangle in host coordinates. The immersive host subtracts device-safe insets and the dedicated feed zone. There are no permanent top/bottom navigation bands. `set_platform_overlays(Array[Rect2])` supplies the current interactive overlay rectangles; the SDK converts them into local `reserved_regions`. The default score HUD moves away from left-side arrow controls. Games should keep critical controls clear of these rectangles. The six bundled games keep their mechanical arena centrally positioned, clear of edge chrome.

Do not position important UI against the application's raw viewport bounds. Use logical coordinates after `begin_draw` or compute from `size` and `reserved_regions`. Drawing and touch coordinates share a uniform, centered 400 × 480 transform, avoiding stretched geometry. Background shaders fill the entire game rectangle. The same game receives a new rectangle when zone position/size changes. Faded metadata controls stop reserving touches; existing game-owned drags retain ownership across all overlays. Native phone insets still require physical-device validation.

## Events

Send events via `report_event(name, payload)`. Current standardized names include `GameStarted`, `GamePaused`, `GameResumed`, `GameRestarted`, `GameCompleted`, `GameOver`, `ScoreChanged`, `AchievementUnlocked`, `LevelCompleted`, `PurchaseRequested`, `AdRequested`, and `ShareRequested`. Not all event types have platform side effects yet; monetization requests do not grant entitlements.

The platform records impressions, openings, high scores, durations, likes/unlikes, favorites, follows, shares, navigation method/direction, canceled gestures, and feed refresh rankings. Events are local, bounded to 1,000 records, and are not sent anywhere. The `PlatformServices` contract gives a future synchronization adapter an explicit acknowledgement boundary.

## Registering and versioning

Use `data/games.json` as the metadata template. Keep the executable scene path under `res://games/`. Include ID, title, creator identity, description, colors/art references, categories/tags, input profile, version/minimum platform, orientation, age rating, resume support, dates, counters, and release records.

Changing the catalog is sufficient to register another trusted game; the feed loads `PackedScene` resources dynamically. A missing/invalid root must not be substituted with a fake playable listing. The current catalog is local and synchronous. Downloaded package registration needs a separate verification and storage pipeline before it can call this layer.

Creator Studio demonstrates metadata snapshots and rollback using bundled packages. Local published remixes appear as unique `local-*` catalog IDs and keep independent sessions and scores. Switching a listing back to Draft/Private/Unlisted removes it from public local discovery. Public/private authorization across users is not implemented.
