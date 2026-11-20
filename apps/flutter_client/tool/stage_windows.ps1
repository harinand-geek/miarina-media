# Assembles the Windows app as it will be installed (plan R2):
#   build\windows\stage\Miarina Media\
#     miarina_media.exe, Flutter and plugin DLLs, data\   (flutter build)
#     libmpv-2.dll        pinned, newer build (replaces media_kit's 2023 one)
#     msvcp140.dll, vcruntime140.dll, vcruntime140_1.dll  (Visual C++ runtime)
#     tools\              yt-dlp, FFmpeg, QuickJS-NG (pinned, as 0.1.x)
#     tools\*.txt         licence texts and notices
#
# Usage (from apps\flutter_client, after `flutter build windows --release`):
#   powershell -File tool\stage_windows.ps1
# The release build must not point at a scratch folder (no MM_DATA_DIR).
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

# 1. Pinned tools and libmpv (download-engine fetch_tools, checked digests).
Push-Location $repo
cargo run -q -p download-engine --example fetch_tools -- (Join-Path $client $Cache) --flutter
if ($LASTEXITCODE -ne 0) { throw 'fetch_tools failed' }
Pop-Location

# 2. The app files.
if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
New-Item -ItemType Directory -Force $Out | Out-Null
Get-ChildItem $Release -Exclude tools | Copy-Item -Destination $Out -Recurse

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
$res = Join-Path $repo 'apps\client\src-tauri\resources'
foreach ($f in 'LGPL-3.0.txt', 'GPL-3.0.txt', 'QuickJS-NG-LICENSE.txt', 'MDM-NOTICE.txt') {
  Copy-Item (Join-Path $res $f) "$Out\tools\$f"
}
$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9.]+)').Matches[0].Groups[1].Value
(Get-Content -Raw -Encoding utf8 'windows\notices\THIRD-PARTY-TOOLS.txt').Replace('{VERSION}', $version) |
  Set-Content -Encoding utf8 -NoNewline "$Out\tools\THIRD-PARTY-TOOLS.txt"

$size = (Get-ChildItem -Recurse $Out | Measure-Object Length -Sum).Sum
"Staged: $Out ({0:N1} MiB)" -f ($size / 1MB)
