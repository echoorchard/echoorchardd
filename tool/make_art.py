"""Ripe Rhythm bitmap art generator (storybook gouache, procedural).

Generates every in-game bitmap into ``assets/images/``:
  * row backgrounds  bg_{spring,summer,autumn,winter,moon}.jpg   1080x1920
  * splash.jpg                                                    1080x1920
  * hub bands        hub_{spring,summer,autumn,winter,moon}.jpg   1080x1440
  * trees            tree_{season}.png                            360x480
  * fruit            fruit_{apple,pear,plum,peach}.png            96x96
  * baskets          basket_{willow,rush,cedar,birch,moon}.png    480x300
  * keepsakes        keep_{lantern,beehive,scarecrow,windmill,swing,birdhouse}.png 240x240
  * hub props        stake.png 96x160, sapling.png 120x150, mist.png 1080x400

Style: noise-displaced layered hills, thousands of small semi-transparent
brush dabs sampled from the underlying paint, soft-posterised gouache
shading, warm rim light, atmospheric perspective. Only the palette in
docs/DESIGN_LANGUAGE.md (and tones mixed from it) is used. Every element is
drawn from a fixed random seed, so output is deterministic. Everything is
painted above target resolution and LANCZOS-downsampled.

Run from the project root (Python 3 + Pillow + numpy only):
    python tool/make_art.py                 # everything
    python tool/make_art.py trees fruit     # only some groups
Groups: bg splash hub trees fruit baskets keepsakes props
"""
import math
import os
import sys
import time

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG_DIR = os.path.join(ROOT, 'assets', 'images')
PI = math.pi


# --------------------------------------------------------------------------
# palette
# --------------------------------------------------------------------------
def hx(s):
    s = s.lstrip('#')
    return np.array([int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def mix(a, b, t):
    """Blend colours/arrays; t has no channel axis (it is expanded)."""
    a = np.asarray(a, np.float32)
    b = np.asarray(b, np.float32)
    t = np.asarray(t, np.float32)
    if t.ndim > 0:
        t = t[..., None]
    return a + (b - a) * t


CREAM, INK, LEAF, GOLD, DUSK = (hx('FFF6E8'), hx('2C2416'), hx('3D6B4F'),
                                hx('E8A838'), hx('5E4B6E'))
WHITE = hx('FFFFFF')
SEASON = {
    'spring': dict(sky=(hx('FCE7C8'), hx('F6D2C4')), light=hx('FFF0B8'),
                   hills=(hx('A9D0A0'), hx('82B884'), hx('5E9A66')), sig=hx('F3B6C6')),
    'summer': dict(sky=(hx('FFE9A8'), hx('BFE3D0')), light=hx('FFF6D0'),
                   hills=(hx('9CCB7E'), hx('6FAE5C'), hx('4E8A4A')), sig=hx('F7D46A')),
    'autumn': dict(sky=(hx('F7C98B'), hx('E9A46A')), light=hx('FFE0A3'),
                   hills=(hx('C9A15A'), hx('B07A3E'), hx('8A5A30')), sig=hx('D9733A')),
    'winter': dict(sky=(hx('E6EEF5'), hx('C9D8E6')), light=WHITE,
                   hills=(hx('DDE6EE'), hx('B9C9D8'), hx('93A9BF')), sig=WHITE),
    'moon': dict(sky=(hx('2C2A4A'), hx('4B3F6B')), light=hx('FFE6B0'),
                 hills=(hx('3B4A5E'), hx('2E3C4E'), hx('22303F')), sig=GOLD),
}
FRUIT = dict(apple=hx('C8463D'), pear=hx('C9B33F'), plum=hx('7A4E8C'), peach=hx('F2B38A'))
BARK = mix(INK, hx('8A5A30'), 0.45)
BARK_LIGHT = mix(hx('8A5A30'), hx('C9A15A'), 0.35)
MIST = mix(CREAM, hx('C9D8E6'), 0.25)
LIGHT = (-0.55, -0.72, 0.55)  # upper-left key light for sprites


def tones(base, light=None, n=5, cool=0.25, deep=0.42, lift=0.5):
    """Gouache value ramp (dark -> light) derived from one colour."""
    light = CREAM if light is None else light
    sh = mix(mix(base, DUSK, cool), INK, deep)
    return [sh, mix(base, INK, deep * 0.45), base, mix(base, light, lift * 0.55),
            mix(base, light, lift)][:n]


# --------------------------------------------------------------------------
# numeric helpers
# --------------------------------------------------------------------------
def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def vnoise(h, w, cell, rng):
    cell = max(float(cell), 1.0)
    gh, gw = int(h / cell) + 4, int(w / cell) + 4
    g = rng.random((gh, gw), dtype=np.float32)
    big = Image.fromarray(g, 'F').resize((int(gw * cell), int(gh * cell)), Image.BICUBIC)
    a = np.asarray(big)
    oy = int(rng.integers(0, int(cell) + 1))
    ox = int(rng.integers(0, int(cell) + 1))
    return a[oy:oy + h, ox:ox + w]


def fbm(h, w, cell, octaves, rng, persist=0.5):
    """Zero-mean fractal value noise with std ~0.25."""
    tot = np.zeros((h, w), np.float32)
    amp = 1.0
    for _ in range(octaves):
        if cell < 1.2:
            break
        tot += amp * (vnoise(h, w, cell, rng) - 0.5)
        amp *= persist
        cell /= 2.0
    tot -= tot.mean()
    return tot / (tot.std() + 1e-6) * 0.25


def fbm_stretch(h, w, cell, octaves, rng, sx=1.0, sy=1.0):
    """Anisotropic fbm (stretched sx horizontally, sy vertically)."""
    hh, ww = max(2, int(h / sy)), max(2, int(w / sx))
    n = fbm(hh, ww, cell, octaves, rng)
    return np.asarray(Image.fromarray(n, 'F').resize((w, h), Image.BILINEAR))


def noise1d(n, cell, rng, octaves=4):
    tot = np.zeros(n, np.float32)
    amp, asum = 1.0, 0.0
    for _ in range(octaves):
        if cell < 2:
            break
        k = int(n / cell) + 3
        knots = rng.uniform(-1, 1, k)
        xs = np.arange(n) / cell + rng.random()
        i = np.floor(xs).astype(int)
        f = xs - i
        f = f * f * (3 - 2 * f)
        tot += amp * (knots[i] * (1 - f) + knots[i + 1] * f)
        asum += amp
        amp *= 0.5
        cell /= 2.0
    return tot / asum


def _box(a, r, axis):
    a = np.moveaxis(a, axis, 0)
    pad = [(r + 1, r)] + [(0, 0)] * (a.ndim - 1)
    p = np.pad(a, pad, mode='edge')
    c = np.cumsum(p, axis=0, dtype=np.float64)
    out = (c[2 * r + 1:] - c[:-(2 * r + 1)]) / (2 * r + 1)
    return np.moveaxis(out.astype(np.float32), 0, axis)


def blur(a, r, passes=3):
    r = int(round(r))
    if r < 1:
        return a.astype(np.float32)
    a = a.astype(np.float32)
    for _ in range(passes):
        a = _box(_box(a, r, 0), r, 1)
    return a


def grid(h, w):
    g = np.mgrid[0:h, 0:w].astype(np.float32)
    return g[0], g[1]


def lambert(h, light, k=1.0):
    gy, gx = np.gradient(h * k)
    lx, ly, lz = light
    ln = math.sqrt(lx * lx + ly * ly + lz * lz)
    return (-gx * lx - gy * ly + lz) / (ln * np.sqrt(gx * gx + gy * gy + 1.0))


def tangent(h):
    gy, gx = np.gradient(h)
    return np.arctan2(gy, gx) + PI / 2


def soft_poster(t, levels, soft=0.35):
    x = np.clip(t, 0, 0.9999) * levels
    fl = np.floor(x)
    f = x - fl
    return (fl + smoothstep(0.5 - soft / 2, 0.5 + soft / 2, f)) / levels


def ramp(t, cols):
    C = np.stack([np.asarray(c, np.float32) for c in cols])
    t = np.clip(np.nan_to_num(t), 0, 1) * (len(cols) - 1)
    i = np.minimum(np.floor(t).astype(int), len(cols) - 2)
    f = (t - i)[..., None]
    return C[i] * (1 - f) + C[i + 1] * f


def to8(a):
    return (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)


# --------------------------------------------------------------------------
# canvas + brush dabs
# --------------------------------------------------------------------------
class Canvas:
    def __init__(self, w, h, color=None):
        self.w, self.h = w, h
        self.rgb = np.zeros((h, w, 3), np.float32)
        self.a = np.zeros((h, w), np.float32)
        if color is not None:
            self.rgb[:] = color
            self.a[:] = 1.0

    def paint(self, mask, color, op=1.0, at=None):
        color = np.asarray(color, np.float32)
        if at is None:
            sl = (slice(None), slice(None))
            m = mask
        else:
            x0, y0 = int(at[0]), int(at[1])
            mh, mw = mask.shape
            X0, Y0 = max(0, x0), max(0, y0)
            X1, Y1 = min(self.w, x0 + mw), min(self.h, y0 + mh)
            if X1 <= X0 or Y1 <= Y0:
                return
            m = mask[Y0 - y0:Y1 - y0, X0 - x0:X1 - x0]
            if color.ndim == 3:
                color = color[Y0 - y0:Y1 - y0, X0 - x0:X1 - x0]
            sl = (slice(Y0, Y1), slice(X0, X1))
        m = np.clip(m * op, 0, 1).astype(np.float32)
        if color.ndim == 1:
            color = color[None, None, :]
        a0 = self.a[sl]
        an = m + a0 * (1 - m)
        self.rgb[sl] = ((color * m[..., None] + self.rgb[sl] * (a0 * (1 - m))[..., None])
                        / np.maximum(an, 1e-6)[..., None])
        self.a[sl] = an

    def dabs(self, D, clip=None):
        if not D.items:
            return
        base8 = to8(self.rgb)
        img = Image.fromarray(base8)
        dr = ImageDraw.Draw(img, 'RGBA')
        for poly, col in D.items:
            dr.polygon(poly, fill=col)
        delta = (np.asarray(img).astype(np.float32) - base8.astype(np.float32)) / 255.0
        if clip is not None:
            delta *= clip[..., None]
        self.rgb += delta
        D.items = []

    def sample(self, xs, ys):
        xi = np.clip(np.asarray(xs).astype(int), 0, self.w - 1)
        yi = np.clip(np.asarray(ys).astype(int), 0, self.h - 1)
        return self.rgb[yi, xi].copy()


class Dabs:
    """Accumulates semi-transparent polygon brush marks, drawn in order."""

    def __init__(self, rng=None):
        self.items = []
        self.rng = rng if rng is not None else np.random.default_rng(7)

    def add(self, x, y, rx, ry, ang, col, alpha, n=12, wobble=0.12, shape='oval'):
        x, y, rx, ry, ang, alpha = np.broadcast_arrays(
            *[np.atleast_1d(np.asarray(v, np.float64)) for v in (x, y, rx, ry, ang, alpha)])
        N = len(x)
        col = np.asarray(col, np.float64)
        if col.ndim == 1:
            col = np.broadcast_to(col, (N, 3))
        t = np.linspace(0, 2 * PI, n, endpoint=False)
        ex = np.cos(t)[None, :]
        ey = np.sin(t)[None, :]
        if shape == 'leaf':
            ey = ey * np.abs(ey) ** 0.6
        wob = 1 + wobble * (self.rng.random((N, n)) - 0.5) * 2
        ex = ex * wob
        ey = ey * wob
        ca = np.cos(ang)[:, None]
        sa = np.sin(ang)[:, None]
        px = x[:, None] + rx[:, None] * ex * ca - ry[:, None] * ey * sa
        py = y[:, None] + rx[:, None] * ex * sa + ry[:, None] * ey * ca
        pts = np.stack([px, py], 2)
        c8 = np.clip(col * 255 + 0.5, 0, 255).astype(int)
        a8 = np.clip(alpha * 255 + 0.5, 0, 255).astype(int)
        for i in range(N):
            if a8[i] <= 0:
                continue
            self.items.append((pts[i].ravel().tolist(),
                               (int(c8[i, 0]), int(c8[i, 1]), int(c8[i, 2]), int(a8[i]))))

    def seg(self, x0, y0, x1, y1, w0, w1, col, alpha):
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy) + 1e-6
        nx, ny = -dy / L, dx / L
        pts = [x0 + nx * w0 / 2, y0 + ny * w0 / 2, x1 + nx * w1 / 2, y1 + ny * w1 / 2,
               x1 - nx * w1 / 2, y1 - ny * w1 / 2, x0 - nx * w0 / 2, y0 - ny * w0 / 2]
        c = tuple(int(v) for v in np.clip(np.asarray(col) * 255 + 0.5, 0, 255)) + (
            int(alpha * 255),)
        self.items.append((pts, c))
        if w1 > 1.5:
            self.add(x1, y1, w1 / 2, w1 / 2, 0, col, alpha, n=10, wobble=0)


def texture(cv, mask, rng, n, size, jitter=0.05, alpha=(0.15, 0.4), elong=2.0,
            angle=None, angle_jit=0.25, tint=None, tint_amt=0.0, clip=None,
            where=0.5, shape='oval', hue=0.35):
    """Brush pass: dabs whose colour is sampled from the paint underneath."""
    idx = np.flatnonzero(mask.ravel() > where)
    if len(idx) == 0 or n <= 0:
        return
    pick = rng.choice(idx, int(n))
    ys, xs = np.divmod(pick, cv.w)
    ys = ys + rng.random(len(ys))
    xs = xs + rng.random(len(xs))
    cols = cv.sample(xs, ys)
    v = 1 + jitter * rng.standard_normal(len(xs))
    cols = cols * v[:, None] + rng.standard_normal((len(xs), 3)) * jitter * hue
    if tint is not None:
        cols = mix(cols, tint, tint_amt * rng.random(len(xs)))
    if angle is None:
        ang = rng.random(len(xs)) * PI
    elif np.ndim(angle) == 2:
        ang = angle[ys.astype(int), xs.astype(int)] + rng.normal(0, angle_jit, len(xs))
    else:
        ang = angle + rng.normal(0, angle_jit, len(xs))
    rx = size * (0.6 + 0.8 * rng.random(len(xs)))
    ry = rx / elong * (0.75 + 0.5 * rng.random(len(xs)))
    a = rng.uniform(alpha[0], alpha[1], len(xs))
    D = Dabs(rng)
    D.add(xs, ys, rx, ry, ang, cols, a, n=10, shape=shape)
    cv.dabs(D, clip)


class Layer:
    """Opaque shape mask drawn with PIL (anti-aliased later by downsampling)."""

    def __init__(self, w, h):
        self.im = Image.new('L', (w, h), 0)
        self.d = ImageDraw.Draw(self.im)

    def poly(self, pts, v=255):
        self.d.polygon([tuple(p) for p in pts], fill=v)
        return self

    def ellipse(self, cx, cy, rx, ry, v=255):
        self.d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=v)
        return self

    def line(self, pts, width, v=255):
        pts = [tuple(p) for p in pts]
        self.d.line(pts, fill=v, width=max(1, int(width)), joint='curve')
        r = width / 2
        for p in (pts[0], pts[-1]):
            self.d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=v)
        return self

    def taper(self, pts, w0, w1, v=255):
        """Polyline whose width tapers from w0 to w1."""
        n = len(pts)
        for i in range(n - 1):
            a, b = pts[i], pts[i + 1]
            wa = w0 + (w1 - w0) * i / (n - 1)
            wb = w0 + (w1 - w0) * (i + 1) / (n - 1)
            dx, dy = b[0] - a[0], b[1] - a[1]
            L = math.hypot(dx, dy) + 1e-6
            nx, ny = -dy / L, dx / L
            self.d.polygon([(a[0] + nx * wa / 2, a[1] + ny * wa / 2),
                            (b[0] + nx * wb / 2, b[1] + ny * wb / 2),
                            (b[0] - nx * wb / 2, b[1] - ny * wb / 2),
                            (a[0] - nx * wa / 2, a[1] - ny * wa / 2)], fill=v)
            self.d.ellipse([b[0] - wb / 2, b[1] - wb / 2, b[0] + wb / 2, b[1] + wb / 2], fill=v)
        return self

    def arr(self, soft=0.0):
        a = np.asarray(self.im, np.float32) / 255.0
        return blur(a, soft, 1) if soft >= 1 else a


