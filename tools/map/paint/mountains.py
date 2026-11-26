"""산 겹(mtn): 산(^)과 동굴 입구(c).

산은 세모를 겹친 것이 아니라 높이 판(산 무리 안쪽일수록 높게 + 능선 잡음)에 왼쪽 위 빛을 비춰 그린다.
능선은 불규칙하고, 아래 산자락은 풀빛으로 섞이며, 오른쪽 아래로 그림자를 드리운다.
꼭대기: 눈(snow), 사막은 층진 평평한 바위 언덕(메사), 용암 지대는 빛나는 분화구.
"""
import numpy as np
from scipy import ndimage

from core import LIGHT, SHADOW, TILE, aa, bbox, fbm, hash1, hexc, mix, organic, ridged, sample, shade, smooth, vnoise, voronoi, warp

SH = hexc("#2b2f45")


def paint(W, L, X, Y):
    f = sample(W.field("mtn", 0.6), X, Y)
    bb = bbox((f > 0.15).astype(np.float32), 40)
    if not bb:
        return
    Xs, Ys, f = X[bb], Y[bb], f[bb]
    oy, ox = bb[0].start, bb[1].start
    a, v = organic(f, Xs, Ys, 501, amp=0.2, scale=40, edge=0.03)
    cap = _cap_w(W, Xs, Ys)
    m0 = sample(W.color("mountain", 0), Xs, Ys)
    m1 = sample(W.color("mountain", 1), Xs, Ys)
    # 산자락 바닥: 자갈 비탈(봉우리 사이로 보이는 곳). 칸 경계가 아니라 불규칙한 선
    tex = fbm(Xs, Ys, 16, 509, 3)
    d1, gap, rid = voronoi(*warp(Xs, Ys, 30, 5, 511), 13, 513)
    scree = mix(m1, shade(m0, 0.05), smooth(0.25, 0.65, tex))
    scree = shade(scree, (rid - 0.5) * 0.16 - smooth(2.0, 0.0, gap) * 0.18)
    gc = sample(W.color("grass", 0), Xs, Ys)
    green = smooth(0.62, 0.5, v) * cap["green"]
    scree = mix(scree, shade(gc, -0.12), green * 0.7)
    rim = smooth(0.5, 0.53, v) * smooth(0.58, 0.52, v)
    scree = mix(scree, shade(m1, -0.5), rim * 0.6)
    sh = ndimage.shift(a, (SHADOW[1], SHADOW[0]), order=1, mode="constant")
    L.over(SH, ndimage.gaussian_filter(sh, 4) * 0.3 * (1 - a), oy, ox)
    L.over(scree, a, oy, ox)
    _peaks(W, L)
    _caves(W, L)


