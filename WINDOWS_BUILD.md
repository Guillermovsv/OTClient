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
- Output binary: `build\windows-release-vs2022\bin\otclient.exe`

## 3. Run
The exe must find `data/`, `modules/`, `mods/`, `init.lua` at the working dir.
Either copy the built `otclient.exe` into the `otclient` root next to `init.lua`,
or run it with that folder as the working directory. Double-click or:
```powershell
Copy-Item build\windows-release-vs2022\bin\otclient.exe .\otclient.exe -Force
.\otclient.exe
```

## Alternative: Visual Studio solution (DirectX build)
Matches RubinOT's DirectX renderer. In Developer PowerShell:
```powershell
msbuild vc18\otclient.sln /p:Configuration=DirectX /p:Platform=x64 `
  /p:VcpkgEnableManifest=true /p:VcpkgRoot="$env:VCPKG_ROOT"
```
Configurations available: `Debug`, `OpenGL`, `DirectX`. (CI uses the v145
toolset for these; on VS 2022 open the .sln and retarget to v143 if prompted.)

## Troubleshooting
- **"v145 toolset not found"** → you ran the stock `windows-release` preset;
  use `windows-release-vs2022` instead (added in `CMakeUserPresets.json`).
- **vcpkg baseline / manifest errors** → confirm `VCPKG_ROOT` is set and the
  terminal was reopened after bootstrap.
- **exe launches but can't connect** → that's the login path we're testing.
  `init.lua` is currently set to the **httpLogin webservice**
  (`http://game.delyriumzot.com:8088/login`, game port `7172`) — the same path
  your working Windows clients use. The whole point of this Windows build is to
  check whether the earlier "Connecting to game server…" hang was specific to
  the macOS build. Report the on-screen result and we iterate.
