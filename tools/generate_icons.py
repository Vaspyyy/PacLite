"""Render original PacLite launcher icons from simple vector-like shapes."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import math

ROOT = Path(__file__).resolve().parents[1] / "assets"
ROOT.mkdir(exist_ok=True)


def icon(size: int, background_only: bool = False) -> Image.Image:
    scale = 4
    n = size * scale
    im = Image.new("RGBA", (n, n), (8, 14, 35, 255))
    layer = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i in range(6):
        box = [int(n * (0.06 + i * 0.014)), int(n * (0.06 + i * 0.014)),
               int(n * (0.94 - i * 0.014)), int(n * (0.94 - i * 0.014))]
        d.rounded_rectangle(box, radius=int(n * 0.17), outline=(44, 125, 212, 70 + i * 8), width=int(n * 0.006))
    dots = [(0.19, 0.30), (0.30, 0.30), (0.75, 0.30), (0.81, 0.30),
            (0.20, 0.72), (0.29, 0.72), (0.72, 0.72), (0.81, 0.72)]
    for x, y in dots:
        r = n * 0.009
        d.ellipse([n*x-r, n*y-r, n*x+r, n*y+r], fill=(250, 210, 166, 200))
    im.alpha_composite(layer)
    if background_only:
        return im.resize((size, size), Image.Resampling.LANCZOS)

    glow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy, r = n * 0.46, n * 0.51, n * 0.255
    gd.ellipse((cx-r, cy-r, cx+r, cy+r), fill=(252, 211, 76, 180))
    glow = glow.filter(ImageFilter.GaussianBlur(n * 0.055))
    im.alpha_composite(glow)
    d = ImageDraw.Draw(im)
    d.ellipse((cx-r, cy-r, cx+r, cy+r), fill=(255, 222, 91, 255))
    d.polygon([(cx, cy), (cx+r*1.08, cy-r*0.49), (cx+r*1.08, cy+r*0.49)], fill=(8, 14, 35, 255))

    gx, gy, gr = n * 0.78, n * 0.53, n * 0.12
    d.pieslice((gx-gr, gy-gr, gx+gr, gy+gr), 180, 360, fill=(255, 83, 110, 255))
    d.rectangle((gx-gr, gy, gx+gr, gy+gr*0.85), fill=(255, 83, 110, 255))
    for i in range(4):
        dx = gx-gr + (i + 0.5) * gr * 0.5
        d.ellipse((dx-gr*0.25, gy+gr*0.62, dx+gr*0.25, gy+gr*1.1), fill=(255, 83, 110, 255))
    for ex in [-gr * 0.38, gr * 0.38]:
        d.ellipse((gx+ex-gr*0.27, gy-gr*0.26, gx+ex+gr*0.27, gy+gr*0.28), fill="white")
        d.ellipse((gx+ex, gy-gr*0.06, gx+ex+gr*0.16, gy+gr*0.12), fill=(17, 29, 66, 255))
    return im.resize((size, size), Image.Resampling.LANCZOS)


if __name__ == "__main__":
    for name, size, background_only in [
        ("icon_192.png", 192, False),
        ("icon_432.png", 432, False),
        ("icon_bg_432.png", 432, True),
    ]:
        icon(size, background_only).quantize(
            colors=32, method=Image.Quantize.FASTOCTREE
        ).save(ROOT / name, optimize=True)