def paint_part(cv, mask, cols, rng, light=LIGHT, soft=10, levels=4, noise=0.1,
               bias=0.0, contrast=1.0, op=1.0, tex=1.0, tex_size=None, jitter=0.05,
               elong=2.2, height=None, k=None, poster_soft=0.4, shape='oval'):
    """Fill a shape with soft-posterised gouache shading plus a brush pass."""
    if height is None:
        h = blur(mask, soft)
        k = soft * 1.4 if k is None else k
    else:
        h = height
        k = 1.0 if k is None else k
    lam = lambert(h, light, k)
    lz = light[2] / math.sqrt(sum(v * v for v in light))
    nz = fbm(cv.h, cv.w, max(4, soft * 1.2), 3, rng) if noise else 0
    t = 0.55 + (lam - lz) * 0.9 * contrast + bias + nz * noise
    q = soft_poster(t, levels, poster_soft)
    col = ramp(q, cols)
    cv.paint(mask, col, op)
    if tex:
        area = float((mask > 0.5).sum())
        ts = tex_size if tex_size is not None else max(2.0, soft * 0.45)
        n = int(area / (ts * ts) * 0.9 * tex)
        texture(cv, mask, rng, n, ts, jitter=jitter, alpha=(0.25, 0.6), elong=elong,
                angle=tangent(h), angle_jit=0.35, clip=mask, shape=shape)
    return h


def soft_ellipse(w, h, cx, cy, rx, ry, soft):
    yy, xx = grid(h, w)
    d = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    return np.clip(1 - smoothstep(1 - soft, 1 + soft, d), 0, 1)


def contact_shadow(cv, cx, cy, rx, ry, op=0.3, col=INK, soft=0.6):
    m = soft_ellipse(cv.w, cv.h, cx, cy, rx, ry, soft) ** 1.4
    cv.paint(m, col, op)


def glow(cv, cx, cy, r, col, op):
    x0, y0 = int(cx - r), int(cy - r)
    yy, xx = grid(int(2 * r) + 1, int(2 * r) + 1)
    d = np.sqrt((xx + x0 - cx) ** 2 + (yy + y0 - cy) ** 2) / r
    g = np.clip(1 - d, 0, 1) ** 2.2
    cv.paint(g, col, op, at=(x0, y0))


def grain(cv, rng, amt=0.03):
    n = fbm(cv.h, cv.w, 2.5, 2, rng)
    cv.rgb *= (1 + n * amt * 2)[..., None]


def save_jpg(cv, name, size, q):
    img = Image.fromarray(to8(cv.rgb)).resize(size, Image.LANCZOS)
    a = np.asarray(img).astype(np.float32)
    a += np.random.default_rng(99).normal(0, 0.8, a.shape)
    img = Image.fromarray(np.clip(a + 0.5, 0, 255).astype(np.uint8))
    path = os.path.join(IMG_DIR, name)
    img.save(path, 'JPEG', quality=q, optimize=True, progressive=True)
    return path


def to_image(cv, size=None):
    rgba = np.dstack([to8(cv.rgb), to8(cv.a)])
    img = Image.fromarray(rgba, 'RGBA')
    if size is not None and img.size != tuple(size):
        img = img.convert('RGBa').resize(size, Image.LANCZOS).convert('RGBA')
    return img


def save_png(cv, name, size):
    path = os.path.join(IMG_DIR, name)
    to_image(cv, size).save(path, 'PNG', optimize=True)
    return path


# --------------------------------------------------------------------------
# landscape building blocks
# --------------------------------------------------------------------------
def sky(cv, top, bottom, rng, S, horizon=None, sun=None, strokes=7000, jitter=0.018):
    """sun = (x, y, radius, colour, strength). horizon = y where bottom colour is reached."""
    h, w = cv.h, cv.w
    yy, xx = grid(h, w)
    hz = horizon if horizon is not None else h * 0.55
    t = np.clip(yy / hz, 0, 1) ** 1.15
    col = mix(top, bottom, t)
    if sun is not None:
        sx, sy, sr, scol, sst = sun
        d = np.sqrt((xx - sx) ** 2 + ((yy - sy) * 1.15) ** 2) / sr
        g = 1.0 / (1.0 + d * d) ** 1.1
        col = mix(col, scol, np.clip(g * sst, 0, 1))
    col *= (1 + fbm(h, w, 180 * S, 3, rng) * 0.025)[..., None]
    cv.paint(np.ones((h, w), np.float32), col)
    texture(cv, np.ones((h, w), np.float32), rng, strokes, 26 * S, jitter=jitter,
            alpha=(0.12, 0.3), elong=4.5, angle=0.0, angle_jit=0.08, hue=0.2)


def cloud(cv, rng, cx, cy, cw, ch, lit, shade, S, op=0.55, tex=True, flat=1.0):
    """One soft gouache cloud: lumpy top, flat-ish base, lit top / shaded base.
    (cx, cy) = centre of the cloud base, cw = width, ch = height of the tallest puff."""
    pw, ph = int(cw * 1.3), int(ch * 2.6)
    x0, y0 = int(cx - pw / 2), int(cy - ph * 0.8)
    yy, xx = grid(ph, pw)
    lx, ly = xx + x0, yy + y0
    f = np.full((ph, pw), -1e9, np.float32)
    npuff = int(rng.integers(9, 14))
    us = np.sort(rng.normal(0, 0.24, npuff)).clip(-0.46, 0.46)
    for u in us:
        pr = ch * (0.32 + 0.68 * math.exp(-(u / 0.22) ** 2)) * rng.uniform(0.7, 1.1)
        px = cx + u * cw
        py = cy - pr * rng.uniform(0.45, 0.85) * flat
        d = np.sqrt((lx - px) ** 2 + ((ly - py) / flat) ** 2)
        f = np.maximum(f, pr - d)
    base = cy + noise1d(pw, 50 * S, rng, 2)[None, :] * ch * 0.06
    f = np.minimum(f, (base - ly) * 1.6)
    f += fbm(ph, pw, 12 * S, 3, rng) * ch * 0.12
    m = smoothstep(-ch * 0.06, ch * 0.1, f)
    vt = np.clip((ly - (cy - ch * flat)) / (ch * flat), 0, 1)
    sh = smoothstep(0.45, 1.0, vt) + np.clip(0.25 - f / ch, 0, 0.25)
    col = mix(lit, shade, np.clip(sh, 0, 1))
    cv.paint(m, col, op, at=(x0, y0))
    if tex:
        full = np.zeros((cv.h, cv.w), np.float32)
        X0, Y0 = max(0, x0), max(0, y0)
        X1, Y1 = min(cv.w, x0 + pw), min(cv.h, y0 + ph)
        full[Y0:Y1, X0:X1] = m[Y0 - y0:Y1 - y0, X0 - x0:X1 - x0]
        texture(cv, full, rng, int(cw * ch / (60 * S * S)), 8 * S, jitter=0.03,
                alpha=(0.2, 0.45), elong=1.8, angle=0.0, angle_jit=0.6, clip=full, where=0.3)


def ridge(w, base, amp, cell, rng, octaves=4):
    return base + amp * noise1d(w, cell, rng, octaves)


def hill(cv, prof, cols, rng, S, haze=None, haze_t=0.0, rim=None, rim_amt=0.6,
         light_from=-1, sun_x=None, calm=1.0, tex_n=6000, edge=5.0):
    h, w = cv.h, cv.w
    yy, xx = grid(h, w)
    disp = fbm(h, w, 7 * S, 3, rng) * edge * S * 2
    d = yy - prof[None, :] + disp
    mask = smoothstep(-1.0 * S, 1.0 * S, d)
    depth = np.maximum(d, 0)
    light, mid, dark = cols
    col = mix(light, mid, smoothstep(0, 90 * S, depth))
    col = mix(col, dark, smoothstep(140 * S, 700 * S, depth) * 0.85)
    # slope lighting from a heavily smoothed ridge (no per-column striping)
    sm = np.convolve(np.pad(prof, (int(60 * S),) * 2, mode='edge'),
                     np.ones(int(120 * S) + 1) / (int(120 * S) + 1), mode='same')[int(60 * S):-int(60 * S)]
    slope = np.gradient(sm)
    lf = np.clip(0.5 + slope * light_from * 6.0, 0, 1)[None, :]
    sx = sun_x if sun_x is not None else w / 2
    sunfac = (0.4 + 0.6 * np.exp(-((xx[0] - sx) / (0.55 * w)) ** 2))[None, :]
    # soft rolling folds inside the band: lighter shoulders, shaded hollows
    folds = blur(fbm(h, w, 160 * S, 2, rng), 6 * S, 1)
    fl = lambert(folds * 200 * S, (light_from * 0.7, -0.7, 0.5))
    col = mix(col, light, np.clip(fl - 0.62, 0, 0.4) * 0.6 * calm)
    col = mix(col, dark, np.clip(0.62 - fl, 0, 0.4) * 0.55 * calm)
    if rim is not None:
        rimw = np.exp(-depth / (9 * S)) * (0.3 + 0.7 * lf) * sunfac
        col = mix(col, rim, np.clip(rimw * rim_amt, 0, 1))
    col = col * (1 + fbm(h, w, 110 * S, 3, rng) * 0.08 * calm)[..., None]
    if haze is not None:
        col = mix(col, haze, haze_t)
    cv.paint(mask, col)
    ang = np.broadcast_to(np.arctan(slope)[None, :], (h, w))
    texture(cv, mask, rng, tex_n, 15 * S, jitter=0.035 * calm, alpha=(0.12, 0.32),
            elong=3.5, angle=ang, angle_jit=0.12, hue=0.25)
    # broken ridge edge: dabs straddling the silhouette
    nr = int(w / (4 * S))
    xs = rng.uniform(0, w, nr)
    xi = xs.astype(int).clip(0, w - 1)
    ys = prof[xi] + rng.uniform(-1.5, 5, nr) * S
    cs = cv.sample(xs, ys + 7 * S) * (1 + 0.02 * rng.standard_normal(nr))[:, None]
    D = Dabs(rng)
    D.add(xs, ys, rng.uniform(6, 14, nr) * S, rng.uniform(2.5, 5, nr) * S,
          np.arctan(slope[xi]) + rng.normal(0, 0.12, nr), cs, 0.55)
    cv.dabs(D)
    return mask


def ground(cv, y0, top_col, bot_col, rng, S, rim=None, rim_amt=0.5, blades=30000,
           blade_jit=0.09, tip=None, tip_amt=0.5, blade_len=(5, 30)):
    h, w = cv.h, cv.w
    yy, xx = grid(h, w)
    prof = y0 + noise1d(w, 260 * S, rng, 3) * 7 * S
    d = yy - prof[None, :]
    mask = smoothstep(-S, S, d)
    t = np.clip(d / (h - y0), 0, 1)
    col = mix(top_col, bot_col, t ** 0.8)
    col = col * (1 + fbm(h, w, 90 * S, 3, rng) * 0.12)[..., None]
    if rim is not None:
        col = mix(col, rim, np.exp(-np.maximum(d, 0) / (6 * S)) * rim_amt)
    cv.paint(mask, col)
    texture(cv, mask, rng, 9000, 16 * S, jitter=0.05, alpha=(0.15, 0.35), elong=3,
            angle=0.0, angle_jit=0.2)
    ys = y0 + (h - y0) * rng.random(blades) ** 0.85
    ys.sort()
    xs = rng.uniform(0, w, blades)
    tt = (ys - y0) / (h - y0)
    rx = (blade_len[0] + blade_len[1] * tt) * S * rng.uniform(0.7, 1.3, blades)
    ry = rx / rng.uniform(5, 8, blades)
    ang = -PI / 2 + rng.normal(0, 0.22, blades)
    cs = cv.sample(xs, ys) * (1 + blade_jit * rng.standard_normal(blades))[:, None]
    if tip is not None:
        sel = rng.random(blades) < 0.35
        cs[sel] = mix(cs[sel], tip, tip_amt * rng.random(sel.sum()))
    cx = xs + np.cos(ang) * rx * 0.8
    cy = ys + np.sin(ang) * rx * 0.8
    D = Dabs(rng)
    D.add(cx, cy, rx, ry, ang, cs, rng.uniform(0.35, 0.8, blades), n=8, shape='leaf')
    cv.dabs(D)
    # tufts straddling the ground line so it reads as grass, not a ruled edge
    n = int(w / (2.2 * S))
    xs = rng.uniform(0, w, n)
    ys = prof[xs.astype(int)] + rng.uniform(-1, 14, n) * S
    o = np.argsort(ys)
    xs, ys = xs[o], ys[o]
    rx = rng.uniform(4, 11, n) * S
    ang = -PI / 2 + rng.normal(0, 0.3, n)
    cs = cv.sample(xs, ys + 10 * S) * (1 + 0.1 * rng.standard_normal(n))[:, None]
    if tip is not None:
        sel = rng.random(n) < 0.4
        cs[sel] = mix(cs[sel], tip, 0.4)
    D.add(xs + np.cos(ang) * rx * 0.8, ys + np.sin(ang) * rx * 0.8, rx, rx / 5.5, ang, cs,
          rng.uniform(0.5, 0.9, n), n=8, shape='leaf')
    cv.dabs(D)
    return prof


def small_tree(D, x, y, r, cols, rng, light=(-0.7, -0.7), blossom=None, trunk=None,
               shadow=INK, shadow_a=0.22, snow=None, rim=None, rim_a=0.6, squash=0.92, simple=False):
    """Painterly miniature tree made of dabs. (x, y) = trunk foot, r = canopy radius."""
    trunk = BARK if trunk is None else trunk
    ln = math.hypot(*light)
    lx, ly = light[0] / ln, light[1] / ln
    if shadow_a > 0:
        D.add(x - lx * r * 0.55, y + r * 0.06, r * 1.15, r * 0.3, 0, shadow, shadow_a * 0.55, n=16)
        D.add(x - lx * r * 0.35, y + r * 0.03, r * 0.75, r * 0.19, 0, shadow, shadow_a, n=16)
    th = r * 0.7
    tx = x + rng.normal() * r * 0.06
    D.seg(x, y + r * 0.02, tx, y - th - r * 0.3, r * 0.16, r * 0.08, trunk, 1.0)
    cx, cy = tx, y - th - r * 0.8
    dark, mid = cols[0], cols[1]
    D.add(cx, cy, r, r * squash, rng.normal(0, 0.1), mid, 0.97, n=18, wobble=0.1)
    D.add(cx - lx * r * 0.2, cy - ly * r * 0.2, r * 0.82, r * 0.72 * squash, 0, dark, 0.85,
          n=16, wobble=0.12)
    m = 6 if simple else 18
    a = rng.uniform(0, 2 * PI, m)
    rr = r * 0.62 * np.sqrt(rng.random(m))
    ox, oy = np.cos(a) * rr, np.sin(a) * rr * squash
    s = np.clip(0.5 + (-(ox * lx + oy * ly) / r) * 0.9 + rng.normal(0, 0.12, m), 0, 1)
    order = np.argsort(s)
    cs = ramp(s[order], cols)
    D.add(cx + ox[order], cy + oy[order], r * rng.uniform(0.25, 0.45, m),
          r * rng.uniform(0.2, 0.36, m), rng.uniform(0, PI, m), cs, 0.85, n=12, wobble=0.18)
    k = 0 if simple else 6
    a = rng.normal(math.atan2(ly, lx), 0.5, k)
    D.add(cx + np.cos(a) * r * 0.55, cy + np.sin(a) * r * 0.5 * squash, r * 0.16, r * 0.1,
          a + PI / 2, cols[-1], 0.75, n=10)
    if rim is not None:
        a = rng.normal(math.atan2(ly, lx), 0.45, 8)
        D.add(cx + np.cos(a) * r * 0.86, cy + np.sin(a) * r * 0.8 * squash, r * 0.2, r * 0.06,
              a + PI / 2, rim, rim_a, n=10)
    if blossom is not None:
        nb = int(14 + r * 0.4)
        a = rng.uniform(0, 2 * PI, nb)
        rr = r * 0.85 * np.sqrt(rng.random(nb))
        ox, oy = np.cos(a) * rr, np.sin(a) * rr * squash
        s = np.clip(0.5 + (-(ox * lx + oy * ly) / r) + rng.normal(0, 0.15, nb), 0, 1)
        bc = ramp(s, [mix(blossom, DUSK, 0.3), blossom, mix(blossom, CREAM, 0.6)])
        D.add(cx + ox, cy + oy, r * rng.uniform(0.07, 0.13, nb), r * rng.uniform(0.06, 0.1, nb),
              rng.uniform(0, PI, nb), bc, 0.9, n=8)
    if snow is not None:
        ns = 7
        a = rng.uniform(-PI * 0.85, -PI * 0.15, ns)
        D.add(cx + np.cos(a) * r * 0.55, cy + np.sin(a) * r * 0.62 * squash,
              r * rng.uniform(0.22, 0.34, ns), r * rng.uniform(0.08, 0.14, ns),
              a + PI / 2, snow, 0.9, n=12)
    return cx, cy


def bare_tree(D, x, y, length, width, col, rng, depth=4, ang=-PI / 2, alpha=1.0, spread=0.55):
    ex = x + math.cos(ang) * length
    ey = y + math.sin(ang) * length
    D.seg(x, y, ex, ey, width, width * 0.7, col, alpha)
    if depth <= 0:
        return
    nb = 2 if rng.random() < 0.6 else 3
    for i in range(nb):
        da = (i - (nb - 1) / 2) * spread + rng.normal(0, 0.18)
        bare_tree(D, ex, ey, length * rng.uniform(0.62, 0.78), width * 0.66, col, rng,
                  depth - 1, ang + da, alpha, spread)


