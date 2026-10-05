# Platform edition — 0.3

## Working in this build

**Play:** six playable games, immersive edge-to-edge surface, dedicated swipe strip, universal pause/Esc, instant replay, random game selection, first-play controls, creator links, likes and saved games. Skyline Sprint is an original procedural 3D runner with articulated animation, eased lane changes, jump/slide clearance, coin trails, escalating speed, trams, magnet and single-hit shield. It shares no artwork, audio, branding, levels or code with the games that inspired the genre.

**Progress:** global XP, levels, daily/weekly quests, qualified-play streaks, saveable collections and Continue Playing. One XP is earned for each ten seconds of active gameplay. Three distinct games earn 60 daily XP; five minutes earns 80 daily XP; three qualified runner attempts earn 150 weekly XP; two qualified personal-best attempts earn 200 weekly XP. Ten seconds qualifies an attempt. Rewards are idempotent for their period. Paused/game-over time is excluded. Dates use the device's local calendar; the local edition is not tamper-resistant.

**Discovery:** separate For You, Trending and New ordering, session-length preference, search and category filters. Trending is seeded demo popularity, not a live global ranking. New sorts publication dates. For You weights preferences and available time; it is a local heuristic.

**Creator tools:** listing drafts/version history/local publication, compatibility reports, device-local opens, active playtime, average visit, early skips, repeat opens, active days, exit-time buckets, provisional maker score, tutorial A/B assignment/exposure/completion counts. A/B supports tutorial copy only; there is one local player, so these observations are not statistically meaningful experimentation results. Cross-user retention, thumbnail/difficulty experiments and cohort significance need a backend. Maker scores use observed load failures, repeat opens, confirmed reports and update history; they are neither creator verification nor real crash-free-user metrics.

**Controls and review:** author-declared age filters, immediate local game disabling across discovery/links/feed, saved copyright review requests with status/history and local disabling. These are functional local operator controls. A child can change the local filter; protected parental identities, server moderation and remote enforcement are not connected.

**Sharing:** copy `loop://game/runner`, paste it into Menu → Open a game link, or launch with `--game=runner`. Optional Windows protocol registration is supplied. Static web preview pages are included separately and need hosting; they are not live public links.

## Service boundaries

The local Developer Dashboard accepts declarative ZIP uploads, keeps immutable package versions and SHA-256 digests, runs a structured Airlock report, supports exact-version preview, manual local review, approval-gated publication, rollback, disable/unpublish, status/search filters, notifications and audit history. Uploaded game code is never executed. Arena Studio is a distinct, configurable solo cell-arena runtime; six starter-game runtimes remain available too. Package assets are validated and retained but not yet shown in the feed/game UI. Reviewer identities are local demo roles, not protected accounts. See `GAME_PACKAGE_FORMAT.md` and `PUBLISHING_PIPELINE.md` for the format, stages and limits.

Cloud saves, authenticated cross-device accounts, real creator/community analytics, production experimentation, signed remote kill policies, malware/content moderation and public takedown delivery require deployed services. This local Airlock performs ZIP/path/size/type/integrity checks; it is not an antivirus or copyright scanner.

A production availability policy should contain a monotonic revision, issue/expiry times, package/version IDs, disabled entries with reasons, and a server signature verified against a pinned key. Cache the last verified policy, reject stale/replayed/unsigned policy, recheck before launch, and suspend a currently disabled game. The present local disabled map exercises enforcement paths but is not remotely controlled.

## Originality and review policy

LOOP's submission policy permits genre conventions and similar mechanics. Every submission must use original or properly licensed art, characters, branding, audio, level layouts and code. No misleading clone listings or impersonation. Require a license/asset inventory and creator attestations; provide attribution where licenses require it. This is the platform's proposed submission policy, not an automated finding about any third-party work.

Production copyright workflow: receive claimant identity, original work, affected package/version and evidence; issue a case ID; acknowledge receipt; preserve an audit trail; review promptly; notify the creator; restrict access when appropriate; offer a documented dispute/appeal process; record the outcome and restore or remove accordingly. Trained review and jurisdiction-appropriate legal procedures are still required. The local queue stores a request and allows review/disable actions; it sends nothing externally.

## Starting the Windows build

Extract the complete `Loop-Platform-Windows.zip` into a new folder. Open `Play LOOP.cmd`, or `Play Skyline Sprint.cmd` to jump directly into the new runner. Keep `bin` and `Loop.pck` beside the launchers. Saves/logs live in `data` in that folder. To retain an older build's progress, close both builds and copy its `data/loop-v1.json` into the new build's `data` folder. Do not overwrite a newer save. Older runner gameplay resets on upgrade; account/social data remains.

This is a native Windows development build with mobile-style input/layout, not an Android/iOS store release or an AAA production asset package. Its 3D artwork is original and procedural. Mobile signing, release export templates, device certification, sound/music production and production services remain separate milestones.
