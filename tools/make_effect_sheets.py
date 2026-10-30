"""증강 이펙트 스프라이트 시트 생성기.

실행: python tools/make_effect_sheets.py   -> assets/effects/{dodge,janggi,merge,coup,wizard}_sheet.png
프레임 256x256, 가로 4칸. 모두 불규칙한 면을 겹쳐 칠한 손그림 느낌이다(그림자 → 본색 → 하이라이트).
머리(진행 방향)는 오른쪽(+x), 꼬리는 왼쪽(-x)이다.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 2          # 슈퍼샘플링 배율
F = 256         # 프레임 한 변(px)
W = F * SS
COLS = 4
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "effects")


def hexcolor(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def P(x, y):
    return (x * SS, y * SS)


def ease_out(p):
    return 1 - (1 - p) ** 3


def curve(p0, p1, bend, n=20):
    """p0 -> p1을 bend만큼 휜 2차 곡선으로 샘플링한다."""
    mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dy) or 1.0
    cx, cy = mx - dy / length * bend, my + dx / length * bend
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * cx + t * t * p1[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * cy + t * t * p1[1]) for t in [i / (n - 1) for i in range(n)]]


def sheet(rows):
    img = Image.new("RGBA", (F * COLS, F * len(rows)), (0, 0, 0, 0))
    for r, frames in enumerate(rows):
        for c, frame in enumerate(frames):
            img.paste(frame, (c * F, r * F))
    return img


# ───────── 빛 번짐 캔버스 (합체) ─────────
class Canvas:
    def __init__(self):
        self.rgb = np.zeros((W, W, 3), np.float32)
        self.a = np.zeros((W, W), np.float32)

    def add(self, mask, color, strength=1.0):
        m = np.asarray(mask, np.float32) / 255.0 * strength
        for c in range(3):
            self.rgb[..., c] = 1.0 - (1.0 - self.rgb[..., c]) * (1.0 - np.clip(m * color[c], 0, 1))
        self.a = 1.0 - (1.0 - self.a) * (1.0 - np.clip(m, 0, 1))

    def glow(self, draw_fn, color, core=(1.0, 1.0, 1.0), halo=16, mid=5, tight=1.3, strength=1.0):
        mask = Image.new("L", (W, W), 0)
        draw_fn(ImageDraw.Draw(mask))
        self.add(mask.filter(ImageFilter.GaussianBlur(halo * SS)), color, 0.75 * strength)
        self.add(mask.filter(ImageFilter.GaussianBlur(mid * SS)), color, 1.0 * strength)
        self.add(mask.filter(ImageFilter.GaussianBlur(tight * SS)), core, 1.0 * strength)

    def to_image(self):
        alpha = np.clip(self.a, 0, 1)
        rgb = np.where(alpha[..., None] > 1e-4, self.rgb / np.maximum(self.a, 1e-4)[..., None], 0)
        out = np.dstack([np.clip(rgb, 0, 1), alpha])
        img = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
        return img.resize((F, F), Image.LANCZOS)


def taper(draw, pts, w0, w1, fill=255):
    n = len(pts)
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        j0, j1 = max(i - 1, 0), min(i + 1, n - 1)
        dx, dy = pts[j1][0] - pts[j0][0], pts[j1][1] - pts[j0][1]
        length = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / length, dx / length
        w = (w0 + (w1 - w0) * i / max(n - 1, 1)) * 0.5
        left.append(P(x + nx * w, y + ny * w))
        right.append(P(x - nx * w, y - ny * w))
    draw.polygon(left + right[::-1], fill=fill)


def ring(draw, cx, cy, r, width, a0=0.0, a1=360.0, fill=255):
    pts = []
    steps = max(int(abs(a1 - a0) / 4), 8)
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    draw.line([P(*p) for p in pts], fill=fill, width=max(int(width * SS), 1), joint="curve")


def disc(draw, cx, cy, r, fill=255):
    draw.ellipse([P(cx - r, cy - r), P(cx + r, cy + r)], fill=fill)


# ───────── 손그림 캔버스 (불규칙한 면을 겹쳐 칠한다) ─────────
class Paint:
    """RGBA 면을 위에 덧칠하는 캔버스. 가장자리는 살짝만 흐려 붓 자국처럼 보이게 한다."""

    def __init__(self, w=None, h=None):
        self.w = w or W
        self.h = h or W
        self.img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))

    def fill(self, draw_fn, color, alpha=1.0, soften=0.6, offset=(0, 0)):
        mask = Image.new("L", (self.w, self.h), 0)
        draw_fn(ImageDraw.Draw(mask))
        if soften > 0:
            mask = mask.filter(ImageFilter.GaussianBlur(soften * SS))
        if offset != (0, 0):
            mask = mask.transform(mask.size, Image.AFFINE, (1, 0, -offset[0] * SS, 0, 1, -offset[1] * SS))
        mask = mask.point(lambda v: int(v * alpha))
        layer = Image.new("RGBA", (self.w, self.h), tuple(int(c * 255) for c in color) + (255,))
        layer.putalpha(mask)
        self.img = Image.alpha_composite(self.img, layer)

    def to_image(self):
        return self.img.resize((self.w // SS, self.h // SS), Image.LANCZOS)


def blob(draw, cx, cy, r, lobes=5, jitter=0.18, seed=0, fill=255):
    rnd = random.Random(seed)
    p1, p2, p3 = rnd.uniform(0, 6.28), rnd.uniform(0, 6.28), rnd.uniform(0, 6.28)
    pts = []
    for i in range(56):
        a = math.tau * i / 56
        k = 1 + jitter * math.sin(lobes * a + p1) + jitter * 0.55 * math.sin(lobes * 2 * a + p2) + jitter * 0.3 * math.sin(7 * a + p3)
        pts.append(P(cx + math.cos(a) * r * k, cy + math.sin(a) * r * k))
    draw.polygon(pts, fill=fill)


def band(draw, pts, wfn, jitter=0.0, seed=0, fill=255):
    """pts 중심선을 따라 폭이 wfn(t)로 변하는 면. jitter만큼 가장자리가 울퉁불퉁하다."""
    rnd = random.Random(seed)
    n = len(pts)
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        j0, j1 = max(i - 1, 0), min(i + 1, n - 1)
        dx, dy = pts[j1][0] - pts[j0][0], pts[j1][1] - pts[j0][1]
        length = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / length, dx / length
        t = i / max(n - 1, 1)
        w = wfn(t) * 0.5
        left.append(P(x + nx * w * (1 + rnd.uniform(-jitter, jitter)), y + ny * w * (1 + rnd.uniform(-jitter, jitter))))
        right.append(P(x - nx * w * (1 + rnd.uniform(-jitter, jitter)), y - ny * w * (1 + rnd.uniform(-jitter, jitter))))
    draw.polygon(left + right[::-1], fill=fill)


def wobble_line(p0, p1, amp, waves, seed, n=26):
    rnd = random.Random(seed)
    ph = rnd.uniform(0, 6.28)
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / length, dx / length
    pts = []
    for i in range(n):
        t = i / (n - 1)
        o = math.sin(t * waves * math.tau + ph) * amp * (0.35 + t)
        pts.append((p0[0] + dx * t + nx * o, p0[1] + dy * t + ny * o))
    return pts


# ───────── 느려(회피): 손으로 칠한 바람 가르기와 흙먼지 ─────────
WIND_WHITE, WIND_MID, WIND_SHADE = hexcolor("f6fbff"), hexcolor("bfd8ea"), hexcolor("7c9db8")
DUST_LIGHT, DUST_MID, DUST_SHADE = hexcolor("f1e9d8"), hexcolor("d3c7ae"), hexcolor("a8997c")


def dodge_whoosh(i, n=4):
    p = (i + 0.5) / n
    grow = ease_out(min(p * 1.5, 1.0))
    fade = 1.0 - max(0.0, (p - 0.55) / 0.45) ** 1.5
    c = Paint()
    head = (212.0, 128.0)
    reach = 50 + 150 * grow
    rnd = random.Random(31 + i)
    for k in range(7):
        off = (k - 3) * (11 + 4 * grow)
        tail = (head[0] - reach * rnd.uniform(0.55, 1.0), head[1] + off * 1.05 + rnd.uniform(-3, 3))
        pts = curve((head[0] - 4, head[1] + off * 0.6), tail, off * 0.18 + rnd.uniform(-4, 4))
        wmax = 17 - abs(k - 3) * 2.2

        def wfn(t, wmax=wmax):
            return wmax * (math.sin(math.pi * min(t * 1.15, 1.0)) ** 0.7) * (1 - t * 0.35) + 0.6

        c.fill(lambda d, pts=pts, wfn=wfn, k=k: band(d, pts, lambda t: wfn(t) * 1.3, 0.12, 100 + k), WIND_SHADE, 0.55 * fade, 1.0, offset=(0, 4))
        c.fill(lambda d, pts=pts, wfn=wfn, k=k: band(d, pts, wfn, 0.1, 200 + k), WIND_MID, 0.9 * fade, 0.8)
        c.fill(lambda d, pts=pts, wfn=wfn, k=k: band(d, pts, lambda t: wfn(t) * 0.42, 0.08, 300 + k), WIND_WHITE, fade, 0.6, offset=(0, -1))
    return c.to_image()


def dodge_arrive(i, n=4):
    p = (i + 0.5) / n
    k = ease_out(p)
    fade = (1 - p) ** 1.1
    c = Paint()
    cx = cy = 128.0
    for j in range(9):
        rnd = random.Random(700 + j)
        a = math.tau * j / 9 + rnd.uniform(-0.25, 0.25)
        dist = (20 + rnd.uniform(0, 16)) + 52 * k * rnd.uniform(0.8, 1.15)
        r = (11 + rnd.uniform(0, 8)) * (0.7 + 0.9 * k)
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist * 0.9
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x + 3, y + 4, r, 5, 0.16, 10 + j), DUST_SHADE, 0.7 * fade, 1.0)
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x, y, r, 5, 0.16, 10 + j), DUST_MID, 0.95 * fade, 0.8)
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x - 2, y - 3, r * 0.55, 4, 0.2, 40 + j), DUST_LIGHT, fade, 0.8)
    return c.to_image()


# ───────── 장기: 먹으로 친 붓 고리 (초는 초록, 한은 붉은색 먹물) ─────────
INK = hexcolor("1c1512")
CHO_GREEN = hexcolor("2f8a55")
HAN_RED = hexcolor("c93a2b")


def brush_ring(c, cx, cy, r, sweep, thick, color, alpha, seed, start=-110):
    """붓으로 한 번에 그은 원(엔소). 시작은 굵고 끝은 가늘며, 마른 붓 결이 비친다."""
    rnd = random.Random(seed)
    layers = 9
    for ly in range(layers):
        off = (ly - layers / 2) * thick / layers
        a0 = start + rnd.uniform(-6, 6)
        a1 = a0 + sweep * rnd.uniform(0.86, 1.0)
        steps = max(int((a1 - a0) / 5), 6)
        pts = []
        for s in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * s / steps)
            rr = r + off + math.sin(a * 3 + seed) * 1.6
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))

        def wfn(t, layers=layers):
            return (thick / layers) * 1.5 * (1.05 - 0.85 * t)

        c.fill(lambda d, pts=pts, wfn=wfn, ly=ly: band(d, pts, wfn, 0.25, seed * 10 + ly), color, alpha * rnd.uniform(0.55, 1.0), 0.5)


def janggi_ink(i, color, n=4):
    p = (i + 0.5) / n
    sweep = min(330.0, 130.0 + 220.0 * p * 1.2)
    fade = 1.0 - max(0.0, (p - 0.6) / 0.4) ** 1.3
    c = Paint()
    cx = cy = 128.0
    r = 70 + 16 * ease_out(p)
    brush_ring(c, cx, cy, r + 3, sweep, 22, color, 0.75 * fade, 3)
    brush_ring(c, cx, cy, r, sweep, 20, INK, 0.95 * fade, 5)
    for j in range(16):
        rnd = random.Random(60 + j)
        a = rnd.uniform(0, math.tau)
        d_r = r + 12 + rnd.uniform(0, 44) * (0.35 + ease_out(p))
        sz = rnd.uniform(2.2, 6.0) * (1 - p * 0.4)
        col = color if j % 3 == 0 else INK
        c.fill(lambda d, a=a, d_r=d_r, sz=sz, j=j: blob(d, cx + math.cos(a) * d_r, cy + math.sin(a) * d_r, sz, 3, 0.3, j), col, 0.9 * fade, 0.4)
    return c.to_image()


# ───────── 합체: 손으로 칠한 금빛 소용돌이와 터짐 ─────────
GOLD_DARK, GOLD, GOLD_LIGHT, GOLD_CREAM = hexcolor("8a5a1c"), hexcolor("e0a23a"), hexcolor("ffd77a"), hexcolor("fff3d2")


def merge_vortex(i, n=4):
    p = (i + 0.5) / n
    fade = 1.0 - max(0.0, (p - 0.75) / 0.25)
    c = Paint()
    cx = cy = 128.0
    for arm in range(5):
        rnd = random.Random(20 + arm)
        t_end = rnd.uniform(0.7, 0.98)
        pts = []
        for s in range(30):
            t = s / 29.0 * t_end
            ang = math.radians(arm * 72 + rnd.uniform(-6, 6) * 0 + 280 * t + 80 * p)
            rad = (108 * (1 - 0.5 * p)) * (1 - t) ** 0.85 * rnd.uniform(0.0, 0.0) + (108 * (1 - 0.5 * p)) * (1 - t) ** 0.85 + 8
            pts.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))

        def wfn(t):
            return 3 + 13 * math.sin(math.pi * min(t * 1.05, 1.0)) ** 0.9

        c.fill(lambda d, pts=pts, wfn=wfn, arm=arm: band(d, pts, lambda t: wfn(t) * 1.3, 0.2, 40 + arm), GOLD_DARK, 0.75 * fade, 1.0, offset=(3, 4))
        c.fill(lambda d, pts=pts, wfn=wfn, arm=arm: band(d, pts, wfn, 0.18, 50 + arm), GOLD, 0.95 * fade, 0.7)
        c.fill(lambda d, pts=pts, wfn=wfn, arm=arm: band(d, pts, lambda t: wfn(t) * 0.22, 0.15, 60 + arm), GOLD_LIGHT, 0.9 * fade, 0.5, offset=(-1, -2))
    core = 8 + 22 * p
    c.fill(lambda d: blob(d, cx + 2, cy + 3, core, 5, 0.14, 7), GOLD_DARK, 0.8 * fade, 0.8)
    c.fill(lambda d: blob(d, cx, cy, core, 5, 0.14, 7), GOLD, fade, 0.7)
    c.fill(lambda d: blob(d, cx - 1, cy - 2, core * 0.5, 4, 0.18, 8), GOLD_CREAM, fade, 0.7)
    return c.to_image()


def star_poly(draw, cx, cy, r, points, inner, rot, fill=255):
    pts = []
    for i in range(points * 2):
        rr = r if i % 2 == 0 else r * inner
        a = math.radians(rot + 180.0 * i / points)
        pts.append(P(cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    draw.polygon(pts, fill=fill)


def merge_impact(i, n=4):
    p = (i + 0.5) / n
    k = ease_out(p)
    fade = (1 - p) ** 1.05
    c = Paint()
    cx = cy = 128.0
    for j in range(9):
        rnd = random.Random(900 + j)
        a = math.tau * j / 9 + rnd.uniform(-0.2, 0.2)
        dist = 18 + 54 * k * rnd.uniform(0.85, 1.15)
        r = (11 + rnd.uniform(0, 8)) * (0.7 + 0.9 * k)
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x + 3, y + 4, r, 5, 0.16, 20 + j), GOLD_DARK, 0.75 * fade, 1.0)
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x, y, r, 5, 0.16, 20 + j), GOLD, 0.95 * fade, 0.8)
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x - 2, y - 3, r * 0.5, 4, 0.2, 40 + j), GOLD_CREAM, fade, 0.8)
    flash = max(0.0, 1.0 - p * 1.7)
    if flash > 0.02:
        c.fill(lambda d: star_poly(d, cx + 2, cy + 3, 56 * flash + 6, 8, 0.45, 10), GOLD_DARK, 0.8, 0.8)
        c.fill(lambda d: star_poly(d, cx, cy, 56 * flash + 6, 8, 0.45, 10), GOLD_LIGHT, 1.0, 0.7)
        c.fill(lambda d: star_poly(d, cx, cy, 30 * flash + 3, 8, 0.45, 10), GOLD_CREAM, 1.0, 0.6)
    for j in range(8):
        rnd = random.Random(950 + j)
        a = math.tau * j / 8 + 0.4
        r0 = 34 + 44 * k
        r1 = r0 + 22 * (1 - p) + 8
        pts = [(cx + math.cos(a) * r0, cy + math.sin(a) * r0), (cx + math.cos(a) * r1, cy + math.sin(a) * r1)]
        c.fill(lambda d, pts=pts: band(d, pts, lambda t: 9 * (1 - t) + 1.5, 0.1, 3), GOLD, 0.95 * fade, 0.5)
    for j in range(12):
        rnd = random.Random(970 + j)
        a = rnd.uniform(0, math.tau)
        dist = 52 + rnd.uniform(0, 40) * (0.4 + k)
        c.fill(lambda d, a=a, dist=dist, j=j: blob(d, cx + math.cos(a) * dist, cy + math.sin(a) * dist, 2.6, 3, 0.25, j), GOLD_LIGHT, 0.95 * fade, 0.4)
    return c.to_image()


# ───────── 쿠데타: 흑백이 뒤집히는 먹물 태극 ─────────
CREAM = hexcolor("f3e8cf")


def coup_flip(i, n=4):
    p = (i + 0.5) / n
    k = ease_out(p)
    alpha_out = 1.0 - max(0.0, (p - 0.7) / 0.3)
    fade = 1.0
    R = 52 + 34 * k
    squash = abs(math.cos(math.pi * p * 1.0)) * 0.75 + 0.25  # 동전 뒤집듯 폭이 줄었다 늘어난다
    angle = 200.0 * ease_out(p)
    tile = Paint()
    cx = cy = 128.0

    def disc_mask(d, x, y, r):
        d.ellipse([P(x - r, y - r), P(x + r, y + r)], fill=255)

    # 그림자 → 본체(크림 바탕 위에 먹 반쪽, 위아래 작은 원) → 먹 테두리
    tile.fill(lambda d: disc_mask(d, cx + 3, cy + 4, R + 4), INK, 0.35 * fade, 1.2)
    tile.fill(lambda d: disc_mask(d, cx, cy, R), CREAM, fade, 0.5)
    tile.fill(lambda d: d.pieslice([P(cx - R, cy - R), P(cx + R, cy + R)], 90, 270, fill=255), INK, fade, 0.5)
    tile.fill(lambda d: disc_mask(d, cx, cy - R / 2, R / 2), CREAM, fade, 0.5)
    tile.fill(lambda d: disc_mask(d, cx, cy + R / 2, R / 2), INK, fade, 0.5)
    tile.fill(lambda d: disc_mask(d, cx, cy - R / 2, R / 6), INK, fade, 0.4)
    tile.fill(lambda d: disc_mask(d, cx, cy + R / 2, R / 6), CREAM, fade, 0.4)
    for r in (R + 2.5, R + 5):
        tile.fill(lambda d, r=r: d.arc([P(cx - r, cy - r), P(cx + r, cy + r)], 0, 360, fill=255, width=int(3.5 * SS)), INK, 0.9 * fade, 0.5)
    img = tile.img
    # 회전과 납작해짐(뒤집힘)은 슈퍼샘플링 이미지 전체에 적용한다.
    img = img.rotate(angle, resample=Image.BICUBIC, center=(W / 2, W / 2))
    new_w = max(int(W * squash), 2)
    squashed = img.resize((new_w, W), Image.LANCZOS)
    out = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    out.paste(squashed, ((W - new_w) // 2, 0), squashed)
    tile.img = out
    body_alpha = out.getchannel('A').point(lambda v: int(v * alpha_out))
    tile.img.putalpha(body_alpha)
    # 튀는 먹물과 종이 조각
    for j in range(14):
        rnd = random.Random(1200 + j)
        a = rnd.uniform(0, math.tau)
        dist = R + 10 + rnd.uniform(0, 36) * (0.3 + k)
        sz = rnd.uniform(2.4, 6.0) * (1 - 0.4 * p)
        col = INK if j % 2 == 0 else CREAM
        tile.fill(lambda d, a=a, dist=dist, sz=sz, j=j: blob(d, cx + math.cos(a) * dist, cy + math.sin(a) * dist, sz, 3, 0.3, j), col, 0.95 * alpha_out, 0.4)
    return tile.to_image()


# ───────── 마법사: 화염구(날아가는 불덩이와 맞는 폭발) ─────────
FIRE_DARK, FIRE_RED, FIRE_ORANGE, FIRE_YELLOW, FIRE_WHITE = hexcolor("7a1d0f"), hexcolor("d7381a"), hexcolor("ff7b1f"), hexcolor("ffd24a"), hexcolor("fff4c4")
SMOKE_DARK, SMOKE_MID = hexcolor("3b302c"), hexcolor("6a5d57")


def flame(c, base, tip, width, seed, scale=1.0, alpha=1.0):
    """base에서 tip으로 뻗는, 불규칙하게 넘실대는 불꽃 혓바닥 한 줄기."""
    pts = wobble_line(base, tip, 7 * scale, 1.3, seed)
    for col, k in ((FIRE_DARK, 1.18), (FIRE_RED, 1.0), (FIRE_ORANGE, 0.72), (FIRE_YELLOW, 0.42)):
        c.fill(lambda d, k=k: band(d, pts, lambda t: width * k * (1 - t) ** 0.85 * (1 + 0.3 * math.sin(t * 7 + seed)), 0.1, seed), col, alpha, 0.7)


def wizard_fireball(i, n=4):
    c = Paint()
    rnd = random.Random(40 + i)
    head = (190.0, 128.0)
    for t in range(7):
        off = (t - 3) * 10
        tip = (head[0] - rnd.uniform(80, 150), head[1] + off * 1.6 + rnd.uniform(-10, 10))
        flame(c, (head[0] - 8, head[1] + off * 0.5), tip, 26 - abs(t - 3) * 3.2, 90 + t * 3 + i)
    for t in range(6):
        ex = head[0] - rnd.uniform(40, 150)
        ey = head[1] + rnd.uniform(-46, 46)
        sz = rnd.uniform(1.8, 3.6)
        c.fill(lambda d, ex=ex, ey=ey, sz=sz, t=t: blob(d, ex, ey, sz, 3, 0.2, t), FIRE_YELLOW, 0.95, 0.4)
    for col, rr in ((FIRE_DARK, 36), (FIRE_RED, 32), (FIRE_ORANGE, 26), (FIRE_YELLOW, 17), (FIRE_WHITE, 8)):
        c.fill(lambda d, rr=rr: blob(d, head[0], head[1], rr, 6, 0.1, 5 + i), col, 1.0, 0.7)
    return c.to_image()


def wizard_blast(i, n=4):
    p = (i + 0.5) / n
    k = ease_out(p)
    c = Paint()
    cx = cy = 128.0
    fade = (1 - p) ** 0.9
    if p > 0.35:
        for j in range(8):
            rnd = random.Random(70 + j)
            a = math.tau * j / 8 + rnd.uniform(-0.3, 0.3)
            dist = 26 + 62 * k * rnd.uniform(0.7, 1.1)
            r = (16 + rnd.uniform(0, 12)) * (0.6 + 0.9 * p)
            x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist
            c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x, y, r, 5, 0.22, 300 + j), SMOKE_MID, min(0.9, 0.8 * (p - 0.3) * fade * 1.6), 1.2)
            c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x - 3, y - 4, r * 0.6, 4, 0.22, 320 + j), SMOKE_DARK, 0.35 * fade, 1.0)
    sizes = (1.0, 0.82, 0.6, 0.36, 0.16)
    cols = (FIRE_DARK, FIRE_RED, FIRE_ORANGE, FIRE_YELLOW, FIRE_WHITE)
    base_r = 22 + 66 * k
    core_fade = max(0.0, 1.0 - max(0.0, p - 0.45) / 0.55)
    for col, sz in zip(cols, sizes):
        rr = base_r * sz
        a = core_fade if col in (FIRE_YELLOW, FIRE_WHITE, FIRE_ORANGE) else 0.4 + 0.6 * core_fade
        c.fill(lambda d, rr=rr: blob(d, cx, cy, rr, 7, 0.2, 11 + i), col, a, 0.8)
    for j in range(11):
        rnd = random.Random(210 + j)
        a = math.tau * j / 11 + rnd.uniform(-0.2, 0.2)
        r0 = base_r * 0.7
        r1 = base_r * rnd.uniform(1.15, 1.6)
        pts = [(cx + math.cos(a) * r0, cy + math.sin(a) * r0), (cx + math.cos(a) * r1, cy + math.sin(a) * r1)]
        c.fill(lambda d, pts=pts: band(d, pts, lambda t: 13 * (1 - t) ** 0.9 + 1, 0.1, 1), FIRE_ORANGE, 0.9 * core_fade, 0.6)
    for j in range(10):
        rnd = random.Random(400 + j)
        a = rnd.uniform(0, math.tau)
        dist = base_r * rnd.uniform(1.0, 1.5) + 14 * p
        c.fill(lambda d, a=a, dist=dist, j=j: blob(d, cx + math.cos(a) * dist, cy + math.sin(a) * dist, 2.4, 3, 0.2, j), FIRE_YELLOW, 0.95 * fade, 0.4)
    return c.to_image()


# ───────── 나는 왕: 땅을 가르는 충격파 ─────────
DUST_TAN = hexcolor("c9b48f")
KING_GOLD, KING_GOLD_DARK, KING_GOLD_LIGHT = hexcolor("e8b53f"), hexcolor("8a5a1c"), hexcolor("ffe08a")


def ring_band(c, cx, cy, r, w, base, shade, high, alpha, seed, jitter=0.12):
    pts = [(cx + math.cos(math.tau * i / 72) * r, cy + math.sin(math.tau * i / 72) * r) for i in range(73)]
    rnd = random.Random(seed)
    ph = rnd.uniform(0, 6.28)

    def wfn(t):
        return w * (1 + 0.25 * math.sin(t * 18 + ph))

    c.fill(lambda d: band(d, pts, lambda t: wfn(t) * 1.3, jitter, seed), shade, 0.8 * alpha, 1.0, offset=(2, 3))
    c.fill(lambda d: band(d, pts, wfn, jitter, seed + 1), base, alpha, 0.7)
    c.fill(lambda d: band(d, pts, lambda t: wfn(t) * 0.35, jitter, seed + 2), high, alpha, 0.6, offset=(-1, -1))


def king_shock(i, n=4):
    p = (i + 0.5) / n
    k = ease_out(p)
    fade = (1 - p) ** 1.0
    c = Paint()
    cx = cy = 128.0
    # 땅 갈라짐: 가운데에서 뻗는 먹빛 균열
    for j in range(9):
        rnd = random.Random(2100 + j)
        a = math.tau * j / 9 + rnd.uniform(-0.2, 0.2)
        length = (30 + 78 * k) * rnd.uniform(0.7, 1.15)
        pts = wobble_line((cx + math.cos(a) * 12, cy + math.sin(a) * 12), (cx + math.cos(a) * length, cy + math.sin(a) * length), 5, 3.0, 2200 + j)
        c.fill(lambda d, pts=pts, j=j: band(d, pts, lambda t: 7 * (1 - t) ** 0.8 + 1.0, 0.25, j), INK, 0.9 * (0.4 + 0.6 * fade), 0.5)
    # 충격 고리
    ring_band(c, cx, cy, 16 + 92 * k, 15 * (1 - p * 0.55), KING_GOLD, KING_GOLD_DARK, KING_GOLD_LIGHT, 0.95 * fade + 0.05, 11)
    ring_band(c, cx, cy, 10 + 58 * k, 8 * (1 - p * 0.6), KING_GOLD_LIGHT, KING_GOLD, hexcolor("fff6d0"), 0.9 * fade, 21)
    # 먼지 덩어리
    for j in range(10):
        rnd = random.Random(2300 + j)
        a = math.tau * j / 10 + rnd.uniform(-0.2, 0.2)
        dist = 30 + 70 * k * rnd.uniform(0.85, 1.1)
        r = (10 + rnd.uniform(0, 8)) * (0.7 + 0.8 * k)
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x + 3, y + 4, r, 5, 0.16, 50 + j), DUST_SHADE, 0.7 * fade, 1.0)
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x, y, r, 5, 0.16, 50 + j), DUST_TAN, 0.9 * fade, 0.8)
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x - 2, y - 3, r * 0.5, 4, 0.2, 70 + j), DUST_LIGHT, fade, 0.8)
    flash = max(0.0, 1.0 - p * 1.8)
    if flash > 0.02:
        c.fill(lambda d: star_poly(d, cx + 2, cy + 3, 46 * flash + 6, 10, 0.5, 5), KING_GOLD_DARK, 0.85, 0.8)
        c.fill(lambda d: star_poly(d, cx, cy, 46 * flash + 6, 10, 0.5, 5), KING_GOLD_LIGHT, 1.0, 0.7)
        c.fill(lambda d: star_poly(d, cx, cy, 24 * flash + 3, 10, 0.5, 5), hexcolor("fffaf0"), 1.0, 0.6)
    return c.to_image()


# ───────── 피의 축제: 핏빛 붓 베기와 튀는 핏방울 ─────────
BLOOD_DARK, BLOOD, BLOOD_BRIGHT = hexcolor("5a0b16"), hexcolor("b3141f"), hexcolor("ea4a52")


def blood_slash(i, n=4):
    p = (i + 0.5) / n
    reveal = min(1.0, p * 1.9)
    fade = 1.0 - max(0.0, (p - 0.6) / 0.4) ** 1.2
    c = Paint()
    a0, a1 = (34.0, 52.0), (222.0, 204.0)
    mid = ((a0[0] + a1[0]) / 2, (a0[1] + a1[1]) / 2 - 18)
    pts_full = curve(a0, a1, -22, 28)
    pts = pts_full[: max(int(len(pts_full) * reveal), 3)]

    def wfn(t):
        return 4 + 34 * math.sin(math.pi * min(t * 0.9 + 0.08, 1.0)) ** 0.7

    c.fill(lambda d: band(d, pts, lambda t: wfn(t) * 1.25, 0.2, 7), BLOOD_DARK, 0.85 * fade, 1.0, offset=(3, 4))
    c.fill(lambda d: band(d, pts, wfn, 0.18, 8), BLOOD, fade, 0.7)
    c.fill(lambda d: band(d, pts, lambda t: wfn(t) * 0.32, 0.15, 9), BLOOD_BRIGHT, 0.95 * fade, 0.6, offset=(-1, -2))
    # 튀는 핏방울
    for j in range(18):
        rnd = random.Random(2500 + j)
        t = rnd.uniform(0.15, 0.95) * reveal
        base = pts_full[min(int(t * (len(pts_full) - 1)), len(pts_full) - 1)]
        a = rnd.uniform(0, math.tau)
        dist = rnd.uniform(14, 62) * (0.3 + ease_out(p))
        sz = rnd.uniform(2.2, 6.8) * (1 - p * 0.3)
        x, y = base[0] + math.cos(a) * dist, base[1] + math.sin(a) * dist
        c.fill(lambda d, x=x, y=y, sz=sz, j=j: blob(d, x, y, sz, 3, 0.3, j), BLOOD, 0.95 * fade, 0.4)
        c.fill(lambda d, x=x, y=y, sz=sz, j=j: blob(d, x - sz * 0.25, y - sz * 0.3, sz * 0.4, 3, 0.2, j), BLOOD_BRIGHT, 0.9 * fade, 0.3)
    return c.to_image()


# ───────── 은신: 안개로 번져 사라지는 돌 ─────────
MIST_SHADE, MIST_MID, MIST_LIGHT = hexcolor("5b7088"), hexcolor("9fb3c8"), hexcolor("e3edf6")


def stealth_vanish(i, n=4):
    p = (i + 0.5) / n
    k = ease_out(p)
    c = Paint()
    cx = cy = 128.0
    # 돌 모양이 흐려지며 사라진다
    ghost = (1 - p) ** 1.4
    if ghost > 0.02:
        c.fill(lambda d: disc(d, cx + 2, cy + 3, 22), MIST_SHADE, 0.5 * ghost, 1.2)
        c.fill(lambda d: disc(d, cx, cy, 22), MIST_LIGHT, 0.85 * ghost, 1.0)
    for j in range(12):
        rnd = random.Random(2700 + j)
        a = math.tau * j / 12 + rnd.uniform(-0.3, 0.3)
        dist = 14 + 52 * k * rnd.uniform(0.7, 1.15)
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist - 22 * p
        r = (12 + rnd.uniform(0, 10)) * (0.6 + 0.9 * k)
        fade = (1 - p) ** 0.9
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x + 3, y + 4, r, 5, 0.2, 80 + j), MIST_SHADE, 0.55 * fade, 1.6)
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x, y, r, 5, 0.2, 80 + j), MIST_MID, 0.8 * fade, 1.4)
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x - 3, y - 4, r * 0.55, 4, 0.25, 100 + j), MIST_LIGHT, 0.9 * fade, 1.4)
    # 소용돌이치는 안개 띠
    for arm in range(3):
        pts = []
        for s_ in range(22):
            t = s_ / 21.0
            ang = math.radians(arm * 120 + 200 * t + 90 * p)
            rad = 12 + 62 * t * (0.5 + k * 0.6)
            pts.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
        c.fill(lambda d, pts=pts, arm=arm: band(d, pts, lambda t: 11 * (1 - t) + 2, 0.25, 120 + arm), MIST_LIGHT, 0.7 * (1 - p), 1.4)
    return c.to_image()


def stealth_mist(i, n=4):
    c = Paint()
    cx = cy = 128.0
    for j in range(6):
        rnd = random.Random(2900 + j)
        a = math.tau * j / 6 + math.tau * i / 24
        dist = 34 + rnd.uniform(-4, 4)
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist
        r = 11 + rnd.uniform(0, 5)
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x, y, r, 5, 0.2, 150 + j), MIST_MID, 0.6, 1.8)
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x - 2, y - 3, r * 0.5, 4, 0.25, 170 + j), MIST_LIGHT, 0.7, 1.6)
    return c.to_image()


# ───────── 조준경: 저격 조준점 ─────────
def scope_reticle():
    c = Paint()
    cx = cy = 128.0
    red = hexcolor("d7261e")
    # 바깥 고리: 그림자 → 먹 → 크림 속선
    for r, w in ((92, 9), (62, 4)):
        c.fill(lambda d, r=r, w=w: d.ellipse([P(cx - r - w, cy - r - w), P(cx + r + w, cy + r + w)], fill=255), INK, 0.35, 1.2, offset=(2, 3))
        c.fill(lambda d, r=r, w=w: d.ellipse([P(cx - r - w / 2, cy - r - w / 2), P(cx + r + w / 2, cy + r + w / 2)], fill=255), INK, 1.0, 0.5)
        c.fill(lambda d, r=r, w=w: d.ellipse([P(cx - r + w / 2, cy - r + w / 2), P(cx + r - w / 2, cy + r - w / 2)], fill=0), (0, 0, 0), 0.0, 0.0)
    # 구멍 뚫기: 안쪽을 투명하게 되돌린다(링 모양 만들기)
    ring_mask = Image.new("L", (W, W), 0)
    rd = ImageDraw.Draw(ring_mask)
    for r, w in ((92, 9), (62, 4)):
        rd.ellipse([P(cx - r - w / 2, cy - r - w / 2), P(cx + r + w / 2, cy + r + w / 2)], fill=255)
        rd.ellipse([P(cx - r + w / 2, cy - r + w / 2), P(cx + r - w / 2, cy + r - w / 2)], fill=0)
    ring_layer = Image.new("RGBA", (W, W), tuple(int(v * 255) for v in INK) + (255,))
    ring_layer.putalpha(ring_mask.filter(ImageFilter.GaussianBlur(0.5 * SS)))
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    shadow.putalpha(ring_mask.filter(ImageFilter.GaussianBlur(1.4 * SS)).point(lambda v: int(v * 0.35)))
    base = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    base = Image.alpha_composite(base, shadow.transform(shadow.size, Image.AFFINE, (1, 0, -2 * SS, 0, 1, -3 * SS)))
    base = Image.alpha_composite(base, ring_layer)
    c.img = base
    # 십자선: 가운데는 비우고 끝은 가늘어진다
    for ang in (0, 90, 180, 270):
        a = math.radians(ang)
        r0, r1 = 14, 112
        pts = [(cx + math.cos(a) * r0, cy + math.sin(a) * r0), (cx + math.cos(a) * r1, cy + math.sin(a) * r1)]
        c.fill(lambda d, pts=pts: band(d, pts, lambda t: 5 - 3.2 * t, 0.0, 1), INK, 1.0, 0.4)
    # 눈금
    for ang in range(0, 360, 30):
        a = math.radians(ang + 15)
        pts = [(cx + math.cos(a) * 62, cy + math.sin(a) * 62), (cx + math.cos(a) * 72, cy + math.sin(a) * 72)]
        c.fill(lambda d, pts=pts: band(d, pts, lambda t: 3, 0.0, 1), INK, 0.95, 0.4)
    # 붉은 중심점과 크림 하이라이트
    c.fill(lambda d: disc(d, cx, cy, 7), INK, 1.0, 0.4)
    c.fill(lambda d: disc(d, cx, cy, 4.5), red, 1.0, 0.4)
    c.fill(lambda d: disc(d, cx - 1.4, cy - 1.6, 1.4), hexcolor("fff4d6"), 0.9, 0.3)
    return c.to_image()


# ───────── 칙칙폭폭: 손으로 칠한 증기기관차 ─────────
IRON_DARK, IRON, IRON_LIGHT = hexcolor("202228"), hexcolor("3b3f48"), hexcolor("747a88")
BRASS_DARK, BRASS, BRASS_LIGHT = hexcolor("7a5420"), hexcolor("c99a3c"), hexcolor("f1d58a")
CAB_DARK, CAB, CAB_LIGHT = hexcolor("5c1a1a"), hexcolor("9a2d27"), hexcolor("c8564a")
STEAM_CREAM = hexcolor("f3e8cf")


def train_sprite():
    w, h = 380 * SS, 200 * SS
    c = Paint(w, h)

    def rr(x0, y0, x1, y1, r):
        return lambda d: d.rounded_rectangle([P(x0, y0), P(x1, y1)], radius=r * SS, fill=255)

    def layered(shape_fn, base, shade, high, hi_inset=3, hi_h=0.35):
        c.fill(shape_fn, INK, 1.0, 0.5, offset=(0, 0))
        return

    def part(x0, y0, x1, y1, r, base, shade, high):
        # 먹 테두리 → 본색 → 아래 그늘 → 위 하이라이트
        c.fill(rr(x0 - 2.5, y0 - 2.5, x1 + 2.5, y1 + 2.5, r + 2), INK, 1.0, 0.4)
        c.fill(rr(x0, y0, x1, y1, r), base, 1.0, 0.4)
        c.fill(rr(x0, y0 + (y1 - y0) * 0.6, x1, y1, r), shade, 0.75, 0.6)
        c.fill(rr(x0 + 3, y0 + 2.5, x1 - 3, y0 + 2.5 + (y1 - y0) * 0.22, 2), high, 0.85, 0.7)

    # 바닥 그림자
    c.fill(lambda d: d.ellipse([P(28, 176), P(352, 196)], fill=255), INK, 0.3, 2.0)
    # 보일러(긴 몸통)
    part(104, 62, 300, 132, 14, IRON, IRON_DARK, IRON_LIGHT)
    for bx in (150, 210, 262):
        part(bx, 60, bx + 9, 134, 2, BRASS, BRASS_DARK, BRASS_LIGHT)
    # 앞쪽 연기 상자와 헤드라이트
    part(292, 56, 330, 136, 10, IRON, IRON_DARK, IRON_LIGHT)
    c.fill(lambda d: disc(d, 326, 94, 12), INK, 1.0, 0.4)
    c.fill(lambda d: disc(d, 326, 94, 9), BRASS_LIGHT, 1.0, 0.4)
    c.fill(lambda d: disc(d, 324, 92, 3.5), hexcolor("fffbe8"), 1.0, 0.4)
    # 굴뚝(위가 퍼진 모양)
    c.fill(lambda d: d.polygon([P(256, 66), P(278, 66), P(284, 24), P(252, 24)], fill=255), INK, 1.0, 0.4, offset=(0, 0))
    c.fill(lambda d: d.polygon([P(258, 64), P(276, 64), P(281, 28), P(255, 28)], fill=255), IRON, 1.0, 0.4)
    c.fill(lambda d: d.polygon([P(270, 64), P(276, 64), P(281, 28), P(274, 28)], fill=255), IRON_DARK, 0.8, 0.6)
    part(246, 12, 290, 30, 6, IRON, IRON_DARK, IRON_LIGHT)
    # 증기 돔
    part(172, 40, 204, 64, 12, BRASS, BRASS_DARK, BRASS_LIGHT)
    # 운전실
    part(20, 28, 112, 140, 6, CAB, CAB_DARK, CAB_LIGHT)
    part(12, 18, 122, 36, 5, IRON, IRON_DARK, IRON_LIGHT)
    c.fill(rr(36, 48, 90, 96, 4), INK, 1.0, 0.4)
    c.fill(rr(40, 52, 86, 92, 3), STEAM_CREAM, 1.0, 0.4)
    c.fill(rr(40, 52, 86, 62, 3), hexcolor("ffffff"), 0.6, 0.6)
    c.fill(lambda d: d.line([P(63, 52), P(63, 92)], fill=255, width=3 * SS), INK, 1.0, 0.3)
    c.fill(lambda d: d.line([P(40, 72), P(86, 72)], fill=255, width=3 * SS), INK, 1.0, 0.3)
    # 하부 프레임과 배장기
    part(18, 128, 336, 148, 4, IRON_DARK, hexcolor("111216"), IRON)
    c.fill(lambda d: d.polygon([P(326, 138), P(364, 170), P(326, 170)], fill=255), INK, 1.0, 0.4)
    c.fill(lambda d: d.polygon([P(329, 143), P(358, 166), P(329, 166)], fill=255), IRON, 1.0, 0.4)
    for ty in (150, 158, 166):
        c.fill(lambda d, ty=ty: d.line([P(330, ty), P(352, ty + 2)], fill=255, width=2 * SS), IRON_LIGHT, 0.9, 0.3)
    # 바퀴: 큰 동륜 셋, 작은 선륜 하나
    for wx, wr in ((66, 29), (130, 29), (194, 29), (284, 18)):
        wy = 168 - wr * 0.0 - 4 if wr > 20 else 170
        wy = 170 - (0 if wr > 20 else 0)
        c.fill(lambda d, wx=wx, wy=wy, wr=wr: disc(d, wx + 2, wy + 3, wr + 4), INK, 0.35, 1.2)
        c.fill(lambda d, wx=wx, wy=wy, wr=wr: disc(d, wx, wy, wr + 3), INK, 1.0, 0.4)
        c.fill(lambda d, wx=wx, wy=wy, wr=wr: disc(d, wx, wy, wr), hexcolor("a3322b"), 1.0, 0.4)
        c.fill(lambda d, wx=wx, wy=wy, wr=wr: disc(d, wx, wy, wr * 0.82), IRON_DARK, 1.0, 0.4)
        for sp in range(8):
            a = math.tau * sp / 8
            c.fill(lambda d, wx=wx, wy=wy, wr=wr, a=a: d.line([P(wx, wy), P(wx + math.cos(a) * wr * 0.8, wy + math.sin(a) * wr * 0.8)], fill=255, width=int(2.4 * SS)), IRON_LIGHT, 0.95, 0.3)
        c.fill(lambda d, wx=wx, wy=wy, wr=wr: disc(d, wx, wy, wr * 0.26), BRASS, 1.0, 0.4)
        c.fill(lambda d, wx=wx, wy=wy, wr=wr: disc(d, wx - wr * 0.06, wy - wr * 0.08, wr * 0.1), BRASS_LIGHT, 1.0, 0.3)
    # 연결봉
    c.fill(lambda d: d.line([P(66, 170), P(194, 170)], fill=255, width=int(7 * SS)), INK, 1.0, 0.3)
    c.fill(lambda d: d.line([P(66, 170), P(194, 170)], fill=255, width=int(4 * SS)), BRASS, 1.0, 0.3)
    c.fill(lambda d: d.line([P(66, 169), P(194, 169)], fill=255, width=int(1.5 * SS)), BRASS_LIGHT, 1.0, 0.3)
    return c.to_image()


# ───────── 월마리아: 손으로 칠한 돌벽 ─────────
STONE_DARK, STONE, STONE_LIGHT, MORTAR = hexcolor("7c6c58"), hexcolor("b7a68a"), hexcolor("e2d5b8"), hexcolor("4d4234")


def wall_sprite():
    w, h = 330 * SS, 56 * SS
    c = Paint(w, h)
    c.fill(lambda d: d.rectangle([P(0, 0), P(330, 56)], fill=255), INK, 1.0, 0.4)
    c.fill(lambda d: d.rectangle([P(3, 3), P(327, 53)], fill=255), MORTAR, 1.0, 0.4)
    rnd = random.Random(77)
    for row in range(2):
        y0 = 4 + row * 26
        x = 4 + (0 if row == 0 else -28)
        while x < 326:
            bw = rnd.uniform(46, 70)
            x0, x1 = max(x, 4), min(x + bw - 3, 326)
            if x1 - x0 > 8:
                j = lambda: rnd.uniform(-1.2, 1.2)
                pts = [P(x0 + j(), y0 + j()), P(x1 + j(), y0 + j()), P(x1 + j(), y0 + 23 + j()), P(x0 + j(), y0 + 23 + j())]
                c.fill(lambda d, pts=pts: d.polygon(pts, fill=255), STONE, 1.0, 0.5)
                c.fill(lambda d, x0=x0, x1=x1, y0=y0: d.rectangle([P(x0, y0 + 16), P(x1, y0 + 23)], fill=255), STONE_DARK, 0.7, 0.8)
                c.fill(lambda d, x0=x0, x1=x1, y0=y0: d.rectangle([P(x0 + 2, y0 + 1.5), P(x1 - 2, y0 + 6)], fill=255), STONE_LIGHT, 0.85, 0.7)
                # 돌 결과 금
                for _ in range(2):
                    cx0, cy0 = rnd.uniform(x0 + 4, x1 - 4), rnd.uniform(y0 + 6, y0 + 18)
                    c.fill(lambda d, cx0=cx0, cy0=cy0: d.line([P(cx0, cy0), P(cx0 + rnd.uniform(-6, 6), cy0 + rnd.uniform(-3, 3))], fill=255, width=SS), STONE_DARK, 0.7, 0.3)
            x += bw
    return c.to_image()


# ───────── 나는 왕(2): 내려찍는 발구름 — 바위 파편과 갈라지는 땅 ─────────
ROCK_DARK, ROCK, ROCK_LIGHT = hexcolor("4d4640"), hexcolor("8b8277"), hexcolor("c9bfae")
CRATER, CRATER_RIM = hexcolor("3a2f26"), hexcolor("a8957a")


def zigzag(p0, p1, amp, seg, seed):
    rnd = random.Random(seed)
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / length, dx / length
    n = max(int(length / seg), 2)
    pts = []
    for i in range(n + 1):
        t = i / n
        o = 0.0 if i in (0, n) else rnd.uniform(-amp, amp)
        pts.append((p0[0] + dx * t + nx * o, p0[1] + dy * t + ny * o))
    return pts


def shard(draw, cx, cy, r, rot, seed, fill=255):
    rnd = random.Random(seed)
    n = rnd.randint(5, 7)
    pts = []
    for i in range(n):
        a = rot + math.tau * i / n + rnd.uniform(-0.3, 0.3)
        rr = r * rnd.uniform(0.55, 1.0)
        pts.append(P(cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    draw.polygon(pts, fill=fill)


def king_stomp(i, n=4):
    p = (i + 0.5) / n
    k = ease_out(p)
    fade = (1 - p) ** 0.9
    c = Paint()
    cx = cy = 128.0
    # 움푹 패인 자리와 둘레 흙 테두리
    cr = 12 + 30 * k
    c.fill(lambda d: blob(d, cx, cy, cr + 7, 7, 0.14, 3), CRATER_RIM, 0.9 * fade, 0.8)
    c.fill(lambda d: blob(d, cx + 1, cy + 2, cr, 7, 0.14, 3), CRATER, 0.95 * (0.5 + 0.5 * fade), 0.8)
    # 각진 균열
    for j in range(8):
        rnd = random.Random(3100 + j)
        a = math.tau * j / 8 + rnd.uniform(-0.2, 0.2)
        length = (34 + 74 * k) * rnd.uniform(0.75, 1.15)
        pts = zigzag((cx + math.cos(a) * cr * 0.8, cy + math.sin(a) * cr * 0.8), (cx + math.cos(a) * length, cy + math.sin(a) * length), 5, 11, 3200 + j)
        c.fill(lambda d, pts=pts: band(d, pts, lambda t: 6.5 * (1 - t) ** 0.7 + 1.2, 0.1, 5), INK, 0.95 * (0.35 + 0.65 * fade), 0.4)
    # 먼지 구름
    for j in range(8):
        rnd = random.Random(3300 + j)
        a = math.tau * j / 8 + 0.2 + rnd.uniform(-0.25, 0.25)
        dist = 26 + 62 * k * rnd.uniform(0.85, 1.1)
        r = (12 + rnd.uniform(0, 8)) * (0.7 + 0.9 * k)
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x + 3, y + 4, r, 5, 0.16, 400 + j), DUST_SHADE, 0.6 * fade, 1.0)
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x, y, r, 5, 0.16, 400 + j), DUST_TAN, 0.8 * fade, 0.8)
        c.fill(lambda d, x=x, y=y, r=r, j=j: blob(d, x - 2, y - 3, r * 0.5, 4, 0.2, 420 + j), DUST_LIGHT, 0.9 * fade, 0.8)
    # 튀어 오르는 바위 파편
    for j in range(13):
        rnd = random.Random(3500 + j)
        a = rnd.uniform(0, math.tau)
        dist = (22 + rnd.uniform(0, 50)) + 50 * k
        sz = rnd.uniform(5, 11) * (1 - 0.25 * p)
        x, y = cx + math.cos(a) * dist, cy + math.sin(a) * dist - 14 * math.sin(math.pi * min(p * 1.2, 1.0))
        rot = rnd.uniform(0, math.tau) + p * 2.5
        c.fill(lambda d, x=x, y=y, sz=sz, rot=rot, j=j: shard(d, x + 1.5, y + 2, sz, rot, 500 + j), ROCK_DARK, 0.9 * fade, 0.3)
        c.fill(lambda d, x=x, y=y, sz=sz, rot=rot, j=j: shard(d, x, y, sz, rot, 500 + j), ROCK, fade, 0.3)
        c.fill(lambda d, x=x, y=y, sz=sz, rot=rot, j=j: shard(d, x - sz * 0.2, y - sz * 0.25, sz * 0.5, rot, 520 + j), ROCK_LIGHT, 0.9 * fade, 0.3)
    # 왕의 금빛: 처음에 번쩍이는 작은 불꽃
    flash = max(0.0, 1.0 - p * 2.2)
    if flash > 0.02:
        c.fill(lambda d: star_poly(d, cx, cy, 34 * flash + 4, 8, 0.5, 8), KING_GOLD, 1.0, 0.6)
        c.fill(lambda d: star_poly(d, cx, cy, 16 * flash + 2, 8, 0.5, 8), hexcolor("fffaf0"), 1.0, 0.5)
    return c.to_image()


# ───────── 칙칙폭폭(2): 위에서 내려다본 증기기관차 (오른쪽이 앞) ─────────
def train_top_sprite():
    w, h = 380 * SS, 150 * SS
    c = Paint(w, h)
    cyc = 75.0

    def rr(x0, y0, x1, y1, r):
        return lambda d: d.rounded_rectangle([P(x0, y0), P(x1, y1)], radius=r * SS, fill=255)

    def block(x0, y0, x1, y1, r, base, shade, high, hi_frac=0.28):
        c.fill(rr(x0 - 2.5, y0 - 2.5, x1 + 2.5, y1 + 2.5, r + 2), INK, 1.0, 0.4)
        c.fill(rr(x0, y0, x1, y1, r), base, 1.0, 0.4)
        c.fill(rr(x0, y0 + (y1 - y0) * 0.62, x1, y1, r), shade, 0.75, 0.7)
        c.fill(rr(x0 + 3, y0 + 2.5, x1 - 3, y0 + 2.5 + (y1 - y0) * hi_frac, 3), high, 0.8, 0.8)

    # 그림자
    c.fill(lambda d: d.rounded_rectangle([P(24, 22), P(372, 134)], radius=24 * SS, fill=255), INK, 0.28, 2.4, offset=(0, 4))
    # 양옆 바퀴 윗면과 연결봉(차체 아래로 삐져나온 부분)
    for side in (-1, 1):
        y = cyc + side * 52
        c.fill(rr(70, y - 7, 240, y + 7, 4), INK, 1.0, 0.4)
        c.fill(rr(72.5, y - 4.5, 237.5, y + 4.5, 3), IRON, 1.0, 0.4)
        for wx in (96, 150, 204):
            c.fill(lambda d, wx=wx, y=y: d.rounded_rectangle([P(wx - 21, y - 9), P(wx + 21, y + 9)], radius=4 * SS, fill=255), INK, 1.0, 0.4)
            c.fill(lambda d, wx=wx, y=y: d.rounded_rectangle([P(wx - 19, y - 7), P(wx + 19, y + 7)], radius=3 * SS, fill=255), hexcolor("a3322b"), 1.0, 0.4)
            c.fill(lambda d, wx=wx, y=y: d.rounded_rectangle([P(wx - 14, y - 4), P(wx + 14, y + 4)], radius=2 * SS, fill=255), IRON_DARK, 1.0, 0.4)
        c.fill(lambda d, y=y: d.rounded_rectangle([P(268, y - 7), P(296, y + 7)], radius=3 * SS, fill=255), INK, 1.0, 0.4)
        c.fill(lambda d, y=y: d.rounded_rectangle([P(270, y - 5), P(294, y + 5)], radius=2 * SS, fill=255), IRON, 1.0, 0.4)
    # 앞 배장기(삼각)
    c.fill(lambda d: d.polygon([P(318, cyc - 34), P(372, cyc), P(318, cyc + 34)], fill=255), INK, 1.0, 0.4)
    c.fill(lambda d: d.polygon([P(321, cyc - 29), P(364, cyc), P(321, cyc + 29)], fill=255), IRON, 1.0, 0.4)
    for off in (-18, -9, 0, 9, 18):
        c.fill(lambda d, off=off: d.line([P(326, cyc + off * 0.9), P(352 - abs(off) * 0.6, cyc + off * 0.25)], fill=255, width=2 * SS), IRON_LIGHT, 0.9, 0.3)
    # 보일러: 위에서 본 원통(가운데가 밝고 양옆이 어둡다)
    block(108, cyc - 38, 322, cyc + 38, 30, IRON, IRON_DARK, IRON_LIGHT, 0.0)
    c.fill(rr(112, cyc - 24, 318, cyc - 4, 12), IRON_LIGHT, 0.45, 2.0)
    c.fill(rr(116, cyc - 18, 314, cyc - 9, 5), hexcolor("a4a9b6"), 0.55, 1.5)
    for bx in (150, 206, 262):
        c.fill(rr(bx - 4, cyc - 40, bx + 5, cyc + 40, 3), INK, 1.0, 0.4)
        c.fill(rr(bx - 2, cyc - 38, bx + 3, cyc + 38, 2), BRASS, 1.0, 0.4)
        c.fill(rr(bx - 2, cyc - 38, bx, cyc + 38, 1), BRASS_LIGHT, 0.9, 0.4)
    # 연기 상자와 헤드라이트
    c.fill(lambda d: d.ellipse([P(296, cyc - 30), P(334, cyc + 30)], fill=255), INK, 1.0, 0.4)
    c.fill(lambda d: d.ellipse([P(299, cyc - 27), P(331, cyc + 27)], fill=255), IRON, 1.0, 0.4)
    c.fill(lambda d: disc(d, 346, cyc, 10), INK, 1.0, 0.4)
    c.fill(lambda d: disc(d, 346, cyc, 7.5), BRASS_LIGHT, 1.0, 0.4)
    c.fill(lambda d: disc(d, 344.5, cyc - 1.5, 3), hexcolor("fffbe8"), 1.0, 0.4)
    # 굴뚝(위에서 보면 동심원)
    for r, col in ((20, INK), (17.5, IRON), (11, IRON_DARK), (7.5, hexcolor("0b0c0f"))):
        c.fill(lambda d, r=r: disc(d, 268, cyc, r), col, 1.0, 0.4)
    c.fill(lambda d: d.arc([P(250.5, cyc - 17.5), P(285.5, cyc + 17.5)], 200, 280, fill=255, width=int(2.5 * SS)), IRON_LIGHT, 0.9, 0.5)
    # 증기 돔
    for r, col in ((15, INK), (12.5, BRASS), (7, BRASS_LIGHT)):
        c.fill(lambda d, r=r: disc(d, 188, cyc, r), col, 1.0, 0.4)
    c.fill(lambda d: disc(d, 185, cyc - 3, 2.6), hexcolor("fff4cf"), 0.95, 0.3)
    # 운전실 지붕
    block(22, cyc - 46, 112, cyc + 46, 10, CAB, CAB_DARK, CAB_LIGHT, 0.0)
    c.fill(rr(30, cyc - 38, 104, cyc - 12, 6), CAB_LIGHT, 0.5, 1.6)
    c.fill(rr(30, cyc + 10, 104, cyc + 38, 6), CAB_DARK, 0.5, 1.6)
    c.fill(rr(54, cyc - 10, 80, cyc + 10, 4), INK, 1.0, 0.4)
    c.fill(rr(56.5, cyc - 7.5, 77.5, cyc + 7.5, 3), IRON_DARK, 1.0, 0.4)
    # 석탄차 쪽 연결고리
    c.fill(rr(6, cyc - 8, 24, cyc + 8, 3), INK, 1.0, 0.4)
    c.fill(rr(8, cyc - 5.5, 22, cyc + 5.5, 2), IRON, 1.0, 0.4)
    return c.to_image()


# ───────── 월마리아(2): 쌓은 바위 벽 (위에서 본 모양) ─────────
def wall_boulder_sprite():
    w, h = 330 * SS, 56 * SS
    c = Paint(w, h)
    MOSS_DARK, MOSS, MOSS_LIGHT = hexcolor("3d5a2e"), hexcolor("6f9a4a"), hexcolor("a9c97a")
    stones = [(34, 28, 30, 21), (92, 29, 33, 23), (156, 27, 31, 22), (216, 29, 34, 22), (276, 28, 32, 22)]
    rnd = random.Random(5)
    # 바닥 그림자
    c.fill(lambda d: d.rounded_rectangle([P(4, 8), P(326, 54)], radius=16 * SS, fill=255), INK, 0.3, 2.6, offset=(0, 3))
    for idx, (sx, sy, rx, ry) in enumerate(stones):
        def poly(scale=1.0, dx=0.0, dy=0.0, seed=idx):
            r2 = random.Random(100 + seed)
            pts = []
            for i in range(11):
                a = math.tau * i / 11
                k = r2.uniform(0.82, 1.06)
                pts.append(P(sx + dx + math.cos(a) * rx * scale * k, sy + dy + math.sin(a) * ry * scale * k))
            return pts

        c.fill(lambda d, idx=idx: d.polygon(poly(1.12), fill=255), INK, 1.0, 0.4)
        c.fill(lambda d, idx=idx: d.polygon(poly(1.0), fill=255), STONE_DARK, 1.0, 0.4)
        c.fill(lambda d, idx=idx: d.polygon(poly(0.93, -1.5, -2.0), fill=255), STONE, 1.0, 0.5)
        c.fill(lambda d, idx=idx: d.polygon(poly(0.62, -4.5, -5.5), fill=255), STONE_LIGHT, 0.9, 1.0)
        # 금과 패인 자국
        for _ in range(2):
            x0, y0 = sx + rnd.uniform(-rx * 0.5, rx * 0.5), sy + rnd.uniform(-ry * 0.4, ry * 0.4)
            c.fill(lambda d, x0=x0, y0=y0: d.line([P(x0, y0), P(x0 + rnd.uniform(-8, 8), y0 + rnd.uniform(2, 7))], fill=255, width=SS), INK, 0.65, 0.3)
        # 이끼 한 점
        if idx % 2 == 0:
            mx, my = sx + rnd.uniform(-rx * 0.4, rx * 0.4), sy + ry * 0.45
            c.fill(lambda d, mx=mx, my=my: blob(d, mx, my, 5.5, 4, 0.3, idx), MOSS_DARK, 0.9, 0.5)
            c.fill(lambda d, mx=mx, my=my: blob(d, mx - 0.6, my - 0.8, 4, 4, 0.3, idx + 9), MOSS, 0.95, 0.5)
            c.fill(lambda d, mx=mx, my=my: blob(d, mx - 1.2, my - 1.6, 1.8, 3, 0.3, idx + 7), MOSS_LIGHT, 0.95, 0.4)
    return c.to_image()


# ───────── 나는 왕(3): 만화 같은 충격선과 먹 테두리 충격 고리 ─────────
def king_impact(i, n=4):
    p = (i + 0.5) / n
    k = ease_out(p)
    fade = (1 - p) ** 0.85
    c = Paint()
    cx = cy = 128.0
    # 바깥으로 뻗는 충격선(먹): 처음엔 길고 굵게, 뒤로 갈수록 바깥으로 밀려나며 가늘어진다.
    for j in range(20):
        rnd = random.Random(4100 + j)
        a = math.tau * j / 20 + rnd.uniform(-0.08, 0.08)
        r0 = 36 + 52 * k + rnd.uniform(0, 6)
        r1 = r0 + rnd.uniform(26, 62) * (1 - 0.5 * p)
        pts = [(cx + math.cos(a) * r0, cy + math.sin(a) * r0), (cx + math.cos(a) * r1, cy + math.sin(a) * r1)]
        wmax = rnd.uniform(5, 9) * (1 - 0.4 * p)
        c.fill(lambda d, pts=pts, wmax=wmax, j=j: band(d, pts, lambda t: wmax * (1 - t) ** 0.8 + 0.8, 0.12, j), INK, 0.95 * fade, 0.4)
    # 충격 고리: 먹 테두리 → 금색 → 크림 속선
    R = 22 + 58 * k
    w = 17 * (1 - 0.55 * p)
    pts = [(cx + math.cos(math.tau * t / 72) * R, cy + math.sin(math.tau * t / 72) * R) for t in range(73)]

    def wob(t):
        return w * (1 + 0.18 * math.sin(t * 15 + 1.3))

    c.fill(lambda d: band(d, pts, lambda t: wob(t) + 9, 0.1, 31), INK, 0.35 * fade, 1.4, offset=(2, 3))
    c.fill(lambda d: band(d, pts, lambda t: wob(t) + 6, 0.08, 32), INK, fade, 0.4)
    c.fill(lambda d: band(d, pts, wob, 0.1, 33), KING_GOLD, fade, 0.5)
    c.fill(lambda d: band(d, pts, lambda t: wob(t) * 0.45, 0.1, 34), KING_GOLD_LIGHT, fade, 0.5, offset=(-1, -1))
    # 가운데 충격 별: 처음 두 프레임
    flash = max(0.0, 1.0 - p * 1.6)
    if flash > 0.02:
        c.fill(lambda d: star_poly(d, cx + 2, cy + 3, 64 * flash + 8, 12, 0.46, 3), INK, 0.9, 0.5)
        c.fill(lambda d: star_poly(d, cx, cy, 60 * flash + 6, 12, 0.46, 3), KING_GOLD, 1.0, 0.4)
        c.fill(lambda d: star_poly(d, cx, cy, 32 * flash + 3, 12, 0.46, 3), hexcolor("fff8e2"), 1.0, 0.4)
    return c.to_image()


# ───────── 월마리아(3): 진격의 거인의 성벽 — 매끈한 거대 석벽을 위에서 본 모양 ─────────
WALL_STONE, WALL_SHADE, WALL_LIGHT, WALL_GAP = hexcolor("969aa2"), hexcolor("5d616b"), hexcolor("cdd1d6"), hexcolor("34373e")
WALL_MOSS_DARK, WALL_MOSS, WALL_STAIN = hexcolor("3c5a2c"), hexcolor("6d9448"), hexcolor("4e4a3c")


def wall_titan_sprite():
    w, h = 330 * SS, 56 * SS
    c = Paint(w, h)
    rnd = random.Random(12)

    def rect(x0, y0, x1, y1):
        return lambda d: d.rectangle([P(x0, y0), P(x1, y1)], fill=255)

    # 성가퀴(이빨 모양 난간): 위·아래 가장자리에 톱니가 이어진다.
    teeth = []
    x = 40.0
    while x + 20 < 292:
        teeth.append(x)
        x += 30
    body = (0, 12, 330, 44)
    outline = [rect(*body)] + [rect(tx, 3, tx + 20, 13) for tx in teeth] + [rect(tx, 43, tx + 20, 53) for tx in teeth] + [rect(0, 0, 40, 56), rect(290, 0, 330, 56)]
    for fn in outline:
        # 먹 테두리: 각 도형을 2.5px 부풀려 겹쳐 칠한다.
        pass
    c.fill(lambda d: [d.rectangle([P(-2.5, 9.5), P(332.5, 46.5)], fill=255)] and None, INK, 1.0, 0.4)
    for tx in teeth:
        c.fill(rect(tx - 2.5, 0.5, tx + 22.5, 13), INK, 1.0, 0.4)
        c.fill(rect(tx - 2.5, 43, tx + 22.5, 55.5), INK, 1.0, 0.4)
    c.fill(rect(-2.5, -2.5, 42.5, 58.5), INK, 1.0, 0.4)
    c.fill(rect(287.5, -2.5, 332.5, 58.5), INK, 1.0, 0.4)
    # 본체(밝은 돌 + 오른쪽 아래 그늘)
    c.fill(rect(*body), WALL_STONE, 1.0, 0.4)
    for tx in teeth:
        c.fill(rect(tx, 3, tx + 20, 14), WALL_STONE, 1.0, 0.4)
        c.fill(rect(tx, 42, tx + 20, 53), WALL_STONE, 1.0, 0.4)
        c.fill(rect(tx, 3, tx + 20, 6), WALL_LIGHT, 0.9, 0.5)
        c.fill(rect(tx + 14, 3, tx + 20, 14), WALL_SHADE, 0.55, 0.6)
        c.fill(rect(tx, 49, tx + 20, 53), WALL_SHADE, 0.6, 0.6)
    # 돌 블록 이음매 (두 줄, 엇갈리게)
    for row in range(2):
        y0 = 12 + row * 16
        c.fill(rect(0, y0 + 14.5, 330, y0 + 16), WALL_GAP, 0.9, 0.3)
        x = 44.0 + (0 if row == 0 else 20)
        while x < 290:
            c.fill(rect(x, y0, x + 1.6, y0 + 16), WALL_GAP, 0.85, 0.3)
            x += rnd.uniform(34, 46)
        c.fill(rect(0, y0 + 1, 330, y0 + 4), WALL_LIGHT, 0.7, 0.8)
        c.fill(rect(0, y0 + 11, 330, y0 + 15), WALL_SHADE, 0.5, 0.8)
    # 양 끝 망루
    for x0 in (0, 290):
        c.fill(rect(x0, 0, x0 + 40, 56), WALL_STONE, 1.0, 0.4)
        c.fill(rect(x0, 0, x0 + 40, 6), WALL_LIGHT, 0.9, 0.5)
        c.fill(rect(x0, 50, x0 + 40, 56), WALL_SHADE, 0.7, 0.5)
        c.fill(rect(x0 + 6, 8, x0 + 34, 48), WALL_SHADE, 0.45, 0.8)
        c.fill(rect(x0 + 10, 12, x0 + 30, 44), WALL_STONE, 1.0, 0.5)
        c.fill(rect(x0 + 10, 12, x0 + 30, 16), WALL_LIGHT, 0.9, 0.5)
        c.fill(rect(x0 + 19, 12, x0 + 21, 44), WALL_GAP, 0.6, 0.3)
    # 오랜 세월의 빗물 자국(갈색 얼룩)과 아래쪽 이끼
    for _ in range(16):
        sx = rnd.uniform(46, 284)
        c.fill(rect(sx, 12, sx + rnd.uniform(1.8, 3.6), 12 + rnd.uniform(10, 32)), WALL_STAIN, 0.4, 1.2)
    for _ in range(11):
        mx = rnd.uniform(44, 286)
        mr = rnd.uniform(3.5, 7.0)
        c.fill(lambda d, mx=mx, mr=mr: blob(d, mx, 43.5, mr, 4, 0.3, int(mx)), WALL_MOSS_DARK, 0.9, 0.6)
        c.fill(lambda d, mx=mx, mr=mr: blob(d, mx - 0.6, 42.6, mr * 0.7, 4, 0.3, int(mx) + 3), WALL_MOSS, 0.95, 0.6)
    for _ in range(4):
        x0, y0 = rnd.uniform(60, 270), rnd.uniform(16, 36)
        pts = zigzag((x0, y0), (x0 + rnd.uniform(-10, 10), y0 + rnd.uniform(6, 12)), 2.0, 4, rnd.randint(0, 99))
        c.fill(lambda d, pts=pts: d.line([P(*q) for q in pts], fill=255, width=SS), WALL_GAP, 0.7, 0.3)
    return c.to_image()


# ───────── 월마리아(4): 진격의 거인의 성벽 — 이모지 같은 외곽선 없이 거대한 석재를 사실적으로 칠한 윗면 ─────────
def _noise(shape, sigma, seed, amp):
    rng = np.random.default_rng(seed)
    n = rng.normal(0.0, 1.0, shape).astype(np.float32)
    img = Image.fromarray(((n * 40) + 128).clip(0, 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(sigma))
    arr = (np.asarray(img, np.float32) - 128.0) / 40.0
    arr = arr / (arr.std() + 1e-6)
    return arr * amp


def wall_realistic_sprite():
    w, h = 330 * SS, 56 * SS
    rnd = random.Random(21)
    base = np.zeros((h, w, 3), np.float32)
    base[:] = (160, 156, 146)
    shade = np.zeros((h, w), np.float32)   # 밝기 가감
    warm = np.zeros((h, w), np.float32)    # 따뜻한 얼룩(갈색) 가감

    # 길게 난 세 띠: 위 난간, 가운데 통로, 아래 난간
    bands = [(0, 15, 38.0), (15, 41, 54.0), (41, 56, 38.0)]
    seams_v = []
    for y0, y1, bw in bands:
        x = rnd.uniform(0, bw * 0.6)
        while x < 330:
            seams_v.append((x, y0, y1))
            nxt = x + rnd.uniform(bw * 0.8, bw * 1.2)
            # 블록마다 밝기를 조금씩 다르게 한다.
            tone = rnd.uniform(-14, 12)
            xa, xb = int(max(x, 0) * SS), int(min(nxt, 330) * SS)
            shade[int(y0 * SS):int(y1 * SS), xa:xb] += tone
            warm[int(y0 * SS):int(y1 * SS), xa:xb] += rnd.uniform(-3, 6)
            x = nxt
    # 돌 결(거친 입자) + 얼룩진 큰 무늬
    shade += _noise((h, w), 1.2, 1, 5.0) + _noise((h, w), 6.0, 2, 8.0)
    warm += _noise((h, w), 9.0, 3, 5.0)
    img = base.copy()
    img[..., 0] += shade + warm
    img[..., 1] += shade + warm * 0.55
    img[..., 2] += shade - warm * 0.5

    # 이음매: 가로 띠 경계와 세로 이음. 안쪽 그늘(AO)을 블러로 깔고 얇은 어두운 선을 얹는다.
    seam = np.zeros((h, w), np.float32)
    sm = Image.new("L", (w, h), 0)
    sd = ImageDraw.Draw(sm)
    for y in (15, 41):
        sd.line([(0, y * SS), (w, y * SS)], fill=255, width=int(1.6 * SS))
    for x, y0, y1 in seams_v:
        sd.line([(x * SS, y0 * SS), (x * SS, y1 * SS)], fill=255, width=int(1.3 * SS))
    seam_core = np.asarray(sm, np.float32) / 255.0
    seam_ao = np.asarray(sm.filter(ImageFilter.GaussianBlur(2.2 * SS)), np.float32) / 255.0
    img -= seam_ao[..., None] * 34.0
    img -= seam_core[..., None] * 38.0
    # 블록의 위·왼쪽 모서리는 밝게, 아래·오른쪽은 어둡게(입체감)
    hl = np.zeros((h, w), np.float32)
    hm = Image.new("L", (w, h), 0)
    hd = ImageDraw.Draw(hm)
    for y in (15, 41):
        hd.line([(0, y * SS + 2 * SS), (w, y * SS + 2 * SS)], fill=255, width=int(1.2 * SS))
    for x, y0, y1 in seams_v:
        hd.line([(x * SS + 2 * SS, y0 * SS + 1), (x * SS + 2 * SS, y1 * SS)], fill=255, width=int(1.0 * SS))
    hl = np.asarray(hm.filter(ImageFilter.GaussianBlur(0.6 * SS)), np.float32) / 255.0
    img += hl[..., None] * 18.0

    # 난간 안쪽(통로 쪽) 그림자 띠: 높이감
    for y, direction in ((15, 1), (41, -1)):
        grad = np.zeros((h, w), np.float32)
        for k in range(int(6 * SS)):
            yy = y * SS + direction * k
            if 0 <= yy < h:
                grad[yy, :] = (1 - k / (6 * SS)) * 26.0
        img -= grad[..., None]

    # 오랜 세월의 빗물 자국: 위에서 아래로 번진 어두운 줄무늬
    for _ in range(22):
        sx = rnd.uniform(4, 326)
        sw = rnd.uniform(1.0, 3.2)
        y0 = rnd.uniform(0, 30)
        length = rnd.uniform(10, 40)
        m = Image.new("L", (w, h), 0)
        ImageDraw.Draw(m).rectangle([sx * SS, y0 * SS, (sx + sw) * SS, (y0 + length) * SS], fill=255)
        m = np.asarray(m.filter(ImageFilter.GaussianBlur(1.4 * SS)), np.float32) / 255.0
        img[..., 0] -= m * 22.0
        img[..., 1] -= m * 24.0
        img[..., 2] -= m * 28.0
    # 이끼: 이음매 근처 군데군데 초록빛이 번진다.
    moss = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(moss)
    for _ in range(18):
        mx, my = rnd.uniform(6, 324), rnd.choice([15, 41, rnd.uniform(2, 54)])
        mr = rnd.uniform(2.5, 6.5)
        md.ellipse([(mx - mr) * SS, (my - mr * 0.6) * SS, (mx + mr) * SS, (my + mr * 0.6) * SS], fill=255)
    moss_a = np.asarray(moss.filter(ImageFilter.GaussianBlur(1.6 * SS)), np.float32) / 255.0
    moss_a *= (0.55 + 0.45 * np.clip(_noise((h, w), 2.5, 7, 1.0) * 0.5 + 0.5, 0, 1))
    img[..., 0] = img[..., 0] * (1 - moss_a * 0.55) + 70 * moss_a * 0.55
    img[..., 1] = img[..., 1] * (1 - moss_a * 0.55) + 112 * moss_a * 0.55
    img[..., 2] = img[..., 2] * (1 - moss_a * 0.55) + 56 * moss_a * 0.55

    # 가장자리: 살짝 깎인 모서리와 바깥쪽이 어두워지는 둘레
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    edge = np.minimum.reduce([xx, w - 1 - xx, yy, h - 1 - yy]) / SS
    img -= (np.clip(1.0 - edge / 2.6, 0, 1) ** 1.5)[..., None] * 60.0
    img[..., 0] = np.clip(img[..., 0], 0, 255)
    img[..., 1] = np.clip(img[..., 1], 0, 255)
    img[..., 2] = np.clip(img[..., 2], 0, 255)

    # 모서리를 조금 깨고, 가장자리를 둥글게 깎는다.
    alpha = Image.new("L", (w, h), 0)
    ImageDraw.Draw(alpha).rounded_rectangle([0, 0, w - 1, h - 1], radius=5 * SS, fill=255)
    chips = ImageDraw.Draw(alpha)
    for _ in range(9):
        cx0 = rnd.choice([rnd.uniform(0, 330), rnd.uniform(0, 330)])
        top = rnd.choice([True, False])
        cy0 = 0 if top else 56
        chips.ellipse([(cx0 - 2.4) * SS, (cy0 - 1.4) * SS, (cx0 + 2.4) * SS, (cy0 + 1.4) * SS], fill=0)
    out = Image.fromarray(img.astype(np.uint8), "RGB").convert("RGBA")
    out.putalpha(alpha)
    return out.resize((330, 56), Image.LANCZOS)


# ───────── 월마리아(5): 진격의 거인의 성벽 — 윗면 + 깎아지른 앞면이 보이는 석벽 (2.5D) ─────────
def wall_titan_face_sprite():
    """330x80. 위 44px은 성벽 윗면(통로·난간), 아래 36px은 보이는 앞면(큰 석재 두 단, 빗물 자국, 아래 이끼)."""
    W2, H2 = 330 * SS, 80 * SS
    TOP = 44
    rnd = random.Random(33)
    img = np.zeros((H2, W2, 3), np.float32)
    img[:TOP * SS] = (178, 172, 160)
    img[TOP * SS:] = (150, 144, 134)
    shade = np.zeros((H2, W2), np.float32)
    warm = np.zeros((H2, W2), np.float32)

    # (y0, y1, 블록 평균 폭) 띠 목록
    bands = [(0, 10, 36.0), (10, 34, 52.0), (34, TOP, 36.0), (TOP, 62, 70.0), (62, 80, 70.0)]
    seams_v = []
    for y0, y1, bw in bands:
        x = rnd.uniform(0, bw * 0.7)
        while x < 330:
            seams_v.append((x, y0, y1))
            nxt = x + rnd.uniform(bw * 0.8, bw * 1.25)
            xa, xb = int(max(x, 0) * SS), int(min(nxt, 330) * SS)
            shade[int(y0 * SS):int(y1 * SS), xa:xb] += rnd.uniform(-12, 10)
            warm[int(y0 * SS):int(y1 * SS), xa:xb] += rnd.uniform(-3, 6)
            x = nxt
    shade += _noise((H2, W2), 1.2, 11, 5.0) + _noise((H2, W2), 7.0, 12, 8.0)
    warm += _noise((H2, W2), 10.0, 13, 5.0)
    img[..., 0] += shade + warm
    img[..., 1] += shade + warm * 0.55
    img[..., 2] += shade - warm * 0.5

    # 이음매
    sm = Image.new("L", (W2, H2), 0)
    sd = ImageDraw.Draw(sm)
    for y in (10, 34, 62):
        sd.line([(0, y * SS), (W2, y * SS)], fill=255, width=int(1.6 * SS))
    for x, y0, y1 in seams_v:
        sd.line([(x * SS, y0 * SS), (x * SS, y1 * SS)], fill=255, width=int(1.3 * SS))
    seam_core = np.asarray(sm, np.float32) / 255.0
    seam_ao = np.asarray(sm.filter(ImageFilter.GaussianBlur(2.2 * SS)), np.float32) / 255.0
    img -= seam_ao[..., None] * 32.0 + seam_core[..., None] * 38.0
    hm = Image.new("L", (W2, H2), 0)
    hd = ImageDraw.Draw(hm)
    for y in (10, 34, 62):
        hd.line([(0, y * SS + 2 * SS), (W2, y * SS + 2 * SS)], fill=255, width=int(1.2 * SS))
    hl = np.asarray(hm.filter(ImageFilter.GaussianBlur(0.6 * SS)), np.float32) / 255.0
    img += hl[..., None] * 16.0

    # 윗면과 앞면의 경계: 밝은 모서리 선 → 바로 아래 짙은 그늘(처마 아래)
    lip = Image.new("L", (W2, H2), 0)
    ImageDraw.Draw(lip).line([(0, TOP * SS), (W2, TOP * SS)], fill=255, width=int(1.6 * SS))
    lip_a = np.asarray(lip.filter(ImageFilter.GaussianBlur(0.5 * SS)), np.float32) / 255.0
    img += lip_a[..., None] * 40.0
    for k in range(int(9 * SS)):
        yy = TOP * SS + int(1.6 * SS) + k
        img[yy, :, :] -= (1 - k / (9 * SS)) * 30.0
    # 앞면은 아래로 갈수록 어두워진다(그늘진 면)
    ramp = np.linspace(0.0, 1.0, int((80 - TOP) * SS), dtype=np.float32)
    img[TOP * SS:] -= (ramp[:, None, None] * 22.0)

    # 빗물 자국: 윗면 가장자리에서 앞면으로 길게 흘러내린 줄무늬
    for _ in range(34):
        sx = rnd.uniform(4, 326)
        sw = rnd.uniform(1.2, 3.8)
        y0 = rnd.choice([TOP - 2, TOP + rnd.uniform(0, 6), rnd.uniform(0, 30)])
        length = rnd.uniform(14, 36)
        m = Image.new("L", (W2, H2), 0)
        ImageDraw.Draw(m).rectangle([sx * SS, y0 * SS, (sx + sw) * SS, (y0 + length) * SS], fill=255)
        m = np.asarray(m.filter(ImageFilter.GaussianBlur(1.5 * SS)), np.float32) / 255.0
        img[..., 0] -= m * 26.0
        img[..., 1] -= m * 28.0
        img[..., 2] -= m * 32.0
    # 이끼: 앞면 아래쪽과 이음매에 번진다.
    moss = Image.new("L", (W2, H2), 0)
    md = ImageDraw.Draw(moss)
    for _ in range(30):
        mx = rnd.uniform(4, 326)
        my = rnd.uniform(66, 80) if rnd.random() < 0.8 else rnd.uniform(2, 60)
        mr = rnd.uniform(3, 8)
        md.ellipse([(mx - mr) * SS, (my - mr * 0.6) * SS, (mx + mr) * SS, (my + mr * 0.6) * SS], fill=255)
    moss_a = np.asarray(moss.filter(ImageFilter.GaussianBlur(1.8 * SS)), np.float32) / 255.0
    moss_a *= (0.5 + 0.5 * np.clip(_noise((H2, W2), 2.5, 17, 1.0) * 0.5 + 0.5, 0, 1))
    for c_, v in enumerate((66, 108, 52)):
        img[..., c_] = img[..., c_] * (1 - moss_a * 0.6) + v * moss_a * 0.6

    # 윗면 바깥 테두리와 앞면 양끝의 모서리 그늘
    yy, xx = np.mgrid[0:H2, 0:W2].astype(np.float32)
    edge = np.minimum.reduce([xx, W2 - 1 - xx, yy, H2 - 1 - yy]) / SS
    img -= (np.clip(1.0 - edge / 2.6, 0, 1) ** 1.5)[..., None] * 55.0
    img = np.clip(img, 0, 255)

    alpha = Image.new("L", (W2, H2), 0)
    ImageDraw.Draw(alpha).rounded_rectangle([0, 0, W2 - 1, H2 - 1], radius=4 * SS, fill=255)
    ad = ImageDraw.Draw(alpha)
    for _ in range(10):
        cx0 = rnd.uniform(0, 330)
        top = rnd.random() < 0.4
        cy0 = 0 if top else 80
        ad.ellipse([(cx0 - 2.4) * SS, (cy0 - 1.4) * SS, (cx0 + 2.4) * SS, (cy0 + 1.4) * SS], fill=0)
    out = Image.fromarray(img.astype(np.uint8), "RGB").convert("RGBA")
    out.putalpha(alpha)
    return out.resize((330, 80), Image.LANCZOS)


# ───────── 월마리아(6): 유럽 중세 성벽 — 총안(성가퀴)·돌출 받침·화살구멍이 있는 석회암 성벽 (2.5D) ─────────
def wall_castle_sprite():
    """330x80. 위 44px은 성벽 위 통로와 총안 난간, 아래 36px은 받침 줄·석재 단·화살구멍이 보이는 앞면."""
    W2, H2 = 330 * SS, 80 * SS
    TOP = 44
    rnd = random.Random(61)
    img = np.zeros((H2, W2, 3), np.float32)
    shade = np.zeros((H2, W2), np.float32)
    outline = Image.new("L", (W2, H2), 0)      # 돌 사이 어두운 틈
    hilite = Image.new("L", (W2, H2), 0)       # 돌 위·왼쪽 모서리 밝은 선
    od, hd = ImageDraw.Draw(outline), ImageDraw.Draw(hilite)

    def fill(x0, y0, x1, y1, color, tone=0.0):
        a, b, c_, d_ = int(x0 * SS), int(y0 * SS), int(x1 * SS), int(y1 * SS)
        img[b:d_, a:c_] = color
        shade[b:d_, a:c_] += tone

    def stone(x0, y0, x1, y1, color, tone_range=10.0):
        fill(x0, y0, x1, y1, color, rnd.uniform(-tone_range, tone_range))
        od.rectangle([P(x0, y0), P(x1, y1)], outline=255, width=int(1.2 * SS))
        hd.line([P(x0 + 1, y0 + 1.2), P(x1 - 1, y0 + 1.2)], fill=255, width=int(1.0 * SS))
        hd.line([P(x0 + 1.2, y0 + 1), P(x0 + 1.2, y1 - 1)], fill=255, width=int(0.8 * SS))

    LIME, LIME_TOP, LIME_FACE, LIME_DARK = (150, 141, 122), (214, 204, 182), (156, 143, 120), (122, 112, 96)

    # 1) 통로 바닥: 큰 판석이 엇갈려 깔려 있다.
    y = 0.0
    row = 0
    while y < TOP:
        h = 14.0
        x = -rnd.uniform(0, 30) if row % 2 else 0.0
        while x < 330:
            w = rnd.uniform(34, 50)
            stone(max(x, 0), y, min(x + w, 330), min(y + h, TOP), LIME, 9.0)
            x += w
        y += h
        row += 1
    # 2) 총안 난간(성가퀴): 윗면 + 앞면. 틈에서는 통로 바닥이 보인다.
    merlon_w, pitch = 30.0, 48.0
    xs = [10.0 + pitch * i for i in range(int((330 - 10 - merlon_w) // pitch) + 1)]
    cast = Image.new("L", (W2, H2), 0)
    cd = ImageDraw.Draw(cast)
    for mx in xs:
        cd.rectangle([P(mx + 3, 14), P(mx + merlon_w + 9, 22)], fill=255)  # 뒤쪽 바닥에 드리운 그림자
    cast_a = np.asarray(cast.filter(ImageFilter.GaussianBlur(2.0 * SS)), np.float32) / 255.0
    shade -= cast_a * 46.0
    for mx in xs:
        stone(mx, 22, mx + merlon_w, 31, LIME_TOP, 6.0)                 # 윗면(밝음)
        stone(mx, 31, mx + merlon_w, TOP, (146, 133, 111), 6.0)          # 앞면(그늘진 면)
        od.line([P(mx + merlon_w / 2, 31), P(mx + merlon_w / 2, TOP)], fill=255, width=int(1.0 * SS))
    # 3) 앞면: 돌출 받침(코벨) 줄 — 총안 아래를 떠받치는 돌 받침과 그 사이 그늘
    fill(0, TOP, 330, TOP + 9, (84, 76, 64))
    x = 4.0
    while x < 326:
        stone(x, TOP, x + 12, TOP + 8, LIME_FACE, 6.0)
        # 받침 아래가 둥글게 파인 모양(작은 아치 그늘)
        od.arc([P(x + 12.5, TOP + 1), P(x + 20, TOP + 9)], 180, 360, fill=255, width=int(1.2 * SS))
        x += 20.0
    # 4) 석재 단: 위에서 아래로 갈수록 돌이 크고 어두워진다. 맨 아래는 넓게 튀어나온 기단.
    rows = [(TOP + 9, TOP + 20, LIME_FACE, 28, 44), (TOP + 20, TOP + 29, LIME_FACE, 30, 50), (TOP + 29, 80, LIME_DARK, 34, 56)]
    for r_i, (y0, y1, col, wmin, wmax) in enumerate(rows):
        x = -rnd.uniform(0, 26) if r_i % 2 else 0.0
        while x < 330:
            w = rnd.uniform(wmin, wmax)
            stone(max(x, 0), y0, min(x + w, 330), y1, col, 9.0)
            x += w
    # 5) 모서리 쐐기돌(쿼인): 양 끝에 길고 짧은 돌이 번갈아 쌓인다.
    for side_x in (0.0, 318.0):
        yq = TOP + 9
        k = 0
        while yq < 80:
            hh = 11 if k % 3 else 9
            stone(side_x, yq, side_x + (12 if k % 2 == 0 else 8), yq + hh, (196, 185, 162), 5.0)
            yq += hh
            k += 1
    # 6) 화살구멍
    slit = Image.new("L", (W2, H2), 0)
    sd = ImageDraw.Draw(slit)
    for sx in (66.0, 165.0, 264.0):
        stone(sx - 8, TOP + 8, sx + 8, TOP + 13, (200, 189, 166), 3.0)   # 위 인방(lintel)
        sd.rectangle([P(sx - 2.4, TOP + 13), P(sx + 2.4, TOP + 30)], fill=255)
        stone(sx - 7, TOP + 30, sx + 7, TOP + 34, (196, 185, 162), 3.0)   # 아래 문턱
    slit_a = np.asarray(slit.filter(ImageFilter.GaussianBlur(0.5 * SS)), np.float32) / 255.0

    # 질감과 밝기
    img += (shade)[..., None] * np.array([1.0, 1.0, 1.0], np.float32)
    n1 = _noise((H2, W2), 1.2, 21, 5.0)
    n2 = _noise((H2, W2), 7.0, 22, 7.0)
    warm = _noise((H2, W2), 10.0, 23, 4.5)
    img[..., 0] += n1 + n2 + warm
    img[..., 1] += n1 + n2 + warm * 0.55
    img[..., 2] += n1 + n2 - warm * 0.5
    gap_core = np.asarray(outline.filter(ImageFilter.GaussianBlur(0.4 * SS)), np.float32) / 255.0
    gap_ao = np.asarray(outline.filter(ImageFilter.GaussianBlur(2.0 * SS)), np.float32) / 255.0
    img -= gap_ao[..., None] * 26.0 + gap_core[..., None] * 44.0
    hl = np.asarray(hilite.filter(ImageFilter.GaussianBlur(0.5 * SS)), np.float32) / 255.0
    img += hl[..., None] * 20.0
    # 윗면과 앞면 경계(처마 아래 그늘)와 아래로 갈수록 어두워지는 앞면
    for k in range(int(8 * SS)):
        yy = TOP * SS + k
        img[yy, :, :] -= (1 - k / (8 * SS)) * 24.0
    ramp = np.linspace(0.0, 1.0, int((80 - TOP) * SS), dtype=np.float32)
    img[TOP * SS:] -= ramp[:, None, None] * 22.0
    img *= (1.0 - slit_a[..., None] * 0.93)        # 화살구멍은 거의 새까맣다
    img += slit_a[..., None] * 18.0 * 0.0

    # 빗물 자국, 이끼와 담쟁이(앞면 아래쪽과 모서리)
    for _ in range(26):
        sx = rnd.uniform(4, 326)
        sw = rnd.uniform(1.2, 3.4)
        y0 = rnd.choice([TOP - 1, TOP + rnd.uniform(0, 14), rnd.uniform(0, 30)])
        length = rnd.uniform(12, 32)
        m = Image.new("L", (W2, H2), 0)
        ImageDraw.Draw(m).rectangle([sx * SS, y0 * SS, (sx + sw) * SS, (y0 + length) * SS], fill=255)
        m = np.asarray(m.filter(ImageFilter.GaussianBlur(1.4 * SS)), np.float32) / 255.0
        img[..., 0] -= m * 24.0
        img[..., 1] -= m * 26.0
        img[..., 2] -= m * 30.0
    moss = Image.new("L", (W2, H2), 0)
    md = ImageDraw.Draw(moss)
    for _ in range(26):
        mx = rnd.uniform(4, 326)
        my = rnd.uniform(66, 80) if rnd.random() < 0.75 else rnd.uniform(46, 66)
        mr = rnd.uniform(3, 8)
        md.ellipse([(mx - mr) * SS, (my - mr * 0.6) * SS, (mx + mr) * SS, (my + mr * 0.6) * SS], fill=255)
    moss_a = np.asarray(moss.filter(ImageFilter.GaussianBlur(1.8 * SS)), np.float32) / 255.0
    moss_a *= (0.5 + 0.5 * np.clip(_noise((H2, W2), 2.5, 27, 1.0) * 0.5 + 0.5, 0, 1))
    for c_, v in enumerate((64, 104, 50)):
        img[..., c_] = img[..., c_] * (1 - moss_a * 0.6) + v * moss_a * 0.6

    yy, xx = np.mgrid[0:H2, 0:W2].astype(np.float32)
    edge = np.minimum.reduce([xx, W2 - 1 - xx, yy, H2 - 1 - yy]) / SS
    img -= (np.clip(1.0 - edge / 2.4, 0, 1) ** 1.5)[..., None] * 50.0
    img = np.clip(img, 0, 255)

    alpha = Image.new("L", (W2, H2), 0)
    ImageDraw.Draw(alpha).rounded_rectangle([0, 0, W2 - 1, H2 - 1], radius=3 * SS, fill=255)
    # 총안 틈(통로가 앞으로 열린 곳)은 윗면 가장자리까지 그대로 보이므로 따로 잘라내지 않는다.
    out = Image.fromarray(img.astype(np.uint8), "RGB").convert("RGBA")
    out.putalpha(alpha)
    return out.resize((330, 80), Image.LANCZOS)


# ───────── 월마리아(7): 콘스탄티노플 성벽 — 석회암과 붉은 벽돌 띠, 아치 개구부, 양 끝의 원형 탑 (2.5D) ─────────
def wall_constantinople_sprite():
    """330x100. y 10~54는 성벽 윗면(충돌 크기), 아래는 앞면. 양 끝에 성가퀴 두른 원형 탑이 솟아 있다."""
    W2, H2 = 330 * SS, 100 * SS
    TOP0, TOP = 10, 54
    rnd = random.Random(88)
    img = np.zeros((H2, W2, 3), np.float32)
    shade = np.zeros((H2, W2), np.float32)
    outline = Image.new("L", (W2, H2), 0)
    hilite = Image.new("L", (W2, H2), 0)
    od, hd = ImageDraw.Draw(outline), ImageDraw.Draw(hilite)
    mask_all = Image.new("L", (W2, H2), 0)   # 그림이 차지하는 영역(알파)
    ma = ImageDraw.Draw(mask_all)

    LIME, LIME_TOP, LIME_FACE, LIME_DARK = (150, 141, 122), (214, 204, 182), (178, 166, 142), (130, 120, 102)
    BRICK, BRICK_DARK = (158, 76, 54), (122, 56, 40)

    def fill(x0, y0, x1, y1, color, tone=0.0):
        a, b, c_, d_ = int(x0 * SS), int(y0 * SS), int(x1 * SS), int(y1 * SS)
        img[b:d_, a:c_] = color
        shade[b:d_, a:c_] += tone
        ma.rectangle([a, b, c_ - 1, d_ - 1], fill=255)

    def stone(x0, y0, x1, y1, color, tone_range=10.0, lines=True):
        fill(x0, y0, x1, y1, color, rnd.uniform(-tone_range, tone_range))
        if lines:
            od.rectangle([P(x0, y0), P(x1, y1)], outline=255, width=int(1.2 * SS))
            hd.line([P(x0 + 1, y0 + 1.2), P(x1 - 1, y0 + 1.2)], fill=255, width=int(1.0 * SS))
            hd.line([P(x0 + 1.2, y0 + 1), P(x0 + 1.2, y1 - 1)], fill=255, width=int(0.8 * SS))

    def brick_band(x0, y0, x1, y1):
        """붉은 벽돌 띠: 얇은 벽돌 줄 여러 겹이 엇갈려 쌓인다."""
        rows = max(int((y1 - y0) / 2.0), 1)
        for r in range(rows):
            ya, yb = y0 + r * (y1 - y0) / rows, y0 + (r + 1) * (y1 - y0) / rows
            x = x0 - (rnd.uniform(0, 7) if r % 2 else 0.0)
            while x < x1:
                w = rnd.uniform(7, 11)
                col = BRICK if rnd.random() > 0.3 else BRICK_DARK
                fill(max(x, x0), ya, min(x + w, x1), yb, col, rnd.uniform(-8, 8))
                od.line([P(max(x, x0), ya), P(min(x + w, x1), ya)], fill=160, width=int(0.9 * SS))
                od.line([P(x + w, ya), P(x + w, yb)], fill=170, width=int(0.8 * SS))
                x += w

    def lime_row(x0, y0, x1, y1, color, wmin, wmax):
        x = x0 - (rnd.uniform(0, wmin * 0.8) if rnd.random() < 0.5 else 0.0)
        while x < x1:
            w = rnd.uniform(wmin, wmax)
            stone(max(x, x0), y0, min(x + w, x1), y1, color, 9.0)
            x += w

    WX0, WX1 = 30.0, 300.0     # 성벽 몸통이 이어지는 구간(양 끝은 탑이 덮는다)
    # 1) 통로 바닥과 총안 난간
    y = float(TOP0)
    row = 0
    while y < TOP:
        h = 14.7
        x = WX0 - (rnd.uniform(0, 30) if row % 2 else 0.0)
        while x < WX1:
            w = rnd.uniform(34, 50)
            stone(max(x, WX0), y, min(x + w, WX1), min(y + h, TOP), LIME, 9.0)
            x += w
        y += h
        row += 1
    xs = [62.0 + 46.0 * i for i in range(5)]
    cast = Image.new("L", (W2, H2), 0)
    cd = ImageDraw.Draw(cast)
    for mx in xs:
        cd.rectangle([P(mx + 3, TOP0 + 4), P(mx + 38, TOP0 + 12)], fill=255)
    shade -= np.asarray(cast.filter(ImageFilter.GaussianBlur(2.0 * SS)), np.float32) / 255.0 * 46.0
    for mx in xs:
        stone(mx, TOP0 + 12, mx + 28, TOP0 + 21, LIME_TOP, 6.0)
        stone(mx, TOP0 + 21, mx + 28, TOP, (150, 137, 114), 6.0)
        od.line([P(mx + 14, TOP0 + 21), P(mx + 14, TOP)], fill=255, width=int(1.0 * SS))

    # 2) 앞면: 받침 줄 → 석회암 → 벽돌 띠 → 석회암 → 벽돌 띠 → 기단
    fill(WX0, TOP, WX1, TOP + 8, (84, 76, 64))
    x = WX0 + 2
    while x < WX1:
        stone(x, TOP, x + 12, TOP + 7, LIME_FACE, 6.0)
        od.arc([P(x + 12.5, TOP + 1), P(x + 20, TOP + 9)], 180, 360, fill=255, width=int(1.2 * SS))
        x += 20.0
    lime_row(WX0, TOP + 8, WX1, TOP + 18, LIME_FACE, 28, 44)
    brick_band(WX0, TOP + 18, WX1, TOP + 25)
    lime_row(WX0, TOP + 25, WX1, TOP + 35, LIME_FACE, 30, 48)
    brick_band(WX0, TOP + 35, WX1, TOP + 42)
    lime_row(WX0, TOP + 42, WX1, 100, LIME_DARK, 34, 56)

    # 3) 아치 개구부: 붉은 벽돌 아치테 + 어두운 안쪽
    arch = Image.new("L", (W2, H2), 0)
    ad = ImageDraw.Draw(arch)
    for ax in (118.0, 212.0):
        ad.rectangle([P(ax - 7, TOP + 17), P(ax + 7, TOP + 36)], fill=255)
        ad.pieslice([P(ax - 7, TOP + 9), P(ax + 7, TOP + 25)], 180, 360, fill=255)
        od.arc([P(ax - 9, TOP + 7), P(ax + 9, TOP + 27)], 180, 360, fill=255, width=int(2.0 * SS))
        for ang in range(190, 360, 18):   # 아치를 두른 쐐기 벽돌
            a = math.radians(ang)
            x1, y1 = ax + math.cos(a) * 8, TOP + 17 + math.sin(a) * 8
            x2, y2 = ax + math.cos(a) * 11, TOP + 17 + math.sin(a) * 11
            od.line([P(x1, y1), P(x2, y2)], fill=255, width=int(0.9 * SS))
        fill(ax - 10, TOP + 36, ax + 10, TOP + 39, BRICK, 0.0)   # 문턱 벽돌
    arch_a = np.asarray(arch.filter(ImageFilter.GaussianBlur(0.5 * SS)), np.float32) / 255.0

    # 4) 원형 탑: 몸통(원통 음영) → 윗면 원판 → 성가퀴 고리
    tower_shade = np.zeros((H2, W2), np.float32)
    for cx in (34.0, 296.0):
        R = 24.0
        body_top, body_bot = 36.0, 100.0
        # 몸통: 위에서 아래로 석회암/벽돌 띠가 감싸고, 좌우로 원통처럼 음영이 진다.
        fill(cx - R, body_top, cx + R, body_bot, LIME_FACE, 0.0)
        lime_row(cx - R, body_top, cx + R, 66, LIME_FACE, 14, 20)
        brick_band(cx - R, 66, cx + R, 73)
        lime_row(cx - R, 73, cx + R, 85, LIME_FACE, 14, 20)
        brick_band(cx - R, 85, cx + R, 92)
        lime_row(cx - R, 92, cx + R, 100, LIME_DARK, 14, 20)
        for xx in range(int((cx - R) * SS), int((cx + R) * SS)):
            f = (xx / SS - cx) / R                      # -1(왼쪽)~+1(오른쪽)
            tower_shade[int(body_top * SS):int(body_bot * SS), xx] = (f * 30.0) - (1 - abs(f) ** 2) * -10.0 + (abs(f) ** 3) * -45.0
        # 탑의 아치 화살구멍
        sx = cx
        fill(sx - 3.0, 60, sx + 3.0, 78, (28, 24, 22), 0.0)
        ad.pieslice([P(sx - 3.0, 56), P(sx + 3.0, 64)], 180, 360, fill=255)
        fill(sx - 3.0, 58.5, sx + 3.0, 64, (28, 24, 22), 0.0)
        # 윗면 원판(바닥) + 성가퀴 고리
        ma.ellipse([P(cx - R, 0), P(cx + R, 48)], fill=255)
        disc_mask = Image.new("L", (W2, H2), 0)
        ImageDraw.Draw(disc_mask).ellipse([P(cx - R, 0), P(cx + R, 48)], fill=255)
        dm = np.asarray(disc_mask, np.float32) / 255.0
        img[dm > 0.5] = LIME
        # 원판 안쪽에 가운데로 갈수록 어두운 바닥, 바깥 둘레는 밝은 돌 고리
        img[dm > 0.5] += np.array([0, 0, 0], np.float32)
        for k in range(12):
            a = math.tau * k / 12
            mx, my = cx + math.cos(a) * (R - 5.0), 24.0 + math.sin(a) * (R - 5.0)
            fill(mx - 3.4, my - 3.0, mx + 3.4, my + 3.0, LIME_TOP, 4.0)
            od.rectangle([P(mx - 3.4, my - 3.0), P(mx + 3.4, my + 3.0)], outline=255, width=int(0.9 * SS))
        od.ellipse([P(cx - R, 0), P(cx + R, 48)], outline=255, width=int(1.4 * SS))
        od.ellipse([P(cx - R + 9, 9), P(cx + R - 9, 39)], outline=255, width=int(1.0 * SS))
        fill(cx - 8, 16, cx + 8, 32, (118, 108, 92), 0.0)   # 탑 위 가운데 계단실 지붕
        img[int(16 * SS):int(32 * SS), int((cx - 8) * SS):int((cx + 8) * SS)] = (170, 78, 56)   # 붉은 기와지붕
    shade += tower_shade

    # 5) 질감·조명 (이전과 같은 방식)
    img += shade[..., None]
    n1 = _noise((H2, W2), 1.2, 41, 5.0)
    n2 = _noise((H2, W2), 7.0, 42, 6.0)
    warm = _noise((H2, W2), 10.0, 43, 4.0)
    img[..., 0] += n1 + n2 + warm
    img[..., 1] += n1 + n2 + warm * 0.55
    img[..., 2] += n1 + n2 - warm * 0.5
    gap_core = np.asarray(outline.filter(ImageFilter.GaussianBlur(0.4 * SS)), np.float32) / 255.0
    gap_ao = np.asarray(outline.filter(ImageFilter.GaussianBlur(2.0 * SS)), np.float32) / 255.0
    img -= gap_ao[..., None] * 24.0 + gap_core[..., None] * 42.0
    hl = np.asarray(hilite.filter(ImageFilter.GaussianBlur(0.5 * SS)), np.float32) / 255.0
    img += hl[..., None] * 20.0
    for k in range(int(8 * SS)):
        yy = TOP * SS + k
        img[yy, int(WX0 * SS):int(WX1 * SS), :] -= (1 - k / (8 * SS)) * 22.0
    ramp = np.linspace(0.0, 1.0, int((100 - TOP) * SS), dtype=np.float32)
    img[TOP * SS:] -= ramp[:, None, None] * 20.0
    img *= (1.0 - arch_a[..., None] * 0.94)
    # 빗물 자국과 아래쪽 이끼
    for _ in range(24):
        sx = rnd.uniform(34, 296)
        sw = rnd.uniform(1.2, 3.2)
        y0 = rnd.choice([TOP - 1, TOP + rnd.uniform(0, 14)])
        length = rnd.uniform(10, 30)
        m = Image.new("L", (W2, H2), 0)
        ImageDraw.Draw(m).rectangle([sx * SS, y0 * SS, (sx + sw) * SS, (y0 + length) * SS], fill=255)
        m = np.asarray(m.filter(ImageFilter.GaussianBlur(1.4 * SS)), np.float32) / 255.0
        for c_, v in enumerate((22.0, 24.0, 28.0)):
            img[..., c_] -= m * v
    moss = Image.new("L", (W2, H2), 0)
    md = ImageDraw.Draw(moss)
    for _ in range(26):
        mx = rnd.uniform(6, 324)
        my = rnd.uniform(86, 100)
        mr = rnd.uniform(3, 7.5)
        md.ellipse([(mx - mr) * SS, (my - mr * 0.6) * SS, (mx + mr) * SS, (my + mr * 0.6) * SS], fill=255)
    moss_a = np.asarray(moss.filter(ImageFilter.GaussianBlur(1.8 * SS)), np.float32) / 255.0
    moss_a *= (0.5 + 0.5 * np.clip(_noise((H2, W2), 2.5, 47, 1.0) * 0.5 + 0.5, 0, 1))
    for c_, v in enumerate((64, 104, 50)):
        img[..., c_] = img[..., c_] * (1 - moss_a * 0.55) + v * moss_a * 0.55
    img = np.clip(img, 0, 255)

    # 알파: 그린 영역(탑의 원판 포함)만 남기고 가장자리를 조금 부드럽게
    alpha = mask_all.filter(ImageFilter.GaussianBlur(0.6 * SS))
    out = Image.fromarray(img.astype(np.uint8), "RGB").convert("RGBA")
    out.putalpha(alpha)
    return out.resize((330, 100), Image.LANCZOS)


# ───────── 월마리아(8): 손으로 그린 콘스탄티노플 성벽 — 노이즈 질감 없이 면과 선으로 칠한 만화풍 일러스트 ─────────
HP_INK = hexcolor("34291f")
HP_LIME_L, HP_LIME, HP_LIME_D = hexcolor("e2d6ba"), hexcolor("c3b595"), hexcolor("93866a")
HP_FLOOR_L, HP_FLOOR, HP_FLOOR_D = hexcolor("c4b693"), hexcolor("a89a79"), hexcolor("7f7358")
HP_BRICK_L, HP_BRICK, HP_BRICK_D = hexcolor("d27a58"), hexcolor("b3553a"), hexcolor("843a28")
HP_MOSS_D, HP_MOSS, HP_MOSS_L = hexcolor("3f5d2e"), hexcolor("6d9a45"), hexcolor("a8cf72")
HP_SHADOW = hexcolor("3c3226")


def _quad(x0, y0, x1, y1, jit, rnd):
    j = lambda: rnd.uniform(-jit, jit)
    return [P(x0 + j(), y0 + j()), P(x1 + j(), y0 + j()), P(x1 + j(), y1 + j()), P(x0 + j(), y1 + j())]


def hp_block(c, x0, y0, x1, y1, base, light, dark, rnd, jit=0.45, chip=True):
    """돌 한 덩이: 먹선 → 본색 → 위·왼쪽 밝은 면 → 아래·오른쪽 어두운 면. 모서리는 손으로 그린 듯 살짝 어긋난다."""
    seed = rnd.randint(0, 10 ** 6)
    r2 = random.Random(seed)
    c.fill(lambda d: d.polygon(_quad(x0 - 0.8, y0 - 0.8, x1 + 0.8, y1 + 0.8, jit, random.Random(seed)), fill=255), HP_INK, 1.0, 0.25)
    c.fill(lambda d: d.polygon(_quad(x0, y0, x1, y1, jit, random.Random(seed)), fill=255), base, 1.0, 0.2)
    w, h = x1 - x0, y1 - y0
    t = min(2.2, h * 0.28)
    c.fill(lambda d: d.polygon([P(x0 + 0.5, y0 + 0.5), P(x1 - 0.5, y0 + 0.5), P(x1 - 2.0, y0 + t), P(x0 + t, y0 + t), P(x0 + t, y1 - 1.0), P(x0 + 0.5, y1 - 0.5)], fill=255), light, 0.85, 0.2)
    c.fill(lambda d: d.polygon([P(x1 - 0.5, y0 + 1.0), P(x1 - 0.5, y1 - 0.5), P(x0 + 1.0, y1 - 0.5), P(x0 + 1.5, y1 - t * 0.9), P(x1 - t * 0.9, y1 - t * 0.9), P(x1 - t * 0.9, y0 + 1.5)], fill=255), dark, 0.75, 0.2)
    if chip and r2.random() < 0.25 and w > 12:
        cx = x1 - 1.0 if r2.random() < 0.5 else x0 + 1.0
        c.fill(lambda d: d.polygon([P(cx, y0), P(cx + (-3.5 if cx > x0 + 2 else 3.5), y0), P(cx, y0 + 3.0)], fill=255), HP_SHADOW, 0.55, 0.2)
    if r2.random() < 0.12 and w > 16:
        sx = r2.uniform(x0 + 3, x1 - 3)
        pts = [(sx, y0 + 1), (sx + r2.uniform(-2, 2), (y0 + y1) / 2), (sx + r2.uniform(-3, 3), y1 - 1)]
        c.fill(lambda d: d.line([P(*q) for q in pts], fill=255, width=int(0.8 * SS)), HP_INK, 0.75, 0.2)


def hp_row(c, x0, y0, x1, y1, base, light, dark, rnd, wmin, wmax):
    x = x0 - (rnd.uniform(0, wmin * 0.9) if rnd.random() < 0.6 else 0.0)
    while x < x1:
        w = rnd.uniform(wmin, wmax)
        hp_block(c, max(x, x0), y0, min(x + w - 0.6, x1), y1, base, light, dark, rnd)
        x += w


def hp_brick_band(c, x0, y0, x1, y1, rnd):
    rows = 2
    for r in range(rows):
        ya, yb = y0 + r * (y1 - y0) / rows, y0 + (r + 1) * (y1 - y0) / rows
        x = x0 - (rnd.uniform(0, 4.5) if r % 2 else 0.0)
        while x < x1:
            w = rnd.uniform(7.5, 10.5)
            tone = rnd.random()
            base = HP_BRICK if tone > 0.25 else HP_BRICK_D
            hp_block(c, max(x, x0), ya, min(x + w - 0.5, x1), yb, base, HP_BRICK_L, HP_BRICK_D, rnd, jit=0.25, chip=False)
            x += w


def hp_moss(c, x, y, rnd, size=1.0):
    for k in range(4):
        dx, dy = rnd.uniform(-5, 5) * size, rnd.uniform(-1.5, 1.5) * size
        r = rnd.uniform(2.6, 4.6) * size
        c.fill(lambda d, dx=dx, dy=dy, r=r, k=k: blob(d, x + dx, y + dy, r, 4, 0.3, rnd.randint(0, 999)), HP_MOSS_D, 0.95, 0.3)
        c.fill(lambda d, dx=dx, dy=dy, r=r, k=k: blob(d, x + dx - 0.5, y + dy - 0.6, r * 0.72, 4, 0.3, rnd.randint(0, 999)), HP_MOSS, 0.98, 0.3)
        c.fill(lambda d, dx=dx, dy=dy, r=r, k=k: blob(d, x + dx - 1.0, y + dy - 1.2, r * 0.32, 3, 0.3, rnd.randint(0, 999)), HP_MOSS_L, 0.98, 0.3)


def wall_handpainted_sprite():
    """330x100. y 10~54는 성벽 윗면(충돌 크기), 아래는 앞면. 양 끝에 성가퀴 두른 원형 탑."""
    c = Paint(330 * SS, 100 * SS)
    rnd = random.Random(404)
    TOP0, TOP = 10, 54
    WX0, WX1 = 30.0, 300.0

    # 1) 통로 바닥 판석
    y = float(TOP0)
    row = 0
    while y < TOP - 0.1:
        h = (TOP - TOP0) / 3.0
        x = WX0 - (rnd.uniform(0, 26) if row % 2 else 0.0)
        while x < WX1:
            w = rnd.uniform(34, 50)
            hp_block(c, max(x, WX0), y, min(x + w - 0.6, WX1), y + h - 0.5, HP_FLOOR, HP_FLOOR_L, HP_FLOOR_D, rnd)
            x += w
        y += h
        row += 1
    # 2) 총안 난간: 뒤쪽 바닥에 드리운 그림자 → 윗면 → 앞면
    xs = [62.0 + 46.0 * i for i in range(5)]
    for mx in xs:
        c.fill(lambda d, mx=mx: d.polygon([P(mx + 2, TOP0 + 30), P(mx + 30, TOP0 + 30), P(mx + 36, TOP0 + 22), P(mx + 8, TOP0 + 22)], fill=255), HP_SHADOW, 0.3, 0.5)
    for mx in xs:
        hp_block(c, mx, TOP0 + 26, mx + 28, TOP0 + 33, HP_LIME_L, HP_LIME_L, HP_LIME, rnd, chip=False)
        hp_block(c, mx, TOP0 + 33, mx + 14, TOP, HP_LIME, HP_LIME_L, HP_LIME_D, rnd, chip=False)
        hp_block(c, mx + 14, TOP0 + 33, mx + 28, TOP, HP_LIME, HP_LIME_L, HP_LIME_D, rnd, chip=False)
    # 3) 앞면
    c.fill(lambda d: d.rectangle([P(WX0, TOP), P(WX1, TOP + 8)], fill=255), HP_SHADOW, 1.0, 0.2)
    x = WX0 + 2
    while x < WX1 - 10:
        hp_block(c, x, TOP, x + 12, TOP + 6.5, HP_LIME, HP_LIME_L, HP_LIME_D, rnd, chip=False)
        c.fill(lambda d, x=x: d.pieslice([P(x + 12.5, TOP - 1), P(x + 20, TOP + 8)], 0, 180, fill=255), HP_INK, 0.85, 0.2)
        x += 20.0
    hp_row(c, WX0, TOP + 8, WX1, TOP + 18, HP_LIME, HP_LIME_L, HP_LIME_D, rnd, 26, 42)
    hp_brick_band(c, WX0, TOP + 18, WX1, TOP + 25, rnd)
    hp_row(c, WX0, TOP + 25, WX1, TOP + 35, HP_LIME, HP_LIME_L, HP_LIME_D, rnd, 28, 46)
    hp_brick_band(c, WX0, TOP + 35, WX1, TOP + 42, rnd)
    hp_row(c, WX0, TOP + 42, WX1, 100, HP_LIME_D, HP_LIME, HP_LIME_D, rnd, 32, 52)
    # 4) 아치 문: 어두운 안쪽 + 아치를 두른 붉은 쐐기 벽돌
    for ax in (118.0, 212.0):
        c.fill(lambda d, ax=ax: d.polygon([P(ax - 9.2, TOP + 38), P(ax - 9.2, TOP + 18), P(ax - 8, TOP + 14), P(ax - 4.5, TOP + 10.8), P(ax, TOP + 9.6), P(ax + 4.5, TOP + 10.8), P(ax + 8, TOP + 14), P(ax + 9.2, TOP + 18), P(ax + 9.2, TOP + 38)], fill=255), HP_INK, 1.0, 0.25)
        c.fill(lambda d, ax=ax: d.rectangle([P(ax - 7, TOP + 17), P(ax + 7, TOP + 38)], fill=255), hexcolor("221b15"), 1.0, 0.2)
        c.fill(lambda d, ax=ax: d.pieslice([P(ax - 7, TOP + 10), P(ax + 7, TOP + 24)], 180, 360, fill=255), hexcolor("221b15"), 1.0, 0.2)
        for ang in range(200, 350, 22):
            a0, a1 = math.radians(ang), math.radians(ang + 16)
            pts = [P(ax + math.cos(a0) * 7.4, TOP + 17 + math.sin(a0) * 7.4), P(ax + math.cos(a1) * 7.4, TOP + 17 + math.sin(a1) * 7.4),
                   P(ax + math.cos(a1) * 11.4, TOP + 17 + math.sin(a1) * 11.4), P(ax + math.cos(a0) * 11.4, TOP + 17 + math.sin(a0) * 11.4)]
            c.fill(lambda d, pts=pts: d.polygon(pts, fill=255), HP_INK, 1.0, 0.2)
            inner = [P(ax + math.cos(a0) * 7.9, TOP + 17 + math.sin(a0) * 7.9), P(ax + math.cos(a1) * 7.9, TOP + 17 + math.sin(a1) * 7.9),
                     P(ax + math.cos(a1) * 10.9, TOP + 17 + math.sin(a1) * 10.9), P(ax + math.cos(a0) * 10.9, TOP + 17 + math.sin(a0) * 10.9)]
            c.fill(lambda d, inner=inner: d.polygon(inner, fill=255), HP_BRICK if ang % 44 else HP_BRICK_L, 1.0, 0.2)
        hp_block(c, ax - 9.5, TOP + 38, ax + 9.5, TOP + 41, HP_BRICK, HP_BRICK_L, HP_BRICK_D, rnd, jit=0.2, chip=False)
    # 5) 원형 탑: 몸통 → 원통 음영 → 윗면 원판 → 성가퀴 고리 → 지붕
    for cx in (34.0, 296.0):
        R = 24.0
        c.fill(lambda d, cx=cx: d.rectangle([P(cx - R - 0.9, 35.2), P(cx + R + 0.9, 100)], fill=255), HP_INK, 1.0, 0.25)
        hp_row(c, cx - R, 36, cx + R, 66, HP_LIME, HP_LIME_L, HP_LIME_D, rnd, 13, 19)
        hp_brick_band(c, cx - R, 66, cx + R, 73, rnd)
        hp_row(c, cx - R, 73, cx + R, 85, HP_LIME, HP_LIME_L, HP_LIME_D, rnd, 13, 19)
        hp_brick_band(c, cx - R, 85, cx + R, 92, rnd)
        hp_row(c, cx - R, 92, cx + R, 100, HP_LIME_D, HP_LIME, HP_LIME_D, rnd, 13, 19)
        # 원통 음영: 왼쪽은 밝게, 오른쪽은 어둡게 (평평한 띠로)
        c.fill(lambda d, cx=cx: d.rectangle([P(cx - R, 36), P(cx - R + 7, 100)], fill=255), HP_LIME_L, 0.45, 0.6)
        c.fill(lambda d, cx=cx: d.rectangle([P(cx + R - 12, 36), P(cx + R, 100)], fill=255), HP_SHADOW, 0.4, 0.8)
        c.fill(lambda d, cx=cx: d.rectangle([P(cx + R - 5, 36), P(cx + R, 100)], fill=255), HP_SHADOW, 0.35, 0.6)
        # 아치 화살구멍
        c.fill(lambda d, cx=cx: d.rectangle([P(cx - 3.3, 59), P(cx + 3.3, 80)], fill=255), HP_INK, 1.0, 0.2)
        c.fill(lambda d, cx=cx: d.pieslice([P(cx - 3.3, 55.5), P(cx + 3.3, 62.5)], 180, 360, fill=255), HP_INK, 1.0, 0.2)
        # 윗면 원판
        c.fill(lambda d, cx=cx: d.ellipse([P(cx - R - 1.2, -1.2), P(cx + R + 1.2, 49.2)], fill=255), HP_INK, 1.0, 0.3)
        c.fill(lambda d, cx=cx: d.ellipse([P(cx - R, 0), P(cx + R, 48)], fill=255), HP_FLOOR, 1.0, 0.3)
        c.fill(lambda d, cx=cx: d.ellipse([P(cx - R + 3, 3), P(cx + R - 9, 36)], fill=255), HP_FLOOR_L, 0.55, 1.2)
        for k in range(12):
            a = math.tau * k / 12 + 0.1
            mx, my = cx + math.cos(a) * (R - 4.6), 24.0 + math.sin(a) * (R - 4.6)
            hp_block(c, mx - 3.6, my - 3.1, mx + 3.6, my + 3.1, HP_LIME_L, HP_LIME_L, HP_LIME, rnd, jit=0.3, chip=False)
        c.fill(lambda d, cx=cx: d.ellipse([P(cx - R + 8, 8), P(cx + R - 8, 40)], fill=255), HP_INK, 0.0, 0.2)
        # 탑 위 가운데: 낮은 돌 해치(계단실 뚜껑)
        c.fill(lambda d, cx=cx: d.ellipse([P(cx - 8.6, 16.4), P(cx + 8.6, 32.6)], fill=255), HP_INK, 1.0, 0.25)
        c.fill(lambda d, cx=cx: d.ellipse([P(cx - 7.4, 17.6), P(cx + 7.4, 31.4)], fill=255), HP_LIME, 1.0, 0.25)
        c.fill(lambda d, cx=cx: d.ellipse([P(cx - 6.2, 18.4), P(cx + 1.2, 25.4)], fill=255), HP_LIME_L, 0.9, 0.5)
        c.fill(lambda d, cx=cx: d.ellipse([P(cx - 2.6, 21.6), P(cx + 4.6, 28.2)], fill=255), HP_INK, 0.85, 0.3)
    # 6) 빗물 얼룩(평평한 띠)과 이끼 무더기
    for _ in range(9):
        sx = rnd.uniform(WX0 + 6, WX1 - 6)
        c.fill(lambda d, sx=sx: d.polygon([P(sx, TOP + 8), P(sx + rnd.uniform(2, 3.4), TOP + 8), P(sx + rnd.uniform(1.4, 2.6), TOP + rnd.uniform(24, 40)), P(sx + 0.6, TOP + rnd.uniform(24, 40))], fill=255), HP_SHADOW, 0.22, 0.9)
    for mx in (70, 168, 252):
        hp_moss(c, mx, 98.4, rnd, 1.0)
    hp_moss(c, 20, 98.0, rnd, 0.8)
    hp_moss(c, 310, 98.0, rnd, 0.8)
    return c.to_image()


# ───────── 월마리아(9): 무난한 석벽 (위에서 본 모양, 장식 없이 돌 두 줄) ─────────
def wall_plain_sprite():
    c = Paint(330 * SS, 56 * SS)
    rnd = random.Random(9)
    base, light, dark = hexcolor("a9a398"), hexcolor("cbc6ba"), hexcolor("7f796e")
    c.fill(lambda d: d.rounded_rectangle([P(0, 0), P(330, 56)], radius=5 * SS, fill=255), HP_INK, 1.0, 0.25)
    for row in range(2):
        y0 = 3 + row * 25
        x = 3 - (rnd.uniform(0, 26) if row else 0.0)
        while x < 327:
            w = rnd.uniform(38, 56)
            hp_block(c, max(x, 3), y0, min(x + w - 0.8, 327), y0 + 24, base, light, dark, rnd, jit=0.3, chip=False)
            x += w
    return c.to_image()


def main():
    os.makedirs(OUT, exist_ok=True)
    sheets = {
        "dodge_sheet.png": [[dodge_whoosh(i) for i in range(4)], [dodge_arrive(i) for i in range(4)]],
        "janggi_sheet.png": [[janggi_ink(i, CHO_GREEN) for i in range(4)], [janggi_ink(i, HAN_RED) for i in range(4)]],
        "merge_sheet.png": [[merge_vortex(i) for i in range(4)], [merge_impact(i) for i in range(4)]],
        "king_sheet.png": [[king_impact(i) for i in range(4)]],
        "blood_sheet.png": [[blood_slash(i) for i in range(4)]],
        "stealth_sheet.png": [[stealth_vanish(i) for i in range(4)], [stealth_mist(i) for i in range(4)]],
        "coup_sheet.png": [[coup_flip(i) for i in range(4)]],
        "wizard_sheet.png": [[wizard_fireball(i) for i in range(4)], [wizard_blast(i) for i in range(4)]],
    }
    for name, rows in sheets.items():
        sheet(rows).save(os.path.join(OUT, name))
        print("saved", name)
    for name, fn in (("scope_reticle.png", scope_reticle), ("painted_train.png", train_top_sprite), ("painted_wall.png", wall_plain_sprite)):
        fn().save(os.path.join(OUT, name))
        print("saved", name)


if __name__ == "__main__":
    main()
