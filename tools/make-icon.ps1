Add-Type -AssemblyName System.Drawing

$size = 1024
$bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# --- фон ---
$bgRect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $bgRect,
    [System.Drawing.Color]::FromArgb(255, 26, 15, 51),
    [System.Drawing.Color]::FromArgb(255, 8, 5, 20),
    45)
$g.FillRectangle($bgBrush, $bgRect)
$bgBrush.Dispose()

# --- мягкое свечение ---
for ($i = 0; $i -lt 6; $i++) {
    $alpha = 16 - ($i * 2)
    $inset = $i * 40
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($alpha, 150, 90, 255))
    $g.FillEllipse($brush, (140 - $inset), (40 - $inset), (740 + $inset * 2), (740 + $inset * 2))
    $brush.Dispose()
}

# --- скруглённый квадрат ---
function New-RoundedRect([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddArc($x, $y, $r * 2, $r * 2, 180, 90)
    $p.AddArc($x + $w - $r * 2, $y, $r * 2, $r * 2, 270, 90)
    $p.AddArc($x + $w - $r * 2, $y + $h - $r * 2, $r * 2, $r * 2, 0, 90)
    $p.AddArc($x, $y + $h - $r * 2, $r * 2, $r * 2, 90, 90)
    $p.CloseFigure()
    return $p
}

$tileX = 176; $tileY = 176; $tileW = 672; $tileH = 672; $radius = 168
$tile = New-RoundedRect $tileX $tileY $tileW $tileH $radius

$tileRect = New-Object System.Drawing.RectangleF([single]$tileX, [single]$tileY, [single]$tileW, [single]$tileH)
$tileBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $tileRect,
    [System.Drawing.Color]::FromArgb(255, 155, 107, 255),
    [System.Drawing.Color]::FromArgb(255, 255, 92, 158),
    45)
$g.FillPath($tileBrush, $tile)
$tileBrush.Dispose()

$edge = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 255, 255, 255), 4)
$g.DrawPath($edge, $tile)
$edge.Dispose()

# --- кнопка play ---
$triangle = @(
    (New-Object System.Drawing.PointF(452, 392)),
    (New-Object System.Drawing.PointF(668, 512)),
    (New-Object System.Drawing.PointF(452, 632))
)
$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$playPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 56)
$playPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
$g.FillPolygon($white, $triangle)
$g.DrawPolygon($playPen, $triangle)
$playPen.Dispose()
$white.Dispose()

# --- искра ---
$spark = @(
    (New-Object System.Drawing.PointF(716, 168)),
    (New-Object System.Drawing.PointF(742, 236)),
    (New-Object System.Drawing.PointF(810, 262)),
    (New-Object System.Drawing.PointF(742, 288)),
    (New-Object System.Drawing.PointF(716, 356)),
    (New-Object System.Drawing.PointF(690, 288)),
    (New-Object System.Drawing.PointF(622, 262)),
    (New-Object System.Drawing.PointF(690, 236))
)
$sparkBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 255, 255, 255))
$g.FillPolygon($sparkBrush, $spark)
$sparkBrush.Dispose()

$g.Dispose()

$out = Join-Path $PSScriptRoot "..\LiveWall\Assets.xcassets\AppIcon.appiconset\AppIcon.png"
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "saved: $out"
