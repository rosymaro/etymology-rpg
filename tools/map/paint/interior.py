#!/usr/bin/env python3
"""성 안 지도 그림(사용자 의견: 성의 퀄리티를 동화책 삽화풍으로). 칸(data/map/world.json cave_maps.s01_castle)은 그대로.

돌바닥 판석, 손으로 쌓은 벽(윗면이 밝고 바닥 쪽은 그늘), 금테 붉은 융단, 둥근 기둥, 왕좌와 휘장,
서쪽 방 책장(서고), 동쪽 방 무기 걸이(무기고), 벽의 횃불. 결과: assets/map/caves/s01_castle.webp
쓰는 법: python3 tools/map/paint/interior.py [--out 폴더]
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from core import TILE, Layer, aa, fbm, hexc, mix, shade, smooth, vnoise, voronoi  # noqa: E402
from castle import masonry, moss_ivy, wobble_edge, finish, SH  # noqa: E402
from world import ROOT  # noqa: E402

FLOOR = hexc("#e3d6c0")
WALLC = hexc("#857c8e")
CARPET = hexc("#b8475a")
GOLD = hexc("#f2cf4a")
WOOD = hexc("#8a5f3a")


def paint(cm):
    rows = np.array([list(r) for r in cm["rows"]])
    H, W = rows.shape
    h, w = H * TILE, W * TILE
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    L = Layer(0, 0, w, h)
    cx = np.clip((xx // TILE).astype(int), 0, W - 1)
    cy = np.clip((yy // TILE).astype(int), 0, H - 1)
    wall = rows[cy, cx] == "^"
    # 바닥: 큰 판석(따뜻한 베이지), 가운데 길은 붉은 융단과 금테
    floor = masonry(xx, yy, FLOOR, 901, size=28, flat=True)
    floor = shade(floor, (fbm(xx, yy, 200, 903, 3) - 0.5) * 0.12)
    L.over(floor, np.ones((h, w), np.float32))
    mx = W // 2
    carpet_zone = (np.abs(xx - (mx + 0.5) * TILE) < TILE * 1.25) & (yy > TILE * 1.6)
    edge = np.abs(np.abs(xx - (mx + 0.5) * TILE) - TILE * 1.05) < 5
    ux = np.abs(xx - (mx + 0.5) * TILE)
    pattern = (np.abs(ux / 22 + np.abs(((yy / 64) % 1.0) - 0.5) * 2.2 - 0.9) < 0.07) & (ux < TILE * 0.8)  # 마름모 무늬
    cc = shade(CARPET, (vnoise(xx * 0.5, yy * 0.5, 2, 905) - 0.5) * 0.12 + (0.5 - (xx - (mx - 1) * TILE) / (3 * TILE)) * 0.1)
    cc = np.where(edge[..., None], GOLD, cc)
    cc = np.where(pattern[..., None], shade(GOLD, -0.1), cc)
    sd = wobble_edge(carpet_zone & ~wall, xx, yy, 907, 0.8)
    c, a = finish(cc, sd, shade(CARPET, -0.5), 0.9)
    L.over(c, a)
    # 서고·무기고 바닥 깔개
    for (x0, y0, x1, y1, col) in ((3, 9, 10, 15, hexc("#5f7fc8")), (W - 11, 9, W - 4, 15, hexc("#7f9a5a"))):
        rx0, rx1, ry0, ry1 = (x0 + 1.2) * TILE, (x1 - 0.2) * TILE, (y0 + 1.4) * TILE, (y1 - 0.4) * TILE
        rcx, rcy = (rx0 + rx1) / 2, (ry0 + ry1) / 2
        rsd = np.maximum(np.abs(xx - rcx) - (rx1 - rx0) / 2 + 18, np.abs(yy - rcy) - (ry1 - ry0) / 2 + 18)
        rsd = np.where(rsd > 0, np.hypot(np.maximum(np.abs(xx - rcx) - (rx1 - rx0) / 2 + 18, 0), np.maximum(np.abs(yy - rcy) - (ry1 - ry0) / 2 + 18, 0)), rsd) - 18
        rc = shade(col, (vnoise(xx, yy, 3, 909) - 0.5) * 0.1)
        border = (rsd > -14) & (rsd < -4)
        rc = np.where(border[..., None], shade(GOLD, -0.05), rc)
        dia = np.abs(np.abs(xx - rcx) / ((rx1 - rx0) * 0.32) + np.abs(yy - rcy) / ((ry1 - ry0) * 0.32) - 1) < 0.05
        dia |= np.abs(np.abs(xx - rcx) / ((rx1 - rx0) * 0.14) + np.abs(yy - rcy) / ((ry1 - ry0) * 0.14) - 1) < 0.1
        rc = np.where(dia[..., None], shade(GOLD, 0.05), rc)
        rc = shade(rc, -smooth(-30, 0, rsd) * 0.0 + smooth(-40, 0, rsd) * -0.08)
        fringe = (np.abs(xx - rcx) < (rx1 - rx0) / 2 - 20) & (np.abs(np.abs(yy - rcy) - (ry1 - ry0) / 2) < 8) & ((xx % 7) < 3)
        c, a = finish(rc, rsd + (vnoise(xx, yy, 9, 910) - 0.5) * 2, shade(col, -0.5))
        L.over(SH, ndimage.gaussian_filter((rsd < 0).astype(np.float32), 4) * 0.0)
        L.over(c, a * 0.95)
        L.over(shade(GOLD, -0.1), fringe.astype(np.float32))
    # 벽: 손으로 쌓은 돌, 바닥과 닿는 아래쪽 면(앞면)은 조금 어둡고, 윗면 가장자리 밝게
    wc = masonry(xx, yy, WALLC, 911, size=15)
    below_floor = np.zeros_like(wall)
    below_floor[:-1] = ~wall[1:] & wall[:-1]
    front = np.zeros_like(wall)
    for d in range(1, 26):  # 바닥 바로 위 벽 26px = 벽의 앞면
        front[:-d] |= wall[:-d] & ~wall[d:]
    depth = ndimage.distance_transform_edt(wall)
    wc = shade(wc, -smooth(6, 60, depth) * 0.3 + smooth(10, 2, depth) * 0.12)  # 벽 덩어리 안쪽은 어둡고 가장자리는 밝게
    wc = np.where(front[..., None], shade(masonry(xx, yy, shade(WALLC, 0.05), 913, size=11), -0.02), wc)
    rel = np.zeros_like(xx)
    wc = moss_ivy(wc, xx, yy, np.where(front, 0.85, 0.0), 915, 0.5)
    sdw = wobble_edge(wall, xx, yy, 917, 1.0)
    wcol, wa = finish(wc, sdw, shade(WALLC, -0.55))
    # 벽 그림자(바닥 쪽으로)
    sh = ndimage.gaussian_filter(ndimage.shift(wall.astype(np.float32), (14, 8), order=0), 6) * (1 - wall) * 0.32
    L.over(SH, sh)
    L.over(wcol, wa)
    # 나가는 곳: 따뜻한 빛
    ys, xs = np.nonzero(rows == "x")
    for y, x in zip(ys, xs):
        glow = aa(np.hypot(xx - (x + 0.5) * TILE, (yy - (y + 0.5) * TILE) * 1.4) - TILE * 1.2, 30)
        L.over(hexc("#fff3c4"), glow * 0.55)
    # 기둥(왕좌의 방): 둥근 돌기둥, 왼쪽 밝게
    ys, xs = np.nonzero(rows == "^")
    for y, x in zip(ys, xs):
        if 1 <= y <= 6 and abs(x - mx) == 3 and rows[y - 1, x] == "k":
            _pillar(L, xx, yy, (x + 0.5) * TILE, (y + 1) * TILE - 6)
    _throne(L, xx, yy, (mx + 0.5) * TILE, 1.2 * TILE)
    # 서고: 벽 앞 책장, 무기고: 무기 걸이와 방패
    for k in range(3):
        _shelf(L, (3.6 + k * 2.2) * TILE, 9.05 * TILE, k)
    for k in range(3):
        _rack(L, (W - 10.4 + k * 2.2) * TILE, 9.05 * TILE, k)
    # 횃불(벽 앞면에)
    for (tx, ty) in ((mx - 5, 16), (mx + 5, 16), (mx - 6, 1), (mx + 6, 1), (6, 9), (W - 7, 9)):
        _torch(L, (tx + 0.5) * TILE, (ty + 0.05) * TILE)
    return L.rgba8((0, 0, w, h))


def _pillar(L, xx, yy, cx, base):
    r = 17
    lx = xx - cx
    m = (np.abs(lx) < r) & (yy > base - 80) & (yy < base)
    u = np.clip(lx / r, -1, 1)
    col = shade(masonry(np.arcsin(u) * r + cx, yy, hexc("#d8cfc6"), 921, size=10), -u * 0.4 + 0.05)
    cap = (np.abs(lx) < r + 5) & (np.abs(yy - (base - 80)) < 6) | (np.abs(lx) < r + 6) & (np.abs(yy - base + 4) < 5)
    col = np.where(cap[..., None], shade(hexc("#e8e0d6"), -u * 0.3), col)
    allm = m | cap
    L.over(SH, aa(np.hypot((lx - 10) / 26, (yy - base - 2) / 9) - 1, 0.1) * 0.3)
    c, a = finish(col, wobble_edge(allm, xx, yy, 923, 0.8), shade(hexc("#9d93a0"), -0.5))
    L.over(c, a)


def _throne(L, xx, yy, cx, top):
    lx = xx - cx
    back = (np.abs(lx) < 30 - np.clip((yy - top) * 0.0, 0, 0)) & (yy > top) & (yy < top + 70) | (np.hypot(lx, yy - top) < 30) & (yy <= top)
    seat = (np.abs(lx) < 36) & (yy > top + 50) & (yy < top + 82)
    col = np.where(back[..., None], shade(GOLD, -np.clip(lx / 30, -1, 1) * 0.25), shade(hexc("#c9a227"), -0.05))
    cushion = (np.abs(lx) < 22) & (yy > top + 8) & (yy < top + 60)
    col = np.where(cushion[..., None], shade(CARPET, -np.clip(lx / 22, -1, 1) * 0.2), col)
    gem = np.hypot(lx, yy - top + 8) < 6
    col = np.where(gem[..., None], hexc("#7fd8e0"), col)
    m = back | seat
    L.over(SH, aa(np.hypot((lx - 14) / 46, (yy - top - 86) / 12) - 1, 0.1) * 0.3)
    c, a = finish(col, wobble_edge(m, xx, yy, 931, 0.8), shade(hexc("#c9a227"), -0.55))
    L.over(c, a)
    # 뒤 벽의 큰 휘장 둘
    for s in (-1, 1):
        bx = cx + s * 90
        b = (np.abs(xx - bx) < 20) & (yy > 4) & (yy < 110 - np.abs(xx - bx) * 0.6)
        bc = shade(hexc("#5f7fc8"), (np.sin((xx - bx) * 0.4) * 0.1) - np.clip((xx - bx) / 20, -1, 1) * 0.15)
        bc = np.where((np.hypot(xx - bx, yy - 50) < 8)[..., None], GOLD, bc)
        L.over(bc, b.astype(np.float32))


def _shelf(L, x0, y0, k):
    w, h = 120, 46
    yy, xx = np.mgrid[0:h, 0:int(w)].astype(np.float32)
    col = shade(WOOD, (vnoise(xx * 0.3, yy, 3, 941 + k) - 0.5) * 0.15)
    for r in range(3):
        sy = 4 + r * 14
        books = (yy > sy) & (yy < sy + 11) & (xx > 4) & (xx < w - 4)
        bid = np.floor(xx / 7)
        from core import _hash
        bc = np.stack([_hash(bid.astype(np.int64) + r * 31 + k * 7, np.zeros_like(bid, np.int64) + c, 943) for c in range(3)], -1) * 0.5 + 0.35
        gap = ((xx % 7) < 1.0)
        col = np.where((books & ~gap)[..., None], bc, col)
    L.over(SH, np.ones_like(xx) * 0.0, int(y0), int(x0))
    edge = np.zeros_like(xx, bool)
    edge[:, :2] = edge[:, -2:] = edge[:2, :] = edge[-2:, :] = True
    col = np.where(edge[..., None], shade(WOOD, -0.5), col)
    L.over(col, np.ones_like(xx), int(y0), int(x0))


def _rack(L, x0, y0, k):
    w, h = 120, 60
    yy, xx = np.mgrid[0:h, 0:int(w)].astype(np.float32)
    a = np.zeros_like(xx)
    col = np.zeros(xx.shape + (3,), np.float32)
    bar = (np.abs(yy - 12) < 3) & (xx > 4) & (xx < w - 4)
    col[bar] = shade(WOOD, -0.1)
    a = np.maximum(a, bar)
    for s in range(3):  # 창·칼 세 자루
        px = 22 + s * 38
        shaft = (np.abs(xx - px) < 2) & (yy > 2) & (yy < 56)
        tip = (np.abs(xx - px) < 5 - (yy - 2) * 0.5) & (yy > 0) & (yy < 10)
        col[shaft] = WOOD
        col[tip] = hexc("#d8dce8")
        a = np.maximum(a, shaft | tip)
    shield = np.hypot((xx - w / 2) / 16, (yy - 36) / 18) < 1
    sc = shade(hexc("#b8475a"), -np.clip((xx - w / 2) / 16, -1, 1) * 0.2)
    col = np.where(shield[..., None], sc, col)
    a = np.maximum(a, shield)
    L.over(col, a.astype(np.float32), int(y0), int(x0))


def _torch(L, cx, y):
    yy, xx = np.mgrid[0:90, 0:90].astype(np.float32)
    lx, ly = xx - 45, yy - 30
    glow = aa(np.hypot(lx, ly) - 34, 22) * 0.35
    L.over(hexc("#ffcf6b"), glow, int(y - 30), int(cx - 45))
    stick = (np.abs(lx) < 3) & (ly > 0) & (ly < 22)
    L.over(WOOD, stick.astype(np.float32), int(y - 30), int(cx - 45))
    flame = np.hypot(lx / 7, (ly + 4) / 11) < 1
    L.over(mix(hexc("#ff9a4a"), hexc("#ffe07a"), smooth(6, -8, ly)), flame.astype(np.float32), int(y - 30), int(cx - 45))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "assets/map/caves"))
    a = ap.parse_args()
    d = json.load(open(os.path.join(ROOT, "data/map/world.json"), encoding="utf-8"))
    os.makedirs(a.out, exist_ok=True)
    img = paint(d["cave_maps"]["s01_castle"])
    p = os.path.join(a.out, "s01_castle.webp")
    Image.fromarray(img[..., :3], "RGB").save(p, "WEBP", quality=88, method=5)
    imp = p + ".import"
    if not os.path.exists(imp):
        with open(imp, "w") as f:
            f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=1\ncompress/lossy_quality=0.85\nmipmaps/generate=false\n')
    print("→", p)


if __name__ == "__main__":
    main()