def flower(D, x, y, r, petal, center, rng, alpha=0.9):
    k = 5
    a0 = rng.uniform(0, 2 * PI)
    a = a0 + np.arange(k) * 2 * PI / k
    D.add(x + np.cos(a) * r * 0.55, y + np.sin(a) * r * 0.42, r * 0.5, r * 0.32, a,
          petal * rng.uniform(0.95, 1.04), alpha, n=8)
    D.add(x, y, r * 0.28, r * 0.22, 0, center, alpha, n=8)


# --------------------------------------------------------------------------
# row backgrounds
# --------------------------------------------------------------------------
BG_CFG = {
    'spring': dict(seed=101, sun=(0.72, 0.30, 0.055), sun_str=0.75, light_from=1,
                   clouds=[(0.28, 0.215, 0.5, 0.05, 0.6), (0.84, 0.16, 0.38, 0.04, 0.6),
                           (0.56, 0.30, 0.34, 0.03, 0.55)]),
    'summer': dict(seed=202, sun=(0.24, 0.17, 0.065), sun_str=0.9, light_from=-1,
                   clouds=[(0.70, 0.22, 0.46, 0.075, 1.0), (0.24, 0.31, 0.34, 0.05, 0.9),
                           (0.98, 0.31, 0.26, 0.04, 0.9)]),
    'autumn': dict(seed=303, sun=(0.76, 0.32, 0.065), sun_str=0.85, light_from=1,
                   clouds=[(0.26, 0.19, 0.56, 0.045, 0.5), (0.62, 0.245, 0.4, 0.035, 0.5),
                           (0.12, 0.30, 0.34, 0.03, 0.5)]),
    'winter': dict(seed=404, sun=(0.30, 0.26, 0.05), sun_str=0.6, light_from=-1,
                   clouds=[(0.72, 0.18, 0.5, 0.05, 0.65), (0.36, 0.315, 0.44, 0.04, 0.6)]),
    'moon': dict(seed=505, sun=(0.68, 0.23, 0.13), sun_str=0.55, light_from=1,
                 clouds=[(0.26, 0.32, 0.62, 0.06, 0.4), (0.92, 0.36, 0.46, 0.05, 0.4)]),
}
GROUND_Y = 0.70  # fraction of height where trees stand


def make_bg(season, W=1080, H=1920, S=1.5):
    P, C = SEASON[season], BG_CFG[season]
    rng = np.random.default_rng(C['seed'])
    w, h = int(W * S), int(H * S)
    cv = Canvas(w, h, P['sky'][0])
    top, bot = P['sky']
    light = P['light']
    moon = season == 'moon'
    sx, sy, sr = C['sun'][0] * w, C['sun'][1] * h, C['sun'][2] * w
    glow_col = light if not moon else mix(light, bot, 0.35)
    sky(cv, top, bot, rng, S, horizon=h * 0.52,
        sun=(sx, sy, sr * (3.2 if not moon else 2.2), glow_col, C['sun_str']))
    yy, xx = grid(h, w)

    if moon:
        # stars: a few, small, softly haloed
        D = Dabs(rng)
        n = 46
        stx = rng.uniform(0, w, n)
        sty = h * (0.05 + 0.36 * rng.random(n) ** 1.3)
        keep = np.hypot(stx - sx, sty - sy) > sr * 2.2
        stx, sty = stx[keep], sty[keep]
        sz = rng.uniform(1.0, 2.4, len(stx)) * S
        sc = mix(CREAM, light, rng.random(len(stx)))
        D.add(stx, sty, sz * 3, sz * 3, 0, sc, 0.08, n=10)
        D.add(stx, sty, sz, sz, 0, sc, rng.uniform(0.55, 0.95, len(stx)), n=8)
        cv.dabs(D)
    # sun / moon disc
    disc = np.sqrt((xx - sx) ** 2 + (yy - sy) ** 2)
    if moon:
        m = 1 - smoothstep(sr - 1.5 * S, sr + 1.5 * S, disc)
        mot = fbm(h, w, sr * 0.35, 3, rng)
        mc = mix(light, hx('F2B38A'), np.clip(0.18 + blur(mot, 3 * S, 1) * 0.6, 0, 0.4))
        mc = mix(mc, CREAM, np.clip(1 - disc / sr, 0, 1) ** 2 * 0.35)
        cv.paint(m, mc)
        texture(cv, m, rng, 900, 9 * S, jitter=0.03, alpha=(0.2, 0.45), elong=1.6, clip=m)
        halo = np.clip(1 - (disc - sr) / (sr * 1.1), 0, 1) ** 2 * (disc > sr)
        cv.paint(halo, light, 0.22)
    else:
        sun_col = mix(light, CREAM, 0.45) if season != 'winter' else WHITE
        m = 1 - smoothstep(sr - 10 * S, sr + 4 * S, disc + fbm(h, w, 10 * S, 2, rng) * 6 * S)
        cv.paint(m, sun_col, 0.85)
        texture(cv, m, rng, 500, 8 * S, jitter=0.02, alpha=(0.2, 0.4), elong=2.5, angle=0.0,
                clip=m, where=0.3)
    # clouds
    for (cx, cy, cw, ch, flat) in C['clouds']:
        if moon:
            lit, shade = mix(bot, light, 0.3), mix(top, bot, 0.55)
            op = 0.5
        elif season == 'winter':
            lit, shade = mix(WHITE, top, 0.2), mix(bot, hx('93A9BF'), 0.25)
            op = 0.6
        else:
            lit = mix(CREAM, light, 0.5)
            shade = mix(bot, P['sig'] if season == 'spring' else top, 0.35)
            shade = mix(shade, DUSK, 0.08)
            op = 0.62
        cloud(cv, rng, cx * w, cy * h, cw * w, ch * h, lit, shade, S, op=op, flat=flat)

    # falling sky particles (kept out of the calm band and the HUD strip)
    def particles(n, y_lo, y_hi, cols, size, kind):
        D = Dabs(rng)
        px = rng.uniform(0, w, n)
        py = rng.uniform(y_lo, y_hi, n)
        cs = np.stack([cols[i] for i in rng.integers(0, len(cols), n)])
        sz = size * S * rng.uniform(0.6, 1.4, n)
        if kind == 'snow':
            D.add(px, py, sz * 1.8, sz * 1.8, 0, cs, 0.18, n=10)
            D.add(px, py, sz, sz, 0, cs, 0.75, n=8)
        else:
            ang = rng.uniform(0, PI, n)
            D.add(px, py, sz, sz * 0.5, ang, cs, rng.uniform(0.6, 0.9, n), n=10, shape='leaf')
            D.add(px - 0.2 * sz, py - 0.2 * sz, sz * 0.5, sz * 0.22, ang,
                  mix(cs, CREAM, 0.4), 0.5, n=8, shape='leaf')
        cv.dabs(D)

    hz = mix(bot, light, 0.25) if not moon else mix(bot, top, 0.3)
    H0, H1, H2 = P['hills']
    rim = mix(light, CREAM, 0.3) if not moon else light
    lf = C['light_from']
    far = ridge(w, h * 0.47, h * 0.042, 420 * S, rng, 3)
    hill(cv, far, (mix(H0, light, 0.3), H0, mix(H0, H1, 0.5)), rng, S, haze=hz,
         haze_t=0.45 if not moon else 0.3, rim=rim, rim_amt=0.45, light_from=lf, sun_x=sx,
         calm=0.5, tex_n=5000, edge=3)
    if season == 'winter':
        D = Dabs(rng)
        for i in range(26):
            tx = rng.uniform(0, w)
            ty = far[int(tx)] + rng.uniform(2, 14) * S
            bare_tree(D, tx, ty, rng.uniform(9, 15) * S, 2.2 * S, mix(H2, INK, 0.25), rng,
                      depth=3, alpha=0.45)
        cv.dabs(D)
    mid = ridge(w, h * 0.555, h * 0.034, 330 * S, rng, 3)
    hill(cv, mid, (mix(H1, light, 0.2), H1, mix(H1, H2, 0.5)), rng, S, haze=hz,
         haze_t=0.25 if not moon else 0.15, rim=rim, rim_amt=0.5, light_from=lf, sun_x=sx,
         calm=0.6, tex_n=6000, edge=4)
    # distant life on the mid hill: low contrast so the play band stays calm
    D = Dabs(rng)
    if season in ('spring', 'summer', 'autumn'):
        tc = {'spring': [mix(H2, hz, 0.5), mix(H1, hz, 0.4), mix(H0, light, 0.3)],
              'summer': [mix(H2, hz, 0.45), mix(H2, H1, 0.5), mix(H0, light, 0.3)],
              'autumn': [mix(hx('8A5A30'), hz, 0.4), mix(P['sig'], hz, 0.45),
                         mix(H0, light, 0.4)]}[season]
        xs = np.sort(rng.uniform(0, w, 22))
        for tx in xs:
            ty = mid[int(tx)] + rng.uniform(14, 50) * S
            small_tree(D, tx, ty, rng.uniform(10, 15) * S, tc, rng, light=(lf, -0.6), simple=True,
                       blossom=mix(P['sig'], hz, 0.35) if season == 'spring' else None,
                       trunk=mix(BARK, hz, 0.5), shadow_a=0.06)
    elif season == 'winter':
        for i in range(18):
            tx = rng.uniform(0, w)
            ty = mid[int(tx)] + rng.uniform(4, 30) * S
            bare_tree(D, tx, ty, rng.uniform(13, 20) * S, 3 * S, mix(H2, INK, 0.35), rng,
                      depth=3, alpha=0.55)
    cv.dabs(D)
    near = ridge(w, h * 0.628, h * 0.026, 300 * S, rng, 3)
    hill(cv, near, (mix(H2, light, 0.15) if not moon else mix(H1, H2, 0.3), mix(H1, H2, 0.6), H2),
         rng, S, haze=hz, haze_t=0.1 if not moon else 0.05, rim=rim, rim_amt=0.55,
         light_from=lf, sun_x=sx, calm=0.7, tex_n=6000, edge=4)
    if moon:
        # distant lanterns: small warm points with a soft falloff
        for i in range(9):
            lx_ = rng.uniform(0.04, 0.96) * w
            band = mid if i % 2 else near
            ly_ = band[int(lx_)] + rng.uniform(14, 60) * S
            glow(cv, lx_, ly_, 16 * S, GOLD, 0.28)
            D.add(lx_, ly_, 2.6 * S, 3.2 * S, 0, mix(GOLD, light, 0.5), 0.95, n=8)
        cv.dabs(D)

    # foreground strip
    gy = GROUND_Y * h
    if season == 'spring':
        gt, gb, tip = mix(H2, light, 0.2), mix(H2, INK, 0.4), mix(H0, light, 0.5)
    elif season == 'summer':
        gt, gb, tip = mix(H1, light, 0.15), mix(H2, INK, 0.38), mix(H0, light, 0.5)
    elif season == 'autumn':
        gt, gb, tip = mix(H0, light, 0.2), mix(H2, INK, 0.25), mix(H0, light, 0.6)
    elif season == 'winter':
        gt, gb, tip = mix(WHITE, H0, 0.3), mix(H1, H2, 0.45), WHITE
    else:
        gt, gb, tip = mix(H1, H2, 0.4), mix(H2, INK, 0.45), mix(H0, light, 0.35)
    ground(cv, gy, gt, gb, rng, S, rim=rim, rim_amt=0.45 if not moon else 0.3,
           blades=9000 if season == 'winter' else 30000,
           blade_jit=0.05 if season == 'winter' else 0.09, tip=tip, tip_amt=0.55,
           blade_len=(4, 22) if season == 'winter' else (5, 30))
    ft = (yy - gy) / (h - gy)

    D = Dabs(rng)
    patch = fbm(h, w, 150 * S, 3, rng)

    def fg_points(n, power=1.0, clustered=True):
        ys = gy + 14 * S + (h - gy - 14 * S) * rng.random(n * 4) ** power
        xs = rng.uniform(0, w, n * 4)
        if clustered:
            p = 0.2 + 0.8 * smoothstep(-0.15, 0.3, patch[ys.astype(int).clip(0, h - 1), xs.astype(int)])
            keep = rng.random(len(xs)) < p
            xs, ys = xs[keep], ys[keep]
        xs, ys = xs[:n], ys[:n]
        o = np.argsort(ys)
        xs, ys = xs[o], ys[o]
        return xs, ys, (ys - gy) / (h - gy)

    if season == 'spring':
        xs, ys, tt = fg_points(600, 0.8)
        pc = [P['sig'], mix(P['sig'], CREAM, 0.5), mix(P['sig'], DUSK, 0.2)]
        cs = np.stack([pc[i] for i in rng.integers(0, 3, len(xs))])
        sz = (2.5 + 9 * tt) * S
        D.add(xs, ys, sz, sz * 0.55, rng.uniform(0, PI, len(xs)), cs, 0.85, n=10, shape='leaf')
        xs, ys, tt = fg_points(70, 0.7)
        for x_, y_, t_ in zip(xs, ys, tt):
            flower(D, x_, y_, (4 + 12 * t_) * S, mix(CREAM, P['sig'], rng.uniform(0, 0.4)),
                   mix(hx('F7D46A'), light, 0.3), rng)
        cv.dabs(D)
        particles(50, h * 0.14, h * 0.34, pc, 7.5, 'petal')
        particles(50, h * 0.73, h * 0.98, pc, 9, 'petal')
    elif season == 'summer':
        xs, ys, tt = fg_points(380, 0.75)
        pal = [P['sig'], P['sig'], CREAM, mix(DUSK, CREAM, 0.5), mix(P['sig'], hx('D9733A'), 0.3)]
        for x_, y_, t_ in zip(xs, ys, tt):
            pcol = pal[rng.integers(0, len(pal))]
            flower(D, x_, y_, (3 + 15 * t_) * S, pcol, mix(hx('B07A3E'), GOLD, 0.4), rng)
        cv.dabs(D)
        # light motes drifting in the high warm air
        particles(40, h * 0.73, h * 0.98, [mix(light, CREAM, 0.5)], 3, 'snow')
    elif season == 'autumn':
        xs, ys, tt = fg_points(800, 0.8)
        lc = [P['sig'], mix(P['sig'], hx('C8463D'), 0.35), hx('B07A3E'), mix(H0, light, 0.3),
              mix(P['sig'], GOLD, 0.4)]
        cs = np.stack([lc[i] for i in rng.integers(0, len(lc), len(xs))])
        sz = (3 + 12 * tt) * S
        ang = rng.uniform(0, PI, len(xs))
        D.add(xs + 1.5 * S, ys + 1.5 * S, sz, sz * 0.45, ang, mix(gb, INK, 0.3), 0.35, n=10,
              shape='leaf')
        D.add(xs, ys, sz, sz * 0.45, ang, cs, 0.9, n=10, shape='leaf')
        cv.dabs(D)
        particles(36, h * 0.14, h * 0.34, lc, 11, 'leaf')
        particles(40, h * 0.73, h * 0.98, lc, 12, 'leaf')
    elif season == 'winter':
        # cool shadow drifts across the snow, frost glints, dry stalks
        sh = smoothstep(0.05, 0.35, fbm(h, w, 160 * S, 3, rng) + 0.1) * (yy > gy + 6 * S)
        cv.paint(blur(sh.astype(np.float32), 10 * S), mix(H2, DUSK, 0.15), 0.22)
        xs, ys, tt = fg_points(45, 0.8)
        for x_, y_, t_ in zip(xs, ys, tt):
            for k in range(rng.integers(3, 7)):
                L = (8 + 30 * t_) * S * rng.uniform(0.6, 1.2)
                a = -PI / 2 + rng.normal(0, 0.3)
                D.seg(x_, y_, x_ + math.cos(a) * L, y_ + math.sin(a) * L, 1.2 * S * (1 + t_),
                      0.4 * S, mix(BARK_LIGHT, H2, 0.55), 0.55)
        xs, ys, tt = fg_points(450, 0.9, False)
        D.add(xs, ys, (1 + 2.5 * tt) * S, (1 + 2.5 * tt) * S, 0, WHITE, rng.uniform(0.5, 1, len(xs)), n=8)
        cv.dabs(D)
        particles(70, h * 0.14, h * 0.34, [WHITE, mix(WHITE, top, 0.3)], 3.5, 'snow')
        particles(60, h * 0.73, h * 0.98, [WHITE], 5, 'snow')
    else:
        # moonlit dew on grass tips + a few fireflies near the ground
        xs, ys, tt = fg_points(500, 0.9, False)
        D.add(xs, ys, (1 + 2 * tt) * S, (1 + 2 * tt) * S, 0, mix(light, hx('B9C9D8'), 0.5),
              rng.uniform(0.3, 0.7, len(xs)), n=8)
        cv.dabs(D)
        xs, ys, tt = fg_points(26, 1.3, False)
        for x_, y_ in zip(xs, ys):
            glow(cv, x_, y_, 13 * S, GOLD, 0.22)
            D.add(x_, y_, 2 * S, 2 * S, 0, mix(GOLD, light, 0.6), 0.9, n=8)
        cv.dabs(D)

    # gentle light falloff toward the bottom corners frames the basket
    vig = smoothstep(0.35, 1.0, ft) * (0.5 + 0.5 * np.abs(xx / w - 0.5) * 2)
    cv.paint(np.clip(vig, 0, 1) * (yy > gy), INK if not moon else mix(INK, H2, 0.3), 0.22)
    grain(cv, rng, 0.03)
    return save_jpg(cv, f'bg_{season}.jpg', (W, H), 88)