def _peaks(W, L):
    """봉우리: 손으로 그린 듯 들쭉날쭉한 능선, 왼쪽 빛면·오른쪽 그늘면, 골짜기 주름, 꼭대기 눈. 뒤에서 앞으로 겹쳐 산맥이 된다."""
    x0, y0 = L.x0, L.y0
    cx0, cy0 = max(0, int(x0 // TILE) - 3), max(0, int(y0 // TILE) - 1)
    cx1, cy1 = min(W.w, int((x0 + L.w) // TILE) + 3), min(W.h, int((y0 + L.h) // TILE) + 5)
    depth = W.edt("mtn")
    items = []
    for cy in range(cy0, cy1):
        for cx in range(cx0, cx1):
            if W.rows[cy, cx] != "^":
                continue
            d = float(depth[cy, cx])
            hv = hash1(cx, cy, 531)
            if d >= 2.5 and (cx + cy) % 2 == 1 and hv < 0.7:
                continue  # 안쪽은 큰 봉우리가 덮는다
            size = min(d, 5.0)
            w = TILE * (1.7 + 0.55 * size) * (0.85 + 0.3 * hash1(cx, cy, 533))
            h = TILE * (0.6 + 0.36 * size) * (0.85 + 0.3 * hash1(cx, cy, 535))
            bx = (cx + 0.5) * TILE + (hash1(cx, cy, 537) - 0.5) * 30
            by = (cy + 1.0) * TILE + (hash1(cx, cy, 539) - 0.5) * 10
            items.append((by, bx, w, h, cx * 7919 + cy * 131))
    items.sort()
    for by, bx, w, h, seed in items:
        b = W.biome_at(int(by // TILE) - 1, int(bx // TILE))
        _peak(L, bx - x0, by - y0, w, h, seed, b)


def _peak(L, bx, by, w, h, seed, b):
    g = np.random.default_rng(seed & 0xFFFFFFF)
    m0, m1 = hexc(b["mountain"][0]), hexc(b["mountain"][1])
    jit = g.uniform(-0.07, 0.07)
    m0, m1 = shade(m0, jit), shade(m1, jit)
    cap = b["mountain"][2]
    desert = b["name"] == "desert"
    PW = int(w / 2 + 12)
    PH = int(h + 24)
    yy, xx = np.mgrid[0:PH, 0:2 * PW].astype(np.float32)
    lx = xx - PW  # 밑동 가운데 기준
    ly = yy - (PH - 8)  # 위가 음수
    u = lx / (w / 2)  # -1~1
    apex = g.uniform(-0.25, 0.25)
    # 능선: 꼭대기에서 양쪽으로 떨어지는 굽은 비탈 + 들쭉날쭉한 작은 봉우리
    k = np.where(u < apex, (u - apex) / (1 + apex), (u - apex) / (1 - apex))
    prof = 1 - np.abs(k) ** g.uniform(1.7, 2.3)  # 둥근 어깨
    for _ in range(int(g.integers(1, 3))):  # 옆에 작은 봉우리(능선이 여러 번 굽이친다)
        sc = g.uniform(-0.65, 0.65)
        sw = g.uniform(0.25, 0.45)
        prof = np.maximum(prof, g.uniform(0.5, 0.8) * (1 - np.clip(np.abs((u - sc) / sw), 0, 1) ** 2))
    if desert:
        prof = np.clip(prof * 1.6, 0, 0.8) / 0.8
    jag = (vnoise(lx + seed % 997, np.zeros_like(lx), 9, 541) - 0.5) * 0.16 + (vnoise(lx + seed % 991, np.zeros_like(lx), 3.5, 543) - 0.5) * 0.06
    top = -h * np.clip(prof + jag * (1 - np.abs(k) * 0.5), 0, None)
    base_w = 6 * np.sin(lx / 9 + seed % 7)  # 밑동도 울퉁불퉁
    sd = np.minimum(ly - top, base_w * 0 + (4 + base_w * 0.4) - ly)
    a = aa(-sd, 1.0) * (np.abs(u) < 1.02)
    if a.max() <= 0:
        return
    # 빛면/그늘면: 꼭대기에서 밑동으로 내려오는 굽은 등줄기 왼쪽이 밝다
    spine = apex * (w / 2) + w * 0.1 + (vnoise(ly, np.zeros_like(ly) + seed % 13, 14, 545) - 0.5) * 16 + ly * 0.12
    side = lx - spine
    rel = np.clip(-ly / h, 0, 1)  # 0 밑동 ~ 1 꼭대기
    # 둥근 산처럼: 등줄기에서 옆으로 갈수록 기울어진 면(왼쪽이 빛을 받는다)
    nx = np.clip(side / (w * 0.42), -1, 1) * 0.7
    ny = -0.25 - 0.45 * (1 - rel)
    nz = np.sqrt(np.clip(1 - nx * nx * 0.85, 0.05, 1))
    nn = np.sqrt(nx * nx + ny * ny + nz * nz)
    lit = (nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]) / nn
    lit = (lit - 0.45) * 1.6
    # 주름(골짜기): 능선에서 비스듬히 내려오는 어두운 선
    crease = np.sin((lx * 0.9 + ly * np.sign(side + 1e-3) * 0.6) / (7 + seed % 5) + vnoise(lx, ly, 18, 547) * 3)
    lit = lit - smooth(0.75, 0.98, crease) * 0.3 * smooth(0.05, 0.3, rel)
    tex = fbm(xx + bx * 1.7, yy + by * 1.3, 10, 549, 3)
    # 비탈을 따라 내려오는 바위 붓질(빛면은 오른쪽 아래로, 그늘면은 왼쪽 아래로)
    dirn = np.where(side < 0, 1.0, -1.0)
    stroke = vnoise((lx + bx) * 0.25 + (ly + by) * 0.5 * dirn, (ly + by) * 0.9 - (lx + bx) * 0.3 * dirn, 4, 557)
    lv = lit + (tex - 0.5) * 0.25 + (stroke - 0.5) * 0.25
    dk = mix(m1, m1 * np.array([0.82, 0.84, 0.95], np.float32), 0.6)
    col = mix(dk, m1, smooth(-0.7, -0.3, lv))
    col = mix(col, m0, smooth(-0.05, 0.2, lv))
    col = mix(col, shade(m0, 0.3), smooth(0.55, 0.75, lv))
    if desert:  # 메사: 층진 붉은 바위 띠
        strata = np.sin(ly / 7.5 + vnoise(lx, ly, 30, 551) * 2)
        col = shade(col, smooth(0.5, 1, strata) * 0.1 - smooth(0.6, 1, -strata) * 0.14)
    # 초록 지역: 아래 비탈에 덤불·풀 무더기
    if b["name"] not in ("desert", "snow", "lava", "twilight"):
        gc = hexc(b["grass"] or "#8fbf7a")
        bush = smooth(0.5, 0.7, vnoise(xx + bx * 2.3, yy + by * 1.9, 16, 555)) * smooth(0.4, 0.0, rel)
        col = mix(col, shade(gc, -0.12 - smooth(-12, 10, side) * 0.15), bush * 0.55)
    # 밑동은 바닥색으로 스며든다
    col = shade(col, -smooth(-14, 2, ly) * 0.12)
    # 눈 덮인 꼭대기(아랫단이 들쭉날쭉)
    if cap == "snow" and h > TILE * 1.25:
        line = 0.62 + (vnoise(lx, np.zeros_like(lx) + seed % 17, 7, 553) - 0.5) * 0.25
        snow = smooth(line, line + 0.03, rel)
        snowc = np.where((side < 0)[..., None], hexc("#fbfdff"), hexc("#c9d5ea"))
        col = mix(col, snowc, snow)
    if cap == "lava" and h > TILE * 1.6:
        glow = smooth(0.84, 0.9, rel) * (np.abs(lx - apex * w / 2) < w * 0.12)
        col = mix(col, hexc("#ff8a3d"), glow)
        stream = (np.abs(lx - apex * w / 2 - np.sin(ly / 9) * 5) < 2.2) * smooth(0.2, 0.85, rel) * (g.random() < 0.6)
        col = mix(col, hexc("#ff7a2e"), stream * 0.9)
    # 테두리: 그늘 쪽이 더 진한 손그림 선
    outline = smooth(-2.6, -0.3, -(-sd))  # 가장자리 안쪽
    edge = smooth(-3.0, -0.2, sd)
    col = mix(col, dk * 0.72, (edge * (0.6 + 0.3 * (side > 0)))[..., None])
    # 빛면 윤곽 안쪽의 밝은 테(손그림 하이라이트)
    hl = smooth(-7, -3.5, sd) * smooth(-2.5, -3.5, sd) * (side < -4) * smooth(0.25, 0.6, rel)
    col = mix(col, shade(m0, 0.4), hl[..., None] * 0.6)
    # 그림자(오른쪽 아래로)
    L.over(SH, aa(np.hypot((lx - w * 0.15) / (w * 0.55), (ly - 2) / 9) - 1, 4) * 0.22, int(by - (PH - 8)) + 4, int(bx - PW) + 10)
    L.over(col, a, int(by - (PH - 8)), int(bx - PW))


def _cap_w(W, X, Y):
    out = {}
    for k, test in (("snow", lambda b: b["mountain"][2] == "snow"), ("lava", lambda b: b["mountain"][2] == "lava"),
                    ("mesa", lambda b: b["name"] == "desert"), ("green", lambda b: b["name"] not in ("desert", "snow", "lava", "twilight"))):
        key = ("cap", k)
        if key not in W._fields:
            m = np.zeros_like(W.stage, bool)
            for s, b in W.bio.items():
                if s and test(b):
                    m |= W.stage == s
            W._fields[key] = ndimage.gaussian_filter(m.astype(np.float32), 1.5)
        out[k] = sample(W._fields[key], X, Y)
    return out


def _caves(W, L):
    """동굴 입구: 산자락의 어두운 굴, 둘레에 바위 테."""
    ys, xs = np.nonzero(W.rows == "c")
    for cy, cx in zip(ys, xs):
        lx = int(cx * TILE + 32 - L.x0)
        ly = int(cy * TILE + 40 - L.y0)
        if lx < -80 or ly < -80 or lx > L.w + 80 or ly > L.h + 80:
            continue
        S = 44
        yy, xx = np.mgrid[0:S * 2, 0:S * 2].astype(np.float32)
        dx, dy = xx - S, yy - S
        ang = np.arctan2(dy, dx)
        r = 22 * (1 + 0.08 * np.sin(ang * 5 + cx))
        arch = np.where(dy < 0, np.hypot(dx, dy * 1.15) - r, np.abs(dx) - r)
        arch = np.maximum(arch, dy - 14)
        rimc = shade(hexc("#8f8377"), np.clip(-(dx + dy) / 30, -1, 1) * 0.25 + (vnoise(xx, yy, 4, 521) - 0.5) * 0.2)
        L.over(rimc, aa(arch - 7, 1.0), ly - S, lx - S)
        hole = mix(hexc("#2a2328"), hexc("#14101a"), smooth(0, 20, dy + 10))
        L.over(hole, aa(arch, 1.0), ly - S, lx - S)
