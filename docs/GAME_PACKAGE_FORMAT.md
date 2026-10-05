# LOOP declarative game package · v1

The local Creator Studio accepts `.zip` and `.loopgame` files. A `.loopgame` is a ZIP archive with exactly the same format. The package is data-only: LOOP never executes scripts, native libraries, executables, shaders, HTML, or uploaded scenes. The selected reviewed runtime supplies gameplay code. `loop_arena_v1` is Arena Studio: it creates a fresh, configurable solo cell-arena game rather than selecting one of the six sample-game scenes. It is the first creator runtime ABI; arbitrary game genres still need new platform runtimes.

## Required files

- `manifest.json`: immutable project/version identity and platform declarations. Required fields include `gameId`, `version`, `displayName`, `developerId`, `minimumPlatformVersion`, `orientation`, `inputProfile`, `entryPoint`, `supportsResume`, `requiredCapabilities`, `assets`, and `runtimeTemplate`.
- `game.json`: a JSON object whose `template` matches `manifest.json`'s `runtimeTemplate`.
- Optional `assets/*.png` or `assets/*.webp`: declared image files only. Each asset path in the manifest must exactly match a file in the package.

The creator dashboard can produce an Arena Studio Cell Odyssey sample package with different rules from the runtime defaults. To include images, build the archive externally with the two JSON files and declared assets, then choose it in Creator Studio. Thumbnail, icon, and screenshot paths must appear in the asset inventory. The current built-in templates validate and preserve these images in the versioned package but do not yet render creator artwork in game/feed UI.

## Arena Studio `game.json`

`loop_arena_v1` currently supports `world` width/height/background; player name/radius/speed/color; pellet count/radius/color/mass; opponent count/minimum and maximum radius/color/speed; goal radius/time limit/win text; and deterministic random seed. Bounds and exact required fields are enforced by `CreatorArenaRuntime.validate_definition`. `manifest.json` must include the exact same object as `experienceDefinition`. The game has touch-drag/tap movement, arrow-key movement, pellet collection, growing cells, rival AI, win/loss and replay. This is a concrete new solo game format, not general-purpose code upload.

## Bounds and validation

The default maximum archive is 15 MiB; expanded content is limited to 20 MiB, with at most 34 entries. Each declared asset is limited to 6 MiB; manifest/config JSON to 256 KiB. The parser rejects encrypted or multi-disk ZIPs, ZIP64, traversal/absolute paths, symlink/device entries, unsupported compression, suspicious expansion ratios, undeclared paths, unrecognized image signatures, missing files, identity mismatches, and unsupported capability/input declarations. SHA-256 is stored with the immutable version and checked again on Airlock entry.

Allowed templates are `loop_arena_v1` (Arena Studio), `stack`, `runner`, `crowd`, `racer`, `color_gate`, and `merge`. Supported capability declarations are `local_storage`, `leaderboard`, `achievements`, `analytics`, and `share_ui`; declarations do not grant arbitrary operating-system APIs. Only portrait orientation and the client-supported controls are accepted. The Airlock checks metadata and the selected trusted template, not uploaded executable code.

For production, move validation and storage to a server, authenticate ownership and reviewer roles, isolate all execution, scan assets/content, sign manifests, and treat local records as untrusted. This desktop mock is not a security boundary for third-party code.
