"""마을 성벽(M)과 성(K): 산 겹(mtn)에 그린다(높이가 있어 풀·물 위, 나무 아래).

사용자 의견: 판타지 시대상에 맞게 성벽 안의 마을, 뒤에는 성. 동화책 삽화풍(기하학 느낌 없이, 손그림 윤곽, 같은 빛).
- 돌: 바둑판 벽돌이 아니라 크기가 제각각인 손으로 쌓은 돌(보로노이). 돌마다 왼쪽 위가 밝은 모서리, 사이 줄눈.
- 윤곽: 잡음으로 살짝 흔들린 손그림 선(물체 색의 진한 색). 아래는 그늘(AO)과 이끼, 군데군데 담쟁이.
- 성벽: 칸 발자국을 위로 밀어 올린 입체(윗면 통로는 판석, 앞면은 돌), 크기가 조금씩 다른 총안.
  성문(바깥 길과 만나는 곳)마다 양옆 둥근 탑과 아치 문루. 모서리에도 탑.
- 성: 앞 성벽과 큰 아치 성문(나무 문, 쇠창살), 휘장, 뒤의 본성(비늘 기와), 둥근 탑 넷(원뿔 지붕, 깃발), 가운데 작은 탑.
"""
import numpy as np
from scipy import ndimage

from core import LIGHT, TILE, _hash, aa, fbm, hexc, mix, shade, smooth, vnoise, voronoi

SH = hexc("#2b2f45")
STONE = hexc("#ddd3c4")
STONE_D = hexc("#c2b6a4")
ROOF = hexc("#5f7fc8")
ROOF2 = hexc("#c9604f")
MOSS = hexc("#7f9f5f")
WALL = hexc("#c9c3c0")  # 마을 성벽: 광장 돌바닥(따뜻한 베이지)과 구별되는 서늘한 회색 돌
WALL_D = hexc("#a39c9c")
IVY = hexc("#5f8f4f")


def paint(W, L, X, Y):
    _walls(W, L)
    for bd in W.buildings():
        if bd["id"] == "castle":
            _castle(L, bd)


# ---------- 돌 결 ----------

def masonry(GX, GY, base, seed, size=13.0, flat=False):
    """손으로 쌓은 돌: 가로로 조금 긴 크고 작은 돌, 돌마다 색이 다르고 왼쪽 위 모서리가 밝다. flat: 윗면 판석."""
    sx = 0.62 if not flat else 0.9
    d1, gap, sid = voronoi(GX * sx, GY, size, seed, jitter=0.9)
    col = mix(base, shade(base, -0.14), sid)
    col = mix(col, col * np.array([1.03, 1.0, 0.94], np.float32), smooth(0.6, 0.9, _hash(np.floor(sid * 977).astype(np.int64), np.zeros_like(GX, np.int64), seed + 1))[..., None])
    gy, gx = np.gradient(gap)
    bevel = -(gx * LIGHT[0] + gy * LIGHT[1]) * smooth(4.0, 0.5, gap)
    col = shade(col, np.clip(bevel * 0.9, -0.22, 0.22) + (fbm(GX, GY, 5, seed + 2, 2) - 0.5) * 0.12)
    mortar = smooth(1.5, 0.2, gap + (vnoise(GX, GY, 3, seed + 3) - 0.5) * 0.8)
    col = mix(col, shade(base, -0.42), mortar[..., None] * 0.85)
    return col


def wobble_edge(mask, GX, GY, seed, amp=1.6):
    """손그림 윤곽: 가장자리를 잡음으로 살짝 흔든다(부드러운 알파)."""
    dist_in = ndimage.distance_transform_edt(mask)
    dist_out = ndimage.distance_transform_edt(~mask)
    sd = np.where(mask, -dist_in + 0.5, dist_out - 0.5) + (vnoise(GX, GY, 7, seed) - 0.5) * 2 * amp
    return sd


def finish(col, sd, edge_col, a_soft=0.9):
    """윤곽선과 알파: sd<0 안쪽. 가장자리 2px는 진한 선."""
    a = aa(sd, a_soft)
    line = smooth(-3.0, -0.6, sd)
    col = mix(col, edge_col, line[..., None] * 0.8)
    return col, a


