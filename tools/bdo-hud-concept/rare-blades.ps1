# Lâminas de raro/elite do alvo Zerker: leque de lâminas de metal cravadas na borda do
# losango (cima, esquerda, baixo; o lado das barras fica livre) + contorno metálico.
# Desenha 512x512 (o quadro cobre 1,5x a caixa do losango, centrado nele); o
# rare-blades.js reduz para 256 e grava Media/BDO/RareSilver.tga e RareGold.tga.
# Uso: node tools/bdo-hud-concept/rare-blades.js   (chama este script)
param([string]$outDir)
Add-Type -AssemblyName System.Drawing
function P($x,$y){ New-Object System.Drawing.PointF ([single]$x),([single]$y) }
function C($a,$r,$g,$b){ [System.Drawing.Color]::FromArgb($a,$r,$g,$b) }
$MT=@{
 Silver=@{ hi=(C 255 245 248 255); mid=(C 255 168 178 194); lo=(C 255 78 86 100) };
 Gold=@{ hi=(C 255 255 238 170); mid=(C 255 222 168 62); lo=(C 255 112 72 20) } }
$N=512
$F=512/(1.5*136.2)*58.1/46   # px do quadro por px da prévia (losango de 46 px no print)
$cx=$N/2; $cy=$N/2; $D=48*$F
function MetalBrush($m,$y0,$y1){
 $b=New-Object System.Drawing.Drawing2D.LinearGradientBrush((P 0 $y0),(P 0 ($y1+0.01)),$m.hi,$m.lo)
 $cb=New-Object System.Drawing.Drawing2D.ColorBlend 4; $cb.Colors=@($m.hi,$m.mid,$m.lo,$m.mid)
 $cb.Positions=@([single]0,[single]0.35,[single]0.7,[single]1); $b.InterpolationColors=$cb; $b }
function FillMetal($g,$pts,$m){
 $pa=New-Object System.Drawing.Drawing2D.GraphicsPath; $pa.AddPolygon([System.Drawing.PointF[]]$pts); $r=$pa.GetBounds()
 $g.FillPath((MetalBrush $m $r.Top $r.Bottom),$pa); $g.DrawPath((New-Object System.Drawing.Pen((C 220 0 0 0),(0.8*$F))),$pa) }
function Blades($g,$angs,[double]$len,[double]$half,$m){
 foreach($a in $angs){ $t=$a*[math]::PI/180; $c=[math]::Cos($t); $s=[math]::Sin($t)
  $r=$D/([math]::Abs($c)+[math]::Abs($s)); $r0=$r-5*$F
  $nx=-$s*$half; $ny=$c*$half
  $bx=$cx+$c*$r0; $by=$cy+$s*$r0; $tx=$cx+$c*($r+$len); $ty=$cy+$s*($r+$len)
  $mx=$cx+$c*($r+$len*0.35); $my=$cy+$s*($r+$len*0.35)
  FillMetal $g @((P ($bx+$nx) ($by+$ny)),(P ($mx+$nx*0.8) ($my+$ny*0.8)),(P $tx $ty),(P ($mx-$nx*0.8) ($my-$ny*0.8)),(P ($bx-$nx) ($by-$ny))) $m
  $g.DrawLine((New-Object System.Drawing.Pen((C 170 255 255 255),(0.5*$F))),[single]($cx+$c*$r),[single]($cy+$s*$r),[single]$tx,[single]$ty) } }
