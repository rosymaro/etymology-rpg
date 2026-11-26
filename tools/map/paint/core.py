"""지도 그림 공통: 결정적인 잡음(fBm), 부드러운 칸 경계, 색 섞기, 겹치기, 도장(작은 모양) 그리기.

모든 잡음은 지도 전체 좌표(px)로 정해져서 조각(1024×1536)을 따로 그려도 이음매가 없다.
빛은 늘 왼쪽 위에서 온다(LIGHT). 그림자는 오른쪽 아래로 진다.
"""
import numpy as np
from scipy import ndimage

TILE = 64
LIGHT = np.array([-0.55, -0.65, 0.52])  # 왼쪽 위 앞에서
LIGHT = LIGHT / np.linalg.norm(LIGHT)
SHADOW = np.array([9.0, 12.0])  # 그림자 방향(px, 오른쪽 아래)


# ---------- 잡음 ----------

def _hash(ix, iy, seed):
    h = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF).astype(np.float32) / float(0xFFFFFF)


def hash1(i, j, seed):
    """칸·점마다 정해진 0~1 값(스칼라)."""
    return float(_hash(np.array(i), np.array(j), seed))


def vnoise(X, Y, scale, seed):
    fx = X / scale
    fy = Y / scale
    ix = np.floor(fx)
    iy = np.floor(fy)
    tx = fx - ix
    ty = fy - iy
    tx = tx * tx * (3 - 2 * tx)
    ty = ty * ty * (3 - 2 * ty)
    ix = ix.astype(np.int64)
    iy = iy.astype(np.int64)
    a = _hash(ix, iy, seed)
    b = _hash(ix + 1, iy, seed)
    c = _hash(ix, iy + 1, seed)
    d = _hash(ix + 1, iy + 1, seed)
    return (a + (b - a) * tx) + ((c + (d - c) * tx) - (a + (b - a) * tx)) * ty


def fbm(X, Y, scale, seed, octaves=4, gain=0.5):
    out = np.zeros_like(X, dtype=np.float32)
    amp, tot, s = 1.0, 0.0, scale
    for o in range(octaves):
        out += amp * vnoise(X, Y, s, seed + o * 101)
        tot += amp
        amp *= gain
        s *= 0.5
    return out / tot


def ridged(X, Y, scale, seed, octaves=3):
    return 1.0 - np.abs(fbm(X, Y, scale, seed, octaves) * 2 - 1)


def warp(X, Y, scale, amt, seed):
    """좌표를 잡음으로 비틀기(손그림 결)."""
    return (X + (fbm(X, Y, scale, seed, 3) - 0.5) * 2 * amt, Y + (fbm(X, Y, scale, seed + 7, 3) - 0.5) * 2 * amt)


def voronoi(X, Y, cell, seed, jitter=0.85):
    """돌·판 무늬: 가장 가까운 점까지 거리(d1), 두 번째와의 차(d2-d1, 이음매), 점 id."""
    gx = np.floor(X / cell).astype(np.int64)
    gy = np.floor(Y / cell).astype(np.int64)
    d1 = np.full(X.shape, 1e9, np.float32)
    d2 = np.full(X.shape, 1e9, np.float32)
    idv = np.zeros(X.shape, np.float32)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            cx = gx + ox
            cy = gy + oy
            px = (cx + 0.5 + (_hash(cx, cy, seed) - 0.5) * jitter) * cell
            py = (cy + 0.5 + (_hash(cx, cy, seed + 3) - 0.5) * jitter) * cell
            d = np.hypot(X - px, Y - py)
            closer = d < d1
            d2 = np.where(closer, d1, np.minimum(d2, d))
            idv = np.where(closer, _hash(cx, cy, seed + 9), idv)
            d1 = np.where(closer, d, d1)
    return d1, d2 - d1, idv


# ---------- 칸 → 부드러운 판 ----------

def cell_field(mask, sigma):
    """칸(지도 전체) 0/1 → 흐린 값. 경계가 칸 모양이 아니라 둥글고 부드럽게."""
    f = mask.astype(np.float32)
    return ndimage.gaussian_filter(f, sigma, mode="nearest") if sigma > 0 else f


def sample(field, X, Y):
    """칸 단위 판(지도 전체)을 픽셀 좌표에서 읽는다(쌍선형)."""
    cy = Y / TILE - 0.5
    cx = X / TILE - 0.5
    if field.ndim == 2:
        return ndimage.map_coordinates(field, [cy, cx], order=1, mode="nearest").astype(np.float32)
    return np.stack([ndimage.map_coordinates(field[..., k], [cy, cx], order=1, mode="nearest") for k in range(field.shape[2])], -1).astype(np.float32)


