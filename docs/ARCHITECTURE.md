# Architecture and integration boundaries

## Why Godot

Godot 4.5.2 Standard provides native touch UI, procedural 2D games, a dedicated 3D runner viewport, data-driven PackedScene loading, desktop test execution and a path to mobile exports. Compatibility rendering supports the six bundled games. Skyline Sprint batches static scenery by material and disables its viewport when paused.

The Windows companion uses the official editor executable as a portable development runtime. It is larger than an exported release template. Use normal Godot release export templates for actual mobile distribution and production-size measurements.

## Layering

The native shell depends on `PlatformRepository`, `GameFeed`, and `FeedNavigation`. Games depend on `MiniGame`, drawing helpers, and their own JSON-safe state. The repository owns catalog lookup, preferences, collections, local analytics, recommendations, publication records, and persistence. Feed owns scene lifecycle. Navigation owns pointer arbitration. The shell draws the screens and binds user actions to these components.

The repository exposes a locally available state projection for responsive rendering. A network implementation must preserve that projection while asynchronously fetching/synchronizing. It should not replace every button action with a blocking network call.

## Feed and resources

Initial catalog order is curated. Refresh recomputes a weighted mix from trending seeds, likes, saves, follows, categories of liked games, recent-game penalties, and randomness. Each catalog ID appears at most once. Signals such as time played are recorded for future recommendation strategies, but the current ranker does not train a model or use every recorded signal.

At index i, desired cache is [i−1, i, i+1, i+2], clipped to feed bounds. Current games load immediately when needed; neighbor scenes are requested with Godot threaded loading and instantiated when ready, one per frame. A just-requested current scene can still cause a synchronous load; this is acceptable for the tiny bundled procedural scenes but must be revisited for downloaded 3D games. Prefetching is not a guarantee of zero stalls.

Only current gameplay processes. Departures pause, hide, snapshot, and persist. Evictions snapshot before freeing. The platform itself continues processing so navigation and loading remain available even when no game loaded successfully. Resource metadata and root type are validated; load failure offers retry/skip. GDScript does not offer general exception isolation for arbitrary game code.

## Service replacement seams

- **Authentication:** local player today; provider subject, user ID, expiry/session refresh in a future adapter. Local profile must be migrated explicitly after sign-in.
- **Games/versions:** stable game ID, immutable published package/version ID, scene/package reference, minimum SDK, release notes, content hash, current-live pointer. Future package verification happens before registration.
- **Sessions:** user/game/version key, snapshot schema, current state, score, play duration, completion; use migration or reset on incompatible game updates.
- **Likes/favorites/follows:** unique user/target keys, idempotent mutations, offline command queue, deletion tombstones.
- **Analytics:** unique event IDs and deduplicated batch acknowledgement are required before production sync. Current events have timestamps but are a local ring buffer, not a reliable delivery queue.
- **Leaderboards:** server-authoritative or verified scores, anti-cheat, season/category, moderation. Current self-reported scores are not trustworthy competitive results.
- **Reports:** reporter, game/version, reason, notes, state, review history, enforcement action. Local resolving does not disable a game or suspend a creator.
- **Notifications/challenges:** recipient, type, target ID, creation/expiry, read state. Contracts exist; no delivery channel or inbox is wired.
- **Monetization/revenue:** integer minor currency units, entitlement verification, ad completion verification, qualified play definition, revenue-share basis points, immutable ledger, payout states. Stub methods return unavailable and grant nothing.

## Public publishing prerequisites

A real UGC launch still requires authentication, package/object storage, signed immutable content, rollback policy, age ratings, review tools, content moderation, server-enforced visibility, reporting response processes, privacy controls, and a true untrusted-code boundary. A downloaded GDScript is native application code, not a sandboxed mini-app. An isolated or declarative runtime is a separate engineering milestone.

## Persistence and privacy

`schema=1` JSON is replaced through a temp file and rename. Malformed JSON is backed up. Individual SDK snapshots require fields/types compatible with the game's default state; custom migrations and deep validation are the responsibility of game authors. Progress is not encrypted and should not include secrets. Production apps need export/delete flows, retention limits, consent policy, and authenticated server access where applicable.

There are no credentials, tracking services, HTTP requests, or public uploads in this project. Sharing copies a game link only when the player chooses Copy. The native app parses known game IDs; optional Windows protocol registration and unhosted static web previews are supplied.

See PLATFORM_FEATURES.md for the 0.3 implementation boundaries and MINIGAME_SPEC.md for strict submission budgets. PlayerProgression owns idempotent daily/weekly rewards. PlatformPanels contains the new native sheets. CompatibilityAudit operates only on the bundled allowlist, and never executes external packages.
