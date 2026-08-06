# Delyriumz Tibia 15.25 Monk-safe spell compatibility

This patch is coupled to native client release
`tibia-15.25-monk-safe-20260805.2`.

## Result

- Monk and Exalted Monk keep their native IDs `273`-`297`, names, icons and
  spells.
- The native 15.25 spell list does not receive custom IDs `299`-`304`, because
  the compiled client has no independent metadata records for them.
- The six custom stances still cast normally through `Say Text` hotkeys using
  their canonical words.
- Forked Glacier remains server ID `305` and is presented to the native client
  through its built-in ID `299`.
- OTClient and OTCv8 still receive canonical IDs `299`-`305`; their complete
  spell library, descriptions, icons and extended opcode `232` behavior remain
  unchanged.

## Native-client hotkeys

| Vocation | Stance | Say Text value |
|---|---|---|
| Druid | Elemental Synthesis | `utito dru` |
| Druid | Shared Conservation | `utura sio` |
| Sorcerer | Master of Flames | `uteta flam` |
| Sorcerer | Master of Thunder | `uteta vis` |
| Sorcerer | Master of Decay | `uteta mort` |
| Paladin | Divine Defiance | `utori hur` |

## Mandatory preflight

From the extracted handoff directory:

```bash
bash verify-server-prerequisites.sh /path/to/canary
```

The check must find canonical spell IDs `299`-`305` and their expected words.
Do not change the spell scripts to Monk IDs.

## Install on Linux

From the Canary repository root:

```bash
git status --short --branch
git apply --check /path/to/canary-tibia-15.25-monk-safe.patch
git apply /path/to/canary-tibia-15.25-monk-safe.patch

cmake --preset linux-release
cmake --build --preset linux-release --target canary
```

Restart Canary using the service or container workflow already configured on
the host. Examples:

```bash
sudo systemctl restart YOUR_CANARY_SERVICE
sudo journalctl -u YOUR_CANARY_SERVICE -n 200 --no-pager
```

or:

```bash
docker compose restart canary
docker compose logs --tail=200 canary
```

Do not guess the service name, repository path or container working directory.

## Coupled validation

1. Native Monk: verify Virtues, Focus Harmony, Balanced Brawl and Focus
   Serenity retain their original names, icons and casts.
2. Native Druid/Sorcerer/Paladin: create the canonical text hotkeys and verify
   the stance effect plus 30-second individual / 2-second shared cooldown.
3. Native Druid: verify Forked Glacier appears and casts normally.
4. OTCv8: verify IDs `299`-`305` remain in its full spell library.

## Native library limitation

The `dudantas/tibia-client` repository distributes the compiled client package,
not source code for the CipSoft spell metadata table. A full native library
with new independent records would require a source-buildable client. OTClient
supports this through `modules/gamelib/spells.lua` without replacing Monk IDs.
