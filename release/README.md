# Unified Windows release

This repository is the authoritative source for DelyriumzOT client
`2026.08.12.01`, including the native client, Lua/OTUI loader modules, Helper,
launcher source, and artwork.

`data/things/1525` and `data/sounds/1525` remain runtime-downloaded assets and
are intentionally not stored in Git. To reproduce the published full ZIP,
place those directories in their standard OTC paths before packaging. The
client asset installer retains strict manifest SHA-256 validation.

The packager also verifies the exact Tibia `15.25.0a00a0` appearance baseline
and the active Delyriumz appearance file before it creates a ZIP. That asset
line contains the client-side appearances used by Echo Raids. Raid spawning,
monsters, rewards, and cooldown rules remain server-side behavior.

The upload set is:

- `OtLauncher.exe`
- `client-windows.zip`
- `version.txt`

The launcher and both data files must be distributed together for local
bootstrap. The public update channel is `https://delyriumzot.com/client/otc/`.
