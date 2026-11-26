#!/usr/bin/env python3
"""전투 화면 그림(사용자 레퍼런스: 밤의 마법 서재, 금테 양피지 카드, 금테 알약, 고풍스러운 코인).

만드는 것(assets/ui/battle/):
  bg.webp            전투 바탕 1440×2560: 아치 창 너머 밤의 성, 양쪽 책장, 촛불 탁자, 수정 구슬, 떠다니는 빛
  card.png           카드 틀(9-patch, 여백 72): 금테 + 양피지
  pill.png           알약 틀(9-patch, 여백 44×40): 금테 + 크림 안쪽(목록·버튼)
  pill_dark.png      알약 틀(어두운 안쪽): 빨리 보기 같은 보조 버튼
  gem.png            카드 위 가운데 보석 장식
  coin_heads.png     앞면(금화, 해 문양) 160×160
  coin_tails.png     뒷면(은화, 달과 별)
  coin_pending.png   아직 던지지 않은 코인(청동, ?)
assets/art/fx/impact.png 부딪힐 때 터지는 금빛 별(Art.draw가 쓴다)
쓰는 법(저장소 루트): python3 tools/ui/battle_art.py
필요한 것: numpy, scipy, Pillow
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets/ui/battle")
FONT = os.path.join(ROOT, "assets/fonts/Jua-Regular.ttf")
LIGHT = np.array([-0.5, -0.65, 0.58])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


def rng(seed):
    return np.random.default_rng(seed)


def noise(h, w, scale, seed, oct=4):
    g = rng(seed)
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(oct):
        s = max(1, int(scale / (2 ** o)))
        small = g.random((h // s + 2, w // s + 2)).astype(np.float32)
        big = ndimage.zoom(small, (s, s), order=3)[:h, :w]
        out += big * amp
        tot += amp
        amp *= 0.5
    return out / tot


def blur(a, s):
    return ndimage.gaussian_filter(a, s)


def over(dst, col, alpha):
    a = np.clip(alpha, 0, 1)[..., None]
    dst[:] = dst * (1 - a) + np.asarray(col, np.float32) * a


def add(dst, col, amount):
    dst[:] = dst + np.asarray(col, np.float32) * np.clip(amount, 0, None)[..., None]


def mask_from(draw_fn, w, h, ss=1):
    im = Image.new("L", (w * ss, h * ss), 0)
    draw_fn(ImageDraw.Draw(im), ss)
    if ss > 1:
        im = im.resize((w, h), Image.LANCZOS)
    return np.asarray(im, np.float32) / 255.0


def shade_from_height(H, strength=1.0):
    gy, gx = np.gradient(H)
    n = np.dstack([-gx * strength, -gy * strength, np.ones_like(H)])
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    d = (n * LIGHT).sum(-1)
    half = n + np.array([0, 0, 1.0]) * 0 + LIGHT  # 반사광(대략)
    half /= np.linalg.norm(half, axis=-1, keepdims=True)
    spec = np.clip(half[..., 2], 0, 1) ** 40
    return d, spec


# ------------------------------------------------------------------ 바탕

def background(W=1440, H=2560):
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    img = np.zeros((H, W, 3), np.float32)
    t = yy / H
    top, mid, bot = hexc("#1b2150"), hexc("#2b2464"), hexc("#140f2c")
    img[:] = np.where((t < 0.55)[..., None], top + (mid - top) * (t / 0.55)[..., None], mid + (bot - mid) * ((t - 0.55) / 0.45)[..., None])
    # 큰 아치 창(가운데 위): 밤하늘, 별, 달, 성 실루엣
    cx, wy0, wy1, ww = W / 2, 120, 1250, 900
    win = ((np.abs(xx - cx) < ww / 2) & (yy > wy0 + ww / 2) & (yy < wy1)) | (((xx - cx) ** 2 + (yy - (wy0 + ww / 2)) ** 2) < (ww / 2) ** 2) & (yy <= wy0 + ww / 2)
    win = blur(win.astype(np.float32), 2)
    sky = hexc("#2f4a9a") * (1 - t[..., None] * 0.9) + hexc("#6a5fc4") * (t[..., None] * 0.6)
    over(img, sky, win)
    g = rng(5)
    for _ in range(260):  # 별
        sx, sy = g.uniform(cx - ww / 2, cx + ww / 2), g.uniform(wy0, wy1 - 300)
        r = g.uniform(1.2, 3.2)
        add(img, hexc("#fff6d8"), np.exp(-((xx - sx) ** 2 + (yy - sy) ** 2) / (2 * r * r)) * win * g.uniform(0.4, 1.0))
    mx, my = cx + 230, 420  # 달과 달무리
    d2 = (xx - mx) ** 2 + (yy - my) ** 2
    add(img, hexc("#bcd2ff"), np.exp(-d2 / (2 * 160 ** 2)) * win * 0.35)
    over(img, hexc("#fff3cf"), np.clip((80 ** 2 - d2) / 400, 0, 1) * win)
    # 성 실루엣(창 아래쪽): 뾰족 지붕 탑들, 따뜻한 창불
    cast = mask_from(lambda d, s: _castle(d, s, cx, ww, wy1), W, H, 1)
    cast = cast * win
    over(img, hexc("#110d2c"), cast)
    for _ in range(90):
        sx, sy = g.uniform(cx - ww / 2 + 30, cx + ww / 2 - 30), g.uniform(wy1 - 520, wy1 - 40)
        if cast[int(sy), int(sx)] > 0.9:
            m = (np.abs(xx - sx) < 7) & (np.abs(yy - sy) < 11)
            over(img, hexc("#ffcf6e"), m.astype(np.float32) * 0.95)
            add(img, hexc("#ff9a3c"), np.exp(-((xx - sx) ** 2 + (yy - sy) ** 2) / (2 * 26 ** 2)) * 0.25)
    # 창틀(돌): 창 둘레의 띠
    frame = np.clip(blur(win, 14) * 1.0 - win, 0, 1) * 3.0
    over(img, hexc("#3a3466"), np.clip(frame, 0, 1))
    # 양쪽 책장
    for side in (0, 1):
        x0 = 0 if side == 0 else W - 330
        shelf = (xx >= x0) & (xx < x0 + 330) & (yy > 200) & (yy < 2050)
        over(img, hexc("#241c3e"), shelf.astype(np.float32))
        for row in range(9):
            ry = 260 + row * 195
            over(img, hexc("#3b2b4a"), ((xx >= x0) & (xx < x0 + 330) & (np.abs(yy - ry - 160) < 10)).astype(np.float32))
            bx = x0 + 18
            while bx < x0 + 312:
                bw = g.uniform(18, 38)
                bh = g.uniform(110, 150)
                col = hexc(["#6b2f3f", "#2f4f6b", "#5b4a2a", "#3f5b3a", "#4a3a6b", "#7a5a2a"][g.integers(6)]) * g.uniform(0.7, 1.0)
                book = (xx >= bx) & (xx < bx + bw - 3) & (yy > ry + 150 - bh) & (yy < ry + 150)
                over(img, col, book.astype(np.float32))
                over(img, hexc("#d9b46a"), ((xx >= bx) & (xx < bx + bw - 3) & (np.abs(yy - (ry + 150 - bh * 0.7)) < 3)).astype(np.float32) * 0.6)
                bx += bw
        # 책장 쪽 어둡게(가운데로 밝게)
        dark = np.clip(1 - np.abs(xx - (x0 + 165)) / 600, 0, 1) * 0.0
    # 마법 소용돌이(카드 뒤): 파랑·금빛 빛줄기
    sw = np.zeros((H, W), np.float32)
    sw2 = np.zeros((H, W), np.float32)
    for k in range(6):  # 소용돌이 빛줄기: 끝으로 갈수록 가늘고 흐려지는 나선 조각
        ph = k * 1.05
        m = np.zeros((H, W), np.float32)
        for i in range(60):
            a0 = i / 60 * math.pi * 1.3 + ph
            a1 = (i + 1) / 60 * math.pi * 1.3 + ph
            r0, r1 = 230 + i * 7.5, 230 + (i + 1) * 7.5
            p0 = (W / 2 + math.cos(a0) * r0 * 1.1, 1150 + math.sin(a0) * r0 * 0.62 - i * 2)
            p1 = (W / 2 + math.cos(a1) * r1 * 1.1, 1150 + math.sin(a1) * r1 * 0.62 - i * 2)
            fade = math.sin(i / 60 * math.pi)
            m += mask_from(lambda d, s, p0=p0, p1=p1, w=int(2 + 9 * fade): d.line([p0, p1], fill=255, width=w), W, H) * fade
        (sw if k % 2 == 0 else sw2)[:] += m
    add(img, hexc("#7fc8ff"), blur(sw, 6) * 1.4 + blur(sw, 30) * 0.8)
    add(img, hexc("#ffcf6e"), blur(sw2, 6) * 1.2 + blur(sw2, 30) * 0.7)
    # 아래 탁자, 책 더미, 펼친 책, 촛불, 수정 구슬
    desk = (yy > 2120).astype(np.float32)
    over(img, hexc("#3a2418") * 1.0, desk)
    over(img, hexc("#5a3a22"), ((yy > 2120) & (yy < 2150)).astype(np.float32))
    wood = noise(H, W, 60, 11, 3)
    img[:] *= (1 - desk * 0.12 * (wood - 0.5) * 2)[..., None]
    for (bx, by, bw, bh, col) in [(40, 2010, 330, 70, "#6b2f3f"), (60, 1950, 300, 64, "#2f4f6b"), (90, 1896, 250, 56, "#5b4a2a"), (1130, 2050, 280, 70, "#4a3a6b")]:
        m = mask_from(lambda d, s, b=(bx, by, bw, bh): d.rounded_rectangle([b[0], b[1], b[0] + b[2], b[1] + b[3]], 10, fill=255), W, H)
        over(img, hexc(col), m)
        over(img, hexc("#e8d6ad"), mask_from(lambda d, s, b=(bx, by, bw, bh): d.rectangle([b[0] + 8, b[1] + 8, b[0] + b[2] - 8, b[1] + 18], fill=255), W, H) * 0.8)
        over(img, hexc("#d9b46a"), mask_from(lambda d, s, b=(bx, by, bw, bh): d.rectangle([b[0] + b[2] * 0.2, b[1], b[0] + b[2] * 0.25, b[1] + b[3]], fill=255), W, H))
    ob = mask_from(lambda d, s: d.polygon([(420, 2200), (720, 2160), (1020, 2200), (980, 2330), (720, 2300), (460, 2330)], fill=255), W, H)
    over(img, hexc("#efe0bd"), ob)
    over(img, hexc("#b89a6a"), mask_from(lambda d, s: d.line([(720, 2165), (720, 2300)], fill=255, width=5), W, H))
    for (cxn, cyn, ch) in [(150, 1890, 170), (250, 1950, 120), (1290, 2045, 150), (1380, 1990, 200)]:
        body = mask_from(lambda d, s, c=(cxn, cyn, ch): d.rounded_rectangle([c[0] - 22, c[1] - c[2], c[0] + 22, c[1]], 8, fill=255), W, H)
        over(img, hexc("#f3e6c8"), body)
        fl = np.exp(-(((xx - cxn) / 10) ** 2 + ((yy - (cyn - ch - 26)) / 22) ** 2))
        over(img, hexc("#fff2b0"), fl)
        add(img, hexc("#ff9a3c"), np.exp(-((xx - cxn) ** 2 + (yy - (cyn - ch - 26)) ** 2) / (2 * 140 ** 2)) * 0.45)
    ox, oy = 1240, 2300  # 수정 구슬
    d2 = (xx - ox) ** 2 + (yy - oy) ** 2
    orb = np.clip((95 ** 2 - d2) / 300, 0, 1)
    over(img, hexc("#6fb8ff"), orb * 0.85)
    add(img, hexc("#bfe6ff"), np.exp(-d2 / (2 * 50 ** 2)) * orb)
    add(img, hexc("#5aa8ff"), np.exp(-d2 / (2 * 220 ** 2)) * 0.5)
    over(img, hexc("#c9a15a"), mask_from(lambda d, s: d.polygon([(1170, 2390), (1310, 2390), (1290, 2440), (1190, 2440)], fill=255), W, H))
    # 떠다니는 빛가루
    for _ in range(160):
        sx, sy = g.uniform(0, W), g.uniform(300, 2400)
        r = g.uniform(1.5, 4.5)
        col = hexc("#ffe7a0") if g.random() < 0.5 else hexc("#a8dcff")
        add(img, col, np.exp(-((xx - sx) ** 2 + (yy - sy) ** 2) / (2 * r * r)) * g.uniform(0.5, 1.0))
    # 가장자리 어둡게(가운데에 눈이 가게)
    vig = ((xx / W - 0.5) ** 2 * 1.6 + (yy / H - 0.47) ** 2 * 1.2)
    img *= np.clip(1.05 - vig * 1.2, 0.35, 1.0)[..., None]
    img = np.clip(img, 0, 1)
    Image.fromarray((img * 255).astype(np.uint8)).save(os.path.join(OUT, "bg.webp"), quality=84, method=5)


def _castle(d, s, cx, ww, base):
    g = rng(9)
    x = cx - ww / 2
    while x < cx + ww / 2:
        w = g.uniform(60, 140)
        h = g.uniform(200, 520)
        d.rectangle([x, base - h, x + w, base], fill=255)
        if g.random() < 0.7:  # 뾰족 지붕
            d.polygon([(x - 8, base - h), (x + w / 2, base - h - g.uniform(90, 200)), (x + w + 8, base - h)], fill=255)
        x += w + g.uniform(-10, 30)


# ------------------------------------------------------------------ 금테

def gold(H, base="#d9a441"):
    d, spec = shade_from_height(H, 2.2)
    c = hexc(base)
    col = c * (0.55 + 0.75 * np.clip(d, 0, 1))[..., None] + spec[..., None] * 0.8
    col = np.minimum(col, 1)
    return col


def frame_tex(w, h, rim, radius, inner_col, seed, dark=False, ornate=True):
    ss = 3
    W, Hh = w * ss, h * ss
    yy, xx = np.mgrid[0:Hh, 0:W].astype(np.float32)
    outer = mask_from(lambda d, s: d.rounded_rectangle([2 * ss, 2 * ss, W - 2 * ss, Hh - 2 * ss], radius * ss, fill=255), W, Hh)
    inner = mask_from(lambda d, s: d.rounded_rectangle([rim * ss, rim * ss, W - rim * ss, Hh - rim * ss], max(4, radius - rim + 4) * ss, fill=255), W, Hh)
    band = np.clip(outer - inner, 0, 1)
    # 금테 높이: 띠 가운데가 볼록 + 안쪽 가는 홈 + 무늬
    dist_in = ndimage.distance_transform_edt(band > 0.5)
    Hg = np.sqrt(np.clip(dist_in / (rim * ss * 0.5), 0, 1)) * 6
    groove = np.abs(dist_in - rim * ss * 0.62) < ss * 1.2
    Hg -= groove * 2.0
    if ornate:  # 모서리 덩굴 무늬(높이로 새긴다)
        orn = np.zeros_like(Hg)
        for (cx, cy) in [(rim * ss * 1.05, rim * ss * 1.05), (W - rim * ss * 1.05, rim * ss * 1.05), (rim * ss * 1.05, Hh - rim * ss * 1.05), (W - rim * ss * 1.05, Hh - rim * ss * 1.05)]:
            r = rim * ss * 0.9
            orn += np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * (r * 0.55) ** 2))) * 5
            ring = np.abs(np.hypot(xx - cx, yy - cy) - r * 0.95) < ss * 2.2
            orn += ring * 2
        Hg = Hg + orn
        corner = np.clip(orn / 4, 0, 1)
    else:
        corner = np.zeros_like(Hg)
    Hg = blur(Hg, ss * 0.8)
    col = gold(Hg)
    img = np.zeros((Hh, W, 4), np.float32)
    # 안쪽: 양피지(또는 어두운 남색)
    if dark:
        ic = hexc("#2a2556") * (0.9 + 0.2 * noise(Hh, W, 40 * ss, seed, 3))[..., None]
    else:
        pn = noise(Hh, W, 50 * ss, seed, 4)
        ic = hexc(inner_col) * (0.92 + 0.12 * pn)[..., None]
        burn = np.clip(1 - ndimage.distance_transform_edt(inner > 0.5) / (rim * ss * 0.9), 0, 1)
        ic = ic * (1 - burn * 0.22)[..., None]
    img[..., :3] = ic * inner[..., None] + col * (1 - inner[..., None])
    a = np.clip(np.maximum(outer, corner * outer), 0, 1)
    img[..., 3] = a
    # 아래 그림자는 Godot가 그린다. 바깥 가는 진한 선
    edge = np.clip(outer - blur((outer > 0.5).astype(np.float32), ss) * 0 - mask_from(lambda d, s: d.rounded_rectangle([3.5 * ss, 3.5 * ss, W - 3.5 * ss, Hh - 3.5 * ss], radius * ss, fill=255), W, Hh), 0, 1)
    img[..., :3] = img[..., :3] * (1 - edge[..., None] * 0.6) + hexc("#5a3510") * edge[..., None] * 0.6
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)
    return im


def gem():
    S = 96
    ss = 3
    N = S * ss
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    c = N / 2
    setting = np.clip((N * 0.46) ** 2 - ((xx - c) ** 2 + (yy - c) ** 2), 0, 1e9) > 0
    Hs = np.sqrt(np.clip(1 - ((xx - c) ** 2 + (yy - c) ** 2) / (N * 0.46) ** 2, 0, 1)) * 30
    col = gold(Hs)
    stone = ((xx - c) ** 2 / (N * 0.3) ** 2 + (yy - c) ** 2 / (N * 0.3) ** 2) < 1
    Hst = np.sqrt(np.clip(1 - ((xx - c) ** 2 + (yy - c) ** 2) / (N * 0.3) ** 2, 0, 1)) * 60
    d, spec = shade_from_height(Hst, 1.5)
    sc = hexc("#3f7fe0") * (0.45 + 0.8 * np.clip(d, 0, 1))[..., None] + spec[..., None] * 1.2
    img = np.zeros((N, N, 4), np.float32)
    img[..., :3] = np.where(stone[..., None], np.minimum(sc, 1), col)
    img[..., 3] = setting
    return Image.fromarray((img * 255).astype(np.uint8), "RGBA").resize((S, S), Image.LANCZOS)


# ------------------------------------------------------------------ 코인

def coin(kind):
    S = 160
    ss = 3
    N = S * ss
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    c = N / 2
    r = np.hypot(xx - c, yy - c)
    R = N * 0.47
    body = r < R
    H = np.zeros((N, N), np.float32)
    H += np.where(body, 4.0, 0)
    rim = (r > R * 0.84) & body
    H += np.where(rim, 6 * np.sqrt(np.clip(1 - np.abs(r - R * 0.92) / (R * 0.08), 0, 1)), 0)
    # 테두리 구슬
    for k in range(36):
        a = k / 36 * math.tau
        bx, by = c + math.cos(a) * R * 0.78, c + math.sin(a) * R * 0.78
        H += 3.5 * np.sqrt(np.clip(1 - ((xx - bx) ** 2 + (yy - by) ** 2) / (R * 0.035) ** 2, 0, 1))
    H += np.where(np.abs(r - R * 0.7) < R * 0.02, 1.6, 0)
    emb = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(emb)
    if kind == "heads":  # 해: 둥근 얼굴과 12갈래 빛
        for k in range(12):
            a = k / 12 * math.tau
            p1 = (c + math.cos(a) * R * 0.3, c + math.sin(a) * R * 0.3)
            p2 = (c + math.cos(a + 0.13) * R * 0.3, c + math.sin(a + 0.13) * R * 0.3)
            tip = (c + math.cos(a + 0.065) * R * 0.6, c + math.sin(a + 0.065) * R * 0.6)
            d.polygon([p1, tip, p2], fill=200)
        d.ellipse([c - R * 0.3, c - R * 0.3, c + R * 0.3, c + R * 0.3], fill=255)
        base, face = "#e0b04a", True
    elif kind == "tails":  # 달과 별
        d.ellipse([c - R * 0.42, c - R * 0.42, c + R * 0.42, c + R * 0.42], fill=255)
        d.ellipse([c - R * 0.22, c - R * 0.5, c + R * 0.55, c + R * 0.3], fill=0)
        for (sx, sy, sr) in [(0.32, -0.25, 0.1), (0.18, 0.28, 0.07), (0.42, 0.12, 0.06)]:
            pts = []
            for i in range(10):
                rr = sr * R * (1 if i % 2 == 0 else 0.42)
                a = -math.pi / 2 + i * math.pi / 5
                pts.append((c + sx * R + math.cos(a) * rr, c + sy * R + math.sin(a) * rr))
            d.polygon(pts, fill=230)
        base, face = "#c9ccd8", False
    else:  # 아직 던지지 않음: 청동, 물음표
        f = ImageFont.truetype(FONT, int(R * 0.95))
        d.text((c, c + R * 0.04), "?", fill=255, font=f, anchor="mm")
        base, face = "#b07a4a", False
    e = np.asarray(emb, np.float32) / 255.0
    e = blur(e, ss * 1.2)
    H += e * 5
    if face:  # 해 얼굴: 눈과 미소(오목)
        for ex in (-0.11, 0.11):
            H -= 1.6 * np.exp(-(((xx - c - ex * R) ** 2 + (yy - c + 0.06 * R) ** 2) / (2 * (R * 0.035) ** 2)))
        sm = np.abs(np.hypot(xx - c, yy - c + 0.05 * R) - R * 0.16) < R * 0.02
        sm &= (yy > c + R * 0.02)
        H -= blur(sm.astype(np.float32), ss) * 1.5
    H = blur(H, ss * 0.7)
    dd, spec = shade_from_height(H, 3.0)
    cb = hexc(base)
    wear = noise(N, N, 30 * ss, 3, 3)
    col = cb * (0.5 + 0.8 * np.clip(dd, 0, 1))[..., None] * (0.92 + 0.12 * wear)[..., None] + spec[..., None] * 0.9
    # 오목한 곳은 세월에 거뭇하게
    cav = np.clip(blur(H, ss * 4) - H, 0, None)
    col *= (1 - np.clip(cav * 0.25, 0, 0.45))[..., None]
    img = np.zeros((N, N, 4), np.float32)
    img[..., :3] = np.minimum(col, 1)
    edge = np.clip((R - r) / ss, 0, 1)
    img[..., 3] = edge
    line = np.clip(1 - np.abs(r - R + ss) / (ss * 1.2), 0, 1)
    img[..., :3] = img[..., :3] * (1 - line[..., None] * 0.7) + hexc("#4a2c10") * line[..., None] * 0.7
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGBA").resize((S, S), Image.LANCZOS)


def impact():
    S = 512
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    c = S / 2
    a = np.arctan2(yy - c, xx - c)
    r = np.hypot(xx - c, yy - c) / (S / 2)
    spikes = 0.5 + 0.5 * np.cos(a * 8) ** 8 + 0.3 * np.cos(a * 16 + 0.3) ** 16
    star = np.clip((spikes * 0.95 - r) * 6, 0, 1)
    core = np.exp(-(r / 0.22) ** 2)
    glow = np.exp(-(r / 0.55) ** 2) * 0.6
    img = np.zeros((S, S, 4), np.float32)
    col = hexc("#ff9a3c") * star[..., None] + hexc("#fff4c2") * np.clip(core * 1.4, 0, 1)[..., None]
    col += hexc("#ffd36e") * glow[..., None]
    img[..., :3] = np.minimum(col / np.maximum(1e-3, np.maximum(star, np.maximum(core, glow)))[..., None], 1)
    img[..., 3] = np.clip(np.maximum(star, np.maximum(core, glow)), 0, 1)
    return Image.fromarray((img * 255).astype(np.uint8), "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    frame_tex(240, 240, 26, 26, "#f1e2bd", 1).save(os.path.join(OUT, "card.png"))
    frame_tex(176, 88, 12, 40, "#fbf0d6", 2, ornate=False).save(os.path.join(OUT, "pill.png"))
    frame_tex(176, 88, 12, 40, "", 3, dark=True, ornate=False).save(os.path.join(OUT, "pill_dark.png"))
    gem().save(os.path.join(OUT, "gem.png"))
    for k in ("heads", "tails", "pending"):
        coin(k).save(os.path.join(OUT, "coin_%s.png" % k))
    fx = os.path.join(ROOT, "assets/art/fx")
    os.makedirs(fx, exist_ok=True)
    impact().save(os.path.join(fx, "impact.png"))
    background()
    print("전투 그림 →", OUT)


if __name__ == "__main__":
    main()
