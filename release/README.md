# Unified Windows release

This repository is the authoritative source for DelyriumzOT client
`2026.08.11.01`, including the native client, Lua/OTUI loader modules, Helper,
launcher source, and artwork.

`data/things/1525` and `data/sounds/1525` remain runtime-downloaded assets and
are intentionally not stored in Git. To reproduce the published full ZIP,
place those directories in their standard OTC paths before packaging. The
client asset installer retains strict manifest SHA-256 validation.

The upload set is:

- `OtLauncher.exe`
- `client-windows.zip`
- `version.txt`

The launcher and both data files must be distributed together for local
bootstrap. The public update channel is `https://delyriumzot.com/client/otc/`.
