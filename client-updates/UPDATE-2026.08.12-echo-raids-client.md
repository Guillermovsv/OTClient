# Client update 2026.08.12 - Echo Raids asset compatibility

Version `2026.08.12.01` is built from DelyriumzOT client commit `089fd424` and
packages the Tibia 15.25 appearance and sprite line used by Echo Raids.

## Client scope

- Uses protocol/client version `1525`.
- Includes the official `15.25.0a00a0` appearance baseline with SHA-256
  `AA44A154F30C7ED59ACC25F246286396E4043851EF0B54EF3CF3951E46D1CE50`.
- Uses the synchronized Delyriumz active appearance file
  `appearances-custom01.dat` with SHA-256
  `E906FE2CA12E161F875AD6D869B3AC614AA36D591F5F491025B0B057AD783AC8`.
- Retains the existing strict client-assets SHA-256 policy and standard
  `data/things/1525` and `data/sounds/1525` runtime paths.
- Adds packaging validation so an older or modified appearance tree cannot be
  published accidentally as this release.

Echo Raid triggers and creatures use the ordinary map thing/effect pipeline;
there is no separate Echo Raids client window or extended opcode to enable.
The server remains authoritative for choosing spawn locations, creating the
echo trigger, starting the raid, and awarding its rewards. This release makes
the client asset-compatible; it does not create server-side raids by itself.

## Upload set

Upload these three matching files together to `/client/otc/`:

- `OtLauncher.exe`
- `client-windows.zip`
- `version.txt`

The launcher will compare the manifest on start and every three minutes, then
install the ZIP after validating its size and SHA-256.
