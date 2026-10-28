# Reproduce the NSIS bitmaps from the approved application icon.
Add-Type -AssemblyName System.Drawing
$root = $PSScriptRoot
$logo = [Drawing.Image]::FromFile((Join-Path $root '../icons/128x128.png'))
function New-BrandBitmap($width, $height, $name, $sidebar) {
    $bitmap = [Drawing.Bitmap]::new($width, $height, [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [Drawing.Graphics]::FromImage($bitmap)
    $g.Clear([Drawing.ColorTranslator]::FromHtml('#101820'))
    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $white = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#F5F7FA'))
    $muted = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#94A3B8'))
    $accent = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#35C9BD'))
    $bold = [Drawing.Font]::new('Segoe UI', 18, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
    $small = [Drawing.Font]::new('Segoe UI', 12, [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
    if ($sidebar) {
        $g.DrawImage($logo, 20, 28, 64, 64)
        $g.DrawString("Miarina`nMedia", $bold, $white, 18, 110)
        $g.FillRectangle($accent, 20, 174, 32, 3)
        $g.DrawString("Your media.`nYour freedom.", $small, $muted, 18, 194)
        $g.DrawString('MIARINA', $small, $muted, 18, 279)
    } else {
        $g.DrawImage($logo, 8, 10, 36, 36)
        $g.DrawString('Miarina Media', $small, $white, 49, 20)
    }
    $bitmap.Save((Join-Path $root $name), [Drawing.Imaging.ImageFormat]::Bmp)
    $g.Dispose(); $bitmap.Dispose(); $white.Dispose(); $muted.Dispose(); $accent.Dispose()
    $bold.Dispose(); $small.Dispose()
}
New-BrandBitmap 164 314 'sidebar.bmp' $true
New-BrandBitmap 150 57 'header.bmp' $false
$logo.Dispose()
