"""마을 성벽(M)과 성(K): 산 겹(mtn)에 그린다(높이가 있어 풀·물 위, 나무 아래).

사용자 의견: 판타지 시대상에 맞게 성벽을 쌓고 그 안에 마을, 뒤에는 성. 성에도 동굴처럼 들어간다(성문 c).
성벽: 칸 모양 발자국을 위로 밀어 올린 입체(윗면 통로는 밝고, 앞면은 벽돌), 바깥 가장자리 총안(凸), 모서리·성문 옆 둥근 탑.
성: 앞 성벽과 큰 성문, 뒤의 본성(뾰족 지붕), 둥근 탑 넷(원뿔 지붕, 깃발). 빛은 왼쪽 위, 그림자는 오른쪽 아래.
"""
import numpy as np
from scipy import ndimage

from core import TILE, _hash, aa, fbm, hexc, mix, shade, smooth, vnoise

SH = hexc("#2b2f45")
STONE = hexc("#d9d0c3")
STONE_D = hexc("#b3a898")
ROOF = hexc("#5f7fc8")
ROOF2 = hexc("#c9604f")


def paint(W, L, X, Y):
    _walls(W, L)
    for bd in W.buildings():
        if bd["id"] == "castle":
            _castle(L, bd)


# ---------- 성벽 ----------