# --------------------------------------------------------------------------
# splash: dawn orchard panorama
# --------------------------------------------------------------------------
def catmull(pts, n=40):
    pts = np.asarray(pts, np.float64)
    P = np.vstack([pts[0], pts, pts[-1]])
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for t in np.linspace(0, 1, n, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return np.array(out)


def make_splash(W=1080, H=1920, S=1.5):
    rng = np.random.default_rng(606)
    w, h = int(W * S), int(H * S)
    sp = SEASON['spring']
    top = mix(sp['sky'][0], hx('C9D8E6'), 0.45)
    bot = sp['sky'][1]
    light = sp['light']
    cv = Canvas(w, h, top)
    sx, sy = 0.74 * w, 0.355 * h
    sky(cv, top, mix(bot, light, 0.3), rng, S, horizon=h * 0.36,
        sun=(sx, sy, 0.2 * w, light, 0.95))
    yy, xx = grid(h, w)
    disc = np.sqrt((xx - sx) ** 2 + (yy - sy) ** 2)
    cv.paint(1 - smoothstep(0.045 * w - 3 * S, 0.045 * w + 3 * S, disc), mix(light, CREAM, 0.5), 0.9)
    for (cx, cy, cw, ch) in [(0.24, 0.16, 0.56, 0.05), (0.78, 0.215, 0.46, 0.04),
                             (0.42, 0.285, 0.4, 0.03), (0.92, 0.12, 0.3, 0.035)]:
        cloud(cv, rng, cx * w, cy * h, cw * w, ch * h, mix(CREAM, light, 0.6),
              mix(mix(bot, sp['sig'], 0.35), DUSK, 0.1), S, op=0.6, flat=0.55)
    hz = mix(bot, light, 0.35)
    H0, H1, H2 = sp['hills']
    rim = mix(light, CREAM, 0.2)
    far = ridge(w, h * 0.37, h * 0.012, 260 * S, rng)
    hill(cv, far, (mix(H0, light, 0.4), H0, H1), rng, S, haze=hz, haze_t=0.55, rim=rim,
         rim_amt=0.5, light_from=1, sun_x=sx, calm=0.5, tex_n=4000, edge=3)
    far2 = ridge(w, h * 0.395, h * 0.012, 200 * S, rng)
    hill(cv, far2, (mix(H0, light, 0.3), H0, H1), rng, S, haze=hz, haze_t=0.4, rim=rim,
         rim_amt=0.5, light_from=1, sun_x=sx, calm=0.5, tex_n=4000, edge=3)
    # the orchard hill: summit left of centre, long lit slope to the right
    xs_ = np.arange(w) / w
    prof = h * (0.405 + 0.075 * ((xs_ - 0.42) / 0.58) ** 2 + 0.01 * noise1d(w, 200 * S, rng, 3))
    hill(cv, prof, (mix(H1, light, 0.35), H1, mix(H1, H2, 0.6)), rng, S, haze=hz, haze_t=0.08,
         rim=rim, rim_amt=0.7, light_from=1, sun_x=sx, calm=1.0, tex_n=12000, edge=3)
    # winding path (perspective: wide near, thin at the summit)
    ctrl = [(0.50, 0.80), (0.60, 0.735), (0.42, 0.665), (0.60, 0.585), (0.45, 0.515),
            (0.55, 0.455), (0.46, 0.42), (0.43, 0.405)]
    pth = catmull([(x * w, y * h) for x, y in ctrl], 60)
    tpar = np.linspace(0, 1, len(pth))
    pw = (70 - 64 * tpar ** 0.7) * S
    L = Layer(w, h)
    for (px, py), r in zip(pth, pw):
        L.ellipse(px, py, r, r * 0.42)
    pm = L.arr(1.5 * S)
    pm *= smoothstep(-0.2, 0.3, fbm(h, w, 6 * S, 2, rng) + 0.3)
    inner = blur(pm, 6 * S)
    pcol = mix(mix(CREAM, hx('C9A15A'), 0.55), mix(CREAM, light, 0.5), smoothstep(0.4, 0.95, inner))
    pcol = mix(pcol, hx('B07A3E'), np.clip(0.5 - inner, 0, 0.5) * 0.6)
    cv.paint(pm, pcol, 0.95)
    texture(cv, pm, rng, 2500, 7 * S, jitter=0.05, alpha=(0.2, 0.45), elong=3, angle=0.0,
            angle_jit=0.3, clip=pm)
    # orchard rows, tinted up the hill: blossom low, green, gold, frost near the top
    D = Dabs(rng)
    rows = 10
    trees = []
    for k in range(rows):
        v = (k + 1) / rows
        r = (6 + 24 * v ** 1.3) * S
        off = (0.014 + 0.265 * v ** 1.2) * h
        spacing = r * 3.6
        x = rng.uniform(0, spacing)
        while x < w:
            yb = (prof[int(min(w - 1, x))] + off + math.sin(x / w * 4.2 + k * 0.7) * r * 0.9
                  + rng.normal(0, r * 0.15))
            if yb < h * 0.70 and np.min(np.hypot(pth[:, 0] - x, (pth[:, 1] - yb) * 1.6)
                                         - pw * 1.1) > r * 1.6:
                trees.append((yb, x, r, v))
            x += spacing * rng.uniform(0.8, 1.25)
    trees.sort()
    gr = [mix(H2, INK, 0.3), H2, H1, mix(H0, light, 0.4)]
    au = [mix(hx('8A5A30'), INK, 0.2), hx('B07A3E'), hx('D9733A'), mix(hx('C9A15A'), light, 0.5)]
    wi = [mix(hx('93A9BF'), INK, 0.25), hx('93A9BF'), hx('B9C9D8'), hx('DDE6EE')]
    for yb, x, r, v in trees:
        hz_t = (1 - v) * 0.45
        if v < 0.25:
            cols, bl, sn = wi, None, WHITE
        elif v < 0.5:
            cols, bl, sn = au, None, None
        elif v < 0.75:
            cols, bl, sn = gr, None, None
        else:
            cols, bl, sn = gr, sp['sig'], None
        cols = [mix(c, hz, hz_t) for c in cols]
        small_tree(D, x, yb, r, cols, rng, light=(0.8, -0.6), blossom=bl, snow=sn,
                   rim=mix(rim, hz, hz_t), trunk=mix(BARK, hz, hz_t), shadow_a=0.2 * (1 - hz_t))
    cv.dabs(D)
    gy = 0.72 * h
    ground(cv, gy, mix(H1, light, 0.25), mix(H2, INK, 0.3), rng, S, rim=None, blades=16000,
           blade_jit=0.05, tip=mix(H0, light, 0.5), tip_amt=0.4, blade_len=(4, 22))
    # mist pooling along the hill foot hides the meadow edge
    mist = smoothstep(0.64 * h, 0.71 * h, yy) * (1 - smoothstep(0.73 * h, 0.80 * h, yy))
    mist *= np.clip(0.75 + fbm(h, w, 120 * S, 3, rng) * 1.2, 0, 1)
    cv.paint(mist, mix(CREAM, light, 0.3), 0.6)
    D = Dabs(rng)
    n = 300
    px_ = rng.uniform(0, w, n)
    py_ = rng.uniform(0.74 * h, h, n)
    pc = [sp['sig'], mix(sp['sig'], CREAM, 0.5)]
    cs = np.stack([pc[i] for i in rng.integers(0, 2, n)])
    D.add(px_, py_, rng.uniform(3, 7, n) * S, rng.uniform(1.5, 3.5, n) * S, rng.uniform(0, PI, n),
          cs, 0.75, n=10, shape='leaf')
    cv.dabs(D)
    vig = smoothstep(0.8 * h, h, yy)
    cv.paint(vig, INK, 0.12)
    grain(cv, rng, 0.03)
    return save_jpg(cv, 'splash.jpg', (W, H), 88)


# --------------------------------------------------------------------------
# hub bands (stacked hillside, seen from slightly above)
# --------------------------------------------------------------------------
HUB_SEEDS = dict(spring=711, summer=722, autumn=733, winter=744, moon=755)


def make_hub(season, W=1080, H=1440, S=1.5):
    P = SEASON[season]
    rng = np.random.default_rng(HUB_SEEDS[season])
    w, h = int(W * S), int(H * S)
    H0, H1, H2 = P['hills']
    light = P['light']
    moon = season == 'moon'
    if season == 'spring':
        fc = [mix(H2, INK, 0.12), H2, H1, mix(H1, H0, 0.6), mix(H0, light, 0.35)]
    elif season == 'summer':
        fc = [mix(H2, INK, 0.1), H2, H1, mix(H1, H0, 0.6), mix(H0, light, 0.35)]
    elif season == 'autumn':
        fc = [mix(H2, INK, 0.1), H2, H1, mix(H1, H0, 0.6), mix(H0, light, 0.45)]
    elif season == 'winter':
        fc = [mix(H2, DUSK, 0.12), H2, H1, mix(H0, H1, 0.4), mix(H0, WHITE, 0.6)]
    else:
        fc = [mix(H2, INK, 0.25), H2, H1, mix(H0, H1, 0.3), mix(H0, light, 0.18)]
    cv = Canvas(w, h, fc[2])
    yy, xx = grid(h, w)
    hgt = (fbm(h, w, 420 * S, 3, rng) + 0.45 * fbm(h, w, 150 * S, 2, rng)) * 240 * S
    lam = lambert(hgt, (-0.5, -0.8, 0.9))
    xf = xx / w
    edge = smoothstep(0.24, 0.06, xf) + smoothstep(0.76, 0.94, xf)
    calm = 0.55 + 0.45 * np.clip(edge, 0, 1)
    t = 0.55 + (lam - lam.mean()) * 0.55 + fbm(h, w, 60 * S, 3, rng) * 0.05
    t = 0.55 + (t - 0.55) * calm
    col = ramp(soft_poster(t, 6, 0.75), fc)
    cv.paint(np.ones((h, w), np.float32), col)
    # the centre 60% is one light meadow value so the code-drawn trail reads on top
    centre = 1 - np.clip(edge, 0, 1)
    meadow = mix(fc[3], fc[2], 0.35) if not moon else mix(fc[2], fc[3], 0.6)
    cv.paint(centre * 0.88, meadow * (1 + fbm(h, w, 220 * S, 2, rng) * 0.04)[..., None])
    ang = tangent(hgt)
    ones = np.ones((h, w), np.float32)
    texture(cv, ones, rng, 26000, 13 * S, jitter=0.022, alpha=(0.12, 0.28), elong=3.2,
            angle=ang, angle_jit=0.2, hue=0.2)
    texture(cv, np.clip(edge, 0, 1), rng, 9000, 11 * S, jitter=0.07, alpha=(0.25, 0.5),
            elong=2.4, angle=ang, angle_jit=0.3, where=0.3)
    # grass tufts, denser at the edges
    D = Dabs(rng)
    n = 9000 if season != 'winter' else 2500
    tx = rng.uniform(0, w, n)
    keep = rng.random(n) < (0.25 + 0.75 * np.clip(smoothstep(0.3, 0.08, tx / w)
                                                   + smoothstep(0.7, 0.92, tx / w), 0, 1))
    tx = tx[keep]
    ty = np.sort(rng.uniform(0, h, len(tx)))
    L_ = rng.uniform(5, 13, len(tx)) * S
    a_ = -PI / 2 + rng.normal(0, 0.3, len(tx))
    cs = cv.sample(tx, ty) * (1 + 0.1 * rng.standard_normal(len(tx)))[:, None]
    tipc = mix(H0, light, 0.5) if not moon else mix(H0, light, 0.25)
    sel = rng.random(len(tx)) < 0.4
    cs[sel] = mix(cs[sel], tipc, 0.5)
    D.add(tx + np.cos(a_) * L_ * 0.8, ty + np.sin(a_) * L_ * 0.8, L_, L_ / 6, a_, cs,
          rng.uniform(0.4, 0.8, len(tx)), n=8, shape='leaf')
    cv.dabs(D)

    def edge_xy(n, inner=0.19, outer=0.01):
        side = rng.random(n) < 0.5
        u = rng.uniform(outer, inner, n)
        xs = np.where(side, u, 1 - u) * w
        ys = rng.uniform(130 * S, h - 110 * S, n)
        o = np.argsort(ys)
        return xs[o], ys[o]

    def scatter(n, size, cols, shape='leaf', centre_frac=0.12, alpha=0.85):
        xs, ys = edge_xy(int(n * (1 - centre_frac)), 0.22)
        cx_ = rng.uniform(0.2, 0.8, int(n * centre_frac)) * w
        cy_ = rng.uniform(0, h, len(cx_))
        xs, ys = np.concatenate([xs, cx_]), np.concatenate([ys, cy_])
        cs = np.stack([cols[i] for i in rng.integers(0, len(cols), len(xs))])
        sz = size * S * rng.uniform(0.6, 1.3, len(xs))
        D.add(xs, ys, sz, sz * 0.5, rng.uniform(0, PI, len(xs)), cs, alpha, n=10, shape=shape)
        cv.dabs(D)

    tl = (-0.7, -0.75)
    if season == 'spring':
        pc = [P['sig'], mix(P['sig'], CREAM, 0.5), mix(P['sig'], DUSK, 0.2)]
        scatter(700, 5, pc)
        xs, ys = edge_xy(9, 0.15, 0.03)
        for x_, y_ in zip(xs, ys):
            small_tree(D, x_, y_, rng.uniform(55, 80) * S,
                       [mix(H2, INK, 0.25), H2, H1, mix(H0, light, 0.4)], rng, light=tl,
                       blossom=P['sig'], rim=mix(light, CREAM, 0.3), squash=0.9)
        cv.dabs(D)
        for k in range(60):
            x_, y_ = edge_xy(1, 0.22)
            flower(D, x_[0], y_[0], rng.uniform(6, 10) * S, mix(CREAM, P['sig'], rng.random() * 0.5),
                   mix(hx('F7D46A'), light, 0.3), rng)
        cv.dabs(D)
    elif season == 'summer':
        xs, ys = edge_xy(900, 0.23)
        pal = [P['sig'], P['sig'], CREAM, mix(DUSK, CREAM, 0.5)]
        for x_, y_ in zip(xs, ys):
            flower(D, x_, y_, rng.uniform(5, 10) * S, pal[rng.integers(0, 4)],
                   mix(hx('B07A3E'), GOLD, 0.4), rng)
        xs, ys = rng.uniform(0.22, 0.78, 90) * w, rng.uniform(0, h, 90)
        for x_, y_ in zip(xs, ys):
            flower(D, x_, y_, rng.uniform(3, 5) * S, pal[rng.integers(0, 4)],
                   mix(hx('B07A3E'), GOLD, 0.4), rng, alpha=0.6)
        cv.dabs(D)
        xs, ys = edge_xy(5, 0.13, 0.03)
        for x_, y_ in zip(xs, ys):
            small_tree(D, x_, y_, rng.uniform(65, 90) * S,
                       [mix(H2, INK, 0.3), H2, H1, mix(H0, light, 0.45)], rng, light=tl,
                       rim=mix(light, CREAM, 0.2), squash=0.9)
        cv.dabs(D)
    elif season == 'autumn':
        lc = [P['sig'], mix(P['sig'], hx('C8463D'), 0.35), hx('B07A3E'), mix(H0, light, 0.4),
              mix(P['sig'], GOLD, 0.4)]
        scatter(900, 6, lc)
        trees = []
        for side in (0, 1):
            for k in range(6):
                x_ = (0.075 + 0.05 * (k % 2)) * w
                x_ = x_ if side == 0 else w - x_
                y_ = (190 + k * 215 + rng.uniform(-20, 20)) * S
                trees.append((y_, x_))
        trees.sort()
        ac = [mix(hx('8A5A30'), INK, 0.25), hx('B07A3E'), P['sig'], mix(hx('C9A15A'), light, 0.45)]
        for y_, x_ in trees:
            small_tree(D, x_, y_, rng.uniform(50, 64) * S, ac, rng, light=tl,
                       rim=mix(light, CREAM, 0.2), squash=0.9)
        cv.dabs(D)
    elif season == 'winter':
        sh = smoothstep(0.0, 0.4, fbm(h, w, 200 * S, 3, rng) + 0.05)
        cv.paint(blur(sh, 12 * S), mix(H2, DUSK, 0.2), 0.18)
        xs, ys = edge_xy(10, 0.16, 0.03)
        for x_, y_ in zip(xs, ys):
            D.add(x_ + 30 * S, y_ + 6 * S, 70 * S, 14 * S, 0, mix(H2, DUSK, 0.25), 0.3, n=14)
            bare_tree(D, x_, y_, rng.uniform(40, 60) * S, 9 * S, mix(BARK, H2, 0.25), rng,
                      depth=4, spread=0.6)
        cv.dabs(D)
        for x_, y_ in zip(xs, ys):
            D.add(x_ + rng.normal(0, 4 * S, 4), y_ - rng.uniform(10, 40, 4) * S, 6 * S, 2 * S,
                  0, WHITE, 0.8, n=8)
        xs = rng.uniform(0, w, 1500)
        ys = rng.uniform(0, h, 1500)
        D.add(xs, ys, rng.uniform(1, 2.5, 1500) * S, rng.uniform(1, 2.5, 1500) * S, 0, WHITE,
              rng.uniform(0.4, 0.9, 1500), n=8)
        cv.dabs(D)
        xs, ys = edge_xy(60, 0.2)
        for x_, y_ in zip(xs, ys):
            for k in range(3):
                a = -PI / 2 + rng.normal(0, 0.35)
                Lk = rng.uniform(10, 24) * S
                D.seg(x_, y_, x_ + math.cos(a) * Lk, y_ + math.sin(a) * Lk, 2 * S, 0.7 * S,
                      mix(BARK_LIGHT, H2, 0.35), 0.7)
        cv.dabs(D)
    else:
        mc = [mix(H2, INK, 0.3), mix(H2, LEAF, 0.35), mix(H1, LEAF, 0.4), mix(H0, LEAF, 0.3)]
        xs, ys = edge_xy(7, 0.14, 0.03)
        for x_, y_ in zip(xs, ys):
            small_tree(D, x_, y_, rng.uniform(55, 75) * S, mc, rng, light=(0.7, -0.7),
                       rim=light, rim_a=0.7, squash=0.9)
        cv.dabs(D)
        xs, ys = edge_xy(6, 0.2, 0.06)
        for x_, y_ in zip(xs, ys):
            D.seg(x_, y_, x_, y_ - 46 * S, 4 * S, 3 * S, mix(BARK, H2, 0.3), 1.0)
            D.add(x_ + 4 * S, y_ + 3 * S, 22 * S, 6 * S, 0, INK, 0.25, n=12)
            cv.dabs(D)
            glow(cv, x_, y_ - 50 * S, 46 * S, GOLD, 0.3)
            glow(cv, x_ + 6 * S, y_ + 4 * S, 30 * S, GOLD, 0.15)
            D.add(x_, y_ - 50 * S, 6 * S, 8 * S, 0, mix(GOLD, light, 0.45), 1.0, n=12)
            D.add(x_, y_ - 59 * S, 5 * S, 2 * S, 0, BARK, 1.0, n=8)
            cv.dabs(D)
        xs, ys = edge_xy(50, 0.24)
        for x_, y_ in zip(xs, ys):
            glow(cv, x_, y_, 10 * S, GOLD, 0.25)
            D.add(x_, y_, 1.8 * S, 1.8 * S, 0, mix(GOLD, light, 0.6), 0.9, n=8)
        cv.dabs(D)
        xs, ys = rng.uniform(0, w, 900), rng.uniform(0, h, 900)
        D.add(xs, ys, 1.4 * S, 1.4 * S, 0, mix(light, hx('B9C9D8'), 0.5),
              rng.uniform(0.2, 0.5, 900), n=8)
        cv.dabs(D)

    grain(cv, rng, 0.03)
    # soft mist at top and bottom so stacked bands cross-fade cleanly
    dist = np.minimum(yy, h - 1 - yy) / S
    wn = fbm(h, w, 70 * S, 3, rng) * 60
    wgt = 1 - smoothstep(0, 125, dist + wn * smoothstep(0, 30, dist))
    cv.paint(np.clip(wgt, 0, 1), MIST, 0.96)
    Dm = Dabs(rng)
    for band_y in (60 * S, h - 60 * S):
        n = 140
        xs = rng.uniform(-40 * S, w + 40 * S, n)
        ys = band_y + rng.normal(0, 30 * S, n)
        Dm.add(xs, ys, rng.uniform(40, 110, n) * S, rng.uniform(10, 22, n) * S,
               rng.normal(0, 0.05, n), mix(MIST, CREAM, 0.5), 0.18, n=14)
    cv.dabs(Dm)
    cv.paint((1 - smoothstep(0, 14, dist)).astype(np.float32), MIST, 1.0)
    return save_jpg(cv, f'hub_{season}.jpg', (W, H), 86)


# --------------------------------------------------------------------------
# big tree sprites
# --------------------------------------------------------------------------
def paint_tree(cv, cx, cy, R, base_x, base_y, style, rng):
    """Painterly round-canopied tree. Canopy centre (cx, cy), radius R, trunk foot at base."""
    light = style.get('light', LIGHT)
    cols = style['ramp']
    h, w = cv.h, cv.w
    yy, xx = grid(h, w)
    s = R / 150.0
    # trunk + limbs
    L = Layer(w, h)
    bw = 21 * s
    L.poly([(base_x - bw * 1.9, base_y), (base_x - bw, base_y - 18 * s),
            (base_x - bw * 0.72, cy + R * 0.55), (base_x + bw * 0.72, cy + R * 0.55),
            (base_x + bw, base_y - 18 * s), (base_x + bw * 2.0, base_y),
            (base_x + bw * 0.8, base_y + 3 * s), (base_x - bw * 0.9, base_y + 3 * s)])
    fy = cy + R * 0.58
    L.taper([(base_x - 2 * s, fy + 10 * s), (cx - R * 0.2, cy + R * 0.25), (cx - R * 0.45, cy)],
            15 * s, 6 * s)
    L.taper([(base_x + 2 * s, fy + 10 * s), (cx + R * 0.15, cy + R * 0.2), (cx + R * 0.42, cy - R * 0.1)],
            14 * s, 6 * s)
    L.taper([(base_x, fy), (cx + R * 0.03, cy - R * 0.2)], 12 * s, 5 * s)
    segs = []
    if style.get('bare'):
        Dt = Dabs(rng)
        for a0, L0, sx0, sy0 in [(-PI / 2 - 0.95, 0.5, -0.45, 0.0), (-PI / 2 + 0.95, 0.5, 0.42, -0.1),
                                 (-PI / 2 - 0.1, 0.5, 0.03, -0.2), (-PI / 2 - 0.5, 0.42, -0.2, 0.25),
                                 (-PI / 2 + 0.5, 0.42, 0.15, 0.2)]:
            bare_tree(Dt, cx + sx0 * R, cy + sy0 * R, R * L0 * 0.5, 6 * s, WHITE, rng, depth=4,
                      ang=a0, spread=0.55)
        for poly, _ in Dt.items:
            L.d.polygon(poly, fill=255)
    tm = L.arr(1.0)
    paint_part(cv, tm, tones(BARK, BARK_LIGHT, lift=0.75, deep=0.5), rng, light=light,
               soft=13 * s, levels=4, tex=1.4, tex_size=3.2 * s, elong=5, jitter=0.1)
    Db = Dabs(rng)
    idx = np.flatnonzero((tm > 0.8).ravel())
    pick = rng.choice(idx, 160)
    py_, px_ = np.divmod(pick, w)
    Db.add(px_, py_, rng.uniform(4, 10, 160) * s, rng.uniform(0.6, 1.2, 160) * s,
           PI / 2 + rng.normal(0, 0.08, 160), mix(BARK, INK, 0.45), rng.uniform(0.3, 0.6, 160), n=8)
    cv.dabs(Db, tm)
    # canopy: union of sub-domes with a leafy scalloped rim
    blobs = [(cx, cy - 0.03 * R, 0.6 * R)]
    if style.get('sparse'):
        # winter: a handful of snow-laden clumps caught in the bare branches
        blobs = []
        for k in range(15):
            a = rng.uniform(0, 2 * PI)
            d = R * math.sqrt(rng.uniform(0.05, 1)) * 0.72
            blobs.append((cx + d * math.cos(a) * 1.1, cy + d * math.sin(a) * 0.85 - 0.08 * R,
                          R * rng.uniform(0.13, 0.21), 0.55))
    off = rng.uniform(0, 2 * PI)
    for k in range(0 if style.get('sparse') else 9):
        a = off + 2 * PI * k / 9 + rng.uniform(-0.2, 0.2)
        d = R * rng.uniform(0.5, 0.57)
        blobs.append((cx + d * math.cos(a), cy + d * math.sin(a) * 0.92, R * rng.uniform(0.36, 0.43)))
    for k in range(0 if style.get('sparse') else 5):
        a = rng.uniform(0, 2 * PI)
        blobs.append((cx + 0.25 * R * math.cos(a), cy + 0.25 * R * math.sin(a), R * 0.34))
    for k in range(0 if style.get('sparse') else 54):
        a = 2 * PI * k / 54 + rng.normal(0, 0.03)
        r = R * rng.uniform(0.07, 0.12)
        d = R * rng.uniform(0.9, 0.97) - r * 0.55
        blobs.append((cx + d * math.cos(a), cy + d * math.sin(a) * 0.93, r))
    sd = np.full((h, w), -1e9, np.float32)
    hd = np.zeros((h, w), np.float32)
    for blob in blobs:
        bx, by, br = blob[:3]
        sq = blob[3] if len(blob) > 3 else 1.0
        d2 = (xx - bx) ** 2 + ((yy - by) / sq) ** 2
        sd = np.maximum(sd, br - np.sqrt(d2))
        hd = np.maximum(hd, np.sqrt(np.clip(br * br - d2, 0, None)) + br * 0.25)
    sd += fbm(h, w, 6 * s, 2, rng) * 5 * s
    m = smoothstep(-1.2, 1.2, sd)
    hb = blur(hd, 3 * s)
    big = np.sqrt(np.clip(R * R - (xx - cx) ** 2 - (yy - cy) ** 2, 0, None))
    wb = 0.85 if style.get('sparse') else 0.55
    lam = wb * lambert(hb, light) + (1 - wb) * lambert(big, light)
    ao = np.clip((blur(hd, 0.14 * R) - hd) / (0.12 * R), 0, 1)
    lz = light[2] / math.sqrt(sum(v * v for v in light))
    t = 0.55 + (lam - lz) * 1.1 - ao * 0.55 - np.clip((yy - cy) / R, 0, 1) * 0.12
    t += fbm(h, w, 14 * s, 3, rng) * 0.14
    q = soft_poster(t, 4, 0.4)
    cv.paint(m, ramp(q, cols))
    leaf_sz = 6.5 * s
    area = float((m > 0.5).sum())
    texture(cv, m, rng, int(area / (leaf_sz ** 2) * 1.1), leaf_sz, jitter=0.07,
            alpha=(0.35, 0.75), elong=1.8, angle=None, clip=m, shape='leaf', hue=0.3)
    D = Dabs(rng)
    for sel_lo, sel_hi, cidx, n, a in [(0.68, 9, -1, 320, 0.6), (-9, 0.3, 0, 260, 0.55)]:
        idx = np.flatnonzero(((t > sel_lo) & (t < sel_hi) & (m > 0.6)).ravel())
        if len(idx):
            pick = rng.choice(idx, n)
            py, px = np.divmod(pick, w)
            D.add(px, py, rng.uniform(3, 6, n) * s, rng.uniform(1.6, 3, n) * s,
                  rng.uniform(0, PI, n), cols[cidx], a, n=10, shape='leaf')
    cv.dabs(D, m)
    # warm rim light on the light-facing edge
    mb = blur(m, style.get('rim_w', 4) * s)
    gy_, gx_ = np.gradient(blur(m, 6 * s))
    gl = np.sqrt(gx_ ** 2 + gy_ ** 2) + 1e-6
    face = np.clip((gx_ * light[0] + gy_ * light[1]) / gl * -1, 0, 1)
    rimw = np.clip(m * (1 - mb) * 2.4, 0, 1) * face ** 1.1
    cv.paint(rimw, style['rim'], style.get('rim_amt', 0.7))
    extra = style.get('extra')
    if extra == 'blossom':
        sig = style['sig']
        D = Dabs(rng)
        idx = np.flatnonzero((m > 0.7).ravel())
        cents = rng.choice(idx, 110)
        for c in cents:
            py, px = divmod(int(c), w)
            k = rng.integers(3, 7)
            ox = px + rng.normal(0, 7 * s, k)
            oy = py + rng.normal(0, 6 * s, k)
            tv = t[py, px]
            bc = ramp(np.clip(tv + rng.normal(0, 0.1, k), 0, 1),
                      [mix(sig, DUSK, 0.35), sig, mix(sig, CREAM, 0.65)])
            D.add(ox, oy, rng.uniform(3, 5.5, k) * s, rng.uniform(2.6, 4.5, k) * s,
                  rng.uniform(0, PI, k), bc, 0.92, n=8)
        cv.dabs(D, m)
    elif extra == 'autumn':
        D = Dabs(rng)
        idx = np.flatnonzero((m > 0.7).ravel())
        pick = rng.choice(idx, 380)
        py, px = np.divmod(pick, w)
        lc = [mix(hx('C9A15A'), style['light_col'], 0.5), mix(hx('D9733A'), hx('C8463D'), 0.4),
              mix(hx('D9733A'), GOLD, 0.35)]
        cs = np.stack([lc[i] for i in rng.integers(0, 3, len(px))])
        cs = mix(cs, cols[0], np.clip(0.55 - t[py, px], 0, 0.5))
        D.add(px, py, rng.uniform(3, 5.5, len(px)) * s, rng.uniform(1.6, 2.6, len(px)) * s,
              rng.uniform(0, PI, len(px)), cs, 0.8, n=10, shape='leaf')
        cv.dabs(D, m)
    elif extra == 'snow':
        gy2, gx2 = np.gradient(hb)
        up = np.clip(gy2 / (np.sqrt(gx2 ** 2 + gy2 ** 2 + 1) + 1e-6), 0, 1)
        cap = smoothstep(0.3, 0.55, up + fbm(h, w, 8 * s, 2, rng) * 0.35) * m
        cap *= smoothstep(-0.2, 0.2, (cy + R * 0.5 - yy) / R)
        sc = mix(mix(WHITE, hx('DDE6EE'), 0.3), hx('B9C9D8'), smoothstep(0.5, 0.0, up))
        cv.paint(cap, sc, 0.95)
        ridge_snow = np.clip(tm - np.roll(tm, int(5 * s), axis=0), 0, 1) * (yy < base_y - 60 * s)
        ridge_snow *= smoothstep(-0.1, 0.2, fbm(h, w, 10 * s, 2, rng) + 0.1)
        cv.paint(blur(ridge_snow, 1), mix(WHITE, hx('DDE6EE'), 0.25), 0.95)
        texture(cv, cap, rng, 700, 4 * s, jitter=0.03, alpha=(0.3, 0.6), elong=2.5, angle=0.0,
                clip=cap)
    return m


TREE_STYLES = {
    'spring': dict(ramp=[mix(hx('5E9A66'), INK, 0.45), hx('5E9A66'), hx('82B884'), hx('A9D0A0'),
                         mix(hx('A9D0A0'), hx('FFF0B8'), 0.5)],
                   rim=mix(hx('FFF0B8'), CREAM, 0.3), extra='blossom', sig=hx('F3B6C6')),
    'summer': dict(ramp=[mix(hx('4E8A4A'), INK, 0.45), hx('4E8A4A'), hx('6FAE5C'), hx('9CCB7E'),
                         mix(hx('9CCB7E'), hx('FFF6D0'), 0.5)],
                   rim=mix(hx('FFF6D0'), GOLD, 0.15)),
    'autumn': dict(ramp=[mix(hx('8A5A30'), INK, 0.3), mix(hx('B07A3E'), hx('D9733A'), 0.35),
                         hx('D9733A'), mix(hx('D9733A'), hx('C9A15A'), 0.55),
                         mix(hx('C9A15A'), hx('FFE0A3'), 0.6)],
                   rim=hx('FFE0A3'), extra='autumn', light_col=hx('FFE0A3')),
    'winter': dict(ramp=[mix(mix(hx('4E8A4A'), hx('93A9BF'), 0.5), INK, 0.4),
                         mix(hx('4E8A4A'), hx('93A9BF'), 0.6), mix(hx('6FAE5C'), hx('B9C9D8'), 0.65),
                         hx('B9C9D8'), hx('DDE6EE')],
                   rim=WHITE, rim_amt=0.6, extra='snow', sparse=True, bare=True),
    'moon': dict(ramp=[mix(hx('22303F'), INK, 0.2), mix(hx('22303F'), hx('4E8A4A'), 0.25),
                       mix(hx('2E3C4E'), hx('4E8A4A'), 0.5), mix(hx('3B4A5E'), hx('6FAE5C'), 0.5),
                       mix(mix(hx('3B4A5E'), hx('6FAE5C'), 0.5), hx('FFE6B0'), 0.35)],
                 rim=hx('FFE6B0'), rim_amt=1.0, light=(0.6, -0.72, 0.6), rim_w=7),
}


def make_tree(season):
    S = 2
    W, H = 360, 480
    rng = np.random.default_rng({'spring': 11, 'summer': 12, 'autumn': 13, 'winter': 14,
                                 'moon': 15}[season])
    cv = Canvas(W * S, H * S)
    st = TREE_STYLES[season]
    shadow_col = INK if season != 'winter' else mix(INK, hx('93A9BF'), 0.4)
    if season == 'moon':
        shadow_col = mix(INK, hx('22303F'), 0.3)
    if season == 'winter':
        contact_shadow(cv, 180 * S, 468 * S, 120 * S, 16 * S, 0.9, mix(WHITE, hx('DDE6EE'), 0.4), 0.3)
        contact_shadow(cv, 186 * S, 470 * S, 92 * S, 11 * S, 0.3, shadow_col, 0.7)
    else:
        contact_shadow(cv, 186 * S, 470 * S, 118 * S, 15 * S, 0.34, shadow_col, 0.7)
    D = Dabs(rng)
    if season != 'winter':
        gcol = {'spring': hx('5E9A66'), 'summer': hx('4E8A4A'), 'autumn': hx('B07A3E'),
                'moon': hx('2E3C4E')}[season]
        n = 70
        gx = 180 * S + rng.normal(0, 38 * S, n)
        L_ = rng.uniform(6, 14, n) * S
        a_ = -PI / 2 + rng.normal(0, 0.35, n)
        cs = mix(gcol, CREAM, rng.uniform(0, 0.25, n))
        D.add(gx + np.cos(a_) * L_ * 0.8, 474 * S + np.sin(a_) * L_ * 0.8, L_, L_ / 6, a_, cs,
              0.85, n=8, shape='leaf')
    paint_tree(cv, 180 * S, 190 * S, 150 * S, 180 * S, 476 * S, st, rng)
    if D.items:
        # grass tufts in front of the trunk foot
        img_a = cv.a.copy()
        L = Layer(cv.w, cv.h)
        for poly, _ in D.items:
            L.d.polygon(poly, fill=255)
        gm = L.arr()
        cv.paint(gm, np.zeros(3), 0.0)
        cv.a = np.maximum(img_a, gm * 0.85)
        cv.dabs(D, gm)
    if season == 'spring':
        # a few petals settled in the grass
        L = Layer(cv.w, cv.h)
        D = Dabs(rng)
        n = 14
        px = 180 * S + rng.normal(0, 60 * S, n)
        py = 470 * S + rng.normal(0, 4 * S, n)
        D.add(px, py, 3.2 * S, 1.8 * S, rng.uniform(0, PI, n), hx('F3B6C6'), 1.0, n=8)
        for poly, _ in D.items:
            L.d.polygon(poly, fill=255)
        pm = L.arr()
        cv.paint(pm, mix(hx('F3B6C6'), CREAM, 0.2), 0.95)
    if season == 'autumn':
        L = Layer(cv.w, cv.h)
        Dl = Dabs(rng)
        n = 9
        px = 180 * S + rng.normal(0, 70 * S, n)
        py = 470 * S + rng.normal(0, 5 * S, n)
        Dl.add(px, py, 5 * S, 2.2 * S, rng.uniform(0, PI, n), hx('D9733A'), 1.0, n=10, shape='leaf')
        for poly, _ in Dl.items:
            L.d.polygon(poly, fill=255)
        cv.paint(L.arr(), mix(hx('D9733A'), hx('C9A15A'), 0.3), 0.95)
    return save_png(cv, f'tree_{season}.png', (W, H))


# --------------------------------------------------------------------------
# fruit
# --------------------------------------------------------------------------
def sdf_circle(xx, yy, cx, cy, r):
    return np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) - r


