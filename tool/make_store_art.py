"""Ripe Rhythm emblem, launcher icon and Play Store art.

Generates:
  assets/icon/logo.png               1024x1024 RGBA  emblem on transparency
  assets/icon/icon_foreground.png    1024x1024 RGBA  emblem edge-to-edge (adaptive icon
                                                     foreground; flutter_launcher_icons insets it)
  assets/icon/icon_full.png          1024x1024 RGB   emblem over Leaf Deep (#3D6B4F), legacy icons
  store/icon-512.png                 512x512   RGB   icon_full resized
  store/feature-graphic.png          1024x500  RGB   orchard dawn + emblem + "Ripe Rhythm" wordmark

The emblem: one painterly round-canopied tree on a dawn-sky disc, held by a
Ripe Gold band ring and two fading cream echo rings. Shares the gouache
painting toolkit in tool/make_art.py; deterministic (fixed seeds).

Run from the project root:
    python tool/make_store_art.py
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_art as A  # noqa: E402
from make_art import (CREAM, INK, LEAF, GOLD, DUSK, PI, Canvas, Dabs, hx, mix, grid,  # noqa: E402
                      smoothstep, fbm, blur, texture, paint_tree, small_tree, ridge, hill, sky)

ROOT = A.ROOT
ICON_DIR = os.path.join(ROOT, 'assets', 'icon')
STORE_DIR = os.path.join(ROOT, 'store')
FONT = os.path.join(ROOT, 'assets', 'fonts', 'Fraunces-Bold.ttf')

DAWN_TOP, DAWN_BOT = hx('FCE7C8'), hx('F6D2C4')
DAWN_LIGHT = hx('FFF0B8')
EMBLEM_TREE = dict(
    ramp=[mix(hx('4E8A4A'), INK, 0.45), hx('4E8A4A'), hx('6FAE5C'), hx('9CCB7E'),
          mix(hx('9CCB7E'), DAWN_LIGHT, 0.55)],
    rim=mix(GOLD, CREAM, 0.45), rim_amt=0.9, rim_w=6, light=(0.55, -0.75, 0.55))


def ring_mask(xx, yy, cx, cy, r, half, wob, rng, n_cell):
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    edge = fbm(xx.shape[0], xx.shape[1], n_cell, 3, rng) * wob
    return smoothstep(half + 1.2, half - 1.2, np.abs(d - r) + edge)


def emblem(N, outer=0.485, seed=900):
    """Paint the emblem on an N x N transparent canvas; outer = outer ring radius / N."""
    rng = np.random.default_rng(seed)
    cv = Canvas(N, N)
    yy, xx = grid(N, N)
    c = N / 2
    k = outer / 0.485
    rd = 0.335 * N * k          # sky disc radius
    # -- the dawn disc, painted on its own opaque canvas then clipped
    sc = Canvas(N, N, DAWN_TOP)
    sun = (c + 0.16 * N * k, c - 0.02 * N * k, 0.22 * N * k, DAWN_LIGHT, 0.95)
    top = mix(DAWN_TOP, hx('C9D8E6'), 0.25)
    sky(sc, top, DAWN_BOT, rng, N / 1024, horizon=c + 0.12 * N * k, sun=sun, strokes=2500)
    s = N / 1024
    hz = mix(DAWN_BOT, DAWN_LIGHT, 0.3)
    xs = np.arange(N)
    far = c + 0.12 * N * k + 0.02 * N * k * np.sin(xs / N * 5.0 + 1.0)
    hill(sc, far, (mix(hx('A9D0A0'), DAWN_LIGHT, 0.35), hx('A9D0A0'), hx('82B884')), rng, s,
         haze=hz, haze_t=0.35, rim=DAWN_LIGHT, rim_amt=0.5, light_from=1, sun_x=sun[0],
         calm=0.6, tex_n=1500, edge=2)
    mound = c + 0.20 * N * k + 0.10 * N * k * ((xs - c) / (0.34 * N * k)) ** 2
    hill(sc, mound, (mix(hx('82B884'), DAWN_LIGHT, 0.35), hx('82B884'), hx('5E9A66')), rng, s,
         rim=mix(DAWN_LIGHT, GOLD, 0.25), rim_amt=0.8, light_from=1, sun_x=sun[0], calm=1.0,
         tex_n=2500, edge=2)
    R = 0.168 * N * k
    tcx, tcy = c - 0.005 * N, c - 0.075 * N * k
    A.contact_shadow(sc, c - 0.03 * N * k, c + 0.205 * N * k, R * 0.8, R * 0.12, 0.3)
    paint_tree(sc, tcx, tcy, R, c, c + 0.205 * N * k, EMBLEM_TREE, rng)
    disc = smoothstep(rd + 1.0, rd - 1.0, np.sqrt((xx - c) ** 2 + (yy - c) ** 2))
    # soft inner shade under the gold band so the disc sits inside the ring
    dd = np.sqrt((xx - c) ** 2 + (yy - c) ** 2)
    inner = smoothstep(rd - 0.03 * N * k, rd, dd) * disc
    sc.paint(inner, INK, 0.22)
    cv.paint(disc, sc.rgb)
    # -- Ripe Gold band ring with brushy tone variation
    band_r, band_h = 0.358 * N * k, 0.03 * N * k
    gm = ring_mask(xx, yy, c, c, band_r, band_h, 0.006 * N, rng, 0.03 * N)
    ang = np.arctan2(yy - c, xx - c)
    lit = 0.5 + 0.5 * np.cos(ang - math.atan2(-0.75, 0.55))
    gcol = A.ramp(np.clip(lit * 0.75 + fbm(N, N, 0.02 * N, 3, rng) * 0.25 + 0.1, 0, 1),
                  [mix(GOLD, hx('8A5A30'), 0.4), mix(GOLD, hx('B07A3E'), 0.2), GOLD,
                   mix(GOLD, CREAM, 0.35)])
    radial = (dd - band_r) / band_h
    gcol = mix(gcol, mix(GOLD, CREAM, 0.5), np.clip(-radial, 0, 1) ** 2 * 0.35 * (lit > 0.4))
    cv.paint(gm, gcol)
    texture(cv, gm, rng, int(N * 3.2), 0.012 * N, jitter=0.06, alpha=(0.3, 0.6), elong=3.5,
            angle=ang + PI / 2, angle_jit=0.1, clip=gm)
    # -- two cream echo rings, the outer one fainter and dry-brushed
    for (rr, half, op, dry) in [(0.418, 0.0115, 0.95, 0.0), (0.468, 0.0085, 0.75, 0.35)]:
        m = ring_mask(xx, yy, c, c, rr * N * k, half * N * k, 0.004 * N, rng, 0.02 * N)
        if dry:
            streak = A.fbm_stretch(N, N, 0.01 * N, 2, rng, sx=1, sy=1)
            m = m * np.clip(1 - dry + streak * 1.6, 0, 1)
        col = mix(CREAM, DAWN_LIGHT, 0.25 + 0.25 * lit)
        cv.paint(m, col, op)
        texture(cv, m, rng, int(N * 1.6), 0.008 * N, jitter=0.03, alpha=(0.3, 0.5), elong=4,
                angle=ang + PI / 2, angle_jit=0.1, clip=m, where=0.3)
    return cv


def to_rgba(cv, size):
    return A.to_image(cv, (size, size))


def leaf_background(N, rng):
    bg = Canvas(N, N, LEAF)
    yy, xx = grid(N, N)
    d = np.sqrt((xx - N * 0.42) ** 2 + (yy - N * 0.38) ** 2) / N
    col = mix(mix(LEAF, hx('5E9A66'), 0.18), mix(LEAF, INK, 0.18), smoothstep(0.1, 0.75, d))
    bg.paint(np.ones((N, N), np.float32), col)
    texture(bg, np.ones((N, N), np.float32), rng, 2600, 0.03 * N, jitter=0.035, alpha=(0.15, 0.35),
            elong=2.5, hue=0.2)
    return bg


def draw_wordmark(img, tx, ty, size, text='Ripe Rhythm'):
    """Set the wordmark in Fraunces Bold (cream, soft ink shadow), left-anchored at (tx, ty).

    Only the bundled OFL Fraunces is used. If it cannot be loaded (e.g. the file is a
    failed download), the wordmark is skipped with a warning: no system-font substitute,
    since those licences do not allow bundling. Re-run once the font is fixed."""
    try:
        font = ImageFont.truetype(FONT, size)
    except OSError as e:
        print('WARNING: could not load assets/fonts/Fraunces-Bold.ttf '
              f'({e}); store/feature-graphic.png was written WITHOUT the "{text}" wordmark. '
              'Replace the font with the real OFL Fraunces and re-run this script.')
        return False
    tl = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(tl).text((tx + 2, ty + 5), text, font=font, anchor='lm',
                            fill=tuple(int(v * 255) for v in INK) + (150,))
    tl = tl.filter(ImageFilter.GaussianBlur(6))
    img.alpha_composite(tl)
    ImageDraw.Draw(img).text((tx, ty), text, font=font, anchor='lm',
                             fill=tuple(int(v * 255) for v in CREAM) + (255,))
    return True


def feature_graphic(emb_img):
    W, H, S = 1024, 500, 2
    w, h = W * S, H * S
    rng = np.random.default_rng(950)
    cv = Canvas(w, h, DAWN_TOP)
    top = mix(DAWN_TOP, hx('C9D8E6'), 0.25)
    sx, sy = 0.8 * w, 0.36 * h
    sky(cv, top, mix(DAWN_BOT, DAWN_LIGHT, 0.2), rng, S, horizon=h * 0.45,
        sun=(sx, sy, 0.16 * w, DAWN_LIGHT, 0.95), strokes=5000)
    yy, xx = grid(h, w)
    disc = np.sqrt((xx - sx) ** 2 + (yy - sy) ** 2)
    cv.paint(1 - smoothstep(26 * S, 34 * S, disc), mix(DAWN_LIGHT, CREAM, 0.5), 0.9)
    for (cx, cy, cw, ch) in [(0.62, 0.17, 0.3, 0.07), (0.93, 0.12, 0.2, 0.05), (0.35, 0.1, 0.26, 0.05)]:
        A.cloud(cv, rng, cx * w, cy * h, cw * w, ch * h, mix(CREAM, DAWN_LIGHT, 0.6),
                mix(mix(DAWN_BOT, hx('F3B6C6'), 0.35), DUSK, 0.1), S, op=0.6, flat=0.55)
    H0, H1, H2 = hx('A9D0A0'), hx('82B884'), hx('5E9A66')
    hz = mix(DAWN_BOT, DAWN_LIGHT, 0.3)
    rim = mix(DAWN_LIGHT, CREAM, 0.2)
    far = ridge(w, h * 0.43, h * 0.03, 160 * S, rng, 3)
    hill(cv, far, (mix(H0, DAWN_LIGHT, 0.35), H0, H1), rng, S, haze=hz, haze_t=0.5, rim=rim,
         rim_amt=0.5, light_from=1, sun_x=sx, calm=0.5, tex_n=3000, edge=2)
    xs_ = np.arange(w) / w
    midp = h * (0.50 + 0.06 * np.sin(xs_ * 4.0 + 0.5)) + A.noise1d(w, 120 * S, rng, 3) * 6 * S
    hill(cv, midp, (mix(H1, DAWN_LIGHT, 0.3), H1, H2), rng, S, haze=hz, haze_t=0.15, rim=rim,
         rim_amt=0.6, light_from=1, sun_x=sx, calm=0.9, tex_n=6000, edge=3)
    # orchard rows on the right-hand slope
    D = Dabs(rng)
    trees = []
    for k in range(5):
        v = (k + 1) / 5
        r = (6 + 10 * v) * S
        x = 0.5 * w + rng.uniform(0, r * 3)
        while x < w + r:
            yb = midp[int(min(w - 1, x))] + (14 + 120 * v) * S + rng.normal(0, 2 * S)
            trees.append((yb, x, r, v))
            x += r * 3.4 * rng.uniform(0.85, 1.2)
    trees.sort()
    gr = [mix(H2, INK, 0.3), H2, H1, mix(H0, DAWN_LIGHT, 0.45)]
    for yb, x, r, v in trees:
        hz_t = (1 - v) * 0.2
        small_tree(D, x, yb, r, [mix(c_, hz, hz_t) for c_ in gr], rng, light=(0.8, -0.6),
                   blossom=hx('F3B6C6') if (int(x) // 7) % 3 == 0 else None,
                   rim=mix(rim, hz, hz_t), shadow_a=0.2)
    cv.dabs(D)
    # deep near hill on the left that holds the wordmark
    near = h * (0.31 + 0.36 * np.clip((xs_ - 0.3) / 0.7, 0, 1) ** 1.8) + A.noise1d(w, 140 * S, rng, 3) * 8 * S
    dk = mix(hx('4E8A4A'), INK, 0.28)
    hill(cv, near, (mix(hx('5E9A66'), DAWN_LIGHT, 0.12), hx('4E8A4A'), dk), rng, S, rim=rim,
         rim_amt=0.55, light_from=1, sun_x=sx, calm=0.6, tex_n=8000, edge=3)
    D = Dabs(rng)
    n = 3000
    gx = rng.uniform(0, w, n)
    gy = np.sort(near[gx.astype(int).clip(0, w - 1)] + rng.uniform(0, 1, n) ** 0.7 * 400 * S)
    gy = np.minimum(gy, h + 10)
    L_ = rng.uniform(5, 14, n) * S
    a_ = -PI / 2 + rng.normal(0, 0.25, n)
    cs = cv.sample(gx, gy) * (1 + 0.08 * rng.standard_normal(n))[:, None]
    D.add(gx + np.cos(a_) * L_ * 0.8, gy + np.sin(a_) * L_ * 0.8, L_, L_ / 6, a_, cs, 0.6, n=8,
          shape='leaf')
    cv.dabs(D)
    A.grain(cv, rng, 0.03)
    img = Image.fromarray(A.to8(cv.rgb)).resize((W, H), Image.LANCZOS).convert('RGBA')
    # emblem, left
    es = 250
    emb = emb_img.resize((es, es), Image.LANCZOS)
    sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ea = np.asarray(emb)[..., 3]
    shadow = Image.new('RGBA', (es, es), tuple(int(v * 255) for v in INK) + (0,))
    shadow.putalpha(Image.fromarray((ea * 0.35).astype(np.uint8)))
    ex, ey = 34, (H - es) // 2 + 6
    sh.alpha_composite(shadow, (ex + 4, ey + 10))
    sh = sh.filter(ImageFilter.GaussianBlur(10))
    img.alpha_composite(sh)
    img.alpha_composite(emb, (ex, ey))
    draw_wordmark(img, ex + es + 18, H // 2 - 4, 66)
    return img.convert('RGB')


def main():
    os.makedirs(ICON_DIR, exist_ok=True)
    os.makedirs(STORE_DIR, exist_ok=True)
    os.makedirs(A.IMG_DIR, exist_ok=True)
    N = 2048
    # icon foreground: rings reach the edge; logo: same emblem with a little air
    fg = to_rgba(emblem(N, outer=0.485), 1024)
    fg.save(os.path.join(ICON_DIR, 'icon_foreground.png'), optimize=True)
    logo = to_rgba(emblem(N, outer=0.455, seed=901), 1024)
    logo.save(os.path.join(ICON_DIR, 'logo.png'), optimize=True)
    rng = np.random.default_rng(960)
    bg = leaf_background(1024, rng)
    full = Image.fromarray(A.to8(bg.rgb)).convert('RGBA')
    small = fg.resize((860, 860), Image.LANCZOS)
    sh = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    sa = np.asarray(small)[..., 3]
    shadow = Image.new('RGBA', small.size, tuple(int(v * 255) for v in INK) + (0,))
    shadow.putalpha(Image.fromarray((sa * 0.4).astype(np.uint8)))
    sh.alpha_composite(shadow, (82, 96))
    sh = sh.filter(ImageFilter.GaussianBlur(14))
    full.alpha_composite(sh)
    full.alpha_composite(small, (82, 82))
    full = full.convert('RGB')
    full.save(os.path.join(ICON_DIR, 'icon_full.png'), optimize=True)
    full.resize((512, 512), Image.LANCZOS).save(os.path.join(STORE_DIR, 'icon-512.png'), optimize=True)
    feature_graphic(logo).save(os.path.join(STORE_DIR, 'feature-graphic.png'), optimize=True)
    for p in [os.path.join(ICON_DIR, 'logo.png'), os.path.join(ICON_DIR, 'icon_foreground.png'),
              os.path.join(ICON_DIR, 'icon_full.png'), os.path.join(STORE_DIR, 'icon-512.png'),
              os.path.join(STORE_DIR, 'feature-graphic.png')]:
        print(f'  {os.path.relpath(p, ROOT)}  {os.path.getsize(p) / 1024:.0f} KB')


if __name__ == '__main__':
    main()
