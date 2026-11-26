"""풀 겹(grass): 풀포기, 꽃, 자갈, 낙엽, 마른 덤불, 눈 속 바위, 불씨 바위. 게임이 바람에 흔든다.

경계를 자연스럽게 섞는 일을 맡는다: 길·물가·숲·산자락 가장자리에 풀과 자갈이 더 많이 난다(사용자 의견).
"""
import numpy as np

from core import TILE, LIGHT, _hash, aa, fbm, hexc, mix, sample, seg_sdf, shade, smooth

SPACING = 16


def _fields(W):
    return {
        "water": W.field("water", 0.62), "path": W.field("path", 0.62), "plaza": W.field("plaza", 0.55),
        "stone": W.field("stone", 0.5), "farm": W.field("farm", 0.45), "mtn": W.field("mtn", 0.6),
        "cliff": W.field("cliff", 0.55), "wall": W.field("wall", 0.5), "forest": W.field("forest", 0.9),
        "ice": W.field("ice", 0.5), "fence": W.field("fence", 0.3),
    }


def paint(W, L, X, Y):
    F = _fields(W)
    x0, y0 = L.x0, L.y0
    gx = np.arange(np.floor(x0 / SPACING), np.ceil((x0 + L.w) / SPACING))
    gy = np.arange(np.floor(y0 / SPACING), np.ceil((y0 + L.h) / SPACING))
    GX, GY = np.meshgrid(gx, gy)
    GX = GX.ravel().astype(np.int64)
    GY = GY.ravel().astype(np.int64)
    px = (GX + _hash(GX, GY, 301)) * SPACING
    py = (GY + _hash(GX, GY, 303)) * SPACING
    pxf = px.astype(np.float32)
    pyf = py.astype(np.float32)
    v = {k: sample(f, pxf, pyf) for k, f in F.items()}
    patch = fbm(pxf, pyf, 160, 305, 3)
    meadow = fbm(pxf, pyf, 90, 307, 3)
    r = _hash(GX, GY, 309)
    r2 = _hash(GX, GY, 311)
    # 놓일 수 없는 곳(물, 길 가운데, 광장, 산·절벽·성벽 안)
    blocked = (v["water"] > 0.38) | (v["path"] > 0.58) | (v["plaza"] > 0.42) | (v["stone"] > 0.45) | (v["farm"] > 0.4) \
        | (v["mtn"] > 0.52) | (v["cliff"] > 0.5) | (v["wall"] > 0.42) | (v["ice"] > 0.45) | (v["fence"] > 0.35)
    # 경계 가까이 더 많이(길·물가·숲·산자락)
    edge = np.maximum.reduce([smooth(0.15, 0.5, v["path"]), smooth(0.1, 0.36, v["water"]), smooth(0.2, 0.5, v["forest"]) * 0.8,
                              smooth(0.2, 0.5, v["mtn"]), smooth(0.2, 0.48, v["cliff"]), smooth(0.2, 0.42, v["plaza"]) * 0.6])
    dens = 0.06 + 0.3 * smooth(0.5, 0.8, patch) + 0.55 * edge
    order = np.argsort(py)  # 위에서 아래로(아래 것이 앞)
    for i in order:
        if blocked[i] or r[i] > dens[i]:
            continue
        cy = int(min(max(py[i] // TILE, 0), W.h - 1))
        cx = int(min(max(px[i] // TILE, 0), W.w - 1))
        if W.rows[cy, cx] in "~wbh,so":
            continue
        b = W.biome_at(cy, cx)
        name = b["name"]
        lx = int(px[i] - x0)
        ly = int(py[i] - y0)
        seed = int(GX[i] * 7919 + GY[i] * 104729) & 0xFFFFFF
        pick = r2[i]
        near_path = v["path"][i] > 0.25
        if name == "lava":
            if pick < 0.5:
                _rock(L, lx, ly, seed, hexc("#5b4a46"), glow=pick < 0.18)
            continue
        if name == "snow":
            if pick < 0.35:
                _rock(L, lx, ly, seed, hexc("#9aa3ad"), snowcap=True)
            elif pick < 0.6:
                _tuft(L, lx, ly, seed, hexc("#8c8a74"), n=3, length=9, dry=True)
            continue
        if name == "desert":
            if pick < 0.3 or near_path:
                _rock(L, lx, ly, seed, hexc("#c4a074"))
            elif pick < 0.55:
                _tuft(L, lx, ly, seed, hexc("#b59a5c"), n=4, length=11, dry=True)
            elif pick < 0.6:
                _flowers(L, lx, ly, seed, [hexc("#f2b5d4")], 1)
            continue
        gc = hexc(b["grass"] or "#8fbf7a")
        fl = [hexc(c) for c in b.get("flowers", [])] or [hexc("#fff1a8")]
        if near_path and pick < 0.35:
            _rock(L, lx, ly, seed, hexc("#a49a8c"))
        elif meadow[i] > 0.6 and pick < 0.45 and v["forest"][i] < 0.3:
            _flowers(L, lx, ly, seed, fl, 2 + int(pick * 6))
        elif name == "autumn" and pick < 0.5:
            _leaves(L, lx, ly, seed, [hexc(c) for c in b["tree"]["colors"]])
        elif name == "twilight" and pick < 0.12:
            _shard(L, lx, ly, seed, [hexc(c) for c in b["tree"]["colors"]])
        else:
            tall = 1.4 if b.get("deco") == "tallgrass" else (1.25 if b.get("deco") == "ferns" else 1.0)
            _tuft(L, lx, ly, seed, gc, n=4 + int(pick * 4), length=int(10 * tall + pick * 6))


def _rng(seed):
    return np.random.default_rng(seed)


def _tuft(L, lx, ly, seed, gc, n=5, length=12, dry=False):
    g = _rng(seed)
    S = length + 10
    yy, xx = np.mgrid[0:S + 4, 0:2 * S].astype(np.float32)
    bx, by = S, S
    a = np.zeros_like(xx)
    t_best = np.zeros_like(xx)
    lit = np.zeros_like(xx)
    for k in range(n):
        off = (k - (n - 1) / 2) * 2.2 + g.uniform(-1, 1)
        lean = off * 0.9 + g.uniform(-3, 3)
        ln = length * g.uniform(0.7, 1.15)
        d, t = seg_sdf(xx, yy, bx + off, by, bx + off + lean, by - ln)
        r = 1.6 * (1 - t) + 0.35
        ak = aa(d - r, 0.8)
        newer = ak > a
        t_best = np.where(newer, t, t_best)
        lit = np.where(newer, 1.0 if lean < 0 else 0.0, lit)
        a = np.maximum(a, ak)
    base = shade(gc, -0.22)
    tip = shade(gc, 0.12 if not dry else 0.06)
    col = mix(base, tip, t_best)
    col = shade(col, lit * 0.12)
    # 포기 밑 그림자
    sh = aa(np.hypot((xx - bx - 2) / 1.0, (yy - by - 1) * 2.2) - length * 0.45, 2.0) * 0.18
    L.over(hexc("#2f3a2c"), sh, ly - by, lx - bx)
    L.over(col, a, ly - by, lx - bx)


def _flowers(L, lx, ly, seed, colors, n):
    g = _rng(seed)
    S = 22
    yy, xx = np.mgrid[0:S * 2, 0:S * 2].astype(np.float32)
    for k in range(n):
        cx = S + g.uniform(-9, 9)
        cy = S + g.uniform(-7, 7)
        c = colors[int(g.integers(len(colors)))]
        rad = g.uniform(2.0, 2.8)
        a = np.zeros_like(xx)
        lt = np.zeros_like(xx)
        rot = g.uniform(0, 6.28)
        for p in range(5):
            ang = rot + p * 1.2566
            pxp = cx + np.cos(ang) * rad * 1.15
            pyp = cy + np.sin(ang) * rad * 0.9
            ap = aa(np.hypot(xx - pxp, yy - pyp) - rad, 0.8)
            a = np.maximum(a, ap)
            lt = np.maximum(lt, ap * (1.0 if np.cos(ang) * LIGHT[0] + np.sin(ang) * LIGHT[1] > 0 else 0.4))
        col = shade(c, lt * 0.12 - 0.06)
        L.over(hexc("#2f3a2c"), aa(np.hypot(xx - cx - 2, (yy - cy - 2) * 1.5) - rad * 1.8, 1.5) * 0.15, ly - S, lx - S)
        L.over(col, a, ly - S, lx - S)
        L.over(hexc("#f5c542"), aa(np.hypot(xx - cx, yy - cy) - rad * 0.55, 0.7), ly - S, lx - S)


def _rock(L, lx, ly, seed, c, snowcap=False, glow=False):
    g = _rng(seed)
    rx = g.uniform(3.5, 7.5)
    ry = rx * g.uniform(0.55, 0.75)
    S = 14
    yy, xx = np.mgrid[0:S * 2, 0:S * 2].astype(np.float32)
    dx = (xx - S) / rx
    dy = (yy - S) / ry
    ang = np.arctan2(dy, dx)
    d = np.hypot(dx, dy) - (1 + 0.12 * np.sin(ang * 3 + seed))
    a = aa(d * rx, 0.9)
    nl = np.clip(-(dx * 0.6 + dy * 0.8), -1, 1)
    col = shade(c, nl * 0.22 + g.uniform(-0.06, 0.06))
    if snowcap:
        cap = smooth(-0.1, 0.3, -dy - 0.1)
        col = mix(col, hexc("#f7fafd"), cap)
    L.over(hexc("#2e2a3a"), aa((np.hypot((xx - S - 2.5) / rx, (yy - S - 2.5) / ry) - 1.05) * rx, 1.6) * 0.22, ly - S, lx - S)
    L.over(col, a, ly - S, lx - S)
    if glow:
        L.over(hexc("#ff9a4a"), aa(np.hypot(xx - S - rx * 0.9, yy - S + 1) - 1.8, 0.8) * 0.9, ly - S, lx - S)


def _leaves(L, lx, ly, seed, colors):
    g = _rng(seed)
    S = 14
    yy, xx = np.mgrid[0:S * 2, 0:S * 2].astype(np.float32)
    for k in range(int(g.integers(2, 5))):
        cx, cy = S + g.uniform(-8, 8), S + g.uniform(-6, 6)
        ang = g.uniform(0, 3.14)
        ca, sa = np.cos(ang), np.sin(ang)
        u = (xx - cx) * ca + (yy - cy) * sa
        v = -(xx - cx) * sa + (yy - cy) * ca
        a = aa((np.hypot(u / 3.4, v / 1.8) - 1) * 2, 0.8)
        c = colors[int(g.integers(len(colors)))]
        L.over(shade(c, g.uniform(-0.1, 0.12)), a, ly - S, lx - S)


def _shard(L, lx, ly, seed, colors):
    g = _rng(seed)
    S = 14
    yy, xx = np.mgrid[0:S * 2, 0:S * 2].astype(np.float32)
    c = colors[int(g.integers(len(colors)))]
    h = g.uniform(7, 11)
    # 끝이 뾰족한 작은 수정(왼쪽 면 밝게)
    dx = xx - S
    dy = yy - S
    inside = (dy < 2) & (dy > -h) & (np.abs(dx) < 3.2 * (1 - np.clip((-dy - h * 0.55) / (h * 0.45), 0, 1)))
    a = inside.astype(np.float32)
    col = np.where((dx < 0)[..., None], shade(c, 0.25), shade(c, -0.12))
    L.over(hexc("#2e2a3a"), aa(np.hypot((dx - 2) / 4, (dy - 2) / 2) - 1, 1.5) * 0.2, ly - S, lx - S)
    L.over(col, a, ly - S, lx - S)
