# Client update 2026.08.08 — Windows build, runtime assets, and the RSA connection fix

Baseline: commit `f813d4a` ("Add full buildable client source + Windows build
instructions"), the first commit where this repository is a complete buildable
OTClient checkout rather than release-assets only.

This file records everything that was missing when building and running this
client from a clean checkout on Windows. Each item below cost real debugging
time; none of it should need to be rediscovered.

## Summary

| # | Symptom | Root cause | Fix |
|---|---|---|---|
| 1 | `abseil` fails: `fatal error C1083 … ''` (empty output file) | Preview **v145** toolset (MSVC 14.51/14.52, VS 2026) | Build with **v143** (MSVC 14.44) |
| 2 | `error: while checking out baseline … versions/baseline.json` | `C:\vcpkg` is a **shallow clone** missing the pinned baseline | `git fetch` that one commit |
| 3 | `openal-soft` fails: `error C3889` in `alc.cpp` (`std::ranges`) | vcpkg built the port with v145 despite the preset | Pin toolset **in the triplet** |
| 4 | `critical: Unable to load 'client_mods' module` | `mods/` ships empty; the mod loader is not in git | Copy the `mods/` set |
| 5 | `Failed to load '/data/things/1525/' (Appearances)` | Game assets (169 MB) are gitignored | Copy `data/things/1525/` |
| 6 | `Failed to load '/data/sounds/1525/' (Sounds)` | Sound assets (100 MB) are gitignored | Copy `data/sounds/1525/` |
| 7 | Shader `stance_palette.frag` not found | Module-relative path resolved under the wrong module | Use absolute virtual path |
| 8 | **Character list loads, entering the game hangs** | Client used stock `OTSERV_RSA`; server uses the **custom Delyriumz key** | Ship `DELYRIUMZ_RSA` |

Items 1–3 block the build. Items 4–7 block or degrade startup. **Item 8 is the
one that looks like a server/network outage and is not.**

---

## 1. Build: use the v143 toolset, not the preview v145

Visual Studio **Build Tools 2026** installs the preview **v145** toolset
(MSVC 14.51/14.52). Two vcpkg ports miscompile with it:

- `abseil` → `fatal error C1083: cannot open compiler-generated file '': Invalid argument`
- `openal-soft` 1.25.1 → `error C3889` on `std::ranges::views::_Transform_fn` in `alc.cpp`

Both build correctly with **v143 (MSVC 14.44)**.

Setting `VCPKG_PLATFORM_TOOLSET` in a CMake preset is **not enough**. vcpkg
builds each port in its own environment and otherwise picks the newest
installed toolset, ignoring the preset cache variable. The toolset must be set
in the **triplet**, which is why every overlay triplet in `cmake/triplets/`
now carries:

```cmake
set(VCPKG_PLATFORM_TOOLSET v143)
```

This includes `cmake/triplets/x64-windows.cmake`, an overlay of vcpkg's
built-in host triplet, so host build-time tools also avoid v145.

Pin the compiler in the shell too, so the client's own sources use v143:

```powershell
Import-Module 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\Microsoft.VisualStudio.DevShell.dll'
Enter-VsDevShell -VsInstallPath 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools' `
  -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64 -vcvars_ver=14.44'
```

Confirm before building — this must report **14.44**, not 14.51/14.52:

```powershell
(Get-Command cl.exe).Source
```

## 2. vcpkg must have the pinned baseline commit

`vcpkg.json` pins baseline `f3e10653cc27d62a37a3763cd84b38bca07c6075`. A
shallow `C:\vcpkg` clone fails with:

```text
error: while checking out baseline from commit 'f3e10653...', failed to `git show` versions/baseline.json
```

Fetch just that commit — a full unshallow is unnecessary:

```powershell
git -C C:\vcpkg fetch --depth 1 origin f3e10653cc27d62a37a3763cd84b38bca07c6075
```

`Enter-VsDevShell` overwrites `VCPKG_ROOT` with the VS-bundled vcpkg, so set it
**after** entering the dev shell:

```powershell
$env:VCPKG_ROOT = 'C:\vcpkg'
```

## 3. Build commands and where the binary lands

```powershell
cmake --preset windows-release-vs2022
cmake --build --preset windows-release-vs2022
```

First configure compiles ~47 dependencies (30–90 min, cached afterwards).

**The executable is written to the source root**, next to `init.lua` — *not*
to `build\windows-release-vs2022\bin\`. Verify there:

```powershell
Get-Item .\otclient.exe
```

---

## 4. Runtime files that are not in git

The repository is buildable but **not runnable** from a clean checkout: the
game assets and the `mods/` set are gitignored. A freshly built `otclient.exe`
cannot start without them. Copy from a working packaged client (for example
`pc-handoff/work/standard-client`):

```powershell
$src = 'C:\...\pc-handoff\work\standard-client'
$dst = 'C:\...\reference-otclient-main-20260731'

# Mod loader + companions. Missing client_mods is a CRITICAL startup failure.
Copy-Item "$src\mods\*" "$dst\mods\" -Recurse -Force

# Game assets (~169 MB) and sounds (~100 MB)
Copy-Item "$src\data\things\1525" "$dst\data\things\" -Recurse -Force
Copy-Item "$src\data\sounds\1525" "$dst\data\sounds\" -Recurse -Force
```

`init.lua` calls `g_modules.ensureModuleLoaded('client_mods')`, which is fatal
when absent. `client_mods` lives in **`mods/`**, not `modules/`, and pulls in
`client_profiles`, `game_buttons`, `game_itemselector`, and `client_textedit`.

Required set under `mods/`:

```text
client_mods  client_profiles  client_textedit  game_buttons  game_itemselector  game_tasks
```

## 5. Shader path must be an absolute virtual path

`game_stance_spell_visuals.lua` loaded the stance shader with a module-relative
path, which OTClient resolved under the calling module's own directory:

```text
Unable to load shader source form file '/game_stance_spell_visuals/modules/game_shaders/shaders/fragment/stance_palette.frag'
```

Each module is mounted at `/<module-name>/`, so a shader owned by
`game_shaders` must be referenced absolutely:

```lua
-- wrong: resolves under /game_stance_spell_visuals/
'modules/game_shaders/shaders/fragment/stance_palette.frag'
-- correct
'/game_shaders/shaders/fragment/stance_palette.frag'
```

---

## 6. The RSA key — why login works but entering the game does not

**This is the failure that wastes the most time, because nothing is logged and
it looks like a dead server.**

### Symptom

The client starts, accepts the account, and **shows the character list**.
Selecting a character never enters the world. `otclient.log` records
**nothing** — no error, no disconnect.

### Why the symptom is misleading

The client uses two independent connections:

```text
Login:      HTTP  game.delyriumzot.com:8088/login   -- plain JSON, NO RSA
Game world: TCP   game.delyriumzot.com:7172         -- session key encrypted with RSA
```

Because `httpLogin` carries no RSA at all, **the character list loads
correctly even with a completely wrong RSA key**. The key is first used when
entering the world: the client RSA-encrypts the XTEA session key, the server
decrypts it with its private key, and on a mismatch it gets garbage and drops
the connection without a client-visible error.

So "character list works" proves the account, the login service, DNS, and
routing are fine. It proves nothing about the RSA key.

### Root cause

The DelyriumzOT server is deployed with the **custom** private key from
`server-rsa-handoff/` (`key.pem`, generated from
`tibia-15.25-server-rsa-private.xml`). Its public modulus is in
`tibia-15.25-client-rsa-public.txt` (1024-bit, exponent 65537):

```text
D1E86F14912B4253952AD24EFFA2EA60...  (hex)
```

The client source shipped only the stock `OTSERV_RSA` and `CIPSOFT_RSA`
constants, so a client built from this tree used the **wrong key**.

### Fix

`modules/gamelib/const.lua` defines `DELYRIUMZ_RSA` — the same modulus in the
decimal form `g_crypt.rsaSetPublicKey` expects — and `modules/gamelib/game.lua`
selects it by default:

```lua
if not G.currentRsa then
    g_game.setRsa(DELYRIUMZ_RSA or OTSERV_RSA)
end
```

This survives connection setup by design: `g_game.chooseRsa(host)` returns
early for any key that is neither `CIPSOFT_RSA` nor `OTSERV_RSA`, so a custom
key is preserved instead of being reset to `OTSERV_RSA`.

`const.lua` is loaded before `game.lua` by `gamelib.otmod`, so the constant is
always defined; the `or OTSERV_RSA` fallback is only belt-and-braces.

### Before blaming the network

Both of these succeeded while the game connection was still failing, so they
do **not** rule out an RSA mismatch:

```powershell
Test-NetConnection game.delyriumzot.com -Port 8088   # True
Test-NetConnection game.delyriumzot.com -Port 7172   # True
```

`game.delyriumzot.com` resolves to a direct IP (`185.164.110.4`), not a
Cloudflare proxy address — correct, since the Tibia game protocol is raw TCP
and must be **DNS only / grey cloud**. See
[`TIBIA-15.25-CONNECTION.md`](TIBIA-15.25-CONNECTION.md).

### If the client and server keys are ever changed

Both sides must be rotated together:

- Server: install the matching `key.pem` at the server root (next to
  `config.lua`), using `server-rsa-handoff/convert-rsa-xml-to-key-pem.ps1`.
- Client: update `DELYRIUMZ_RSA` in `modules/gamelib/const.lua` with the new
  modulus **in decimal**.

Convert a base64/XML modulus to the decimal form the client needs:

```powershell
$mod = [Convert]::FromBase64String('<Modulus from the private XML>')
$le  = @($mod[($mod.Length-1)..0]) + 0     # little-endian + sign byte
([System.Numerics.BigInteger]::new([byte[]]$le)).ToString()
```

If the server is ever reverted to the stock OTServ key, change the client back
to `OTSERV_RSA` — a client with the custom key will then fail in exactly the
same silent way.

### Security

Only the **public** modulus belongs in the client. Never commit, package, or
upload `tibia-15.25-server-rsa-private.xml` or `key.pem`; they belong solely
on the server and in a secret store.

---

## Verification checklist

A correct build and deployment produces this log and nothing worse:

```text
[info] Operating system: Windows
[info] DelyriumzOT Server 4.x rev 0.000 ...
[info] Startup done :]
[warning] [Webscraping - eventschedule] Invalid JSON response format
```

1. `Get-Item .\otclient.exe` exists at the source root.
2. No `critical: Unable to load 'client_mods' module`.
3. No `Failed to load '/data/things/1525/'` or `/data/sounds/1525/`.
4. No `Unable to load shader source form file ... stance_palette.frag`.
5. Account login reaches the character list.
6. **Selecting a character enters the world** — the RSA check that items 1–5
   cannot detect.

The remaining `eventschedule` warning is expected: the event-schedule
webservice returns empty JSON until the deployment configures those links, and
it blocks nothing.
