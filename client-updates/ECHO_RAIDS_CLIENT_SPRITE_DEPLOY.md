# Echo Raids Client Sprite Deployment

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