def moss_ivy(col, GX, GY, rel_bottom, seed, amount=1.0):
    """아래쪽 이끼(rel_bottom 0 위 ~ 1 밑동), 군데군데 담쟁이."""
    moss = smooth(0.72, 1.0, rel_bottom + (fbm(GX, GY, 14, seed, 3) - 0.5) * 0.5) * amount
    col = mix(col, shade(MOSS, (vnoise(GX, GY, 3, seed + 1) - 0.5) * 0.3), moss[..., None] * 0.75)
    ivy_zone = smooth(0.6, 0.8, fbm(GX * 0.7, GY * 0.35, 40, seed + 2, 3)) * smooth(0.2, 0.6, rel_bottom) * amount
    d1, gap, lid = voronoi(GX, GY, 5.5, seed + 3)
    leaf = (d1 < 3.2) & (lid > 0.35)
    ivy = ivy_zone * leaf
    col = mix(col, shade(IVY, (lid - 0.5) * 0.4 + smooth(3.2, 0, d1) * 0.15), ivy[..., None])
    return col


# ---------- 성벽 ----------

def _walls(W, L):
    m = W.rows == "M"
    if not m.any():
        return
    ys, xs = np.nonzero(m)
    x0 = int(max(xs.min() * TILE - L.x0 - 140, 0))
    y0 = int(max(ys.min() * TILE - L.y0 - 200, 0))
    x1 = int(min((xs.max() + 1) * TILE - L.x0 + 140, L.w))
    y1 = int(min((ys.max() + 1) * TILE - L.y0 + 100, L.h))
    if x1 <= x0 or y1 <= y0:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    GX, GY = xx + L.x0, yy + L.y0
    cx = np.clip((GX // TILE).astype(int), 0, W.w - 1)
    cy = np.clip((GY // TILE).astype(int), 0, W.h - 1)
    lx, ly = GX - cx * TILE, GY - cy * TILE

    def nb(dx, dy):
        return m[np.clip(cy + dy, 0, W.h - 1), np.clip(cx + dx, 0, W.w - 1)]
    here = m[cy, cx]
    half = 25 + (vnoise(GX, GY, 40, 751) - 0.5) * 4  # 두께도 조금씩 다르다
    core_ = (np.abs(lx - 32) < half) & (np.abs(ly - 32) < half)
    hor = ((lx < 32) & nb(-1, 0) | (lx >= 32) & nb(1, 0)) & (np.abs(ly - 32) < half)
    ver = ((ly < 32) & nb(0, -1) | (ly >= 32) & nb(0, 1)) & (np.abs(lx - 32) < half)
    foot = here & (core_ | hor | ver)
    Hi = 42
    top = np.zeros_like(foot)
    top[:-Hi] = foot[Hi:]
    body = np.zeros_like(foot)
    for d in range(Hi + 1):
        body[: foot.shape[0] - d] |= foot[d:]
    front = body & ~top
    # 총안: 윗면 바깥 가장자리를 크기가 다른 덩어리로 끊어 더 올린다
    er = ndimage.binary_erosion(top, iterations=8)
    rim = top & ~er
    seg = np.floor((GX + GY * 0.0001) / 15.0) + np.floor(GY / 15.0)
    w_ = _hash(seg.astype(np.int64), np.zeros_like(seg, np.int64), 753)
    # 총안은 바깥쪽 가장자리에만(마을 쪽 통로 가장자리에는 없다)
    t_ = W.d["regions"][0]["town"]
    tcx, tcy = (t_[0] + t_[2] / 2) * TILE, (t_[1] + t_[3] / 2) * TILE
    cxc, cyc = (cx + 0.5) * TILE, (cy + 0.5) * TILE
    dxo = np.where(np.abs(cxc - tcx) / t_[2] > np.abs(cyc - tcy) / t_[3], np.sign(cxc - tcx), 0)
    dyo = np.where(dxo == 0, np.sign(cyc - tcy), 0)
    outer = ((lx - 32) * dxo + (ly - 32 + Hi) * dyo) > 0
    merl = rim & outer & (((seg % 2) == 0) | (w_ > 0.85))
    mH = 10
    merl_top = np.zeros_like(merl)
    merl_top[:-mH] = merl[mH:]
    merl_body = np.zeros_like(merl)
    for d in range(mH + 1):
        merl_body[: merl.shape[0] - d] |= merl[d:]
    solid = body | merl_body
    # 앞면 돌, 윗면 판석
    stone_front = masonry(GX, GY, WALL_D, 761)
    stone_top = masonry(GX, GY, WALL, 763, size=16, flat=True)
    stone_top = shade(stone_top, 0.06)
    # 앞면의 밑동까지 상대 높이(0 위 ~ 1 밑동): 이끼·담쟁이
    below = np.zeros_like(GY)
    run = np.zeros(foot.shape[1], np.float32)
    for r in range(foot.shape[0] - 1, -1, -1):  # 아래에서 위로 앞면을 따라 올라간 거리
        run = np.where(front[r], run + 1, 0)
        below[r] = run
    rel = np.where(front, 1 - np.clip(below / Hi, 0, 1), 0.0)  # 앞면만(윗면·총안에는 이끼가 없다)
    stone_front = moss_ivy(stone_front, GX, GY, rel, 765)
    stone_front = shade(stone_front, -smooth(0.15, 0.0, rel) * 0.0 - (1 - rel) * 0.0 + smooth(0.75, 1.0, rel) * -0.12)
    col = np.where(top[..., None], stone_top, stone_front)
    col = np.where((merl_body & ~merl_top)[..., None], shade(stone_front, 0.06), col)
    col = np.where(merl_top[..., None], shade(stone_top, 0.1), col)
    # 윗면 앞 가장자리 밝은 테, 안쪽(통로) 살짝 그늘
    col = shade(col, (top & ~ndimage.binary_erosion(top, iterations=3) & ~rim)[..., None][..., 0] * 0.1)
    sd = wobble_edge(solid, GX, GY, 767, 1.4)
    col, a = finish(col, sd, shade(WALL_D, -0.6))
    # 그림자(오른쪽 아래), 밑동 풀
    sh = ndimage.gaussian_filter(ndimage.shift(solid.astype(np.float32), (12, 10), order=0), 5) * (1 - a) * 0.36
    L.over(SH, sh, y0, x0)
    L.over(col, a, y0, x0)
    # 탑: 모서리와 성문 양옆. 성문 위에는 아치 문루
    towers = []
    for (y, x) in zip(ys, xs):
        h_ = (x > 0 and m[y, x - 1]) or (x + 1 < W.w and m[y, x + 1])
        v_ = (y > 0 and m[y - 1, x]) or (y + 1 < W.h and m[y + 1, x])
        nb_s = [(dx, dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= y + dy < W.h and 0 <= x + dx < W.w and W.rows[y + dy, x + dx] == "s"
                and not m[y + dy - (1 if dy else 0), x + dx] if False]  # (쓰지 않음)
        gate_side = any(0 <= y + dy < W.h and 0 <= x + dx < W.w and W.rows[y + dy, x + dx] == "s" and _on_wall_line(m, y + dy, x + dx, dx, dy)
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if (h_ and v_) or gate_side:
            towers.append(((y + 0.5) * TILE, (x + 0.5) * TILE, gate_side))
    towers.sort()
    keep = []
    for t_ in towers:
        if all(abs(t_[0] - k[0]) + abs(t_[1] - k[1]) > TILE * 1.5 for k in keep):
            keep.append(t_)
    _gatehouses(W, L, m)
    for ty_, tx_, g_ in keep:
        _tower(L, tx_ - L.x0, ty_ - L.y0 + 30, 33, 86 if g_ else 76, ROOF2, flag=True, seed=int(tx_ + ty_) % 97)


def _on_wall_line(m, y, x, dx, dy):
    """그 길 칸이 성벽 줄 위의 틈(성문)인가: 성벽과 같은 줄로 이어진다."""
    if dx:  # 가로 이웃 → 가로 성벽의 틈
        return True
    return True


def _gatehouses(W, L, m):
    """성문(성벽의 틈)마다 위를 건너는 아치 문루(돌, 아치 아래는 비어 길이 보인다)."""
    rows = W.rows
    ys, xs = np.nonzero(m)
    gaps = []
    for y in range(ys.min(), ys.max() + 1):  # 가로 성벽의 틈
        xs_ = [x for x in range(xs.min(), xs.max() + 1) if rows[y, x] == "s" and m[y, max(0, x - 1):x + 2].any() is not None]
    seen = set()
    for y in (ys.min(), ys.max()):
        x = xs.min()
        while x <= xs.max():
            if rows[y, x] == "s":
                x2 = x
                while x2 + 1 <= xs.max() and rows[y, x2 + 1] == "s":
                    x2 += 1
                gaps.append(("h", y, x, x2))
                x = x2 + 1
            else:
                x += 1
    for x in (xs.min(), xs.max()):
        y = ys.min()
        while y <= ys.max():
            if rows[y, x] == "s":
                y2 = y
                while y2 + 1 <= ys.max() and rows[y2 + 1, x] == "s":
                    y2 += 1
                gaps.append(("v", x, y, y2))
                y = y2 + 1
            else:
                y += 1
    for g in gaps:
        if g[0] == "h":
            _, y, xa, xb = g
            px0 = xa * TILE - L.x0
            pw = (xb - xa + 1) * TILE
            py = y * TILE - L.y0
            _arch(L, px0 - 8, py - 20, pw + 16, 34, 18, seed=xa * 7 + y)
        else:
            _, x, ya, yb = g
            # 세로 성벽의 문: 문 위 칸 위에 짧은 다리 모양 통로(위에서 본 아치)
            px0 = x * TILE - L.x0 + 7
            py0 = ya * TILE - L.y0 - 30
            ph = (yb - ya + 1) * TILE + 20
            yy, xx = np.mgrid[0:int(ph), 0:50].astype(np.float32)
            GX, GY = xx + px0 + L.x0, yy + py0 + L.y0
            band = (np.abs(yy - 10) < 10) | (np.abs(yy - (ph - 10)) < 10)
            col = masonry(GX, GY, STONE, 771, size=14, flat=True)
            sd = wobble_edge(band, GX, GY, 773, 1.0)
            c, a = finish(col, sd, shade(STONE_D, -0.55))
            L.over(c, a, int(py0), int(px0))


def _arch(L, x0, y0, w, h, depth, seed):
    """가로 성문 위 아치 문루: 앞면에 둥근 아치(가운데는 비어 길이 보인다), 위에 총안 통로."""
    H = int(h + depth + 14)
    yy, xx = np.mgrid[0:H, 0:int(w)].astype(np.float32)
    GX, GY = xx + x0 + L.x0, yy + y0 + L.y0
    topf = (yy >= 10) & (yy < 10 + depth)
    face = (yy >= 10 + depth) & (yy < H)
    cxa = w / 2
    r = w * 0.42
    hole = np.hypot((xx - cxa) / r, (yy - H) / (h * 0.9)) < 1
    face &= ~hole
    merl = (yy < 10) & (yy >= 1) & (((xx + seed) % 20) < 12)
    solid = topf | face | merl
    col = np.where(face[..., None], masonry(GX, GY, STONE_D, 781), shade(masonry(GX, GY, STONE, 783, size=15, flat=True), 0.08))
    ring = (np.hypot((xx - cxa) / (r + 6), (yy - H) / (h * 0.9 + 6)) < 1) & ~hole & face
    col = np.where(ring[..., None], shade(STONE, 0.12), col)
    sd = wobble_edge(solid, GX, GY, 785 + seed, 1.0)
    c, a = finish(col, sd, shade(STONE_D, -0.55))
    L.over(SH, ndimage.gaussian_filter(ndimage.shift(solid.astype(np.float32), (8, 8), order=0), 3) * (1 - a) * 0.3, int(y0), int(x0))
    L.over(c, a, int(y0), int(x0))


# ---------- 탑 ----------

def _tower(L, cx, base, r, h, roof, flag=True, seed=0, windows=None):
    """둥근 탑: 손으로 쌓은 돌을 두른 원통(왼쪽이 밝다), 아래 이끼·그늘, 총안 띠, 원뿔 지붕(비늘), 깃발."""
    S = int(r * 2.2 + 10)
    top = base - h
    Hh = int(h + r * 2.6 + 60)
    yy, xx = np.mgrid[0:Hh, 0:2 * S].astype(np.float32)
    ox, oy = int(cx - S), int(top - r * 1.7 - 46)
    GX, GY = xx + ox + L.x0, yy + oy + L.y0
    lx = xx - S
    gy = yy + oy  # 화면 y
    ell = r * 0.33
    u = np.clip(lx / r, -1, 1)
    circ = np.sqrt(np.clip(1 - u * u, 0, 1))
    body = (np.abs(lx) < r) & (gy < base + ell * circ) & (gy > top - ell * circ)
    # 그림자
    L.over(SH, aa(np.hypot((lx - 14) / (r * 1.4), (gy - base - 6) / (r * 0.55)) - 1, 0.08) * 0.32, oy, ox)
    # 몸통 돌: 원통에 감긴 돌(가로 좌표를 각도로)
    ang = np.arcsin(u) * r * 1.2
    stone = masonry(ang + seed * 37.0, gy, STONE, 791 + seed, size=12)
    light = -u * 0.5 + circ * 0.25 - 0.08
    stone = shade(stone, light * 0.6)
    rel = np.clip((gy - top) / h, 0, 1)
    stone = moss_ivy(stone, GX, GY, rel, 793 + seed, 0.8)
    stone = shade(stone, -smooth(0.8, 1.0, rel) * 0.12)
    nw = windows if windows is not None else (1 if h < 100 else 2)
    for k in range(nw):  # 아치 창(안쪽 어둡고 한쪽에 따뜻한 불빛)
        wy = top + h * (0.28 + k * 0.33)
        wx = -r * 0.2
        win = ((np.abs(lx - wx) < 5) & (np.abs(gy - wy) < 8)) | (np.hypot(lx - wx, gy - (wy - 8)) < 5)
        frame = (((np.abs(lx - wx) < 7.5) & (np.abs(gy - wy) < 10)) | (np.hypot(lx - wx, gy - (wy - 8)) < 7.5)) & ~win
        stone = np.where(frame[..., None], shade(STONE, 0.18), stone)
        stone = np.where(win[..., None], mix(hexc("#3b3049"), hexc("#ffcf6b"), (k + seed) % 2 * 0.55), stone)
    sd = wobble_edge(body, GX, GY, 795 + seed, 1.2)
    c, a = finish(stone, sd, shade(STONE_D, -0.55))
    L.over(c, a, oy, ox)
    # 총안 띠(탑 꼭대기 둘레, 조금 넓다)
    rr = r * 1.12
    u2 = np.clip(lx / rr, -1, 1)
    circ2 = np.sqrt(np.clip(1 - u2 * u2, 0, 1))
    band = (np.abs(lx) < rr) & (gy < top + 10 + ell * circ2) & (gy > top - 4 - ell * circ2)
    merl = (np.abs(lx) < rr) & (gy <= top - 4 - ell * circ2 + 1) & (gy > top - 14 - ell * circ2) & (((np.arcsin(u2) * rr) % 13) < 7.5)
    bm = band | merl
    bc = masonry(np.arcsin(u2) * rr * 1.1 + seed, gy, STONE, 797 + seed, size=10)
    bc = shade(bc, -u2 * 0.45 + 0.1)
    sd2 = wobble_edge(bm, GX, GY, 799 + seed, 0.9)
    c2, a2 = finish(bc, sd2, shade(STONE_D, -0.55))
    L.over(c2, a2, oy, ox)
    _cone(L, cx, top - 8, r * 1.28, r * 1.9, roof, flag=flag, seed=seed)


def _cone(L, cx, ybase, r, h, col, flag=True, seed=0):
    """원뿔 지붕: 물고기 비늘 기와 줄(위로 갈수록 작다), 왼쪽이 밝고, 처마는 둥글게 처진다. 꼭대기 깃발."""
    S = int(r + 12)
    apex_pad = 34
    Hh = int(h + r * 0.6 + apex_pad + 6)
    yy, xx = np.mgrid[0:Hh, 0:2 * S].astype(np.float32)
    ox, oy = int(cx - S), int(ybase - h - apex_pad)
    GX, GY = xx + ox + L.x0, yy + oy + L.y0
    lx = xx - S
    gy = yy - apex_pad
    t = np.clip(gy / h, 0, 1.3)
    halfw = r * (t ** 0.8) * (1 + 0.03 * np.sin(gy * 0.4 + seed))
    eave = h + r * 0.3 * np.sqrt(np.clip(1 - (lx / r) ** 2, 0, 1))
    inside = (np.abs(lx) < halfw) & (gy > 0) & (gy < eave)
    u = np.clip(lx / np.maximum(halfw, 1), -1, 1)
    rowh = 5 + 6 * t
    rowi = np.floor(gy / 7.5)
    off = (rowi % 2) * 0.5
    col_n = (np.arcsin(u) / np.pi + 0.5) * (6 + 14 * t) + off
    fx = (col_n % 1.0) - 0.5
    fy = (gy % 7.5) / 7.5
    scallop = fy - (1 - 0.5 * np.sqrt(np.clip(1 - (fx * 2) ** 2, 0, 1)))
    tid = _hash(np.floor(col_n).astype(np.int64) + seed, rowi.astype(np.int64), 801)
    c = shade(col, -u * 0.36 + 0.08 + (tid - 0.5) * 0.12 - smooth(-0.25, 0.05, scallop) * 0.2 - smooth(0.7, 1.1, t) * 0.1)
    sd = wobble_edge(inside, GX, GY, 803 + seed, 1.0)
    c, a = finish(c, sd, shade(col, -0.55))
    L.over(c, a, oy, ox)
    if flag:
        pole = (np.abs(lx) < 1.4) & (yy < apex_pad + 3) & (yy > 4)
        L.over(hexc("#6e5a4a"), pole.astype(np.float32), oy, ox)
        wave = np.sin(lx * 0.35 + seed) * 2.2
        fl = (lx > 1) & (lx < 24) & (yy > 5 + wave + lx * 0.08) & (yy < 16 + wave - lx * 0.12)
        fc = shade(hexc("#e9576a"), np.where(np.sin(lx * 0.35 + seed) > 0, 0.08, -0.12))
        L.over(fc, fl.astype(np.float32), oy, ox)


# ---------- 성 ----------

def _face(L, x0, y0, w, h, base, seed, windows=0, arch=None, rel_moss=True, buttress=0):
    """앞면 벽: 손으로 쌓은 돌, 아치 창(창틀·불빛), 아래 이끼와 그늘, 담쟁이, 버팀벽, 큰 성문."""
    yy, xx = np.mgrid[0:int(h), 0:int(w)].astype(np.float32)
    GX, GY = xx + x0 + L.x0, yy + y0 + L.y0
    col = masonry(GX, GY, base, seed)
    col = shade(col, (0.5 - xx / w) * 0.14)
    rel = yy / h
    if rel_moss:
        col = moss_ivy(col, GX, GY, rel, seed + 5)
    col = shade(col, -smooth(0.82, 1.0, rel) * 0.15 - smooth(0.12, 0.0, rel) * 0.1)
    mask = np.ones_like(xx, bool)
    for k in range(buttress):  # 버팀벽(밝은 기둥, 아래가 넓다)
        bx = (k + 0.5) * w / buttress
        bw = 9 + 6 * rel
        b = np.abs(xx - bx) < bw
        col = np.where(b[..., None], shade(masonry(GX, GY, shade(base, 0.08), seed + 9, size=10), -np.clip((xx - bx) / bw, -1, 1) * 0.2), col)
    for k in range(windows):
        wx = (k + 0.5) * w / windows
        if arch and abs(wx - arch[0]) < arch[1] / 2 + 24:
            continue
        wy = h * 0.34
        win = ((np.abs(xx - wx) < 7) & (np.abs(yy - wy) < 12)) | (np.hypot(xx - wx, yy - (wy - 12)) < 7)
        frame = (((np.abs(xx - wx) < 10) & (np.abs(yy - wy) < 15)) | (np.hypot(xx - wx, yy - (wy - 12)) < 10)) & ~win
        sill = (np.abs(xx - wx) < 12) & (np.abs(yy - wy - 15) < 2.5)
        lit = (k * 7 + seed) % 3 == 0
        glass = mix(hexc("#3b3049"), hexc("#ffcf6b"), 0.6 if lit else 0.0)
        glass = mix(glass, hexc("#8fb4e4"), (np.abs((xx - wx) + (yy - wy)) < 2)[..., None] * 0.4)
        col = np.where(frame[..., None] | sill[..., None], shade(base, 0.2), col)
        col = np.where(win[..., None], glass, col)
    if arch:  # 큰 성문: 돌 아치(쐐기돌), 나무 문짝, 쇠창살, 문 앞 디딤돌
        ax, aw, ah = arch
        top_c = h - ah + aw / 2
        hole = ((np.abs(xx - ax) < aw / 2) & (yy > top_c)) | (np.hypot(xx - ax, yy - top_c) < aw / 2)
        ringm = (((np.abs(xx - ax) < aw / 2 + 10) & (yy > top_c)) | (np.hypot(xx - ax, yy - top_c) < aw / 2 + 10)) & ~hole
        angk = np.arctan2(yy - top_c, xx - ax)
        voss = np.abs(((angk * 7) % 1.0) - 0.5) < 0.06
        col = np.where(ringm[..., None], shade(STONE, np.where(voss, -0.25, 0.14)), col)
        plank = (np.abs(((xx - ax) % 10) - 5) < 0.9).astype(np.float32)
        door = shade(hexc("#8a5f3a"), -plank * 0.25 + (vnoise(xx * 0.3, yy, 3, seed + 7) - 0.5) * 0.15 + (ax - xx) / aw * 0.2)
        bars = (np.abs(((xx - ax) % 13) - 6.5) < 1.3) | (np.abs((yy % 15) - 7.5) < 1.3)
        door = np.where((bars & (yy < h - 26))[..., None], hexc("#4a3f45"), door)
        col = np.where(hole[..., None], door, col)
    sd = wobble_edge(mask, GX, GY, seed + 11, 1.2)
    sd = np.maximum(sd, -np.minimum.reduce([xx, w - 1 - xx, yy + 50, h - 1 - yy]) + (vnoise(GX, GY, 7, seed + 13) - 0.5) * 2.4)
    c, a = finish(col, sd, shade(base, -0.55))
    L.over(c, a, int(y0), int(x0))


def _parapet(L, x0, y, w, base, seed, depth=18):
    """윗면 통로(판석)와 앞쪽 총안(크기가 조금씩 다르다)."""
    H = depth + 14
    yy, xx = np.mgrid[0:H, 0:int(w)].astype(np.float32)
    GX, GY = xx + x0 + L.x0, yy + (y - H) + L.y0
    walk = (yy > 13) & (yy < 13 + depth)
    k = np.floor((xx + seed) / 21)
    wk = 11 + 4 * _hash(k.astype(np.int64), np.zeros_like(k, np.int64), seed)
    merl = (yy <= 13) & (yy > 1) & (((xx + seed) % 21) < wk)
    solid = walk | merl
    col = np.where(walk[..., None], shade(masonry(GX, GY, base, seed, size=14, flat=True), 0.1), shade(masonry(GX, GY, base, seed + 1, size=9), 0.05))
    sd = wobble_edge(solid, GX, GY, seed + 3, 1.0)
    c, a = finish(col, sd, shade(base, -0.55))
    L.over(c, a, int(y - H), int(x0))


def _roof(L, x0, y0, w, h, col, seed):
    """본성 지붕: 앞 경사면(비늘 기와), 양끝이 안으로, 처마가 살짝 처지고 용마루는 밝다."""
    yy, xx = np.mgrid[0:int(h + 10), 0:int(w)].astype(np.float32)
    GX, GY = xx + x0 + L.x0, yy + y0 + L.y0
    t = yy / h
    inset = (1 - t) * w * 0.18
    sag = 5 * np.sin(np.clip(xx / w, 0, 1) * np.pi)
    inside = (xx > inset) & (xx < w - inset) & (yy < h + sag)
    rowh = 9.0
    row = np.floor(yy / rowh)
    offx = (row % 2) * 7
    tx = (xx + offx) % 14 - 7
    ty = yy % rowh
    sc = ty - (rowh - 2.6 * np.sqrt(np.clip(1 - (tx / 7) ** 2, 0, 1)))
    tid = _hash(np.floor((xx + offx) / 14).astype(np.int64), row.astype(np.int64), seed)
    c = shade(col, -smooth(-2.5, 0.5, sc) * 0.22 + (0.5 - xx / w) * 0.28 + (tid - 0.5) * 0.12 - t * 0.06)
    c = mix(c, shade(col, 0.3), (yy < 5)[..., None] * 0.7)
    sd = wobble_edge(inside, GX, GY, seed + 1, 1.2)
    c, a = finish(c, sd, shade(col, -0.55))
    L.over(c, a, int(y0), int(x0))


def _banner(L, cx, y, seed):
    yy, xx = np.mgrid[0:78, 0:30].astype(np.float32)
    fold = np.sin(xx * 0.5) * 0.12
    ban = (yy < 66 - np.abs(xx - 15) * 0.7) & (yy > 4)
    c = shade(hexc("#b8475a"), (0.5 - xx / 30) * 0.3 + fold)
    emblem = np.hypot(xx - 15, yy - 30) < 7
    c = np.where(emblem[..., None], shade(hexc("#f2cf4a"), -np.clip((xx - 15) / 7, -1, 1) * 0.15), c)
    c = np.where((yy < 8)[..., None], hexc("#6e5a4a"), c)
    L.over(c, ban.astype(np.float32) + (yy < 8) * (np.abs(xx - 15) < 15), int(y), int(cx - 15))


def _castle(L, bd):
    rc = bd["rect"]
    X0 = rc[0] * TILE - L.x0
    Y0 = rc[1] * TILE - L.y0
    w, h = rc[2] * TILE, rc[3] * TILE
    if X0 > L.w + 260 or Y0 > L.h + 360 or X0 + w < -260 or Y0 + h < -400:
        return
    # 넓은 그림자
    gx_, gy_ = np.meshgrid(np.arange(-w * 0.75, w * 0.75), np.arange(-h * 0.55, h * 0.55))
    L.over(SH, aa(np.hypot((gx_ - 16) / (w * 0.6), (gy_ - 12) / (h * 0.46)) - 1, 0.03) * 0.3, int(Y0 + h * 0.55 - h * 0.55), int(X0 + w / 2 - w * 0.75))
    # 뒤쪽 탑 둘(더 높다)
    for i, fx in enumerate((0.12, 0.88)):
        _tower(L, X0 + w * fx, Y0 + h * 0.48, 36, 215, ROOF, flag=True, seed=11 + i, windows=3)
    # 본성
    kx0, kw = X0 + w * 0.23, w * 0.54
    kbase = Y0 + h * 0.6
    kh = 205
    _roof(L, kx0 - 14, kbase - kh - 98, kw + 28, 104, ROOF, 811)
    _face(L, kx0, kbase - kh, kw, kh, STONE, 813, windows=4, buttress=3)
    _parapet(L, kx0 - 6, kbase - kh + 4, kw + 12, STONE, 815)
    _tower(L, X0 + w * 0.5, kbase - kh + 34, 25, 74, ROOF, flag=True, seed=17, windows=1)
    # 앞 성벽과 큰 성문(성문 칸 c가 아래 가운데)
    fh = 152
    fbase = Y0 + h
    fx0 = X0 + 0.06 * w
    gate_x = (bd["door"][0] - L.x0) - fx0
    _face(L, fx0, fbase - fh, w * 0.88, fh, STONE_D, 821, windows=6, arch=(gate_x, 74, 100), buttress=0)
    _parapet(L, fx0 - 6, fbase - fh + 4, w * 0.88 + 12, STONE_D, 823)
    for s in (-1, 1):
        _banner(L, fx0 + gate_x + s * 66, fbase - fh + 20, 825 + s)
    # 앞쪽 탑 둘
    for i, fx in enumerate((0.05, 0.95)):
        _tower(L, X0 + w * fx, fbase + 8, 42, 184, ROOF, flag=True, seed=21 + i, windows=2)