def smin(a, b, k):
    hh = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - hh) + a * hh - k * hh * (1 - hh)


def leaf_poly(x, y, length, width, ang, n=24):
    t = np.linspace(0, PI, n)
    up = np.stack([np.sin(t / 2) * 0 + (1 - np.cos(t)) / 2 * length, np.sin(t) * width / 2], 1)
    lo = up[::-1] * np.array([1, -1])
    pts = np.vstack([up, lo])
    ca, sa = math.cos(ang), math.sin(ang)
    return [(x + px * ca - py * sa, y + px * sa + py * ca) for px, py in pts]


def make_fruit(kind):
    S = 4
    N = 96 * S
    rng = np.random.default_rng({'apple': 21, 'pear': 22, 'plum': 23, 'peach': 24}[kind])
    cv = Canvas(N, N)
    yy, xx = grid(N, N)
    f = lambda v: v * S
    base = FRUIT[kind]
    if kind == 'apple':
        d = smin(sdf_circle(xx, yy, f(40), f(53), f(30)), sdf_circle(xx, yy, f(56), f(53), f(30)), f(8))
        d = smin(d, sdf_circle(xx, yy, f(48), f(62), f(28)), f(6))
        d = -smin(-d, sdf_circle(xx, yy, f(48), f(19), f(9)), f(7))
        stem = [(f(48), f(29)), (f(49), f(20)), (f(52), f(10))]
        leaf = (f(51), f(17), f(25), f(11), -0.35)
        R = f(34)
    elif kind == 'pear':
        d = smin(sdf_circle(xx, yy, f(48), f(64), f(28)), sdf_circle(xx, yy, f(46), f(34), f(15)), f(16))
        stem = [(f(46), f(21)), (f(47), f(13)), (f(51), f(5))]
        leaf = (f(49), f(11), f(23), f(10), -0.25)
        R = f(30)
    elif kind == 'plum':
        d = (np.sqrt(((xx - f(48)) / f(33)) ** 2 + ((yy - f(55)) / f(36)) ** 2) - 1) * f(33)
        d = -smin(-d, sdf_circle(xx, yy, f(47), f(16), f(6)), f(6))
        stem = [(f(47), f(22)), (f(48), f(14)), (f(51), f(8))]
        leaf = (f(50), f(14), f(22), f(9.5), -0.5)
        R = f(34)
    else:
        d = sdf_circle(xx, yy, f(48), f(56), f(36))
        d = -smin(-d, sdf_circle(xx, yy, f(48), f(17), f(7)), f(8))
        stem = [(f(48), f(23)), (f(49), f(16)), (f(52), f(10))]
        leaf = (f(50), f(16), f(24), f(10.5), -0.4)
        R = f(36)
    m = smoothstep(f(0.4), -f(0.4), d)
    hgt = np.sqrt(np.clip(R * R - np.clip(R + d, 0, None) ** 2, 0, None))
    hgt = blur(hgt, 1.5 * S)
    lit = mix(hx('FFF0B8'), CREAM, 0.5)
    cols = [mix(mix(base, DUSK, 0.4), INK, 0.4), mix(mix(base, DUSK, 0.15), INK, 0.2), base,
            mix(base, lit, 0.28), mix(base, lit, 0.55)]
    if kind == 'pear':
        cols = [mix(mix(base, hx('8A5A30'), 0.4), INK, 0.35), mix(base, hx('8A5A30'), 0.3), base,
                mix(base, lit, 0.35), mix(base, lit, 0.6)]
    if kind == 'peach':
        cols = [mix(mix(base, hx('D9733A'), 0.55), DUSK, 0.3), mix(base, hx('D9733A'), 0.4), base,
                mix(base, lit, 0.3), mix(base, lit, 0.6)]
    light = (-0.6, -0.75, 0.62)
    lam = lambert(hgt, light)
    t = 0.5 + (lam - 0.45) * 0.95 + fbm(N, N, 10 * S, 3, rng) * 0.1
    gy, gx = np.gradient(blur(m, 3 * S))
    gl = np.sqrt(gx ** 2 + gy ** 2) + 1e-6
    bounce = np.clip(m * (1 - blur(m, 4 * S)) * 2, 0, 1) * np.clip((gx * -0.6 + gy * -0.75) / gl, 0, 1)
    t += bounce * 0.25
    col = ramp(soft_poster(t, 4, 0.45), cols)
    if kind == 'peach':
        blush = smoothstep(0.0, 0.5, fbm(N, N, 14 * S, 3, rng) + 0.3 - np.hypot(xx - f(62), yy - f(50)) / f(34))
        col = mix(col, mix(hx('D9733A'), FRUIT['apple'], 0.35), np.clip(blush, 0, 1) * 0.55)
    if kind == 'apple':
        streak = smoothstep(0.1, 0.4, fbm_stretch(N, N, 5 * S, 3, rng, sx=1, sy=4) + 0.1)
        col = mix(col, mix(base, hx('F7D46A'), 0.35), streak * 0.25 * np.clip(t, 0, 1))
    cv.paint(m, col)
    texture(cv, m, rng, 650, 3.2 * S, jitter=0.05, alpha=(0.2, 0.45), elong=2.4, angle=tangent(hgt),
            angle_jit=0.3, clip=m)
    # crease line for plum / peach
    if kind in ('plum', 'peach'):
        L = Layer(N, N)
        cr = catmull([(f(47), f(22)), (f(42), f(38)), (f(41), f(56)), (f(45), f(74))], 12)
        L.taper(cr, 2.6 * S, 0.8 * S)
        cv.paint(L.arr(1.2 * S) * m, mix(cols[0], cols[1], 0.4), 0.55)
    D = Dabs(rng)
    if kind == 'apple':
        n = 40
        idx = rng.choice(np.flatnonzero((m > 0.9).ravel()), n)
        py, px = np.divmod(idx, N)
        D.add(px, py, 0.9 * S, 0.7 * S, 0, mix(base, CREAM, 0.6), 0.45, n=6)
    elif kind == 'pear':
        n = 90
        idx = rng.choice(np.flatnonzero((m > 0.9).ravel()), n)
        py, px = np.divmod(idx, N)
        D.add(px, py, rng.uniform(0.6, 1.2, n) * S, 0.6 * S, 0, mix(base, hx('8A5A30'), 0.6), 0.5, n=6)
    elif kind == 'plum':
        n = 260
        idx = rng.choice(np.flatnonzero((m > 0.9).ravel()), n)
        py, px = np.divmod(idx, N)
        D.add(px, py, rng.uniform(1.5, 3.5, n) * S, rng.uniform(1, 2, n) * S, rng.uniform(0, PI, n),
              mix(base, hx('B9C9D8'), 0.55), 0.22, n=8)
    else:
        n = 400
        idx = rng.choice(np.flatnonzero((m > 0.9).ravel()), n)
        py, px = np.divmod(idx, N)
        D.add(px, py, 0.7 * S, 0.7 * S, 0, mix(base, CREAM, 0.6), 0.14, n=6)
    cv.dabs(D, m)
    # painterly highlight: two dabs, not a gradient
    hxp, hyp = f(35), f(39) if kind != 'pear' else f(50)
    if kind == 'pear':
        hxp = f(36)
    ha = 0.55 if kind == 'plum' else 0.85
    D.add(hxp, hyp, 7.5 * S, 4.2 * S, -0.75, mix(CREAM, base, 0.15), ha * 0.75, n=14)
    D.add(hxp - 1.2 * S, hyp - 0.8 * S, 3.4 * S, 1.9 * S, -0.75, CREAM, ha, n=12)
    cv.dabs(D, m)
    # stem
    L = Layer(N, N)
    L.taper(catmull(stem, 8), 3.6 * S, 2.4 * S)
    sm = L.arr(0.8 * S)
    paint_part(cv, sm, tones(BARK, BARK_LIGHT, lift=0.8), rng, soft=1.5 * S, levels=3, tex=0)
    # leaf
    lx_, ly_, ll, lw, la = leaf
    L = Layer(N, N)
    L.poly(leaf_poly(lx_, ly_, ll, lw, la))
    lm = L.arr(0.8 * S)
    lc = [mix(hx('4E8A4A'), INK, 0.35), hx('4E8A4A'), hx('6FAE5C'), mix(hx('9CCB7E'), lit, 0.4)]
    yyl = (yy - ly_) * math.cos(la) - (xx - lx_) * math.sin(la)
    lt = np.where(yyl < 0, 0.75, 0.35) + fbm(N, N, 4 * S, 2, rng) * 0.2
    cv.paint(lm, ramp(np.clip(lt, 0, 1), lc))
    texture(cv, lm, rng, 120, 2.2 * S, jitter=0.06, alpha=(0.3, 0.6), elong=2.5, angle=la + 0.6,
            clip=lm)
    L = Layer(N, N)
    L.taper([(lx_ + math.cos(la) * ll * t_, ly_ + math.sin(la) * ll * t_) for t_ in (0.05, 0.5, 0.92)],
            1.4 * S, 0.5 * S)
    cv.paint(L.arr(0.6 * S) * lm, lc[0], 0.6)
    return save_png(cv, f'fruit_{kind}.png', (96, 96))


