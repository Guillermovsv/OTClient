# Client update 2026.08.11 — unified client and launcher

Version `2026.08.11.01` makes this repository the sole supported DelyriumzOT
client. It replaces the old OTC package at `/client/otc/`; Vanilla and OTCv8
remain historical packages and are no longer active release choices.

## Client

- Rebuilt `otclient.exe` from commit `b4cdd42` with the v143 Windows toolchain.
- Includes the current Helper, stance, inventory, prey, premium and connection
  fixes from the August 9 source history.
- Uses the active `mods/game_helper` package and the complete Tibia 15.25 things
  and sounds runtime assets.
- Replaces the login background with the coordinated multi-class battle art.

## Launcher and update contract

- Checks `/client/otc/version.txt` at startup and every three minutes.
- Installs updates automatically when the game is closed and queues an update
  detected while the game is running.
- Requires `version`, `file`, `size` and `sha256` in the JSON manifest.
- Validates package size and SHA-256 before extraction.
- Extracts into a traversal-safe staging directory, validates the runtime, then
  swaps the staged tree into place with rollback if activation fails.
- Preserves settings, keybinds, minimap data, profiles, screenshots, logs and
  exported player files while obsolete packaged program files are removed.

The launcher itself remains stable and does not self-update.