def _walls(W, L):
    m = W.rows == "M"
    if not m.any():
        return
    ys, xs = np.nonzero(m)
    x0 = xs.min() * TILE - L.x0 - 120
    y0 = ys.min() * TILE - L.y0 - 160
    x1 = (xs.max() + 1) * TILE - L.x0 + 120
    y1 = (ys.max() + 1) * TILE - L.y0 + 80
    if x1 < 0 or y1 < 0 or x0 > L.w or y0 > L.h:
        return
    x0, y0 = int(max(x0, 0)), int(max(y0, 0))
    x1, y1 = int(min(x1, L.w)), int(min(y1, L.h))
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    GX, GY = xx + L.x0, yy + L.y0
    cx = np.clip((GX // TILE).astype(int), 0, W.w - 1)
    cy = np.clip((GY // TILE).astype(int), 0, W.h - 1)
    # 발자국: 칸 가운데 띠(두께 40px). 이웃 성벽 칸과 이어진다
    lx, ly = GX - cx * TILE, GY - cy * TILE
    def nb(dx, dy):
        return m[np.clip(cy + dy, 0, W.h - 1), np.clip(cx + dx, 0, W.w - 1)]
    here = m[cy, cx]
    half = 25
    core_ = (np.abs(lx - 32) < half) & (np.abs(ly - 32) < half)
    hor = ((lx < 32) & nb(-1, 0) | (lx >= 32) & nb(1, 0)) & (np.abs(ly - 32) < half)
    ver = ((ly < 32) & nb(0, -1) | (ly >= 32) & nb(0, 1)) & (np.abs(lx - 32) < half)
    foot = here & (core_ | hor | ver)
    H = 40.0  # 성벽 높이(px)
    # 위로 밀어 올린 입체: 윗면 = 발자국을 H만큼 위로, 앞면 = 그 사이
    Hi = int(H)
    top = np.zeros_like(foot)
    top[:-Hi] = foot[Hi:]
    body = np.zeros_like(foot)
    for d in range(Hi + 1):
        body[: foot.shape[0] - d] |= foot[d:]
    front = body & ~top
    # 총안: 윗면 바깥 가장자리 띠를 칸 간격으로 끊어 더 올린다
    er = ndimage.binary_erosion(top, iterations=7)
    rim = top & ~er
    merl = rim & ((((GX // 14) + (GY // 14)) % 2) == 0)
    mH = 9
    merl_top = np.zeros_like(merl)
    merl_top[:-mH] = merl[mH:]
    merl_body = np.zeros_like(merl)
    for d in range(mH + 1):
        merl_body[: merl.shape[0] - d] |= merl[d:]
    merl_front = merl_body & ~merl_top
    tex = fbm(GX, GY, 7, 701, 3)
    # 벽돌 앞면
    row = np.floor(GY / 10)
    off = (row % 2) * 9
    bid = _hash(np.floor((GX + off) / 18).astype(np.int64), row.astype(np.int64), 703)
    fx, fy = (GX + off) % 18, GY % 10
    seam = np.minimum(np.minimum(fx, 18 - fx), np.minimum(fy, 10 - fy))
    brick = shade(mix(STONE_D, shade(STONE_D, -0.12), bid), (tex - 0.5) * 0.16 - smooth(1.6, 0.2, seam) * 0.28 - 0.06)
    topc = shade(mix(STONE, shade(STONE, -0.05), vnoise(GX, GY, 10, 705)), (tex - 0.5) * 0.1 + 0.08)
    # 그림자(오른쪽 아래)
    sh = ndimage.gaussian_filter(ndimage.shift(body.astype(np.float32), (10, 9), order=0), 4) * (1 - body) * 0.35
    L.over(SH, sh, y0, x0)
    col = np.where(top[..., None], topc, brick)
    a = (body | merl_body).astype(np.float32)
    col = np.where(merl_front[..., None], shade(brick, 0.05), col)
    col = np.where(merl_top[..., None], shade(topc, 0.12), col)
    # 가장자리 선(손그림)
    edge = (body | merl_body) & ~ndimage.binary_erosion(body | merl_body)
    col = np.where(edge[..., None], shade(STONE_D, -0.5), col)
    L.over(col, ndimage.gaussian_filter(a, 0.6), y0, x0)
    # 탑: 모서리와 성문(길) 옆
    towers = []
    for (y, x) in zip(ys, xs):
        h_ = (x > 0 and m[y, x - 1]) or (x + 1 < W.w and m[y, x + 1])
        v_ = (y > 0 and m[y - 1, x]) or (y + 1 < W.h and m[y + 1, x])
        open_side = any(W.rows[y + dy, x + dx] == "s" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= y + dy < W.h and 0 <= x + dx < W.w)
        if (h_ and v_) or open_side:
            towers.append(((y + 0.5) * TILE, (x + 0.5) * TILE))
    towers.sort()
    keep = []
    for t_ in towers:  # 가까이 붙은 탑은 하나만(성문 양옆 하나씩, 모서리 하나)
        if all(abs(t_[0] - k[0]) + abs(t_[1] - k[1]) > TILE * 2.5 for k in keep):
            keep.append(t_)
    for ty_, tx_ in keep:
        _tower(L, tx_ - L.x0, ty_ - L.y0 + 26, 32, 74, ROOF2, flag=True)


# ---------- 공통 모양 ----------

def _cyl(L, cx, base, r, h, col, seed, windows=2):
    """둥근 탑 몸통: 왼쪽이 밝은 원통, 벽돌 줄, 작은 창. base는 밑동 y."""
    S = int(r + 6)
    top = base - h
    yy, xx = np.mgrid[0:int(h + r + 12), 0:2 * S].astype(np.float32)
    lx = xx - S
    gy = yy + (top - r * 0.35)
    ell = r * 0.35
    inside = (np.abs(lx) < r) & (gy < base + ell * np.sqrt(np.clip(1 - (lx / r) ** 2, 0, 1)))
    inside &= gy > top
    a = inside.astype(np.float32)
    u = np.clip(lx / r, -1, 1)
    light = -u * 0.55 + np.sqrt(np.clip(1 - u * u, 0, 1)) * 0.35 - 0.1
    row = np.floor(gy / 9)
    off = (row % 2) * 6
    seam = np.abs(((lx * (1 + 0.3 * np.abs(u)) + off) % 12) - 6)
    c = shade(col, light * 0.5 - smooth(1.2, 0.2, np.minimum(seam, np.abs((gy % 9) - 4.5))) * 0.18 + (vnoise(xx, yy, 5, seed) - 0.5) * 0.08)
    for k in range(windows):
        wy = top + h * (0.3 + k * 0.35)
        win = (np.abs(lx + r * 0.15) < 5) & (np.abs(gy - wy) < 8) | (np.hypot(lx + r * 0.15, gy - (wy - 8)) < 5)
        c = np.where(win[..., None], hexc("#3b3049"), c)
    edge = inside & ~ndimage.binary_erosion(inside)
    c = np.where(edge[..., None], shade(col, -0.5), c)
    oy, ox = int(top - r * 0.35), int(cx - S)
    L.over(c, a, oy, ox)


def _cone(L, cx, ybase, r, h, col, flag=True, seed=0):
    """원뿔 지붕: 왼쪽이 밝고 비늘 결, 처마가 살짝 둥글다. 꼭대기 깃발."""
    S = int(r + 8)
    yy, xx = np.mgrid[0:int(h + r * 0.5 + 30), 0:2 * S].astype(np.float32)
    lx = xx - S
    apex = 26
    gy = yy - apex  # 0 = 꼭대기
    t = np.clip(gy / h, 0, 1.2)
    halfw = r * t ** 0.85
    eave = h + r * 0.28 * np.sqrt(np.clip(1 - (lx / r) ** 2, 0, 1))
    inside = (np.abs(lx) < halfw) & (gy > 0) & (gy < eave)
    a = inside.astype(np.float32)
    u = np.clip(lx / np.maximum(halfw, 1), -1, 1)
    scale = 0.5 + 0.5 * np.cos(((gy % 10) / 10) * np.pi)
    c = shade(col, -u * 0.32 + 0.05 - scale * 0.08 + (vnoise(xx, yy, 3, 711 + seed) - 0.5) * 0.08)
    edge = inside & ~ndimage.binary_erosion(inside)
    c = np.where(edge[..., None], shade(col, -0.55), c)
    oy, ox = int(ybase - h - apex), int(cx - S)
    L.over(c, a, oy, ox)
    if flag:
        pole = (np.abs(lx) < 1.3) & (yy < apex + 2) & (yy > 2)
        L.over(hexc("#6e5a4a"), pole.astype(np.float32), oy, ox)
        fl = (lx > 1) & (lx < 20 + np.sin(yy * 0.6) * 2) & (yy > 3) & (yy < 13 + (lx - 1) * 0.05 * 0) & (yy < 13 - np.abs(lx - 10) * 0.0)
        L.over(hexc("#e9576a"), fl.astype(np.float32), oy, ox)


def _tower(L, cx, base, r, h, roof, flag=True, seed=0):
    L.over(SH, aa(np.hypot(*np.meshgrid(np.arange(-r * 2, r * 2) - 12.0, (np.arange(-r, r) - 4.0) * 2)) - r * 1.0, 4) * 0.3,
           int(base - r), int(cx - r * 2))
    _cyl(L, cx, base, r, h, STONE, 721 + seed, windows=1 if h < 80 else 2)
    _cone(L, cx, base - h + 4, r * 1.18, r * 1.6, roof, flag=flag, seed=seed)


def _box(L, x0, y0, w, h, col, seed, windows=0, arch=None):
    """앞면 벽(벽돌, 아치 창). (x0, y0)는 앞면 왼쪽 위."""
    yy, xx = np.mgrid[0:int(h), 0:int(w)].astype(np.float32)
    row = np.floor(yy / 10)
    off = (row % 2) * 9
    bid = _hash(np.floor((xx + off + x0) / 18).astype(np.int64), row.astype(np.int64), seed)
    fx, fy = (xx + off + x0) % 18, yy % 10
    seam = np.minimum(np.minimum(fx, 18 - fx), np.minimum(fy, 10 - fy))
    c = shade(mix(col, shade(col, -0.1), bid), -smooth(1.6, 0.2, seam) * 0.22 + (0.5 - xx / w) * 0.12 + (vnoise(xx + x0, yy + y0, 6, seed + 1) - 0.5) * 0.1)
    c = shade(c, -smooth(0.85, 1.0, yy / h) * 0.12)
    a = np.ones_like(xx)
    for k in range(windows):
        wx = (k + 0.5) * w / windows
        if arch and abs(wx - arch[0]) < arch[1] / 2 + 18:
            continue
        wy = h * 0.32
        win = ((np.abs(xx - wx) < 7) & (np.abs(yy - wy) < 11)) | (np.hypot(xx - wx, yy - (wy - 11)) < 7)
        c = np.where(win[..., None], mix(hexc("#3b3049"), hexc("#f2cf4a"), 0.25 * (k % 2)), c)
        frame = (((np.abs(xx - wx) < 9) & (np.abs(yy - wy) < 13)) | (np.hypot(xx - wx, yy - (wy - 11)) < 9)) & ~win
        c = np.where(frame[..., None], shade(col, 0.15), c)
    if arch:  # 큰 성문: 아치, 나무 문짝과 쇠창살
        ax, aw, ah = arch
        hole = (np.abs(xx - ax) < aw / 2) & (yy > h - ah + aw / 2) | (np.hypot(xx - ax, yy - (h - ah + aw / 2)) < aw / 2)
        ring = ((np.abs(xx - ax) < aw / 2 + 7) & (yy > h - ah + aw / 2) | (np.hypot(xx - ax, yy - (h - ah + aw / 2)) < aw / 2 + 7)) & ~hole
        c = np.where(ring[..., None], shade(col, 0.2), c)
        door = shade(hexc("#7a5636"), -smooth(0, ah, h - yy) * 0.1 + (np.abs(((xx - ax) % 9) - 4.5) < 0.9) * -0.2)
        bars = ((np.abs(((xx - ax) % 12) - 6) < 1.4) | (np.abs(((yy) % 14) - 7) < 1.4))
        door = np.where(bars[..., None], hexc("#4a3f45"), door)
        c = np.where(hole[..., None], door, c)
    edge = np.zeros_like(xx, bool)
    edge[:, :2] = edge[:, -2:] = True
    edge[-2:, :] = True
    c = np.where(edge[..., None], shade(col, -0.45), c)
    L.over(c, a, int(y0), int(x0))


def _battlement(L, x0, y, w, col, depth=16):
    """윗면 통로와 총안(앞쪽 가장자리)."""
    yy, xx = np.mgrid[0:depth + 12, 0:int(w)].astype(np.float32)
    topf = (yy > 12) & (yy < 12 + depth)
    c = np.broadcast_to(shade(col, 0.12), xx.shape + (3,)).copy()
    merl = (yy <= 12) & ((xx % 22) < 13) & (yy > 0)
    c = np.where(merl[..., None], shade(col, 0.02), c)
    a = (topf | merl).astype(np.float32)
    edge = (topf | merl) & ~ndimage.binary_erosion(topf | merl)
    c = np.where(edge[..., None], shade(col, -0.45), c)
    L.over(c, a, int(y - depth - 12), int(x0))


def _gable(L, x0, y0, w, h, col, seed):
    """본성 지붕: 앞쪽 경사면(비늘 기와), 양끝이 살짝 안으로."""
    yy, xx = np.mgrid[0:int(h), 0:int(w)].astype(np.float32)
    t = yy / h
    inset = (1 - t) * w * 0.16
    inside = (xx > inset) & (xx < w - inset)
    rowh = 9.0
    row = np.floor(yy / rowh)
    offx = (row % 2) * 7
    tx = (xx + offx) % 14 - 7
    ty = yy % rowh
    sc = ty - (rowh - 2.5 * np.sqrt(np.clip(1 - (tx / 7) ** 2, 0, 1)))
    c = shade(col, -smooth(-2.5, 0.5, sc) * 0.2 + (0.5 - xx / w) * 0.25 + (vnoise(xx, yy, 4, seed) - 0.5) * 0.08 - t * 0.08)
    edge = inside & ~ndimage.binary_erosion(inside)
    c = np.where(edge[..., None], shade(col, -0.55), c)
    L.over(c, inside.astype(np.float32), int(y0), int(x0))


# ---------- 성 ----------

def _castle(L, bd):
    rc = bd["rect"]
    X0 = rc[0] * TILE - L.x0
    Y0 = rc[1] * TILE - L.y0
    w, h = rc[2] * TILE, rc[3] * TILE
    if X0 > L.w + 200 or Y0 > L.h + 300 or X0 + w < -200 or Y0 + h < -300:
        return
    # 그림자
    L.over(SH, aa(np.hypot(*np.meshgrid((np.arange(-w * 0.7, w * 0.7) - 14) / (w * 0.55), (np.arange(-h * 0.5, h * 0.5) - 10) / (h * 0.42))) - 1, 0.02) * 0.3,
           int(Y0 + h * 0.55 - h * 0.5), int(X0 + w / 2 - w * 0.7))
    # 뒤쪽 탑 둘(더 높다)
    for fx in (0.12, 0.88):
        _tower(L, X0 + w * fx, Y0 + h * 0.5, 34, 210, ROOF, flag=True, seed=int(fx * 10))
    # 본성: 뒤에 높은 몸통과 지붕
    kx0, kw = X0 + w * 0.24, w * 0.52
    kbase = Y0 + h * 0.62
    kh = 200
    _gable(L, kx0 - 10, kbase - kh - 90, kw + 20, 96, ROOF, 731)
    _box(L, kx0, kbase - kh, kw, kh, STONE, 733, windows=4)
    _battlement(L, kx0 - 4, kbase - kh + 2, kw + 8, STONE)
    # 가운데 작은 탑(본성 앞)
    _tower(L, X0 + w * 0.5, kbase - kh + 30, 24, 70, ROOF, flag=True, seed=5)
    # 앞 성벽과 큰 성문(성문 칸 c가 아래 가운데)
    fh = 150
    fbase = Y0 + h
    gate_x = (bd["door"][0] - L.x0) - (X0 + 0.06 * w)
    _box(L, X0 + 0.06 * w, fbase - fh, w * 0.88, fh, STONE_D, 741, windows=6, arch=(gate_x, 70, 96))
    _battlement(L, X0 + 0.06 * w - 4, fbase - fh + 2, w * 0.88 + 8, STONE_D)
    # 깃발 휘장(성문 양옆)
    for s in (-1, 1):
        bx = X0 + 0.06 * w + gate_x + s * 62
        yy, xx = np.mgrid[0:70, 0:26].astype(np.float32)
        ban = (yy < 60 - np.abs(xx - 13) * 0.6)
        c = shade(hexc("#b8475a"), (0.5 - xx / 26) * 0.3)
        c = np.where(((np.abs(xx - 13) < 6) & (np.abs(yy - 26) < 6))[..., None], hexc("#f2cf4a"), c)
        L.over(c, ban.astype(np.float32), int(fbase - fh + 22), int(bx - 13))
    # 앞쪽 탑 둘
    for fx in (0.05, 0.95):
        _tower(L, X0 + w * fx, fbase + 6, 40, 180, ROOF, flag=True, seed=int(fx * 100))
