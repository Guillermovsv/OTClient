# Building the DelyriumzOT client on Windows

Produces `otclient.exe` from this source tree. The connection fix (init.lua /
config → classic-vs-http login) is already in this folder, so a build from here
carries it. Recipe mirrors the repo's own CI (`.github/workflows/reusable-build-windows.yml`).

## 0. Get the source onto Windows
Copy this entire `otclient/` folder to the Windows machine (≈1.6 GB). You can
**skip** `build/` and `vcpkg_installed/` if present — they're regenerated.

## 1. Install prerequisites (once)
1. **Visual Studio 2022** (Community is fine) with the **"Desktop development
   with C++"** workload. That installs MSVC v143, CMake, and Ninja.
   - (If you have VS 2026 preview with the v145 toolset, you can use the stock
     `windows-release` preset instead of the vs2022 one below.)
2. **Git for Windows** — https://git-scm.com/download/win
3. **vcpkg** (dependency manager). In *Developer PowerShell for VS 2022*:
   ```powershell
   git clone https://github.com/microsoft/vcpkg C:\vcpkg
   C:\vcpkg\bootstrap-vcpkg.bat
   [Environment]::SetEnvironmentVariable("VCPKG_ROOT", "C:\vcpkg", "User")
   ```
   Close and reopen the terminal so `VCPKG_ROOT` is set.
   > vcpkg manifest mode auto-pins to the baseline in `vcpkg.json`
   > (`f3e10653cc27d62a37a3763cd84b38bca07c6075`) — no manual checkout needed.

## 2. Build (VS 2022 / v143)
From **Developer PowerShell for VS 2022**, in the `otclient` folder:
```powershell
cmake --preset windows-release-vs2022
cmake --build --preset windows-release-vs2022
```
- First configure downloads + compiles all C++ dependencies via vcpkg —
  **30–90 min** the first time (cached afterward).
- Output binary: **`.\otclient.exe` in the source root**, next to `init.lua`.
  CMake does not leave it under `build\...\bin\`.

If your Visual Studio install also has the preview **v145** toolset (VS 2026
Build Tools ships MSVC 14.51/14.52), pin the shell to v143 first or `abseil`
and `openal-soft` will fail to compile:

```powershell
Import-Module 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\Common7\Tools\Microsoft.VisualStudio.DevShell.dll'
Enter-VsDevShell -VsInstallPath 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools' `
  -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64 -vcvars_ver=14.44'
$env:VCPKG_ROOT = 'C:\vcpkg'   # Enter-VsDevShell overwrites this; set it after
(Get-Command cl.exe).Source    # must report 14.44
```

## 3. Run
The exe must find `data/`, `modules/`, `mods/`, `init.lua` at the working dir.
The build already places `otclient.exe` in the source root, so just run it with
that folder as the working directory — double-click or:
```powershell
.\otclient.exe
```

A clean checkout includes the required `client_mods`, its support modules, and
the RTC Helper. The 15.25 game/sound assets remain runtime-downloaded and
gitignored. The configured `clientAssets` loader installs them to the standard
runtime paths on first launch. For offline testing or packaging, copy only
those assets from a working package:
```powershell
$src = '..\work\standard-client'
Copy-Item "$src\data\things\1525"   .\data\things\  -Recurse -Force
Copy-Item "$src\data\sounds\1525"   .\data\sounds\  -Recurse -Force
```

Build the launcher from `launcher\OtLauncher.csproj`. After the native binary
and runtime assets are present, `tools\package_windows_release.ps1` produces
the launcher, client ZIP, and SHA-256 manifest together.

## Alternative: Visual Studio solution (DirectX build)
Matches RubinOT's DirectX renderer. In Developer PowerShell:
```powershell
msbuild vc18\otclient.sln /p:Configuration=DirectX /p:Platform=x64 `
  /p:VcpkgEnableManifest=true /p:VcpkgRoot="$env:VCPKG_ROOT"
```
Configurations available: `Debug`, `OpenGL`, `DirectX`. (CI uses the v145
toolset for these; on VS 2022 open the .sln and retarget to v143 if prompted.)

## Troubleshooting

Every issue below is documented in full, with causes and fixes, in
[`client-updates/UPDATE-2026.08.08-windows-build-and-connection.md`](client-updates/UPDATE-2026.08.08-windows-build-and-connection.md).
Read that first before debugging a failed build or a client that will not
connect.

- **"v145 toolset not found"** → you ran the stock `windows-release` preset;
  use `windows-release-vs2022` instead (added in `CMakeUserPresets.json`).
- **`abseil` fails with `C1083 … ''`, or `openal-soft` with `C3889`** → the
  preview v145 toolset (MSVC 14.51/14.52) is being used. Enter the dev shell
  with `-vcvars_ver=14.44` and confirm `(Get-Command cl.exe).Source` reports
  **14.44**. The overlay triplets in `cmake/triplets/` already pin
  `VCPKG_PLATFORM_TOOLSET v143`, which a CMake preset alone cannot do.
- **vcpkg baseline / manifest errors** → confirm `VCPKG_ROOT` is set and the
  terminal was reopened after bootstrap. `Enter-VsDevShell` resets
  `VCPKG_ROOT`, so set it **after** entering the shell. If `C:\vcpkg` is a
  shallow clone it will not have the pinned baseline:
  `git -C C:\vcpkg fetch --depth 1 origin f3e10653cc27d62a37a3763cd84b38bca07c6075`
- **`otclient.exe` not found after a successful build** → it is written to the
  **source root**, next to `init.lua`, not to `build\...\bin\`.
- **`critical: Unable to load 'client_mods'`** → the checkout is incomplete;
  `mods/client_mods` and its support modules are tracked in this repository.
- **Missing appearances/sounds** → allow `clientAssets` to install them, or
  copy `data/things/1525` and `data/sounds/1525` from a working package.
- **Character list loads but entering the game hangs, with nothing in the log**
  → **RSA key mismatch.** This is resolved; the client now ships
  `DELYRIUMZ_RSA` in `modules/gamelib/const.lua`. HTTP login on `:8088` uses no
  RSA, so the character list loads even with the wrong key, while the game
  world on `:7172` encrypts the session key with RSA and the server silently
  drops the mismatch. Reaching the character list therefore says nothing about
  the key. If the server's `key.pem` is ever rotated, update `DELYRIUMZ_RSA`
  to match — see the update file for the conversion command.
