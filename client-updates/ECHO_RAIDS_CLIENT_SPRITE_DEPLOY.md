# Echo Raids Client Sprite Deployment

## PENDING as of 2026-08-14: appearance flag fix, files updated but not yet built/published/uploaded

`data/things/1525/appearances-custom01.dat` in this repo has been updated to
drop the `flags.avoid` attribute on item `54267` (the echo trigger). This
commit only updates the source-of-truth data files in this repo — **nobody
has run the packaging script, published a GitHub release, or uploaded a
client package to MyAAC yet.** That work is intentionally left for whoever
picks up the client-side release next.

### What changed and why

- Root cause: the trigger's appearance had `flags.avoid = True`, which the
  client maps to `ThingFlagAttrNotPathable` — the same flag real Tibia/OTClient
  uses for hazard tiles (fire fields, traps). That made the client's
  pathing/auto-walk require a deliberate second step to actually walk onto
  the portal instead of a normal single walk-in.
- Fix (made in the server-side asset-build tooling, not in this repo): the
  build script that generates this appearance no longer sets
  `flags.avoid`. This repo's `data/things/1525/appearances-custom01.dat` was
  regenerated from that fixed script and copied in as-is.
- `catalog-content.json` and `sprites-echo-raids-trigger-54267.bmp.lzma` are
  unchanged (only the appearance flags moved, not the sprite frames or
  catalog entry), confirmed by identical file hashes to what was already
  committed here.
- New SHA-256 for `appearances-custom01.dat`:
  `ee7b7d0cb641078f89210753e9b8f7343c427fe4b1044b23a2b75c5cd4f4d30e`
  (must match the server's copy of the same file — see
  `otserver-push/quickstart/canary/custom-assets/appearances.dat` /
  `otserver-push/ECHO_RAIDS_CLIENT_SPRITE_DEPLOY.md` in the private
  `otserver-push` repo for the server-side half of this change).

### What still needs to happen

1. Build/verify `otclient.exe` and the rest of the runtime client as usual
   (no native/C++ change was needed for this fix, only the appearance data).
2. Run `launcher/scripts/package_client_release.sh` from the OTC workspace to
   publish a new `client-windows.zip` release to this repo.
3. Upload the new package through MyAAC (**Tools -> Client Uploads**).
4. Verify in-game that stepping on an echo trigger now works on the **first**
   step, not the second, and that the portal only disappears when a raid
   actually spawns.

## Current Server Contract

- Echo Raid trigger item id: `54267`
- Item name in appearances: `exploraid trigger`
- Required protocol folder: `data/things/1525`
- Required appearance file selected by catalog: `appearances-custom01.dat`
- Required sprite sheet: `sprites-echo-raids-trigger-54267.bmp.lzma`

The server creates item `54267` for `/echoraid portal,...` and
`/echoraid create,...`. The client will only render the animated floor trigger
if the active client package contains the matching protocol-1525 appearance
catalog and sprite sheet.

## Required Client Files

The shipped client package must include these files together:

- `data/things/1525/appearances-custom01.dat`
- `data/things/1525/catalog-content.json`
- `data/things/1525/sprites-echo-raids-trigger-54267.bmp.lzma`

The catalog must contain an entry for
`sprites-echo-raids-trigger-54267.bmp.lzma`, and its appearance entry must
select `appearances-custom01.dat`.

## Likely Missing Piece When The Trigger Is Invisible

If the GM command creates the portal but no sprite appears in game, the likely
missing piece is operational:

- players are still running an older client package;
- the website `/client/` package was not replaced after the Echo Raids asset
  build;
- the launcher has not downloaded the latest `client-windows.zip`;
- the live package is missing the sprite sheet or still has an older
  `catalog-content.json`.

The Echo Raid trigger uses the normal map item rendering path. It does not need
a custom UI module or extended opcode to appear.

## Build And Publish

From the OTC workspace root:

```sh
cd /Users/memo/Documents/OTC
./launcher/scripts/package_client_release.sh
```

The script stages and zips the runtime client files:

- `otclient.exe`
- `init.lua`
- `otclientrc.lua`
- `config.ini`
- `cacert.pem`
- `data/`
- `modules/`
- `mods/`

It publishes `client-windows.zip` to the `Guillermovsv/OTClient` GitHub
release repo using `.secrets/github_token.txt`.

## Upload To Website

After the GitHub release is created:

1. Open MyAAC admin.
2. Go to **Tools -> Client Uploads**.
3. Upload the new `client-windows.zip` and matching version metadata.
4. Confirm the website serves the new package under `/client/`.
5. Restart the launcher/client so it downloads the new package.

## Verification

After the server and client package are both updated, test:

```text
/echoraid portal,demon
/echoraid create,demon,fiendish
```

Expected behavior:

- an animated `exploraid trigger` appears on the floor;
- any player can step on it;
- monsters cannot activate it;
- `/echoraid create,...` keeps the requested fixed variant;
- `/echoraid portal,...` rolls the variant normally.