def organic(field_px, X, Y, seed, amp=0.22, scale=46, edge=0.04):
    """부드러운 판 + 잡음 → 불규칙한 경계의 알파(0~1, 가장자리만 부드럽게)."""
    n = (fbm(X, Y, scale, seed, 4) - 0.5) * 2 * amp
    v = field_px + n
    return smooth(0.5 - edge, 0.5 + edge, v), v


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def bbox(a, pad=4):
    """알파가 있는 곳만 둘러싼 범위(무거운 무늬는 여기서만 계산)."""
    ys = np.nonzero(a.max(axis=1) > 0)[0]
    if len(ys) == 0:
        return None
    xs = np.nonzero(a.max(axis=0) > 0)[0]
    y0, y1 = max(0, ys[0] - pad), min(a.shape[0], ys[-1] + pad + 1)
    x0, x1 = max(0, xs[0] - pad), min(a.shape[1], xs[-1] + pad + 1)
    return (slice(y0, y1), slice(x0, x1))


# ---------- 색 ----------

def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def mix(a, b, t):
    t = np.asarray(t, np.float32)
    if t.ndim and t.shape[-1] != 1 and np.ndim(a) and np.shape(a)[-1] == 3:
        t = t[..., None]
    return a + (b - a) * t


def shade(c, k):
    """k>0 밝게(따뜻하게), k<0 어둡게(차갑게). 동화풍: 그늘은 보라·파랑 쪽으로."""
    k = np.asarray(k, np.float32)
    if k.ndim:
        k = k[..., None]
    warm = np.array([1.0, 0.97, 0.86], np.float32)
    cool = np.array([0.36, 0.33, 0.52], np.float32)
    return np.where(k >= 0, c + (warm - c) * k * 0.9, c + (cool - c) * (-k)).astype(np.float32)


# ---------- 겹치기 ----------

class Layer:
    """곧은 알파(straight alpha) RGBA 캔버스. 원점(x0, y0)은 지도 좌표."""

    def __init__(self, x0, y0, w, h, opaque=None):
        self.x0, self.y0, self.w, self.h = x0, y0, w, h
        self.rgb = np.zeros((h, w, 3), np.float32)
        self.a = np.zeros((h, w), np.float32)
        if opaque is not None:
            self.rgb[:] = opaque
            self.a[:] = 1

    def over(self, rgb, a, y0=0, x0=0):
        """(y0, x0)에서 시작하는 조각을 위에 얹는다. rgb: (h,w,3) 또는 (3,)"""
        h, w = a.shape
        ys, xs = max(0, y0), max(0, x0)
        ye, xe = min(self.h, y0 + h), min(self.w, x0 + w)
        if ye <= ys or xe <= xs:
            return
        sa = a[ys - y0:ye - y0, xs - x0:xe - x0]
        if np.ndim(rgb) == 1:
            sc = rgb
        else:
            sc = rgb[ys - y0:ye - y0, xs - x0:xe - x0]
        da = self.a[ys:ye, xs:xe]
        dc = self.rgb[ys:ye, xs:xe]
        oa = sa + da * (1 - sa)
        safe = np.maximum(oa, 1e-6)[..., None]
        self.rgb[ys:ye, xs:xe] = (sc * sa[..., None] + dc * (da * (1 - sa))[..., None]) / safe
        self.a[ys:ye, xs:xe] = oa

    def rgba8(self, crop):
        x, y, w, h = crop
        rgb = np.clip(self.rgb[y:y + h, x:x + w], 0, 1)
        a = np.clip(self.a[y:y + h, x:x + w], 0, 1)
        return (np.concatenate([rgb, a[..., None]], -1) * 255 + 0.5).astype(np.uint8)


# ---------- 도장(작은 모양) ----------

def grid(h, w, cy, cx):
    """도장용 좌표판: 중심 (cy, cx) 기준 픽셀 좌표."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    return xx - cx, yy - cy


def blob_sdf(dx, dy, r, seed, wob=0.14, lobes=7):
    """둥근 덩어리(울퉁불퉁한 가장자리)의 부호 거리."""
    ang = np.arctan2(dy, dx)
    d = np.hypot(dx, dy)
    k = seed * 0.6180339
    edge = r * (1 + wob * (np.sin(ang * lobes + k * 6.28) * 0.6 + np.sin(ang * (lobes + 4) + k * 17.0) * 0.4))
    return d - edge


def seg_sdf(px, py, ax, ay, bx, by):
    """선분까지 거리와 선분 위 위치 t(0~1)."""
    vx, vy = bx - ax, by - ay
    l2 = vx * vx + vy * vy + 1e-6
    t = np.clip(((px - ax) * vx + (py - ay) * vy) / l2, 0, 1)
    return np.hypot(px - (ax + vx * t), py - (ay + vy * t)), t


def aa(sdf, soft=1.0):
    """부호 거리 → 알파(가장자리 1px 부드럽게)."""
    return np.clip(0.5 - sdf / (2 * soft), 0, 1)


def sphere_light(dx, dy, r):
    """둥근 덩어리의 빛(왼쪽 위가 밝다): -1~1."""
    nx = dx / r
    ny = dy / r
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    return nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