# --------------------------------------------------------------------------
# baskets (procedural interlaced weave)
# --------------------------------------------------------------------------
BASKETS = {
    'willow': dict(c=mix(hx('C9A15A'), hx('B07A3E'), 0.35), rim=None, seed=31),
    'rush': dict(c=mix(mix(hx('9CCB7E'), hx('C9B33F'), 0.5), hx('B07A3E'), 0.12), rim=None, seed=32),
    'cedar': dict(c=mix(mix(hx('8A5A30'), hx('C8463D'), 0.3), INK, 0.12), rim=None, seed=33),
    'birch': dict(c=mix(mix(CREAM, hx('B9C9D8'), 0.55), hx('C9A15A'), 0.08), rim=None, seed=34, birch=True),
    'moon': dict(c=mix(DUSK, hx('2E3C4E'), 0.15), rim=GOLD, seed=35),
}
BASKET_RIM_Y = 110


def rope(dr_rgb, dr_m, pts, thick, base, light2, rng, twist=0.85, step=None, s=1.0):
    """Twisted rope along a polyline, drawn opaque into an RGB + mask layer pair."""
    pts = np.asarray(pts)
    seglen = np.hypot(*np.diff(pts, axis=0).T)
    cum = np.concatenate([[0], np.cumsum(seglen)])
    step = step or thick * 0.42
    cols = tones(base, lift=0.6)
    for dist in np.arange(0, cum[-1], step):
        i = min(np.searchsorted(cum, dist) - 1, len(pts) - 2)
        i = max(i, 0)
        u = (dist - cum[i]) / max(seglen[i], 1e-6)
        p = pts[i] + (pts[i + 1] - pts[i]) * u
        tx, ty = (pts[i + 1] - pts[i]) / max(seglen[i], 1e-6)
        nx, ny = -ty, tx
        if ny < 0:
            nx, ny = -nx, -ny
        lit = np.clip(0.55 - (nx * light2[0] + ny * light2[1]) * 0.35 + rng.normal(0, 0.05), 0, 1)
        ang = math.atan2(ty, tx) + twist
        for (o, rx, ry, cl) in [(0.18, 0.62, 0.34, 0.0), (0.0, 0.58, 0.28, lit),
                                (-0.12, 0.34, 0.1, min(1, lit + 0.3))]:
            cx, cy = p[0] + nx * thick * o, p[1] + ny * thick * o
            c = ramp(np.array(cl), cols)
            t = np.linspace(0, 2 * PI, 14, endpoint=False)
            ca, sa = math.cos(ang), math.sin(ang)
            poly = [(cx + thick * rx * math.cos(a) * ca - thick * ry * math.sin(a) * sa,
                     cy + thick * rx * math.cos(a) * sa + thick * ry * math.sin(a) * ca) for a in t]
            cc = tuple(int(v) for v in np.clip(c * 255, 0, 255))
            dr_rgb.polygon(poly, fill=cc)
            dr_m.polygon(poly, fill=255)


def commit(cv, rgb_im, m_im, soft=0.0):
    m = np.asarray(m_im, np.float32) / 255.0
    if soft:
        m = blur(m, soft, 1)
    cv.paint(m, np.asarray(rgb_im, np.float32) / 255.0)


