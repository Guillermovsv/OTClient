param(
    [string]$OutputDirectory = "release-output",
    [string]$Version = "2026.08.12.01"
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

# Echo Raids were introduced in Tibia 15.25 and use the normal map appearance
# and sprite pipeline. Refuse to publish a release from an older or incomplete
# asset tree: such a client can connect, but cannot reliably draw the echo
# trigger and associated current appearances.
$thingsPath = Join-Path $repoRoot "data/things/1525"
$officialAppearanceName = "appearances-aa44a154f30c7ed59acc25f246286396e4043851ef0b54ef3cf3951e46d1ce50.dat"
$officialAppearanceHash = "AA44A154F30C7ED59ACC25F246286396E4043851EF0B54EF3CF3951E46D1CE50"
$activeAppearanceName = "appearances-custom01.dat"
$activeAppearanceHash = "E906FE2CA12E161F875AD6D869B3AC614AA36D591F5F491025B0B057AD783AC8"

foreach ($asset in @(
    @{ Name = $officialAppearanceName; Hash = $officialAppearanceHash },
    @{ Name = $activeAppearanceName; Hash = $activeAppearanceHash }
)) {
    $assetPath = Join-Path $thingsPath $asset.Name
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        throw "Missing Tibia 15.25 Echo Raids appearance asset: $($asset.Name)"
    }

    $actualHash = (Get-FileHash -LiteralPath $assetPath -Algorithm SHA256).Hash
    if ($actualHash -ne $asset.Hash) {
        throw "Unexpected SHA-256 for $($asset.Name). Expected $($asset.Hash), got $actualHash."
    }
}

$catalogPath = Join-Path $thingsPath "catalog-content.json"
$catalogEntries = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$appearanceEntries = @($catalogEntries.Where({ $_.type -eq "appearances" }))
if ($appearanceEntries.Count -ne 1 -or $appearanceEntries[0].file -ne $activeAppearanceName) {
    throw "catalog-content.json must select the verified $activeAppearanceName appearance file."
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
