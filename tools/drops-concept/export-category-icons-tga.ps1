Add-Type -AssemblyName System.Drawing

$srcPath = "C:\Users\Novo Usuario\.gemini\antigravity\brain\e07e647f-89c4-4312-b74a-8cc81619678e\azoth_category_icons_3x3_1795045504781.jpg"
$outTga  = "D:\ProjectAzaath\AzaathUI\Media\Sheet\DropCategoryIcons.tga"

$src = [System.Drawing.Bitmap]::FromFile($srcPath)
$cw = [int][Math]::Floor($src.Width / 3)
$ch = [int][Math]::Floor($src.Height / 3)

$out = New-Object System.Drawing.Bitmap(512, 512, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($out)
$g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

for ($idx = 0; $idx -lt 9; $idx++) {
    $sc = $idx % 3
    $sr = [int][Math]::Floor($idx / 3)
    $cell = New-Object System.Drawing.Bitmap($cw, $ch, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $cg = [System.Drawing.Graphics]::FromImage($cell)
    $cg.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $cw, $ch)), (New-Object System.Drawing.Rectangle(($sc * $cw), ($sr * $ch), $cw, $ch)), [System.Drawing.GraphicsUnit]::Pixel)
    $cg.Dispose()

    $rect = New-Object System.Drawing.Rectangle(0, 0, $cw, $ch)
    $bd = $cell.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $len = $bd.Stride * $ch
    $bytes = New-Object byte[] $len
    [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $bytes, 0, $len)

    $vis = New-Object bool[] ($cw * $ch)
    $stack = New-Object System.Collections.Generic.Stack[int]
    for ($x = 0; $x -lt $cw; $x++) { $stack.Push($x); $stack.Push(($ch - 1) * $cw + $x) }
    for ($y = 0; $y -lt $ch; $y++) { $stack.Push($y * $cw); $stack.Push($y * $cw + ($cw - 1)) }

    while ($stack.Count -gt 0) {
        $p = $stack.Pop()
        if ($vis[$p]) { continue }
        $o = $p * 4
        $mx = [Math]::Max($bytes[$o], [Math]::Max($bytes[$o+1], $bytes[$o+2]))
        if ($mx -ge 24) { continue }
        $vis[$p] = $true
        $bytes[$o+3] = 0
        $x = $p % $cw
        $y = [int][Math]::Floor($p / $cw)
        if ($x -gt 0) { $stack.Push($p - 1) }
        if ($x -lt ($cw - 1)) { $stack.Push($p + 1) }
        if ($y -gt 0) { $stack.Push($p - $cw) }
        if ($y -lt ($ch - 1)) { $stack.Push($p + $cw) }
    }

    $minX = $cw; $minY = $ch; $maxX = 0; $maxY = 0
    for ($y = 1; $y -lt ($ch - 1); $y++) {
        for ($x = 1; $x -lt ($cw - 1); $x++) {
            $p = $y * $cw + $x
            if ($vis[$p]) { continue }
            $o = $p * 4
            if ($vis[$p-1] -or $vis[$p+1] -or $vis[$p-$cw] -or $vis[$p+$cw]) {
                $mx = [Math]::Max($bytes[$o], [Math]::Max($bytes[$o+1], $bytes[$o+2]))
                if ($mx -lt 64) {
                    $bytes[$o+3] = [byte][Math]::Round($bytes[$o+3] * [Math]::Max(0.25, $mx / 64.0))
                }
            }
            if ($bytes[$o+3] -gt 20) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $bd.Scan0, $len)
    $cell.UnlockBits($bd)

    $bw = [Math]::Max(1, $maxX - $minX + 1)
    $bh = [Math]::Max(1, $maxY - $minY + 1)
    $dc = $idx % 4
    $dr = [int][Math]::Floor($idx / 4)
    $maxDim = 116.0
    $scFit = [Math]::Min($maxDim / $bw, $maxDim / $bh)
    $dw = [int][Math]::Round($bw * $scFit)
    $dh = [int][Math]::Round($bh * $scFit)
    $dx = $dc * 128 + [int][Math]::Floor((128 - $dw) / 2)
    $dy = $dr * 128 + [int][Math]::Floor((128 - $dh) / 2)

    $g.DrawImage($cell, (New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)), (New-Object System.Drawing.Rectangle($minX, $minY, $bw, $bh)), [System.Drawing.GraphicsUnit]::Pixel)
    $cell.Dispose()
}
$g.Dispose()
$src.Dispose()

# Write bottom-up uncompressed 32-bit BGRA TGA (matching CraftFrames.tga)
$oRect = New-Object System.Drawing.Rectangle(0, 0, 512, 512)
$obd = $out.LockBits($oRect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$raw = New-Object byte[] ($obd.Stride * 512)
[System.Runtime.InteropServices.Marshal]::Copy($obd.Scan0, $raw, 0, $raw.Length)
$out.UnlockBits($obd)
$out.Dispose()

$tga = New-Object byte[] (18 + 512 * 512 * 4)
$tga[2] = 2
$tga[12] = 0; $tga[13] = 2 # 512
$tga[14] = 0; $tga[15] = 2 # 512
$tga[16] = 32
$tga[17] = 8 # bottom-up, 8 alpha bits

$rowBytes = 512 * 4
for ($y = 0; $y -lt 512; $y++) {
    $srcOff = (511 - $y) * $rowBytes
    $dstOff = 18 + $y * $rowBytes
    [Array]::Copy($raw, $srcOff, $tga, $dstOff, $rowBytes)
}

[System.IO.File]::WriteAllBytes($outTga, $tga)
Write-Host "Wrote $outTga ($($tga.Length) bytes)"
