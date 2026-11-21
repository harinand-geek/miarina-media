# Builds the Windows installer of the Flutter app (plan R4) from the staged
# folder (tool\stage_windows.ps1): build\windows\installer\
#   MiarinaMedia-<version>-x64-setup.exe
# It installs over 0.1.x in place (same product, folder, uninstall entry).
#
#   powershell -File tool\build_installer.ps1            # the real product
#   powershell -File tool\build_installer.ps1 -Recette   # recette identity:
#     "Miarina Media Recette Flutter", org.miarina.media.recette.flutter, its
#     own folder and uninstall entry (never the 0.1.x L09 recette identity,
#     whose data must not be touched); the app must be built with
#     --dart-define=MM_APP_ID=org.miarina.media.recette.flutter
#
# NSIS: the copy Tauri installed (%LOCALAPPDATA%\tauri\NSIS, with the
# nsis_tauri_utils plugin), the same tools that built 0.1.x.
param(
  [string]$Stage = "build\windows\stage\Miarina Media",
  [string]$Out = "build\windows\installer",
  [switch]$Recette
)
$ErrorActionPreference = 'Stop'
$client = Split-Path $PSScriptRoot -Parent
Set-Location $client

$exeName = if ($Recette) { 'miarina-media-recette-flutter' } else { 'miarina-media' }
if (-not (Test-Path "$Stage\miarina-media.exe")) { throw "No staged app in $Stage" }
$stageAbs = (Resolve-Path $Stage).Path
$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)').Matches[0]
$semver = $version.Groups[1].Value
$build = $version.Groups[2].Value

New-Item -ItemType Directory -Force $Out | Out-Null
$outAbs = (Resolve-Path $Out).Path
$files = New-Object System.Collections.Generic.List[string]
$unfiles = New-Object System.Collections.Generic.List[string]

# Folders first (deepest last), then every file; the main executable takes
# the product's binary name.
$dirs = Get-ChildItem -Recurse -Directory $stageAbs | ForEach-Object { $_.FullName.Substring($stageAbs.Length + 1) }
foreach ($d in ($dirs | Sort-Object { $_.Length })) { $files.Add("  CreateDirectory `"`$INSTDIR\$d`"") }
foreach ($f in Get-ChildItem -Recurse -File $stageAbs) {
  $rel = $f.FullName.Substring($stageAbs.Length + 1)
  if ($rel -eq 'miarina-media.exe') { $rel = "$exeName.exe" }
  $files.Add("  File `"/oname=$rel`" `"$($f.FullName)`"")
  $unfiles.Add("  Delete `"`$INSTDIR\$rel`"")
}
foreach ($d in ($dirs | Sort-Object { $_.Length } -Descending)) { $unfiles.Add("  RMDir /REBOOTOK `"`$INSTDIR\$d`"") }
$utf8 = New-Object System.Text.UTF8Encoding $true
[IO.File]::WriteAllLines("$outAbs\files.nsh", $files, $utf8)
[IO.File]::WriteAllLines("$outAbs\unfiles.nsh", $unfiles, $utf8)

$kb = [math]::Ceiling(((Get-ChildItem -Recurse -File $stageAbs | Measure-Object Length -Sum).Sum) / 1KB)
$nsis = Join-Path $env:LOCALAPPDATA 'tauri\NSIS'
$makensis = Join-Path $nsis 'Bin\makensis.exe'
if (-not (Test-Path $makensis)) { throw "NSIS not found in $nsis" }
$setup = "$outAbs\MiarinaMedia-$semver-x64-setup.exe"
if ($Recette) { $setup = "$outAbs\MiarinaMediaRecetteFlutter-$semver-x64-setup.exe" }

$defines = @(
  "/DVERSION=$semver",
  "/DVERSIONWITHBUILD=$semver.$build",
  "/DOUTFILE=$setup",
  "/DESTIMATEDSIZE=$kb",
  "/DINSTALLERDIR=$client\windows\installer",
  "/DFILESNSH=$outAbs\files.nsh",
  "/DUNFILESNSH=$outAbs\unfiles.nsh",
  "/DADDITIONALPLUGINSPATH=$nsis\Plugins\x86-unicode\additional"
)
if ($Recette) {
  $defines += '/DPRODUCTNAME=Miarina Media Recette Flutter', '/DBUNDLEID=org.miarina.media.recette.flutter', "/DMAINBINARYNAME=$exeName"
}
& $makensis -V2 -INPUTCHARSET UTF8 @defines "$client\windows\installer\installer.nsi"
if ($LASTEXITCODE -ne 0) { throw 'makensis failed' }
$item = Get-Item $setup
$hash = (Get-FileHash $setup -Algorithm SHA256).Hash.ToLower()
"Installer: $($item.FullName)"
"Size: {0:N1} MiB, SHA-256: {1}" -f ($item.Length / 1MB), $hash
