#!/usr/bin/env python3
"""Gera o ícone do app, a imagem de destaque da Play e a tela de abertura (Pillow).

    python3 tools/gen_store_art.py

Escreve icon.png (512², ícone do projeto e do Android), assets/store/feature-1024x500.png,
assets/store/icon-512.png e assets/ui/splash.png. Mesma paleta das telas (UiTheme / ScreenBackdrop).
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SKY_TOP, SKY_LOW = (26, 92, 143), (250, 184, 122)
SEA, SAND, INK = (26, 128, 153), (219, 186, 133), (13, 31, 51)
BALL, BAND, ORANGE = (255, 219, 51), (31, 89, 217), (250, 128, 56)
FONT = os.path.join(ROOT, "assets", "fonts", "Fredoka.ttf")


def grad(d, box, top, bottom):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        u = (y - y0) / max(1, y1 - y0 - 1)
        d.line([(x0, y), (x1, y)], fill=tuple(int(a + (b - a) * u) for a, b in zip(top, bottom)))


def beach(w, h, horizon=0.58):
    img = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(img)
    hy = int(h * horizon)
    grad(d, (0, 0, w, hy), SKY_TOP, SKY_LOW)
    r = int(h * 0.12)
    d.ellipse([w * 0.7 - r, hy - r * 0.9, w * 0.7 + r, hy + r * 1.1], fill=(255, 219, 140))
    grad(d, (0, hy, w, int(h * 0.74)), (46, 150, 168), (20, 105, 128))
    grad(d, (0, int(h * 0.74), w, h), (230, 200, 150), (205, 170, 118))
    return img


def ball(img, cx, cy, r):
    """Bola amarela com faixas azuis curvas e sombra."""
    big = Image.new("RGBA", (r * 8, r * 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    c, R = r * 4, r * 4 - 8
    d.ellipse([c - R, c - R, c + R, c + R], fill=BALL + (255,), outline=INK + (255,), width=max(4, R // 14))
    for k in (-1, 0, 1):
        off = k * R * 0.55
        d.arc([c - R * 1.6 + off, c - R * 1.1, c + R * 0.4 + off, c + R * 1.1], 290, 70, fill=BAND + (255,), width=R // 6)
    d.ellipse([c - R * 0.55, c - R * 0.7, c - R * 0.15, c - R * 0.35], fill=(255, 248, 210, 255))
    mask = Image.new("L", big.size, 0)
    ImageDraw.Draw(mask).ellipse([c - R, c - R, c + R, c + R], fill=255)
    clipped = Image.new("RGBA", big.size, (0, 0, 0, 0))
    clipped.paste(big, (0, 0), mask)
    ImageDraw.Draw(clipped).ellipse([c - R, c - R, c + R, c + R], outline=INK + (255,), width=max(4, R // 14))
    small = clipped.resize((r * 2, r * 2), Image.LANCZOS)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([cx - r * 0.9, cy + r * 1.05, cx + r * 0.9, cy + r * 1.35], fill=(0, 0, 0, 90))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(r // 10)))
    img.alpha_composite(small, (cx - r, cy - r))


def net(d, x0, x1, y, h):
    for x in range(int(x0), int(x1), max(6, int(h / 6))):
        d.line([(x, y), (x, y + h)], fill=INK, width=2)
    for k in range(6):
        yy = y + k * h / 5
        d.line([(x0, yy), (x1, yy)], fill=INK, width=2)
    d.rectangle([x0, y - h * 0.08, x1, y + h * 0.04], fill=(250, 250, 250))


def text(d, xy, s, size, fill=(255, 255, 255), anchor="mm"):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([600, 100])
    except Exception:
        pass
    d.text(xy, s, font=f, fill=fill, anchor=anchor, stroke_width=max(3, size // 9), stroke_fill=INK)


def icon(size=512):
    img = beach(size, size, 0.6).convert("RGBA")
    d = ImageDraw.Draw(img)
    net(d, -10, size + 10, size * 0.6, size * 0.16)
    ball(img, int(size * 0.5), int(size * 0.4), int(size * 0.27))
    # cantos arredondados (o Android recorta de novo, mas a Play mostra assim)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=size // 6, fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def feature():
    img = beach(1024, 500).convert("RGBA")
    d = ImageDraw.Draw(img)
    net(d, 560, 1060, 300, 70)
    ball(img, 800, 170, 95)
    text(d, (290, 210), "VÔLEI", 118)
    text(d, (290, 320), "MOBILE", 92, fill=(255, 210, 160))
    text(d, (290, 410), "segure · mire · solte", 34)
    return img


def splash():
    img = beach(1280, 720).convert("RGBA")
    d = ImageDraw.Draw(img)
    ball(img, 640, 300, 120)
    text(d, (640, 520), "VÔLEI MOBILE", 84)
    return img


def save(img, *path):
    p = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p, optimize=True)
    print(p)


if __name__ == "__main__":
    ic = icon()
    save(ic, "icon.png")
    save(ic, "assets", "store", "icon-512.png")
    save(feature().convert("RGB"), "assets", "store", "feature-1024x500.png")
    save(splash().convert("RGB"), "assets", "ui", "splash.png")
