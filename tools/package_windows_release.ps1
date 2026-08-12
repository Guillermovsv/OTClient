param(
    [string]$OutputDirectory = "release-output",
    [string]$Version = "2026.08.11.01"
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$output = [IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDirectory))

if (-not (Test-Path (Join-Path $repoRoot "otclient.exe"))) {
    throw "Build otclient.exe before packaging."
}

foreach ($required in @(
    "init.lua",
    "mods/client_mods/mods.otmod",
    "mods/game_helper/helper.otmod",
    "data/things/1525",
    "data/sounds/1525"
)) {
    if (-not (Test-Path (Join-Path $repoRoot $required))) {
        throw "Missing required runtime input: $required"
    }
}

New-Item -ItemType Directory -Path $output -Force | Out-Null
$zipPath = Join-Path $output "client-windows.zip"
$launcherOutput = Join-Path $output "launcher"

if (Test-Path $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

tar -a -cf $zipPath -C $repoRoot `
    data modules mods cacert.pem config.ini init.lua otclient.exe otclientrc.lua
if ($LASTEXITCODE -ne 0) {
    throw "tar failed with exit code $LASTEXITCODE"
}

dotnet publish (Join-Path $repoRoot "launcher/OtLauncher.csproj") `
    -c Release -r win-x64 --self-contained true `
    -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
    -o $launcherOutput
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE"
}

$zip = Get-Item $zipPath
$hash = (Get-FileHash $zipPath -Algorithm SHA256).Hash
$manifest = [ordered]@{
    version = $Version
    file = "client-windows.zip"
    size = $zip.Length
    sha256 = $hash
}
$manifest | ConvertTo-Json | Set-Content (Join-Path $output "version.txt") -Encoding UTF8
Copy-Item (Join-Path $launcherOutput "OtLauncher.exe") (Join-Path $output "OtLauncher.exe") -Force

[PSCustomObject]@{
    Version = $Version
    Zip = $zipPath
    Size = $zip.Length
    SHA256 = $hash
    Launcher = Join-Path $output "OtLauncher.exe"
}
