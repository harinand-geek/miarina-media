# Builds the Windows file-type icons (piste C, owner's choice 2026-11-21)
# from windows\file-icons\*.svg:
#   windows\installer\file-audio.ico, windows\installer\file-video.ico
# Each size uses the drawing made for it (16, 32, 48, large), rendered by
# Microsoft Edge headless on a transparent page, cropped, then stored as PNG
# entries of a multi-size .ico (Windows Vista and later).
#
#   powershell -File tool\make_file_icons.ps1
param([string]$Out = "windows\installer")
$ErrorActionPreference = 'Stop'
$client = Split-Path $PSScriptRoot -Parent
Set-Location $client
Add-Type -AssemblyName System.Drawing

$edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) { throw "Microsoft Edge not found: $edge" }
$src = Resolve-Path "windows\file-icons"
$work = Join-Path $env:TEMP "miarina-file-icons"
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory $work | Out-Null

$sizes = 16, 20, 24, 32, 40, 48, 64, 96, 128, 256
function SourceFor([string]$kind, [int]$px) {
  $variant = if ($px -le 20) { '16' } elseif ($px -le 40) { '32' } elseif ($px -le 48) { '48' } else { 'large' }
  Join-Path $src "$kind-$variant.svg"
}

function Render([string]$svg, [int]$px, [string]$png) {
  $uri = ([Uri]$svg).AbsoluteUri
  $html = Join-Path $work "page.html"
  Set-Content -Encoding utf8 $html "<!doctype html><html><body style=`"margin:0;background:transparent`"><img src=`"$uri`" width=`"$px`" height=`"$px`" style=`"display:block`"></body></html>"
  $shot = Join-Path $work "shot.png"
  if (Test-Path $shot) { Remove-Item $shot }
  # Edge logs harmless messages on stderr: run it apart.
  $edgeArgs = @('--headless=new', '--disable-gpu', '--hide-scrollbars', "--user-data-dir=`"$work\edge`"",
    '--default-background-color=00000000', '--window-size=320,320', '--force-device-scale-factor=1',
    "--screenshot=`"$shot`"", ([Uri]$html).AbsoluteUri)
  Start-Process -FilePath $edge -ArgumentList $edgeArgs -Wait -WindowStyle Hidden
  for ($i = 0; $i -lt 50 -and -not (Test-Path $shot); $i++) { Start-Sleep -Milliseconds 100 }
  $full = [Drawing.Bitmap]::FromFile($shot)
  try {
    $crop = $full.Clone((New-Object Drawing.Rectangle 0, 0, $px, $px), [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $crop.Save($png, [Drawing.Imaging.ImageFormat]::Png)
    $crop.Dispose()
  } finally { $full.Dispose() }
}

function WriteIco([string[]]$pngs, [int[]]$px, [string]$ico) {
  $data = $pngs | ForEach-Object { , [IO.File]::ReadAllBytes($_) }
  $ms = New-Object IO.MemoryStream
  $w = New-Object IO.BinaryWriter $ms
  $w.Write([UInt16]0); $w.Write([UInt16]1); $w.Write([UInt16]$pngs.Count)
  $offset = 6 + 16 * $pngs.Count
  for ($i = 0; $i -lt $pngs.Count; $i++) {
    $s = $px[$i]
    $w.Write([byte]($(if ($s -ge 256) { 0 } else { $s })))
    $w.Write([byte]($(if ($s -ge 256) { 0 } else { $s })))
    $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([UInt16]1); $w.Write([UInt16]32)
    $w.Write([UInt32]$data[$i].Length); $w.Write([UInt32]$offset)
    $offset += $data[$i].Length
  }
  foreach ($d in $data) { $w.Write($d) }
  $w.Flush()
  [IO.File]::WriteAllBytes($ico, $ms.ToArray())
}

New-Item -ItemType Directory -Force $Out | Out-Null
foreach ($kind in 'audio', 'video') {
  $pngs = @()
  foreach ($px in $sizes) {
    $png = Join-Path $work "$kind-$px.png"
    Render (SourceFor $kind $px) $px $png
    $pngs += $png
  }
  $ico = Join-Path (Resolve-Path $Out) "file-$kind.ico"
  WriteIco $pngs $sizes $ico
  "{0}: {1:N0} bytes, sizes {2}" -f $ico, (Get-Item $ico).Length, ($sizes -join ' ')
}
"Previews: $work"
