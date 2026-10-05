# Focused feed, Cell Garden, and game information

Updated October 3, 2026.

## Feed lifecycle

Only the current game runs. The feed loads at most three scene instances: the current slot and its immediate previous/next slots (two at the ends). Neighbors are hidden with processing disabled throughout their node trees; their SubViewports stop rendering. One neighbor is warmed per frame. Other instances are detached and freed.

Only the game just left is eligible for resume, and only when its metadata supports resume. Going back immediately restores it. Revisiting an older game starts a new round. Games without resume restart. Nonadjacent jumps never keep a fourth scene. Reopening the app restores its last current game and, when adjacent, the immediately previous resume snapshot. High scores and library entries remain independent of this small session window.

## Cell Garden

Small World (catalog ID crowd) is replaced by an original offline cell-eating arena. Move with drag/tap or arrow keys, eat nutrients and smaller cells, and avoid bigger cells. Ten CPU rivals forage, gain mass and eat smaller rivals. Nutrients replenish within a fixed cap. Reach size 58 before the three-minute timer expires.

The old crowd game's incompatible session and score are reset once during migration; other games' scores, profile, library and preferences are retained. Cell Garden uses the existing crowd slot and deep link so navigation remains stable.

## Game information and comments

Swipe right starting within the leftmost 24 pixels of the gameplay area to open Game & creator. Interior horizontal swipes still belong to the game. The dedicated black strip still switches games. Desktop: click Game info or press I/Escape.

The hamburger and three-dot controls are removed from gameplay. The panel includes game/creator details, follow, like, save, sharing, tutorials, personal bests and platform navigation. Select the Comments tab for the composer and per-game thread. Swipe left across the panel header, click Back to game/close, or press Escape to return. Opening it pauses the game.

Comments are local-only: persisted in the device save, not transmitted or shared with other players. Empty comments and comments over 500 characters are rejected. Up to 100 comments are retained per game. They render as plain text and can be deleted.

## Verification

- 44 focused checks: cache membership, one active game, frozen previous state, disabled background 3D rendering, direct-previous resume, older-game restart, nonresume metadata, last-current restoration, gesture isolation/back navigation, comment validation/storage/UI submission/deletion, CPU growth/collision/restart, legacy-save rejection.
- 68 existing game/SDK checks, 57 UI checks, and 49 platform checks pass with the replacement-game expectations updated.
- Godot-rendered captures reviewed for gameplay, information and comments. CPU arena cover regenerated from the actual game.
- No physical touch-device testing in this update. Input checks inject Godot mouse/key/touch events. Sandboxed runs report an unrelated Windows certificate-store access warning.

Screenshots are in art_review/cell-garden-gameplay.png, game-information.png and game-comments.png. The earlier visual-review gallery documents the prior visual pass and still depicts the retired Small World game; this note describes the current build.