def make_basket(name):
    S = 2
    W, H = 480, 300
    cfg = BASKETS[name]
    rng = np.random.default_rng(cfg['seed'])
    w, h = W * S, H * S
    cv = Canvas(w, h)
    yy, xx = grid(h, w)
    C = cfg['c']
    cx = 240 * S
    y0, rx0, ry0 = BASKET_RIM_Y * S, 205 * S, 32 * S
    y1, ry1 = 262 * S, 20 * S
    hw = lambda t: (205 - 50 * t ** 1.5) * S
    ryt = lambda t: ry0 + (ry1 - ry0) * t
    light2 = (-0.6, -0.8)
    contact_shadow(cv, 246 * S, 283 * S, 175 * S, 12 * S, 0.3, INK, 0.7)
    rimc = cfg['rim'] if cfg['rim'] is not None else mix(C, INK, 0.08)
    # back rim (behind the opening)
    rgb = Image.new('RGB', (w, h))
    mm = Image.new('L', (w, h), 0)
    dr, dm = ImageDraw.Draw(rgb), ImageDraw.Draw(mm)
    ph = np.linspace(PI, 2 * PI, 90)
    back = np.stack([cx + rx0 * np.cos(ph), y0 + ry0 * np.sin(ph)], 1)
    rope(dr, dm, back, 18 * S, mix(rimc, INK, 0.2), light2, rng)
    commit(cv, rgb, mm)
    # interior: inner back wall with faint weave, deepening toward the front lip
    e = ((xx - cx) / rx0) ** 2 + ((yy - y0) / ry0) ** 2
    im = smoothstep(1.0, 0.96, e)
    s_ = np.clip((xx - cx) / rx0, -0.999, 0.999)
    ytop = y0 - ry0 * np.sqrt(1 - s_ ** 2)
    v = (yy - ytop) / S
    th = np.arcsin(s_)
    wf = 0.5 + 0.5 * np.sin(v / 17 * 2 * PI)
    st = 0.5 + 0.5 * np.cos(th * 17 / PI * 2 * PI)
    depth = np.clip((yy - (y0 - ry0)) / (2 * ry0), 0, 1)
    tcol = 0.45 - depth * 0.32 + (wf * 0.26 + st * 0.1) * (1 - depth * 0.7) + 0.08 * (s_ > 0) * (1 - depth)
    icol = ramp(np.clip(tcol, 0, 1), [mix(C, INK, 0.8), mix(C, INK, 0.6), mix(C, INK, 0.35)])
    cv.paint(im, icol)
    texture(cv, im, rng, 900, 5 * S, jitter=0.06, alpha=(0.2, 0.4), elong=3.5, angle=0.0,
            angle_jit=0.15, clip=im)
    # handle
    rgb = Image.new('RGB', (w, h))
    mm = Image.new('L', (w, h), 0)
    dr, dm = ImageDraw.Draw(rgb), ImageDraw.Draw(mm)
    ph = np.linspace(PI * 1.03, PI * 1.97, 120)
    hrx, hry = 178 * S, 100 * S
    hp = np.stack([cx + hrx * np.cos(ph), y0 + 6 * S + hry * np.sin(ph)], 1)
    hp = np.vstack([[cx - hrx * 0.99, y0 + 20 * S], hp, [cx + hrx * 0.99, y0 + 20 * S]])
    rope(dr, dm, hp, 15 * S, rimc, light2, rng, twist=0.9)
    commit(cv, rgb, mm)
    # front body: inverse-map each pixel onto the basket surface (theta, t)
    t = np.clip((yy - y0) / (y1 - y0), -0.5, 1.5)
    for _ in range(8):
        sx = np.clip((xx - cx) / hw(np.clip(t, 0, 1)), -1, 1)
        cth = np.sqrt(1 - sx ** 2)
        t = (yy - y0 - ryt(np.clip(t, 0, 1)) * cth) / (y1 - y0)
    tc = np.clip(t, 0, 1)
    sx_raw = (xx - cx) / hw(tc)
    side = (1 - np.abs(sx_raw)) * hw(tc)
    body = smoothstep(-0.8, 0.8, np.minimum(side, (1 - t) * (y1 - y0))) * (t > -0.02)
    body *= smoothstep(-0.03, 0.0, t)
    th = np.arcsin(np.clip(sx_raw, -1, 1))
    u = th / (PI / 2)
    nst, nrow = 17, 9
    sxs = (u + 1) / 2 * nst
    sys_ = tc * nrow
    ic, jc = np.floor(sxs), np.floor(sys_)
    fx, fy = sxs - ic, sys_ - jc
    over = ((ic + jc) % 2 == 0)
    cell_rand = np.random.default_rng(cfg['seed'] + 100).normal(0, 1, (nrow + 2, nst + 2))
    cr = cell_rand[np.clip(jc.astype(int), 0, nrow + 1), np.clip(ic.astype(int), 0, nst + 1)]
    weft_cov = smoothstep(0.02, 0.1, fy) * smoothstep(0.98, 0.9, fy)
    stake_w = 0.17
    stake_cov = smoothstep(stake_w + 0.03, stake_w, np.abs(fx - 0.5))
    fyn = np.clip((fy - 0.04) / 0.92, 0, 1)
    weft_b = 0.55 + 0.45 * np.clip(np.sin(PI * fyn), 0, 1) ** 0.7 + 0.12 * (0.5 - fyn)
    weft_b *= np.where(over, 1.0 + 0.08 * (1 - np.abs(fx - 0.5) * 2),
                       0.72 + 0.28 * smoothstep(0.15, 0.45, np.abs(fx - 0.5)))
    stake_b = 0.6 + 0.3 * np.cos(np.clip((fx - 0.5) / stake_w, -1, 1) * PI / 2)
    fib_w = fbm_stretch(h, w, 3 * S, 2, rng, sx=10, sy=1)
    fib_s = fbm_stretch(h, w, 3 * S, 2, rng, sx=1, sy=6)
    weft_b = weft_b * (1 + fib_w * 0.3) + cr * 0.07
    stake_b = stake_b * (1 + fib_s * 0.2) * 0.92
    under_stake = (~over) & (stake_cov > 0)
    gap_b = np.where(stake_cov > 0.5, stake_b * 0.75, 0.12)
    b = gap_b
    b = np.where(weft_cov > 0, gap_b * (1 - weft_cov) + weft_b * weft_cov, b)
    b = np.where(under_stake, b * (1 - stake_cov) + stake_b * stake_cov, b)
    cyl = 0.5 + 0.5 * np.clip(np.cos(th + 0.55), 0, 1) ** 0.8
    shade = cyl * (0.82 + 0.18 * (1 - tc ** 3)) * (0.72 + 0.28 * smoothstep(0.0, 0.14, tc))
    bt = np.clip(b * shade, 0, 1.25) / 1.25
    wcols = [mix(C, INK, 0.72), mix(mix(C, DUSK, 0.2), INK, 0.42), mix(C, INK, 0.15), C,
             mix(C, CREAM, 0.42)]
    bcol = ramp(bt, wcols)
    if cfg.get('birch'):
        ticks = (fbm_stretch(h, w, 2 * S, 1, rng, sx=5, sy=1) > 0.42) & (weft_cov > 0.6)
        bcol = mix(bcol, mix(INK, C, 0.35), ticks.astype(np.float32) * 0.7)
    cv.paint(body, bcol)
    texture(cv, body, rng, 3200, 4.5 * S, jitter=0.06, alpha=(0.2, 0.45), elong=4, angle=0.0,
            angle_jit=0.12, clip=body, shape='leaf')
    # front rim on top
    rgb = Image.new('RGB', (w, h))
    mm = Image.new('L', (w, h), 0)
    dr, dm = ImageDraw.Draw(rgb), ImageDraw.Draw(mm)
    ph = np.linspace(-0.02, PI + 0.02, 110)
    front = np.stack([cx + rx0 * np.cos(ph), y0 + ry0 * np.sin(ph)], 1)[::-1]
    rope(dr, dm, front, 19 * S, rimc, light2, rng)
    commit(cv, rgb, mm)
    if name == 'moon':
        # a thin gold band stitched below the rim
        band = np.exp(-((tc - 0.16) / 0.018) ** 2) * body
        cv.paint(band, mix(GOLD, CREAM, 0.15), 0.85)
    return save_png(cv, f'basket_{name}.png', (W, H))


# --------------------------------------------------------------------------
# keepsakes
# --------------------------------------------------------------------------
def shape_mask(w, h, fn, soft=0.8):
    L = Layer(w, h)
    fn(L)
    return L.arr(soft)


def wood(base=None):
    return tones(BARK if base is None else base, BARK_LIGHT, lift=0.75, deep=0.42)


def make_keepsake(name):
    S = 3
    W = H = 240
    w, h = W * S, H * S
    rng = np.random.default_rng(abs(hash(name)) % 1000 if False else
                                {'lantern': 41, 'beehive': 42, 'scarecrow': 43, 'windmill': 44,
                                 'swing': 45, 'birdhouse': 46}[name])
    cv = Canvas(w, h)
    f = lambda v: v * S
    P = lambda pts: [(f(x), f(y)) for x, y in pts]
    warm = hx('FFF0B8')
    if name == 'lantern':
        contact_shadow(cv, f(118), f(224), f(70), f(9), 0.3)
        glow(cv, f(150), f(214), f(55), GOLD, 0.18)
        post = shape_mask(w, h, lambda L: L.taper(
            [(f(95), f(226)), (f(95), f(120)), (f(96), f(62)), (f(108), f(44)), (f(128), f(40)),
             (f(146), f(46)), (f(150), f(58))], f(11), f(6)))
        paint_part(cv, post, wood(), rng, soft=f(3), levels=4, tex_size=f(1.2), elong=4)
        cord = shape_mask(w, h, lambda L: L.line([(f(150), f(56)), (f(150), f(80))], f(2.2)))
        cv.paint(cord, mix(INK, BARK, 0.5))
        glow(cv, f(150), f(124), f(92), mix(GOLD, warm, 0.4), 0.32)
        body = shape_mask(w, h, lambda L: L.ellipse(f(150), f(124), f(34), f(42)))
        yy, xx = grid(h, w)
        dd = np.sqrt(((xx - f(146)) / f(34)) ** 2 + ((yy - f(120)) / f(42)) ** 2)
        lt = np.clip(1 - dd, 0, 1) ** 0.8 + fbm(h, w, f(4), 2, rng) * 0.12
        lcols = [mix(GOLD, hx('B07A3E'), 0.45), mix(GOLD, hx('D9733A'), 0.2), GOLD,
                 mix(GOLD, warm, 0.6), mix(warm, CREAM, 0.6)]
        cv.paint(body, ramp(soft_poster(np.clip(lt, 0, 1), 4, 0.5), lcols))
        texture(cv, body, rng, 500, f(2.2), jitter=0.04, alpha=(0.2, 0.45), elong=3, angle=0.0, clip=body)
        ribs = np.zeros((h, w), np.float32)
        for k in range(-3, 4):
            yk = f(124) + k * f(10.5)
            half = f(34) * math.sqrt(max(0, 1 - ((yk - f(124)) / f(42)) ** 2))
            m = shape_mask(w, h, lambda L, yk=yk, half=half: L.line(
                [(f(150) - half, yk), (f(150), yk + f(3)), (f(150) + half, yk)], f(1.4)), 0.6)
            ribs = np.maximum(ribs, m)
        cv.paint(ribs * body, mix(GOLD, hx('8A5A30'), 0.55), 0.55)
        caps = shape_mask(w, h, lambda L: (L.ellipse(f(150), f(83), f(17), f(5)),
                                           L.poly(P([(133, 80), (167, 80), (164, 90), (136, 90)])),
                                           L.ellipse(f(150), f(166), f(15), f(4.5)),
                                           L.poly(P([(136, 160), (164, 160), (161, 170), (139, 170)]))))
        paint_part(cv, caps, wood(mix(BARK, INK, 0.2)), rng, soft=f(2), levels=3, tex=0.5)
        tas = shape_mask(w, h, lambda L: L.taper([(f(150), f(170)), (f(150), f(190))], f(5), f(2)))
        cv.paint(tas, mix(hx('C8463D'), DUSK, 0.3), 0.9)
    elif name == 'beehive':
        contact_shadow(cv, f(124), f(214), f(92), f(12), 0.32)
        board = shape_mask(w, h, lambda L: (L.ellipse(f(120), f(203), f(84), f(13)),
                                            L.poly(P([(36, 203), (204, 203), (204, 213), (36, 213)])),
                                            L.ellipse(f(120), f(213), f(84), f(10))))
        paint_part(cv, board, wood(), rng, soft=f(3), levels=4, tex_size=f(1.5), elong=5)
        straw = mix(hx('C9A15A'), hx('C9B33F'), 0.35)
        sc = tones(straw, warm, lift=0.6)
        rows = 8
        for k in range(rows):
            v = k / rows
            yk = f(196) - k * f(17.5)
            half = f(76) * math.sqrt(max(0.04, 1 - (k / (rows - 0.2)) ** 2.2))
            hk = f(11)
            m = shape_mask(w, h, lambda L, yk=yk, half=half, hk=hk: (
                L.ellipse(f(120) - half + hk, yk, hk, hk), L.ellipse(f(120) + half - hk, yk, hk, hk),
                L.poly([(f(120) - half + hk, yk - hk), (f(120) + half - hk, yk - hk),
                        (f(120) + half - hk, yk + hk), (f(120) - half + hk, yk + hk)])))
            yyk, xxk = grid(h, w)
            curve = m * 0
            paint_part(cv, m, sc, rng, soft=f(5), levels=4, tex=0.0)
            texture(cv, m, rng, int(half / S * 6), f(3), jitter=0.08, alpha=(0.3, 0.6), elong=5,
                    angle=0.0, angle_jit=0.15, clip=m, shape='leaf')
            D = Dabs(rng)
            nt = max(2, int(half / f(14)))
            for j in range(nt):
                tx = f(120) - half + hk + (2 * half - 2 * hk) * (j + 0.5) / nt
                D.add(tx, yk, f(2), f(8), 0.4, mix(straw, INK, 0.5), 0.6, n=8)
            cv.dabs(D, m)
        top = shape_mask(w, h, lambda L: L.ellipse(f(120), f(56), f(14), f(9)))
        paint_part(cv, top, sc, rng, soft=f(4), levels=3)
        door = shape_mask(w, h, lambda L: (L.ellipse(f(120), f(194), f(16), f(13)),
                                           L.poly(P([(104, 194), (136, 194), (136, 205), (104, 205)]))))
        cv.paint(door * smoothstep(f(206), f(200), grid(h, w)[0]), mix(INK, DUSK, 0.2), 0.95)
        D = Dabs(rng)
        for (bx, by, ba) in [(170, 92, 0.3), (60, 120, -0.4)]:
            D.add(f(bx) - f(3), f(by) - f(4), f(4), f(2.5), ba - 0.6, mix(CREAM, hx('B9C9D8'), 0.4), 0.7, n=8)
            D.add(f(bx) + f(2), f(by) - f(4), f(4), f(2.5), ba + 0.6, mix(CREAM, hx('B9C9D8'), 0.4), 0.7, n=8)
            D.add(f(bx), f(by), f(5), f(3.4), ba, GOLD, 1.0, n=10)
            D.add(f(bx), f(by), f(1.2), f(3.2), ba, INK, 0.85, n=6)
        Lb = Layer(w, h)
        for poly, _ in D.items:
            Lb.d.polygon(poly, fill=255)
        bm = Lb.arr()
        cv.paint(bm, np.zeros(3), 0.0)
        cv.a = np.maximum(cv.a, bm)
        cv.dabs(D, bm)
    elif name == 'scarecrow':
        contact_shadow(cv, f(126), f(226), f(62), f(9), 0.3)
        pole = shape_mask(w, h, lambda L: (L.taper([(f(120), f(228)), (f(120), f(80))], f(9), f(7)),
                                           L.taper([(f(48), f(106)), (f(192), f(102))], f(7), f(7))))
        paint_part(cv, pole, wood(), rng, soft=f(2.5), levels=4, tex_size=f(1.2), elong=4)
        straw = mix(hx('C9B33F'), hx('C9A15A'), 0.4)
        D = Dabs(rng)
        for (sx0, sy0, a0, n) in [(52, 106, PI, 9), (188, 102, 0, 9), (120, 172, PI / 2, 14)]:
            a = a0 + rng.normal(0, 0.35, n)
            L_ = rng.uniform(10, 18, n) * S
            D.add(f(sx0) + np.cos(a) * L_ * 0.5, f(sy0) + np.sin(a) * L_ * 0.5, L_ * 0.55, f(1.6), a,
                  mix(straw, warm, rng.uniform(0, 0.5, n)), 1.0, n=8, shape='leaf')
        Lb = Layer(w, h)
        for poly, _ in D.items:
            Lb.d.polygon(poly, fill=255)
        stm = Lb.arr()
        cv.paint(stm, straw)
        cv.dabs(D, stm)
        shirt_c = mix(hx('93A9BF'), DUSK, 0.3)
        shirt = shape_mask(w, h, lambda L: (
            L.poly(P([(62, 94), (178, 92), (180, 116), (150, 118), (154, 174), (88, 176), (92, 118), (60, 118)]))))
        paint_part(cv, shirt, tones(shirt_c, warm), rng, soft=f(6), levels=4, tex_size=f(2), elong=2.5)
        patch = shape_mask(w, h, lambda L: L.poly(P([(130, 132), (146, 130), (147, 148), (131, 149)])))
        cv.paint(patch, mix(hx('D9733A'), hx('C9A15A'), 0.3), 0.95)
        D = Dabs(rng)
        for k in range(5):
            D.add(f(129 + k * 4), f(131 + (k % 2)), f(1.6), f(0.6), 1.2, INK, 0.7, n=6)
        for k in range(4):
            D.add(f(120), f(124 + k * 13), f(2.2), f(2.2), 0, mix(CREAM, BARK, 0.3), 0.9, n=8)
        cv.dabs(D, np.maximum(shirt, patch))
        head = shape_mask(w, h, lambda L: L.ellipse(f(120), f(74), f(23), f(24)))
        sack = mix(hx('C9A15A'), CREAM, 0.45)
        paint_part(cv, head, tones(sack, warm), rng, soft=f(6), levels=4, tex_size=f(1.6))
        D = Dabs(rng)
        D.add([f(111), f(129)], [f(74), f(74)], f(2.6), f(3), 0, INK, 0.9, n=10)
        for k in range(6):
            a = PI * (0.2 + 0.6 * k / 5)
            D.add(f(120) + math.cos(a) * f(10), f(80) + math.sin(a) * f(6), f(1.8), f(0.7), a + PI / 2,
                  INK, 0.85, n=6)
        D.add([f(105), f(135)], [f(84), f(84)], f(4), f(2.5), 0, mix(FRUIT['apple'], CREAM, 0.4), 0.45, n=10)
        cv.dabs(D, head)
        hat = shape_mask(w, h, lambda L: (L.ellipse(f(120), f(54), f(42), f(9)),
                                          L.poly(P([(100, 54), (102, 30), (112, 25), (130, 25), (138, 30), (140, 54)]))))
        paint_part(cv, hat, tones(hx('C9A15A'), warm, lift=0.6), rng, soft=f(4), levels=4,
                   tex_size=f(1.6), elong=4)
        band = shape_mask(w, h, lambda L: L.poly(P([(101, 44), (139, 44), (140, 51), (100, 51)])))
        cv.paint(band * hat, DUSK, 0.9)
    elif name == 'windmill':
        contact_shadow(cv, f(126), f(224), f(74), f(10), 0.3)
        wall = mix(CREAM, hx('C9A15A'), 0.28)
        tower = shape_mask(w, h, lambda L: L.poly(P([(84, 222), (156, 222), (142, 98), (98, 98)])))
        paint_part(cv, tower, tones(wall, warm), rng, soft=f(10), levels=4, tex_size=f(2.2), elong=2)
        D = Dabs(rng)
        for k in range(16):
            y = rng.uniform(110, 215)
            D.add(f(rng.uniform(95, 145)), f(y), f(rng.uniform(4, 7)), f(1.6), 0, mix(wall, BARK, 0.35), 0.35, n=8)
        cv.dabs(D, tower)
        door = shape_mask(w, h, lambda L: (L.ellipse(f(120), f(198), f(11), f(10)),
                                           L.poly(P([(109, 198), (131, 198), (131, 222), (109, 222)]))))
        paint_part(cv, door, wood(), rng, soft=f(2), levels=3, tex=0.4)
        win = shape_mask(w, h, lambda L: L.ellipse(f(120), f(146), f(7), f(8)))
        cv.paint(win, mix(GOLD, warm, 0.4), 0.95)
        roof = shape_mask(w, h, lambda L: (L.poly(P([(90, 102), (150, 102), (120, 58)])),
                                           L.ellipse(f(120), f(102), f(30), f(5))))
        paint_part(cv, roof, tones(mix(hx('B07A3E'), FRUIT['apple'], 0.3), warm), rng, soft=f(5),
                   levels=4, tex_size=f(1.5), elong=3)
        hubx, huby = f(120), f(86)
        sail_c = mix(CREAM, hx('DDE6EE'), 0.3)
        for k in range(4):
            a = 0.45 + k * PI / 2
            ca, sa = math.cos(a), math.sin(a)
            nx, ny = -sa, ca
            def sp(t_, o):
                return (hubx + ca * f(t_) + nx * f(o), huby + sa * f(t_) + ny * f(o))
            cloth = shape_mask(w, h, lambda L: L.poly([sp(18, 2), sp(78, 2), sp(78, 20), sp(22, 17)]))
            paint_part(cv, cloth, tones(sail_c, warm), rng, soft=f(4), levels=3, tex_size=f(1.5),
                       light=LIGHT, elong=3)
            frame = shape_mask(w, h, lambda L: (
                L.line([sp(0, 0), sp(80, 0)], f(3.2)),
                L.line([sp(18, 20), sp(79, 20)], f(1.8)),
                *[L.line([sp(t_, 0), sp(t_, 20)], f(1.6)) for t_ in (30, 46, 62, 78)]))
            paint_part(cv, frame, wood(), rng, soft=f(1.5), levels=3, tex=0)
        hub = shape_mask(w, h, lambda L: L.ellipse(hubx, huby, f(6), f(6)))
        paint_part(cv, hub, wood(mix(BARK, INK, 0.2)), rng, soft=f(2), levels=3, tex=0)
    elif name == 'swing':
        contact_shadow(cv, f(126), f(214), f(64), f(9), 0.32)
        branch = shape_mask(w, h, lambda L: L.taper(
            catmull([(f(2), f(44)), (f(60), f(36)), (f(130), f(34)), (f(200), f(28)), (f(238), f(22))], 6),
            f(18), f(9)))
        paint_part(cv, branch, wood(), rng, soft=f(4), levels=4, tex_size=f(1.4), elong=4)
        ropes = shape_mask(w, h, lambda L: (L.line([(f(80), f(38)), (f(84), f(180))], f(2.8)),
                                            L.line([(f(160), f(33)), (f(156), f(180))], f(2.8))))
        rc = mix(hx('C9A15A'), CREAM, 0.35)
        cv.paint(ropes, rc)
        D = Dabs(rng)
        for x0_, x1_, y0_ in [(80, 84, 38), (160, 156, 33)]:
            for yv in np.arange(y0_ + 4, 180, 5):
                tx = x0_ + (x1_ - x0_) * (yv - y0_) / (180 - y0_)
                D.add(f(tx), f(yv), f(1.6), f(0.7), 0.8, mix(rc, BARK, 0.5), 0.6, n=6)
        for xk in (80, 160):
            D.add(f(xk), f(37), f(5), f(4), 0, mix(rc, BARK, 0.3), 1.0, n=10)
        cv.dabs(D, np.maximum(ropes, branch))
        seat = shape_mask(w, h, lambda L: L.poly(P([(66, 178), (174, 178), (172, 190), (68, 190)])))
        paint_part(cv, seat, wood(BARK_LIGHT), rng, soft=f(3), levels=4, tex_size=f(1.4), elong=5)
        D = Dabs(rng)
        leafc = [mix(hx('4E8A4A'), INK, 0.3), hx('4E8A4A'), hx('6FAE5C'), mix(hx('9CCB7E'), warm, 0.4)]
        for (lx0, ly0, n) in [(20, 30, 26), (205, 18, 30), (120, 24, 12)]:
            a = rng.uniform(0, 2 * PI, n)
            r = rng.uniform(0, 22, n) * S
            px = f(lx0) + np.cos(a) * r
            py = f(ly0) + np.sin(a) * r * 0.6
            s = np.clip(0.5 - (np.cos(a) * -0.6 + np.sin(a) * -0.7) * 0.4 * r / f(22), 0, 1)
            D.add(px, py, f(7), f(3.4), rng.uniform(0, PI, n), ramp(s, leafc), 1.0, n=10, shape='leaf')
        Lb = Layer(w, h)
        for poly, _ in D.items:
            Lb.d.polygon(poly, fill=255)
        lm = Lb.arr()
        cv.paint(lm, np.zeros(3), 0.0)
        cv.a = np.maximum(cv.a, lm)
        cv.dabs(D, lm)
    elif name == 'birdhouse':
        contact_shadow(cv, f(124), f(226), f(52), f(8), 0.32)
        post = shape_mask(w, h, lambda L: L.poly(P([(113, 226), (127, 226), (126, 140), (114, 140)])))
        paint_part(cv, post, wood(), rng, soft=f(3), levels=4, tex_size=f(1.2), elong=5)
        body_c = mix(CREAM, hx('F7D46A'), 0.35)
        body = shape_mask(w, h, lambda L: L.poly(P([(82, 150), (158, 150), (158, 92), (120, 60), (82, 92)])))
        paint_part(cv, body, tones(body_c, warm), rng, soft=f(10), levels=4, tex_size=f(2), elong=3)
        D = Dabs(rng)
        for yk in range(98, 150, 9):
            D.add(f(120), f(yk), f(37), f(0.8), 0, mix(body_c, BARK, 0.4), 0.3, n=10)
        cv.dabs(D, body)
        roof_c = mix(mix(hx('8A5A30'), FRUIT['apple'], 0.35), INK, 0.1)
        roof = shape_mask(w, h, lambda L: (L.poly(P([(66, 100), (120, 50), (124, 60), (74, 106)])),
                                           L.poly(P([(174, 100), (120, 50), (116, 60), (166, 106)]))))
        paint_part(cv, roof, tones(roof_c, warm), rng, soft=f(4), levels=4, tex_size=f(1.5), elong=3)
        hole = shape_mask(w, h, lambda L: L.ellipse(f(120), f(108), f(12), f(12)))
        cv.paint(hole, mix(INK, DUSK, 0.25), 0.97)
        lip = shape_mask(w, h, lambda L: L.ellipse(f(118), f(104), f(10), f(9)))
        cv.paint(hole * (1 - lip), mix(INK, body_c, 0.4), 0.6)
        perch = shape_mask(w, h, lambda L: L.line([(f(120), f(130)), (f(120), f(131))], f(5)))
        paint_part(cv, perch, wood(), rng, soft=f(1.5), levels=3, tex=0)
        D = Dabs(rng)
        leafc = [hx('4E8A4A'), hx('6FAE5C'), mix(hx('9CCB7E'), warm, 0.4)]
        for i, (lx0, ly0, la) in enumerate([(160, 102, -0.4), (166, 112, 0.3), (156, 116, 0.9)]):
            D.add(f(lx0), f(ly0), f(8), f(3.6), la, leafc[i], 1.0, n=12, shape='leaf')
        Lb = Layer(w, h)
        for poly, _ in D.items:
            Lb.d.polygon(poly, fill=255)
        lm = Lb.arr()
        cv.paint(lm, leafc[1])
        cv.dabs(D, lm)
    return save_png(cv, f'keep_{name}.png', (W, H))


