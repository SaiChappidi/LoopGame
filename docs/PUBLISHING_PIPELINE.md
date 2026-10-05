# Local developer publishing pipeline

Creator Studio → Developer Dashboard is a device-local publishing lab. It stores project ownership under the local player, metadata, immutable versions, package paths/digests, Airlock run snapshots, review decisions, notification records, and an append-only audit list in the LOOP save file. Packages live under `data/game-packages/<game-id>/`.

## Version flow

`Draft → Uploading → Uploaded → AirlockQueued → AirlockValidating → ValidationPassed | ValidationFailed → AwaitingReview → Approved | ReviewRejected → Published`.

Only a passing build can request review. Review is required by default. Publishing requires approval and atomically advances the live version pointer; it never replaces an existing package. A new version remains staged while the current live version stays available. Rollback points the catalog back to a previously approved immutable version. Operators can disable or unpublish a live version without deleting history. Visibility can be Private, Unlisted, or Public; only public, published, enabled games appear in discovery.

## Airlock report

Each run records package integrity, manifest identity, template compatibility, dependencies, assets, input declaration, simulated safe area, startup, pause/resume/restart/unload/save-load lifecycle, navigation, performance, tracked memory, error handling, crash/execution boundary, network, capabilities, content rating, and a final gate. Package and compatibility measurements are performed locally. The checker exercises only the selected trusted built-in template. Safe area/navigation are declared/simulated desktop checks; GPU FPS, real phone memory, OS crashes, touch hardware, thermal behavior, and long-session soak need device testing. Local reviewer IDs (`local-admin`, `local-player`) are mock roles, not authenticated accounts.

The default budgets are 15 MiB archive, 2 MiB initial download, 1000 ms template initialization, 4 ms simulation p95, and 96 MiB tracked incremental allocation. Performance/memory warnings can be configured to block. A failure report retains each stage's status, severity, measured values, package identity and log. Corrected content requires a new immutable version.

## Local limits

This is not a backend, malware scanner, rights reviewer, antivirus, protected admin system, or arbitrary-code sandbox. The package is never executed; author content selects a reviewed runtime template. Arena Studio can author supported rules and render one credited PNG/WebP backdrop; other templates validate and retain package images without rendering them. Notifications are in-app local records; there is no email/push delivery. This boundary is intentional until production authentication, isolated execution and moderation services exist.
