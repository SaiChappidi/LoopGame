# LOOP experience runtime and delivery plan

## Player experience target

Install LOOP once. The catalog is metadata/thumbnails, not a bundle containing every game. Tapping Play silently retrieves the selected experience's missing signed content, verifies it, caches it, and starts it. A small cache keeps recently played content; under storage pressure it evicts least-recently-used unpinned experience data. The UI reports progress only when startup takes long enough, with retry/cancel and never a separate installer. Cache is an optimization: the client may need network access again after eviction. There is no promise that hundreds of thousands of games are all permanently available offline.

“No extra download” should mean no user-managed install flow. If a game has not been cached yet, its bytes still have to reach the device somehow. Roblox also delivers cloud-hosted assets and can stream world content; its engine, content delivery, moderation and account services are a substantial platform, not just a multiplayer server.

## Required components

1. **LOOP client/runtime:** installed once and responsible for launching experiences, mapping touch/keyboard/controller input, drawing platform overlays, lifecycle, cache policy, crash recovery and SDK services.
2. **Creator SDK/editor:** creators author for the LOOP runtime, declare device/input/save/network needs, test against device profiles, and export signed/versioned experience bundles. LOOP cannot safely run arbitrary native executables or Godot scripts in-process as if they were sandboxed.
3. **Publishing/control plane:** developer identity, immutable version records, metadata, moderation, review queue, rollout/rollback, compatibility reports and signed content manifests.
4. **Content delivery network (CDN):** stores content-addressed chunks and manifests close to players. The client fetches chunks on demand over HTTPS, verifies hashes/signatures, stores an LRU cache, deduplicates shared assets, and resumes/retries interrupted transfers.
5. **Optional multiplayer/session service:** matchmaking and server-authoritative simulation only for experiences that require shared state. Solo simulation can run locally while saves/leaderboards use platform APIs.

## Runtime boundary

Roblox is not simply loading arbitrary app packages into a generic phone app. Its creator content targets Roblox's proprietary engine and APIs, and its platform controls execution and service access. LOOP needs an equivalent supported engine/SDK plus capability isolation. For an initial cross-platform product, evaluate a purpose-built restricted scripting VM (for example, a sandboxed bytecode environment with a small engine API) or a constrained scene/behavior format. Define the API/capability model before making the uploader accept executable content. Package parsing, antivirus checks, or static lint alone do not sandbox code.

The current LOOP client has its built-in Godot scenes plus Arena Studio, a trusted, data-driven solo cell-arena runtime. Creators can change gameplay through bounded `game.json` values without shipping another script or executable. A content-addressed HTTPS fetch/cache component is present; it checks size and SHA-256, caches verified bytes, and evicts least-recently-used packages. It is not connected to a catalog/CDN or game launch, and there is no server endpoint in this project. Uploaded JSON and images are accepted locally; custom authored scene code and arbitrary genres are not. The present local upload/review pipeline is not production publishing infrastructure.

## Suggested delivery format

An immutable signed manifest should include experience ID/version, runtime ABI, entry point, chunk hashes/sizes, total and first-play bytes, platform/device requirements, declared capabilities, input profile, save-schema version, asset-license records, publisher signature and rollout status. Use content-addressed chunks so shared assets are transferred once. Keep startup-critical content small; stream optional levels/audio only after launch. Verify every chunk and the publisher signature before use, never execute partial/unverified content, and retain the previous live version for rollback.

## Build sequence

1. Extend the creator format beyond Arena Studio to a general safe runtime or additional runtime ABIs; prove custom games can be authored, signed, fetched, cached, launched, suspended, resumed and updated.
2. Build developer auth, upload/object storage, metadata database, moderation/review tooling, signed manifests and CDN delivery.
3. Add cache limits, eviction, storage controls, metered-network settings, resumable fetch, version rollback and offline behavior for already-cached games.
4. Add optional isolated multiplayer servers and server-authoritative APIs; do not require a dedicated server for every solo game.
5. Scale operations: automated compatibility/device testing, abuse reports/takedowns, copyright review, observability, regional CDN, cost controls and on-call response.

Do not promise compatibility with Roblox projects such as Agar.io clones as direct uploads. A creator must rebuild/port a game for LOOP's runtime and APIs unless LOOP later supports a clearly specified interoperable engine format.
