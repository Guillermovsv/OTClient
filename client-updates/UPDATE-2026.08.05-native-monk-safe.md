# Client update 2026.08.05 — native 15.25 Monk-safe compatibility

This update applies only to the compiled native Tibia 15.25 client patched for
Delyriumz. It must be deployed together with the Canary patch under
`client-updates/tibia-15.25-monk-safe/`.

## Why a server update is required

The native client has a compiled, global spell metadata table. IDs `274`-`281`
are real Monk spells and cannot be reused for custom Druid, Sorcerer or Paladin
stances. Relabeling those records changes Monk names, icons and action-bar
behavior for every native-client player.

The Monk-safe server patch therefore:

- preserves native Monk IDs `273`-`297` without translation;
- omits custom IDs `299`-`304` only from the native 15.25 spell-list packet;
- keeps those custom spells castable by their canonical words;
- presents Forked Glacier server ID `305` as its native client record `299`;
- leaves OTClient/OTCv8 packets and canonical IDs unchanged.

## Native-client stance hotkeys

The six custom stances do not appear as independent entries in the compiled
native spell library. Configure an action-bar **Say Text** action using the
canonical words:

| Vocation | Stance | Say Text value |
|---|---|---|
| Druid | Elemental Synthesis | `utito dru` |
| Druid | Shared Conservation | `utura sio` |
| Sorcerer | Master of Flames | `uteta flam` |
| Sorcerer | Master of Thunder | `uteta vis` |
| Sorcerer | Master of Decay | `uteta mort` |
| Paladin | Divine Defiance | `utori hur` |

The server remains authoritative for vocation, mana, cooldowns and effects.

## Server files

```text
client-updates/tibia-15.25-monk-safe/
├── README-SERVER.md
├── canary-tibia-15.25-monk-safe.patch
└── verify-server-prerequisites.sh
```

Follow `README-SERVER.md` on the Linux host. Run the prerequisite verifier,
apply the patch, rebuild Canary, restart the existing service and validate one
native Monk plus each affected stance vocation.

## Client publishing

The valid launcher manifest is:

```text
tibia-15.25-monk-safe-20260805.2
```

Upload the matching `client-windows.zip` and `version.txt` to the existing
MyAAC `client/otc` slot. `OtLauncher.exe` does not need to be uploaded for this
change.

Do not publish `tibia-15.25-stance-spells-20260805.1`; that superseded build
reused Monk spell metadata.
