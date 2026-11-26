"""나무 겹(trees): 숲(T)의 나무와 숲 가장자리 덤불. 게임이 바람에 흔든다.

나무마다 수관 모양·크기·색이 조금씩 다르고, 잎은 여러 겹 덩어리로 그린다. 빛은 왼쪽 위, 그림자는 오른쪽 아래.
지역마다 나무 종류(biomes.json tree.kind): round 둥근 나무, acacia, pine 전나무, palm 야자, cactus 선인장, jungle 열대 나무, dead 마른 나무, crystal 수정.
"""
import numpy as np

from core import TILE, LIGHT, _hash, aa, blob_sdf, hexc, mix, seg_sdf, shade, smooth, sphere_light, vnoise

SH = hexc("#2b2f45")  # 그림자 색(차가운 남보라)


def paint(W, L, X, Y):
    x0, y0 = L.x0, L.y0
    cx0 = max(0, int(x0 // TILE) - 1)
    cy0 = max(0, int(y0 // TILE) - 1)
    cx1 = min(W.w, int((x0 + L.w) // TILE) + 2)
    cy1 = min(W.h, int((y0 + L.h) // TILE) + 3)
    depth = W.edt("forest")
    stamps = []
    rows = W.rows
    for cy in range(cy0, cy1):
        for cx in range(cx0, cx1):
            k = rows[cy, cx]
            h = int(_hash(np.array(cx), np.array(cy), 401))
            hv = float(_hash(np.array(cx), np.array(cy), 403))
            if k == "T":
                d = float(depth[cy, cx])
                n = 2 if hv > 0.2 else 1
                for j in range(n):
                    u = float(_hash(np.array(cx * 3 + j), np.array(cy), 405))
                    v = float(_hash(np.array(cx), np.array(cy * 3 + j), 407))
                    px = (cx + 0.15 + u * 0.7) * TILE
                    py = (cy + 0.45 + v * 0.55) * TILE
                    size = (0.82 + 0.1 * min(d, 3.0)) * (0.85 + 0.35 * float(_hash(np.array(cx + j * 13), np.array(cy), 409)))
                    stamps.append((py, px, "tree", size, cx * 977 + cy * 131 + j))
            elif k == "H" and W.biome_at(cy, cx)["name"] != "snow":
                # 생울타리: 칸마다 덤불 두세 개를 촘촘히(성벽은 바닥 겹의 돌벽)
                for j in range(3):
                    u = float(_hash(np.array(cx * 5 + j), np.array(cy), 415))
                    v = float(_hash(np.array(cx), np.array(cy * 5 + j), 417))
                    stamps.append(((cy + 0.35 + v * 0.55) * TILE, (cx + 0.1 + u * 0.8) * TILE, "hedge", 1.0 + u * 0.3, cx * 53 + cy * 29 + j))
            elif k == "." and hv < 0.2:
                # 숲 가장자리·물가 근처의 작은 덤불
                near = rows[max(0, cy - 1):cy + 2, max(0, cx - 1):cx + 2]
                if (near == "T").any() or (hv < 0.035):
                    px = (cx + 0.2 + hv * 3) * TILE
                    py = (cy + 0.6) * TILE
                    stamps.append((py, px, "bush", 0.55 + hv, cx * 31 + cy * 17))
    # 마을의 큰 나무(사라지지 않는 지형지물)
    for bd in W.buildings():
        if bd["id"] == "tree":
            rc = bd["rect"]
            stamps.append(((rc[1] + rc[3]) * TILE - 4, (rc[0] + rc[2] / 2) * TILE, "big", 2.9, 7))
    stamps.sort(key=lambda s: s[0])
    for py, px, kind, size, seed in stamps:
        b = W.biome_at(int(py // TILE), int(px // TILE))
        lx, ly = int(px - x0), int(py - y0)
        if lx < -200 or ly < -60 or lx > L.w + 200 or ly > L.h + 260:
            continue
        cols = [hexc(c) for c in b["tree"]["colors"]]
        tk = b["tree"]["kind"]
        g = np.random.default_rng(seed & 0xFFFFFFF)
        if kind == "hedge":
            _canopy(L, lx, ly, g, [hexc(b["grass"] or "#8fbf7a")], 22 * size, trunk=False, name="hedge_" + b["name"])
            continue
        if kind == "bush":
            if tk in ("cactus", "dead", "crystal"):
                continue
            _canopy(L, lx, ly, g, cols, 15 * size, trunk=False, name=b["name"])
        elif kind == "big":
            _canopy(L, lx, ly, g, [hexc("#5f9f67"), hexc("#4f8f57"), hexc("#6fae6a")], 26 * size, trunk=True, name="meadow", lobes=12)
        elif tk == "pine":
            _pine(L, lx, ly, g, cols, size, snow=b["name"] == "snow")
        elif tk == "palm":
            _palm(L, lx, ly, g, cols, size)
        elif tk == "cactus":
            _cactus(L, lx, ly, g, cols, size)
        elif tk == "dead":
            _dead(L, lx, ly, g, cols, size)
        elif tk == "crystal":
            _crystal(L, lx, ly, g, cols, size)
        elif tk == "acacia":
            _canopy(L, lx, ly, g, cols, 30 * size, trunk=True, name=b["name"], flat=True)
        elif tk == "jungle":
            _jungle(L, lx, ly, g, cols, size)
        else:
            _canopy(L, lx, ly, g, cols, 30 * size, trunk=True, name=b["name"])


def _shadow(L, lx, ly, rx, ry, a=0.26, off=(9, 2)):
    S = int(max(rx, ry) + 6)
    yy, xx = np.mgrid[0:2 * S, 0:2 * S].astype(np.float32)
    d = np.hypot((xx - S) / rx, (yy - S) / ry) - 1
    L.over(SH, aa(d * min(rx, ry), 3.0) * a, ly - S + off[1], lx - S + off[0])


def _tones(c, l, tex):
    """빛(-1~1)을 동화풍 네 단계 색으로(경계는 부드럽게), 잎결을 더한다."""
    dark = shade(c, -0.5)
    mid = shade(c, -0.14)
    light = shade(c, 0.1)
    hi = shade(c, 0.26)
    l = l + (tex - 0.5) * 0.4
    out = mix(dark, mid, smooth(-0.35, -0.05, l))
    out = mix(out, light, smooth(0.35, 0.5, l))
    out = mix(out, hi, smooth(0.72, 0.8, l))
    return out


def _canopy(L, lx, ly, g, cols, R, trunk=True, name="", flat=False, lobes=None):
    """둥근 나무·덤불: 크고 작은 잎 덩어리를 뒤에서 앞으로 겹친다. 각 덩어리는 손그림 같은 울퉁불퉁한 테두리."""
    R = float(R)
    col = cols[int(g.integers(len(cols)))]
    col = shade(col, g.uniform(-0.06, 0.06))
    sy = 0.55 if flat else 1.0
    th = R * (1.15 if trunk else 0.35) * (1.25 if flat else 1.0)  # 수관 가운데에서 밑동까지
    S = int(R * 1.9 + 8)
    H = int(S * 2 + th)
    yy, xx = np.mgrid[0:H, 0:2 * S].astype(np.float32)
    ccx, ccy = S, S  # 수관 가운데
    base_y = ccy + th
    _shadow(L, lx, ly, R * (1.15 if not flat else 1.4), R * 0.42, 0.28 if trunk else 0.2)
    ox, oy = lx - ccx, ly - int(base_y)
    if trunk:
        d, t = seg_sdf(xx, yy, ccx, base_y, ccx + g.uniform(-2, 2), ccy + R * 0.25)
        tw = R * (0.16 if not flat else 0.1)
        ta = aa(d - tw * (1.15 - 0.3 * t), 0.8)
        tcol = shade(hexc("#86603e"), np.clip((ccx - xx) / (tw + 1e-3), -1, 1) * 0.22)
        L.over(tcol, ta, oy, ox)
        if flat:  # 아카시아: 갈라진 가지
            for s in (-1, 1):
                d2, t2 = seg_sdf(xx, yy, ccx, ccy + R * 0.55, ccx + s * R * 0.55, ccy + R * 0.05)
                L.over(hexc("#7a5636"), aa(d2 - tw * 0.6 * (1.1 - 0.5 * t2), 0.8), oy, ox)
    n = int(lobes or g.integers(6, 10))
    blobs = []
    for i in range(n):
        ang = g.uniform(0, 6.283)
        rr = R * g.uniform(0.15, 0.62) * (1.3 if flat else 1.0)
        bx = ccx + np.cos(ang) * rr
        by = ccy + np.sin(ang) * rr * sy * 0.9
        br = R * g.uniform(0.42, 0.62)
        blobs.append((by, bx, br, int(g.integers(1 << 20))))
    blobs.append((ccy + 0.5, ccx, R * 0.62, int(g.integers(1 << 20))))
    blobs.sort()
    tex = vnoise(xx + lx * 3.1, yy + ly * 1.7, 3.2, 411)
    tex2 = vnoise(xx + lx, yy + ly, 7, 413)
    for by, bx, br, bs in blobs:
        dx = xx - bx
        dy = (yy - by) / sy
        sdf = blob_sdf(dx, dy, br, (bs % 997) / 997.0, wob=0.13, lobes=7 + bs % 4) * (sy if flat else 1)
        a = aa(sdf, 0.9)
        if a.max() <= 0:
            continue
        l = 0.55 * sphere_light(xx - ccx, (yy - ccy) / sy, R * 1.25) + 0.5 * sphere_light(dx, dy, br * 1.05)
        l -= smooth(R * 0.1, R * 0.9, yy - ccy) * 0.25  # 수관 아래쪽은 그늘
        c = _tones(col, l, tex * 0.6 + tex2 * 0.4)
        rim = smooth(-2.6, -0.4, sdf)  # 덩어리 테두리: 잎 그늘이 겹친 선
        c = mix(c, shade(col, -0.5), rim[..., None] * 0.55)
        L.over(c, a, oy, ox)
    if name == "hedge_blossom":
        _dots(L, xx, yy, ccx, ccy, R, g, hexc("#f7c6dc"), oy, ox, 0.6 * R)
    if name == "blossom" or (name == "meadow" and g.random() < 0.25):
        _dots(L, xx, yy, ccx, ccy, R, g, hexc("#ffffff") if name == "blossom" else hexc("#ffd6e4"), oy, ox, 0.55 * R)
    if name == "autumn" and g.random() < 0.5:
        _dots(L, xx, yy, ccx, ccy + R * 0.9, R * 1.4, g, shade(col, 0.1), oy, ox, 0.25 * R)


def _dots(L, xx, yy, cx, cy, R, g, c, oy, ox, n):
    a = np.zeros_like(xx)
    for k in range(int(n)):
        ang = g.uniform(0, 6.283)
        rr = R * np.sqrt(g.uniform(0, 0.8))
        px, py = cx + np.cos(ang) * rr, cy + np.sin(ang) * rr
        if py > cy + R * 0.2 and rr < R * 0.8:
            continue
        a = np.maximum(a, aa(np.hypot(xx - px, yy - py) - g.uniform(1.1, 2.0), 0.7))
    L.over(c, a, oy, ox)


def _pine(L, lx, ly, g, cols, size, snow=False):
    col = shade(cols[int(g.integers(len(cols)))], g.uniform(-0.05, 0.05))
    h = 84 * size
    w = 34 * size
    S = int(w + 10)
    H = int(h + 20)
    yy, xx = np.mgrid[0:H, 0:2 * S].astype(np.float32)
    cx, base = S, H - 6
    _shadow(L, lx, ly, w * 0.95, w * 0.38, 0.3)
    ox, oy = lx - cx, ly - base
    d, t = seg_sdf(xx, yy, cx, base, cx, base - 14 * size)
    L.over(hexc("#7a5636"), aa(d - 3.2 * size, 0.8), oy, ox)
    tiers = 4
    for j in range(tiers):
        tb = base - 10 * size - j * h * 0.2  # 층의 아랫단
        tt = tb - h * 0.42  # 층의 꼭대기
        tw = w * (1.0 - j * 0.2)
        rel = np.clip((yy - tt) / (tb - tt), 0, 1)
        half = tw * rel * (1 + 0.1 * np.sin(yy * 0.9 + j * 2 + lx))
        wav = 3.2 * size * np.sin((xx - cx) / (4.5 * size) + j)  # 들쭉날쭉한 아랫단
        inside = (yy > tt) & (yy < tb + wav) & (np.abs(xx - cx) < half)
        sd = np.minimum(half - np.abs(xx - cx), tb + wav - yy)
        a = aa(-sd, 0.9) * (yy > tt)
        side = np.clip((cx - xx) / (tw + 1e-3), -1, 1)  # 왼쪽 밝게
        l = side * 0.6 - rel * 0.35 + 0.15
        tex = vnoise(xx * 0.6 + lx, yy * 1.6 + ly, 3, 421 + j)
        c = _tones(col, l, tex)
        c = mix(c, shade(col, -0.5), smooth(-2.2, -0.2, -sd)[..., None] * 0.5)
        if snow:
            cap = (rel < 0.45) | ((side > 0.1) & (tex > 0.55))
            c = np.where(cap[..., None], mix(hexc("#f4f8fd"), hexc("#cfdcec"), smooth(0.3, -0.6, side)), c)
        L.over(c, a, oy, ox)


def _palm(L, lx, ly, g, cols, size):
    col = shade(cols[int(g.integers(len(cols)))], g.uniform(-0.05, 0.05))
    hgt = 54 * size
    S = int(46 * size + 10)
    H = int(hgt + 50 * size)
    yy, xx = np.mgrid[0:H, 0:2 * S].astype(np.float32)
    bx, base = S, H - 6
    bend = g.uniform(-14, 14) * size
    top = (bx + bend, base - hgt)
    _shadow(L, lx + int(bend * 0.6), ly, 34 * size, 13 * size, 0.24)
    ox, oy = lx - bx, ly - base
    # 휜 줄기, 마디 무늬
    ta = np.zeros_like(xx)
    tl = np.zeros_like(xx)
    for k in range(8):
        t0, t1 = k / 8, (k + 1) / 8
        p0 = (bx + bend * t0 * t0, base - hgt * t0)
        p1 = (bx + bend * t1 * t1, base - hgt * t1)
        d, t = seg_sdf(xx, yy, p0[0], p0[1], p1[0], p1[1])
        a = aa(d - (4.2 - 1.6 * t1) * size, 0.8)
        ta = np.maximum(ta, a)
    ring = 0.5 + 0.5 * np.sin(yy / (3.2 * size))
    tcol = shade(hexc("#b48a58"), (ring - 0.5) * 0.3 + np.clip((top[0] - xx) / 8, -1, 1) * 0.1)
    L.over(tcol, ta, oy, ox)
    # 잎: 꼭대기에서 휘어지며 처지는 긴 잎
    n = int(g.integers(6, 9))
    for i in range(n):
        ang = -np.pi / 2 + (i - (n - 1) / 2) * (2.4 / n) * 1.6 + g.uniform(-0.15, 0.15)
        ln = g.uniform(30, 40) * size
        a = np.zeros_like(xx)
        tb = np.zeros_like(xx)
        for k in range(7):
            s0, s1 = k / 7, (k + 1) / 7
            def pt(s):
                return (top[0] + np.cos(ang) * ln * s, top[1] + np.sin(ang) * ln * s + (ln * 0.55) * s * s)
            p0, p1 = pt(s0), pt(s1)
            d, t = seg_sdf(xx, yy, p0[0], p0[1], p1[0], p1[1])
            w = (5.5 * (1 - s1) + 1.2) * size
            ak = aa(d - w, 0.8)
            tb = np.where(ak > a, s0 + t / 7, tb)
            a = np.maximum(a, ak)
        lit = 0.3 if np.cos(ang) < 0 else -0.15
        c = _tones(col, lit - tb * 0.35, vnoise(xx + lx, yy + ly, 2.5, 431 + i))
        L.over(c, a, oy, ox)
    L.over(hexc("#7a5636"), aa(np.hypot(xx - top[0], yy - top[1] - 2) - 4 * size, 0.8), oy, ox)


def _cactus(L, lx, ly, g, cols, size):
    col = shade(cols[int(g.integers(len(cols)))], g.uniform(-0.05, 0.05))
    hgt = g.uniform(34, 46) * size
    S = int(26 * size + 8)
    H = int(hgt + 16)
    yy, xx = np.mgrid[0:H, 0:2 * S].astype(np.float32)
    bx, base = S, H - 4
    _shadow(L, lx, ly, 16 * size, 6 * size, 0.28)
    ox, oy = lx - bx, ly - base
    w = 6.5 * size
    parts = [(bx, base, bx, base - hgt, w)]
    for s in (-1, 1):
        if g.random() < 0.75:
            ay = base - hgt * g.uniform(0.35, 0.6)
            ax = bx + s * 13 * size
            parts.append((bx, ay, ax, ay, w * 0.75))
            parts.append((ax, ay, ax, ay - hgt * g.uniform(0.25, 0.4), w * 0.75))
    for x1, y1, x2, y2, r in parts:
        d, t = seg_sdf(xx, yy, x1, y1, x2, y2)
        a = aa(d - r, 0.8)
        axis_x = x1 + (x2 - x1) * t
        side = np.clip((axis_x - xx) / r, -1, 1)
        rib = 0.5 + 0.5 * np.cos(side * 5.0)
        c = _tones(col, side * 0.7 + 0.05, rib)
        c = mix(c, shade(col, -0.45), smooth(-2.0, -0.2, d - r)[..., None] * 0.5)
        L.over(c, a, oy, ox)
    if g.random() < 0.4:
        L.over(hexc("#f2a7c8"), aa(np.hypot(xx - bx, yy - (base - hgt - 2)) - 3.5 * size, 0.8), oy, ox)


def _dead(L, lx, ly, g, cols, size):
    col = cols[int(g.integers(len(cols)))]
    S = int(30 * size + 8)
    H = int(50 * size + 12)
    yy, xx = np.mgrid[0:H, 0:2 * S].astype(np.float32)
    bx, base = S, H - 4
    _shadow(L, lx, ly, 18 * size, 6 * size, 0.25)
    ox, oy = lx - bx, ly - base
    segs = [(bx, base, bx + g.uniform(-3, 3), base - 40 * size, 4.5 * size)]
    for k in range(4):
        sy = base - (16 + k * 7) * size
        s = 1 if k % 2 else -1
        segs.append((bx, sy, bx + s * g.uniform(10, 18) * size, sy - g.uniform(8, 16) * size, 2.4 * size))
    a = np.zeros_like(xx)
    for x1, y1, x2, y2, r in segs:
        d, t = seg_sdf(xx, yy, x1, y1, x2, y2)
        a = np.maximum(a, aa(d - r * (1 - 0.5 * t), 0.8))
    c = shade(col, np.clip((bx - xx) / 10, -1, 1) * 0.2 + (vnoise(xx, yy * 0.3, 2, 441) - 0.5) * 0.2)
    L.over(c, a, oy, ox)
    if g.random() < 0.5:  # 가지 끝의 불씨
        x2, y2 = segs[-1][2], segs[-1][3]
        L.over(hexc("#ff9a4a"), aa(np.hypot(xx - x2, yy - y2) - 2.6, 0.8), oy, ox)


def _crystal(L, lx, ly, g, cols, size):
    S = int(26 * size + 10)
    H = int(56 * size + 14)
    yy, xx = np.mgrid[0:H, 0:2 * S].astype(np.float32)
    bx, base = S, H - 6
    _shadow(L, lx, ly, 20 * size, 7 * size, 0.24)
    ox, oy = lx - bx, ly - base
    # 은은한 빛무리
    L.over(hexc("#ffffff"), aa(np.hypot(xx - bx, (yy - base + 20 * size) * 0.8) - 22 * size, 10) * 0.18, oy, ox)
    n = int(g.integers(3, 6))
    items = sorted([(g.uniform(-0.5, 0.5), g.uniform(0.6, 1.0), int(g.integers(len(cols)))) for _ in range(n)], key=lambda t: -t[1])
    for lean, hf, ci in items:
        c = cols[ci]
        hgt = 46 * size * hf
        wd = 7 * size * (0.8 + 0.4 * hf)
        ang = lean * 0.6
        ca, sa = np.cos(ang), np.sin(ang)
        u = (xx - bx - lean * 10 * size) * ca + (yy - base) * sa
        v = -(xx - bx - lean * 10 * size) * sa + (yy - base) * ca  # 위가 음수
        tipf = np.clip((-v - hgt * 0.72) / (hgt * 0.28), 0, 1)
        half = wd * (1 - tipf)
        inside_sd = np.minimum(half - np.abs(u), np.minimum(-v, hgt + v))
        a = aa(-inside_sd, 0.8)
        facet = np.where(u < -wd * 0.15, 0.35, np.where(u < wd * 0.35, 0.05, -0.3))
        col = shade(c, facet + tipf * 0.15)
        col = mix(col, hexc("#ffffff"), smooth(1.2, 0.0, np.abs(u + wd * 0.15))[..., None] * 0.35)
        L.over(col, a, oy, ox)


def _jungle(L, lx, ly, g, cols, size):
    col = shade(cols[int(g.integers(len(cols)))], g.uniform(-0.05, 0.05))
    R = 32 * size
    # 큰 잎이 수관 밖으로 비죽 나온다
    S = int(R * 2.2 + 8)
    H = int(S * 2 + R)
    yy, xx = np.mgrid[0:H, 0:2 * S].astype(np.float32)
    ccx, ccy = S, S
    base = ccy + R * 1.2
    ox, oy = lx - ccx, ly - int(base)
    for i in range(int(g.integers(4, 7))):
        ang = g.uniform(0, 6.283)
        ln = R * g.uniform(1.0, 1.35)
        ex, ey = ccx + np.cos(ang) * ln, ccy + np.sin(ang) * ln * 0.8
        u_dir = np.array([np.cos(ang), np.sin(ang) * 0.8])
        u_dir = u_dir / np.linalg.norm(u_dir)
        d, t = seg_sdf(xx, yy, ccx, ccy, ex, ey)
        w = R * 0.32 * np.sin(np.clip(t, 0, 1) * np.pi) + 0.5
        a = aa(d - w, 0.8) * (t > 0.25)
        side = (xx - ccx) * -u_dir[1] + (yy - ccy) * u_dir[0]
        c = _tones(shade(col, 0.05), np.where(side < 0, 0.3, -0.2), vnoise(xx + lx, yy + ly, 3, 451 + i))
        c = mix(c, shade(col, -0.5), smooth(1.2, 0, np.abs(side))[..., None] * 0.5 * (t > 0.3)[..., None])
        L.over(c, a, oy, ox)
    _canopy(L, lx, ly, g, [col], R, trunk=True, name="jungle")
    if g.random() < 0.6:  # 늘어진 덩굴
        a = np.zeros_like(xx)
        for k in range(2):
            vx = ccx + g.uniform(-R * 0.6, R * 0.6)
            d, t = seg_sdf(xx, yy, vx, ccy + R * 0.3, vx + g.uniform(-3, 3), ccy + R * g.uniform(0.9, 1.3))
            a = np.maximum(a, aa(d - 1.2, 0.6))
        L.over(hexc("#4f8a4a"), a, oy, ox)
