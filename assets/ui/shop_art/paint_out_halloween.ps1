# Repaints the shop art: removes the Halloween header decorations (background.png) and the Halloween scene in the
# FEATURED page's left card (featured.png). Writes shop_background_plain.png / shop_featured_plain.png.
param([string]$dir)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public class Px {
    public int W, H; public byte[] D;
    public Px(string path) {
        using (var b = new Bitmap(path)) {
            W = b.Width; H = b.Height; D = new byte[W * H * 4];
            var bd = b.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            Marshal.Copy(bd.Scan0, D, 0, D.Length); b.UnlockBits(bd);
        }
    }
    public void Save(string path) {
        using (var b = new Bitmap(W, H, PixelFormat.Format32bppArgb)) {
            var bd = b.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            Marshal.Copy(D, 0, bd.Scan0, D.Length); b.UnlockBits(bd); b.Save(path, ImageFormat.Png);
        }
    }
    public void Copy(int sx, int sy, int dx, int dy) {
        if (sx < 0 || sy < 0 || dx < 0 || dy < 0 || sx >= W || dx >= W || sy >= H || dy >= H) return;
        Array.Copy(D, (sy * W + sx) * 4, D, (dy * W + dx) * 4, 4);
    }
    // every pixel in [x0,x1] x [y0,y1] takes the colour of column srcX on its row
    public void FillFromColumn(int srcX, int x0, int x1, int y0, int y1) {
        for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) Copy(srcX, y, x, y);
    }
    public void MirrorColumns(int x0, int x1, int y0, int y1, int axis2) {
        for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) Copy(axis2 - x, y, x, y);
    }
    // stamps the block [bx, bx+bw) x [by, by+bh) every `step` px from x0 up to x1 (clipped)
    public void StampRow(Px src, int bx, int by, int bw, int bh, int x0, int x1, double step) {
        for (double k = x0; k < x1; k += step) {
            int ox = (int)Math.Round(k);
            for (int y = 0; y < bh; y++) for (int x = 0; x < bw; x++) {
                int dx = ox + x; if (dx > x1) continue;
                Array.Copy(src.D, ((by + y) * src.W + bx + x) * 4, D, ((by + y) * W + dx) * 4, 4);
            }
        }
    }
    public void Set(int x, int y, int r, int g, int b) {
        int i = (y * W + x) * 4; D[i] = (byte)b; D[i + 1] = (byte)g; D[i + 2] = (byte)r; D[i + 3] = 255;
    }
    // inside the skipped button rect: leftover scene pixels (not green, not the black outline) take the card colour
    public void CleanAround(int x0, int y0, int x1, int y1, int cardY0, int cardY1, int[] top, int[] bottom) {
        for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) {
            int i = (y * W + x) * 4; int b = D[i], g = D[i + 1], r = D[i + 2];
            if (g >= 100 || r + g + b < 24) continue;
            double t = (double)(y - cardY0) / Math.Max(1, cardY1 - cardY0);
            Set(x, y, (int)(top[0] + (bottom[0] - top[0]) * t), (int)(top[1] + (bottom[1] - top[1]) * t), (int)(top[2] + (bottom[2] - top[2]) * t));
        }
    }
    public int[] Get(int x, int y) { int i = (y * W + x) * 4; return new int[] { D[i + 2], D[i + 1], D[i], D[i + 3] }; }
    // purple card interior: vertical gradient + faint square studs on a `grid` px grid
    public void StudCard(int x0, int y0, int x1, int y1, int[] top, int[] bottom, int grid, int stud, double lift, int skipX0, int skipY0, int skipX1, int skipY1) {
        for (int y = y0; y <= y1; y++) {
            double t = (double)(y - y0) / Math.Max(1, y1 - y0);
            for (int x = x0; x <= x1; x++) {
                if (x >= skipX0 && x <= skipX1 && y >= skipY0 && y <= skipY1) continue;
                double r = top[0] + (bottom[0] - top[0]) * t, g = top[1] + (bottom[1] - top[1]) * t, b = top[2] + (bottom[2] - top[2]) * t;
                int gx = (x - x0) % grid, gy = (y - y0) % grid;
                int o = (grid - stud) / 2;
                if (gx >= o && gx < o + stud && gy >= o && gy < o + stud) {
                    double f = (gy == o || gx == o) ? lift * 1.6 : lift; // lit top/left edge
                    if (gy == o + stud - 1 || gx == o + stud - 1) f = -lift * 0.8; // shadow edge
                    r += (255 - r) * Math.Max(0, f) + r * Math.Min(0, f); g += (255 - g) * Math.Max(0, f) + g * Math.Min(0, f); b += (255 - b) * Math.Max(0, f) + b * Math.Min(0, f);
                }
                Set(x, y, (int)r, (int)g, (int)b);
            }
        }
    }
}
"@
$bg = New-Object Px "$dir\background.png"
$orig = New-Object Px "$dir\background.png"
# header band: every column between the panel edge and the close button takes the clean column x=263 (between the
# pumpkin and the title), then the left edge (covered by the haunted wall) is mirrored from the clean right edge
$bg.FillFromColumn(263, 40, 906, 0, 113)
$bg.MirrorColumns(18, 43, 56, 116, 1025)
# one row of square studs along the top, copied from the clean top-left studs: they repeat every 22.5 px, so a 4-stud
# block (x 59..148, starting just after a stud shadow) tiles every 90 px; x 40..58 takes the block's last 19 px
$bg.StampRow($orig, 130, 34, 19, 20, 40, 58, 1000)
$bg.StampRow($orig, 59, 34, 90, 20, 59, 900, 90)
$bg.Save("$dir\shop_background_plain.png")
'background ok'
$fe = New-Object Px "$dir\featured.png"
"vip sample top: " + ($fe.Get(540, 20) -join ',') + " mid: " + ($fe.Get(540, 120) -join ',')
"left card edge samples: " + ($fe.Get(6, 200) -join ',') + " / " + ($fe.Get(12, 200) -join ',') + " / " + ($fe.Get(506, 200) -join ',') + " / " + ($fe.Get(250, 6) -join ',') + " / " + ($fe.Get(250, 440) -join ',')
# FEATURED left card: the Halloween scene (moon, torii, candles, pedestal, LIMITED badge, timer box) becomes a plain
# purple stud card; the frame and the painted green button stay
$fe.StudCard(11, 11, 502, 437, @(96, 44, 206), @(50, 18, 138), 28, 18, 0.07, 78, 364, 418, 437)
$fe.CleanAround(78, 364, 418, 437, 11, 437, @(96, 44, 206), @(50, 18, 138))
$fe.Save("$dir\shop_featured_plain.png")
'featured ok'
