Add-Type -AssemblyName System.Drawing
$root=Join-Path $PSScriptRoot '../../art/backgrounds/farm'
function Make-Mask($name,$spots){
 $bmp=[System.Drawing.Bitmap]::new(1672,941)
 $g=[System.Drawing.Graphics]::FromImage($bmp);$g.Clear([System.Drawing.Color]::Black)
 foreach($s in $spots){
  $path=[System.Drawing.Drawing2D.GraphicsPath]::new();$path.AddEllipse([single]$s[0],[single]$s[1],[single]$s[2],[single]$s[3])
  $b=[System.Drawing.Drawing2D.PathGradientBrush]::new($path)
  $b.CenterColor=[System.Drawing.Color]::FromArgb(255,[int]$s[4],[int]$s[5],[int]$s[6]);$b.SurroundColors=@([System.Drawing.Color]::Black)
  $g.FillPath($b,$path);$b.Dispose();$path.Dispose()
 }
 $bmp.Save((Join-Path $root $name));$g.Dispose();$bmp.Dispose()
}
# Sparse inset ellipses. No mask covers the hutch, bridges or central footpath.
Make-Mask 'environment.png' @(
 @(325,12,110,60,255,0,0),@(475,4,115,58,255,0,0),@(250,87,95,45,255,0,0),
 @(1350,30,60,65,255,0,0),@(1450,115,58,70,255,0,0),@(1520,250,90,35,255,0,0),
 @(42,408,55,45,255,0,0),@(105,445,40,45,255,0,0),@(352,629,55,65,255,0,0),
 @(831,802,65,70,255,0,0),@(910,770,45,60,255,0,0),@(1160,700,38,42,255,0,0),
 @(1190,866,90,48,0,255,0),@(1260,800,90,42,0,255,0),@(1330,878,105,42,0,255,0),
 @(1480,868,65,44,0,255,0),@(1585,827,60,73,0,255,0),
 @(255,245,80,22,0,0,255),@(405,286,92,21,0,0,255),@(478,311,65,15,0,0,255)
)
Make-Mask 'detail.png' @(
 @(316,20,100,55,95,0,0),@(478,7,110,48,95,0,0),@(1353,35,50,60,95,0,0),
 @(42,412,50,40,70,0,0),@(835,807,55,55,70,0,0),
 @(1261,184,24,30,0,255,0),@(1176,209,12,20,0,255,0)
)
