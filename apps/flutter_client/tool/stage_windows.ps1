# Assembles the Windows app as it will be installed (plan R2):
#   build\windows\stage\Miarina Media\
#     miarina-media.exe (renamed as in 0.1.x), Flutter and plugin DLLs, data\
#     libmpv-2.dll        pinned, newer build (replaces media_kit's 2023 one)
#     msvcp140.dll, vcruntime140.dll, vcruntime140_1.dll  (Visual C++ runtime)
#     tools\              yt-dlp, FFmpeg, QuickJS-NG (pinned, as 0.1.x)
#     tools\*.txt         licence texts and notices
#     miarina-browser-bridge.exe, browser-extension\   Chrome/Edge extension
#
# Usage (from apps\flutter_client), with the pubspec version, e.g. 0.2.0:
#   flutter build windows --release --dart-define=MM_VERSION=0.2.0
#   powershell -File tool\stage_windows.ps1
# The release build must not point at a scratch folder (no MM_DATA_DIR) and
# must carry its version: without MM_VERSION, About says "development build"
# and the in-app updates are off.
param(
  [string]$Release = "build\windows\x64\runner\Release",
  [string]$Out = "build\windows\stage\Miarina Media",
  [string]$Cache = "build\tools-cache"
)
$ErrorActionPreference = 'Stop'
$client = Split-Path $PSScriptRoot -Parent
$repo = Resolve-Path (Join-Path $client '..\..')
Set-Location $client

if (-not (Test-Path "$Release\miarina_media.exe")) { throw "No release build in $Release" }
# A scratch build reads MM_DATA_DIR and must never be shipped.
$exeText = [IO.File]::ReadAllText((Resolve-Path "$Release\data\app.so"), [Text.Encoding]::ASCII)
if ($exeText.Contains('scratchpad')) { throw 'This build points at a scratch data folder; rebuild without MM_DATA_DIR' }
$semver = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+').Matches[0].Groups[1].Value
if (-not $exeText.Contains($semver)) { throw "This build does not carry its version; rebuild with --dart-define=MM_VERSION=$semver" }

# 1. Pinned tools and libmpv (download-engine fetch_tools, checked digests).
Push-Location $repo
cargo run -q -p download-engine --example fetch_tools -- (Join-Path $client $Cache) --flutter
if ($LASTEXITCODE -ne 0) { throw 'fetch_tools failed' }
Pop-Location

# 2. The app files.
if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
New-Item -ItemType Directory -Force $Out | Out-Null
Get-ChildItem $Release -Exclude tools | Copy-Item -Destination $Out -Recurse
# The 0.1.x executable name: shortcuts, taskbar pins and "Open with" keep
# working after the update.
Rename-Item "$Out\miarina_media.exe" 'miarina-media.exe'

# File type icons (piste C) used by "Ouvrir avec" (associations.nsh).
Copy-Item "windows\installer\file-audio.ico", "windows\installer\file-video.ico" $Out -Force

# 3. libmpv: the pinned build replaces media_kit's.
$mpv = Get-ChildItem "$Cache\libmpv\*\libmpv-2.dll" | Select-Object -First 1
if (-not $mpv) { throw 'libmpv missing' }
Copy-Item $mpv.FullName "$Out\libmpv-2.dll" -Force

# 4. Visual C++ runtime, app-local (Microsoft "Distributable Code").
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vs = & $vswhere -latest -products * -property installationPath
$crt = Get-ChildItem -Directory "$vs\VC\Redist\MSVC\*\x64\Microsoft.VC14*.CRT" |
  Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw 'Visual C++ redistributable folder not found' }
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  Copy-Item (Join-Path $crt.FullName $dll) $Out -Force
}

# 5. Tools and their notices.
New-Item -ItemType Directory -Force "$Out\tools" | Out-Null
foreach ($id in 'yt-dlp', 'ffmpeg', 'quickjs') {
  Copy-Item "$Cache\$id" "$Out\tools\$id" -Recurse
}
$res = 'windows\notices'
foreach ($f in 'LGPL-3.0.txt', 'GPL-3.0.txt', 'QuickJS-NG-LICENSE.txt', 'MDM-NOTICE.txt') {
  Copy-Item (Join-Path $res $f) "$Out\tools\$f"
}
$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
(Get-Content -Raw -Encoding utf8 'windows\notices\THIRD-PARTY-TOOLS.txt').Replace('{VERSION}', $version) |
  Set-Content -Encoding utf8 -NoNewline "$Out\tools\THIRD-PARTY-TOOLS.txt"

# 6. The Chrome/Edge extension (loaded unpacked until it is in the stores)
# and its native messaging host, next to the app (EXT-01).
Push-Location $repo
cargo build -q --release -p miarina-browser-bridge
if ($LASTEXITCODE -ne 0) { throw 'browser bridge build failed' }
Pop-Location
Copy-Item (Join-Path $repo 'target\release\miarina-browser-bridge.exe') $Out
$ext = Join-Path $repo 'apps\browser-extension'
New-Item -ItemType Directory -Force "$Out\browser-extension" | Out-Null
foreach ($item in 'manifest.json', 'background.js', 'popup.html', 'popup.js', 'popup.css', '_locales', 'icons') {
  Copy-Item (Join-Path $ext $item) "$Out\browser-extension\$item" -Recurse
}

$size = (Get-ChildItem -Recurse $Out | Measure-Object Length -Sum).Sum
"Staged: $Out ({0:N1} MiB)" -f ($size / 1MB)