foreach($k in 'Silver','Gold'){
 $m=$MT[$k]
 $bmp=New-Object System.Drawing.Bitmap $N,$N,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
 $g=[System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::Transparent); $g.SmoothingMode='AntiAlias'; $g.PixelOffsetMode='Half'
 Blades $g @(-90,-112,-135,-158,180,158,135,112,90) (15*$F) (3.6*$F) $m
 Blades $g @(-101,-124,-146,-169,169,146,124,101) (8*$F) (2.4*$F) $m
 $pa=New-Object System.Drawing.Drawing2D.GraphicsPath
 $pa.AddPolygon([System.Drawing.PointF[]]@((P $cx ($cy-$D)),(P ($cx+$D) $cy),(P $cx ($cy+$D)),(P ($cx-$D) $cy)))
 $o=New-Object System.Drawing.Pen((C 200 0 0 0),((1.6+1.6)*$F)); $o.LineJoin='Miter'; $g.DrawPath($o,$pa)
 $p=New-Object System.Drawing.Pen((MetalBrush $m ($cy-$D-2) ($cy+$D+2)),(1.6*$F)); $p.LineJoin='Miter'; $g.DrawPath($p,$pa)
 $g.DrawPath((New-Object System.Drawing.Pen((C 150 255 255 255),(0.5*$F))),$pa)
 $bmp.Save((Join-Path $outDir "Rare$k.png"),[System.Drawing.Imaging.ImageFormat]::Png)
 $g.Dispose(); $bmp.Dispose()
 # skin Azaath: contorno de metal do triângulo do nível da placa (mesma caixa da
 # Media/Target/InkBadge.tga, 256x128 -> desenhado em 512x256)
 $bmp=New-Object System.Drawing.Bitmap 512,256,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
 $g=[System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::Transparent); $g.SmoothingMode='AntiAlias'; $g.PixelOffsetMode='Half'
 $tri=New-Object System.Drawing.Drawing2D.GraphicsPath
 $tri.AddPolygon([System.Drawing.PointF[]]@((P 62 6),(P 450 6),(P 256 244)))
 $o=New-Object System.Drawing.Pen((C 200 0 0 0),17); $o.LineJoin='Miter'; $g.DrawPath($o,$tri)
 $p=New-Object System.Drawing.Pen((MetalBrush $m 0 250),9); $p.LineJoin='Miter'; $g.DrawPath($p,$tri)
 $g.DrawPath((New-Object System.Drawing.Pen((C 150 255 255 255),2.5)),$tri)
 $bmp.Save((Join-Path $outDir "RareTri$k.png"),[System.Drawing.Imaging.ImageFormat]::Png)
 $g.Dispose(); $bmp.Dispose()
}
# Placa do alvo (Zerker): filete dourado fino em volta da barra (contorno do HPBg).
# Canvas 1024x128 (desenhado em 2048x256): a barra ocupa x 32..992 e y 32..96.
$bmp=New-Object System.Drawing.Bitmap 2048,256,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::Transparent); $g.SmoothingMode='AntiAlias'; $g.PixelOffsetMode='Half'
function BX($x){ 2*(32+$x*960/1024) }
function BY($y){ 2*(32+$y) }
$par=New-Object System.Drawing.Drawing2D.GraphicsPath
$par.AddPolygon([System.Drawing.PointF[]]@((P (BX 5) (BY 2)),(P (BX 941) (BY 2)),(P (BX 1021) (BY 62)),(P (BX 83) (BY 62))))
$o=New-Object System.Drawing.Pen((C 210 0 0 0),20); $o.LineJoin='Miter'; $g.DrawPath($o,$par)
$p=New-Object System.Drawing.Pen((C 255 255 205 90),10); $p.LineJoin='Miter'; $g.DrawPath($p,$par)
$g.DrawPath((New-Object System.Drawing.Pen((C 170 255 245 200),3)),$par)
$bmp.Save((Join-Path $outDir "TargetOutline.png"),[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()

# Placa minimalista (BDO): barra em pílula (pontas arredondadas). Desenhado em 512x32
# (o .js reduz 4x para 128x8). PlateTrack cobre a barra + 1 px de borda (88x7 na tela);
# PlateFill cobre só a barra (86x5): corpo cinza 0,85 + linha clara no topo (volume).
function Pill($g,$brush,[double]$x,[double]$y,[double]$w,[double]$h,[double]$r){ $pa=New-Object System.Drawing.Drawing2D.GraphicsPath
 $pa.AddArc([single]$x,[single]$y,[single]$r,[single]$h,90,180); $pa.AddArc([single]($x+$w-$r),[single]$y,[single]$r,[single]$h,270,180); $pa.CloseFigure()
 $g.FillPath($brush,$pa); $pa }
$bmp=New-Object System.Drawing.Bitmap 512,32,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::Transparent); $g.SmoothingMode='AntiAlias'; $g.PixelOffsetMode='Half'
$bx=512/88; $by=32/7
[void](Pill $g (New-Object System.Drawing.SolidBrush (C 145 8 5 5)) 0 0 512 32 (7*$bx))
$g.CompositingMode='SourceCopy'
[void](Pill $g (New-Object System.Drawing.SolidBrush (C 112 41 33 31)) $bx $by (512-2*$bx) (32-2*$by) (5*$bx))
$bmp.Save((Join-Path $outDir "PlateTrack.png"),[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
$bmp=New-Object System.Drawing.Bitmap 512,32,([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g=[System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::Transparent); $g.SmoothingMode='AntiAlias'; $g.PixelOffsetMode='Half'
$pa=Pill $g (New-Object System.Drawing.SolidBrush (C 255 217 217 217)) 0 0 512 32 (5*512/86)
$g.SetClip($pa); $g.FillRectangle((New-Object System.Drawing.SolidBrush (C 255 255 255 255)),0,0,512,7)
$bmp.Save((Join-Path $outDir "PlateFill.png"),[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