# --------------------------------------------------------------------------
# hub props
# --------------------------------------------------------------------------
def make_stake():
    S = 3
    W, H = 96, 160
    w, h = W * S, H * S
    rng = np.random.default_rng(51)
    cv = Canvas(w, h)
    f = lambda v: v * S
    contact_shadow(cv, f(52), f(152), f(28), f(6), 0.32)
    post = shape_mask(w, h, lambda L: L.poly([(f(38), f(152)), (f(58), f(152)), (f(57), f(34)),
                                              (f(48), f(24)), (f(39), f(34))]))
    paint_part(cv, post, wood(mix(BARK, BARK_LIGHT, 0.35)), rng, soft=f(3), levels=4,
               tex_size=f(1.0), elong=6)
    D = Dabs(rng)
    for k in range(10):
        x = f(rng.uniform(41, 55))
        D.add(x, f(rng.uniform(55, 145)), f(0.6), f(rng.uniform(5, 12)), PI / 2 + 0.02 * 0, mix(BARK, INK, 0.4),
              0.35, n=8)
    cv.dabs(D, post)
    rib = mix(CREAM, INK, 0.06)
    rc = [mix(rib, INK, 0.32), mix(rib, INK, 0.17), rib, mix(rib, WHITE, 0.6)]
    tails = shape_mask(w, h, lambda L: (
        L.poly([(f(56), f(44)), (f(70), f(48)), (f(82), f(46)), (f(90), f(53)), (f(80), f(57)),
                (f(68), f(56)), (f(56), f(51))]),
        L.poly([(f(56), f(48)), (f(64), f(58)), (f(72), f(70)), (f(80), f(78)), (f(70), f(80)),
                (f(62), f(70)), (f(54), f(54))])))
    paint_part(cv, tails, rc, rng, soft=f(3), levels=4, tex_size=f(1.0), elong=3)
    band = shape_mask(w, h, lambda L: (L.poly([(f(37), f(42)), (f(59), f(40)), (f(59), f(50)), (f(37), f(52))]),
                                       L.ellipse(f(58), f(47), f(4.5), f(4.5))))
    paint_part(cv, band, rc, rng, soft=f(2), levels=4, tex_size=f(1.0), elong=3)
    return save_png(cv, 'stake.png', (W, H))


def make_sapling():
    S = 3
    W, H = 120, 150
    w, h = W * S, H * S
    rng = np.random.default_rng(52)
    cv = Canvas(w, h)
    f = lambda v: v * S
    contact_shadow(cv, f(64), f(142), f(34), f(7), 0.3)
    mound = shape_mask(w, h, lambda L: L.ellipse(f(60), f(141), f(22), f(6)))
    paint_part(cv, mound, tones(mix(hx('8A5A30'), hx('B07A3E'), 0.4), lift=0.5), rng, soft=f(2), levels=3)
    stem = shape_mask(w, h, lambda L: (
        L.taper(catmull([(f(60), f(140)), (f(61), f(110)), (f(58), f(80)), (f(60), f(46))], 6), f(5), f(2.4)),
        L.taper([(f(59), f(98)), (f(46), f(82)), (f(36), f(76))], f(2.6), f(1.4)),
        L.taper([(f(60), f(88)), (f(74), f(72)), (f(84), f(66))], f(2.6), f(1.4))))
    paint_part(cv, stem, wood(), rng, soft=f(1.5), levels=3, tex=0)
    D = Dabs(rng)
    lc = [mix(hx('5E9A66'), INK, 0.3), hx('5E9A66'), hx('82B884'), mix(hx('A9D0A0'), hx('FFF0B8'), 0.45)]
    for (cx, cy, n, r) in [(60, 38, 22, 20), (34, 72, 12, 13), (86, 62, 12, 13), (60, 66, 6, 8)]:
        a = rng.uniform(0, 2 * PI, n)
        rr = rng.uniform(0.2, 1, n) * f(r)
        px, py = f(cx) + np.cos(a) * rr, f(cy) + np.sin(a) * rr * 0.8
        s = np.clip(0.55 + (np.cos(a) * 0.6 + np.sin(a) * 0.7) * -0.35 * rr / f(r) + rng.normal(0, 0.12, n), 0, 1)
        o = np.argsort(s)
        D.add(px[o], py[o], f(rng.uniform(5.5, 8, n)), f(rng.uniform(2.6, 3.6, n)), a[o] + rng.normal(0, 0.4, n),
              ramp(s[o], lc), 1.0, n=12, shape='leaf')
    Lb = Layer(w, h)
    for poly, _ in D.items:
        Lb.d.polygon(poly, fill=255)
    lm = Lb.arr()
    cv.paint(lm, lc[1])
    cv.dabs(D, lm)
    texture(cv, lm, rng, 160, f(1.4), jitter=0.05, alpha=(0.2, 0.4), elong=2.5, clip=lm)
    return save_png(cv, 'sapling.png', (W, H))


def make_mist():
    W, H = 1080, 400
    S = 1
    rng = np.random.default_rng(53)
    cv = Canvas(W, H)
    yy, xx = grid(H, W)
    top = 150 + noise1d(W, 260, rng, 3) * 40
    f = np.full((H, W), -1e9, np.float32)
    x = -60.0
    while x < W + 60:
        r = rng.uniform(50, 110)
        cy = top[int(np.clip(x, 0, W - 1))] + r * 0.6
        f = np.maximum(f, r - np.sqrt((xx - x) ** 2 + ((yy - cy) * 1.25) ** 2))
        x += r * rng.uniform(0.9, 1.4)
    f = np.maximum(f, (yy - top[None, :] - 70))
    f += fbm(H, W, 30, 3, rng) * 30
    body = smoothstep(-35, 25, f)
    fade = 1 - smoothstep(280, 395, yy)
    tex = np.clip(0.82 + fbm(H, W, 90, 3, rng) * 0.5, 0, 1)
    a = np.clip(body * fade * tex, 0, 1)
    a = blur(a, 3)
    v = smoothstep(-20, 70, f)
    col = mix(mix(WHITE, CREAM, 0.35), mix(MIST, DUSK, 0.05), 1 - v * 0.0 + 0 * v)
    col = mix(WHITE, mix(CREAM, MIST, 0.6), smoothstep(10, 120, f))
    cv.paint(a, col)
    texture(cv, a, rng, 2500, 16, jitter=0.02, alpha=(0.1, 0.25), elong=3, angle=0.0, clip=a, where=0.2)
    return save_png(cv, 'mist.png', (W, H))


# --------------------------------------------------------------------------
GROUPS = {
    'bg': lambda: [make_bg(s) for s in ('spring', 'summer', 'autumn', 'winter', 'moon')],
    'splash': lambda: [make_splash()],
    'hub': lambda: [make_hub(s) for s in ('spring', 'summer', 'autumn', 'winter', 'moon')],
    'trees': lambda: [make_tree(s) for s in ('spring', 'summer', 'autumn', 'winter', 'moon')],
    'fruit': lambda: [make_fruit(k) for k in ('apple', 'pear', 'plum', 'peach')],
    'baskets': lambda: [make_basket(k) for k in BASKETS],
    'keepsakes': lambda: [make_keepsake(k) for k in ('lantern', 'beehive', 'scarecrow', 'windmill',
                                                     'swing', 'birdhouse')],
    'props': lambda: [make_stake(), make_sapling(), make_mist()],
}


def main(argv):
    os.makedirs(IMG_DIR, exist_ok=True)
    groups = argv or list(GROUPS)
    t0 = time.time()
    for g in groups:
        t = time.time()
        paths = GROUPS[g]()
        for p in paths:
            print(f'  {os.path.relpath(p, ROOT)}  {os.path.getsize(p) / 1024:.0f} KB')
        print(f'[{g}] {time.time() - t:.1f}s')
    print(f'done in {time.time() - t0:.1f}s')


if __name__ == '__main__':
    main(sys.argv[1:])
