"""바닥 겹(ground): 땅의 붓결, 숲 바닥, 길·광장·돌길·밭·얼음·절벽·성벽·생울타리, 물·바닷가·용암, 다리, 울타리.

경계는 칸 모양이 아니라 흐린 칸 판 + 잡음으로 정한 불규칙한 선이다. 판정(칸)은 그대로다.
"""
import numpy as np

from core import (TILE, aa, bbox, fbm, hexc, mix, organic, ridged, sample, shade, smooth, vnoise, voronoi, warp)
from world import biome_color


def _lava_w(W, X, Y):
    if "lava" not in W._fields:
        m = W.stage == 9
        from core import cell_field
        W._fields["lava"] = cell_field(m, 1.2)
    return sample(W._fields["lava"], X, Y)


def _name_w(W, name, X, Y, sigma=1.2):
    k = ("bname", name)
    if k not in W._fields:
        from core import cell_field
        m = np.zeros_like(W.stage, bool)
        for s, b in W.bio.items():
            if b["name"] == name and s != 0:
                m |= W.stage == s
        W._fields[k] = cell_field(m, sigma)
    return sample(W._fields[k], X, Y)


def paint(W, L, X, Y):
    rgb = L.rgb
    snow_w = _name_w(W, "snow", X, Y)
    desert_w = _name_w(W, "desert", X, Y)
    lava_w = _lava_w(W, X, Y)

    # ---- 땅: 지역 색 두 가지를 큰 얼룩으로 섞고, 붓결과 빛 얼룩을 더한다
    g0 = sample(W.color("ground", 0), X, Y)
    g1 = sample(W.color("ground", 1), X, Y)
    patch = fbm(X, Y, 300, 11, 4)
    base = mix(g0, g1, smooth(0.3, 0.7, patch))
    grass_c = sample(W.color("grass", 0), X, Y)
    base = mix(base, grass_c, 0.22 * (1 - desert_w) * (1 - snow_w) * (1 - lava_w))
    # 따뜻한 풀빛과 서늘한 풀빛 얼룩(같은 초록이 반복되지 않게)
    hue = fbm(X, Y, 180, 13, 3)
    base = mix(base, base * np.array([1.04, 1.03, 0.9], np.float32), smooth(0.5, 0.8, hue))
    base = mix(base, base * np.array([0.93, 1.0, 1.03], np.float32), smooth(0.5, 0.2, hue))
    # 붓결: 짧은 붓질 무늬를 세 단계로(물감 덩어리처럼 경계가 보이게)
    Xw, Yw = warp(X, Y, 140, 26, 21)
    strokes = 0.6 * vnoise(Xw * 0.3, Yw, 5.0, 23) + 0.4 * vnoise(Xw * 0.22 + Yw * 0.14, Yw * 1.1, 7.0, 29)
    dab = smooth(0.38, 0.46, strokes) * 0.5 + smooth(0.56, 0.64, strokes) * 0.5
    light = fbm(X, Y, 520, 41, 3)
    k = (dab - 0.5) * 0.13 + (light - 0.5) * 0.2 + (fbm(X, Y, 70, 43, 3) - 0.5) * 0.16
    base = shade(base, k)
    # 사막: 바람이 만든 모래 물결(구불구불한 곡선)
    Xd, Yd = warp(X, Y, 200, 60, 51)
    dune = np.sin((Yd + 0.35 * Xd) / 15.0 + fbm(X, Y, 90, 53, 2) * 5.0)
    dune_k = (smooth(0.55, 1.0, dune) * 0.09 - smooth(0.6, 1.0, -dune) * 0.07) * desert_w
    base = shade(base, dune_k)
    # 눈: 쌓인 눈의 부드러운 둔덕(푸른 그늘)
    drift = fbm(X, Y, 110, 61, 4)
    base = shade(base, (smooth(0.45, 0.8, drift) * 0.10 - smooth(0.5, 0.15, drift) * 0.16) * snow_w)
    # 용암 지대: 검은 재, 갈라진 땅 사이로 빛나는 용암
    ash = fbm(X, Y, 30, 71, 3)
    base = mix(base, shade(base, (ash - 0.5) * 0.35), lava_w)
    crack = ridged(*warp(X, Y, 80, 18, 73), 70, 75, 3)
    glow = smooth(0.90, 0.985, crack) * lava_w * smooth(0.45, 0.6, fbm(X, Y, 160, 77, 2))
    base = mix(base, hexc("#ff8a3d"), glow * 0.9)
    base = mix(base, hexc("#ffe07a"), smooth(0.965, 0.995, crack) * glow)
    halo = smooth(0.80, 0.95, crack) * lava_w * smooth(0.45, 0.6, fbm(X, Y, 160, 77, 2))
    base = mix(base, hexc("#c4553a"), halo * 0.25)
    rgb[:] = base
    L.a[:] = 1

    # ---- 숲 바닥: 나무 밑은 그늘지고 이끼 낀 흙
    fa, fv = organic(sample(W.field("forest", 0.9), X, Y), X, Y, 81, amp=0.2, scale=50, edge=0.12)
    tree0 = sample(W.color("tree", 0), X, Y)
    floor = shade(mix(rgb, tree0, 0.5), -0.2 + (fbm(X, Y, 25, 83, 3) - 0.5) * 0.22)
    L.over(floor, fa * 0.8)

    # ---- 밭: 이랑과 작물
    fa, fv = organic(sample(W.field("farm", 0.45), X, Y), X, Y, 91, amp=0.12, scale=30)
    bb = bbox(fa)
    if bb:
        X0, Y0 = X, Y
        X, Y, fa = X[bb], Y[bb], fa[bb]
        rows = np.sin(Y / 7.0 + fbm(X, Y, 60, 93, 2) * 2)
        soil = mix(hexc("#a57c52"), hexc("#7d5a3a"), smooth(-0.2, 0.6, rows))
        crop = (rows > 0.55) & (vnoise(X, Y, 5, 95) > 0.42)
        soil = np.where(crop[..., None], mix(hexc("#7fae4f"), hexc("#a6cf68"), vnoise(X, Y, 3, 97)), soil)
        L.over(soil, fa, bb[0].start, bb[1].start)
        X, Y = X0, Y0

    # ---- 길: 구불구불하고 폭이 조금씩 다르며 가장자리는 울퉁불퉁. 가운데는 닳아 밝고, 가장자리엔 자갈
    pa, pv = organic(sample(W.field("path", 0.62), X, Y), X, Y, 101, amp=0.28, scale=38, edge=0.05)
    bb = bbox(pa)
    if bb:
        Xs, Ys, av, vv = X[bb], Y[bb], pa[bb], pv[bb]
        pc = _path_color(W, Xs, Ys)
        tex = (fbm(Xs, Ys, 20, 103, 3) - 0.5) * 0.24 + (vnoise(Xs * 0.4, Ys, 3, 105) - 0.5) * 0.1
        worn = smooth(0.66, 1.0, vv) * 0.12
        rim = -smooth(0.66, 0.5, vv) * 0.2
        path = shade(pc, tex + worn + rim)
        # 바퀴 자국처럼 옅은 두 줄, 흩어진 자갈(가장자리에 많다)
        d1, gap, pid = voronoi(Xs, Ys, 10, 107)
        edge_more = smooth(0.75, 0.52, vv)
        peb = (d1 < 1.6 + pid * 2.2) & (pid > 0.965 - edge_more * 0.3)
        pebc = shade(mix(pc, hexc("#8f8579"), 0.55), (pid - 0.8) * 1.2)
        path = np.where(peb[..., None], pebc, path)
        L.over(path, av, bb[0].start, bb[1].start)
    # ---- 마을 광장·건물 터: 손으로 깐 둥근 돌
    _cobble(L, W, X, Y, "plaza", 0.55, 15, "#ebe1cc", "#ddd0b6", 111)
    _cobble(L, W, X, Y, "stone", 0.5, 12, "#cfc8bb", "#b7ae9f", 121)

    # ---- 얼음: 옅은 파랑, 흰 금과 반짝이는 결
    ia, iv = organic(sample(W.field("ice", 0.5), X, Y), X, Y, 131, amp=0.15, scale=24)
    bb = bbox(ia)
    if bb:
        X0, Y0 = X, Y
        X, Y, ia = X[bb], Y[bb], ia[bb]
        ice = mix(hexc("#d6eef9"), hexc("#a9d6ee"), fbm(X, Y, 40, 133, 3))
        cr = ridged(X, Y, 36, 135, 2)
        ice = mix(ice, hexc("#ffffff"), smooth(0.93, 0.99, cr) * 0.9)
        ice = mix(ice, hexc("#ffffff"), smooth(0.7, 0.95, vnoise(X * 0.3 + Y, Y * 0.3, 8, 137)) * 0.35)
        L.over(ice, ia, bb[0].start, bb[1].start)
        X, Y = X0, Y0

    # ---- 절벽: 층진 바위(빛을 받는 윗면, 그늘진 아랫면), 위 가장자리엔 풀
    _cliff(L, W, X, Y)
    # ---- 성벽(눈 덮인 땅)·생울타리(꽃나무 정원)
    _wall(L, W, X, Y)

    # ---- 물: 깊이에 따라 진하게, 물가는 얕은 옥빛, 모래 띠와 거품. 용암 지대는 끓는 용암
    _water(L, W, X, Y, lava_w, snow_w)
    # ---- 다리, 울타리, 분수
    _bridges(L, W, X, Y)
    _fountains(L, W)
    _fences(L, W, X, Y)


def _path_color(W, X, Y):
    return sample(W.color("style:path", 0, 2.0), X, Y)


def _cobble(L, W, X, Y, name, sigma, cell, c1, c2, seed):
    a, v = organic(sample(W.field(name, sigma), X, Y), X, Y, seed, amp=0.16, scale=34, edge=0.05)
    bb = bbox(a)
    if not bb:
        return
    X, Y, a, v, oy, ox = X[bb], Y[bb], a[bb], v[bb], bb[0].start, bb[1].start
    Xw, Yw = warp(X, Y, 40, 3.5, seed + 1)
    d1, gap, sid = voronoi(Xw, Yw, cell, seed + 2)
    stone = mix(hexc(c1), hexc(c2), sid)
    stone = shade(stone, (fbm(X, Y, 9, seed + 3, 2) - 0.5) * 0.12 - smooth(3.0, 0.0, gap) * 0.14)
    mortar = shade(mix(hexc(c2), hexc("#a39d8c"), 0.4), -0.08)
    col = mix(mortar, stone, smooth(0.4, 1.6, gap))
    # 가장자리는 돌이 듬성듬성해지며 흙·풀과 섞인다
    keep = smooth(0.5, 0.62, v + (sid - 0.5) * 0.12)
    L.over(col, a * np.maximum(keep, smooth(0.62, 0.7, v)), oy, ox)


def _cliff(L, W, X, Y):
    ca, cv = organic(sample(W.field("cliff", 0.55), X, Y), X, Y, 141, amp=0.2, scale=30, edge=0.04)
    bb = bbox(ca, 8)
    if not bb:
        return
    X, Y, ca, cv, oy, ox = X[bb], Y[bb], ca[bb], cv[bb], bb[0].start, bb[1].start
    m0 = sample(W.color("mountain", 0), X, Y)
    m1 = sample(W.color("mountain", 1), X, Y)
    Xw, Yw = warp(X, Y, 50, 10, 143)
    strata = np.sin(Yw / 6.5 + fbm(X, Y, 70, 145, 2) * 4.0)
    rock = mix(m1, m0, smooth(-0.6, 0.8, strata))
    d1, gap, rid = voronoi(Xw * 0.7, Yw * 1.4, 18, 147)
    rock = shade(rock, (rid - 0.5) * 0.16 - smooth(2.0, 0.0, gap) * 0.28 + (fbm(X, Y, 12, 149, 2) - 0.5) * 0.14)
    # 위(북쪽)를 보는 면은 밝게, 아래는 그늘: 칸 판의 세로 기울기
    f = sample(W.field("cliff", 0.55), X, Y)
    gy = np.gradient(f, axis=0) * 40
    rock = shade(rock, np.clip(gy, -0.35, 0.3))
    # 윗가장자리 풀 입술
    lip = smooth(0.5, 0.56, cv) * smooth(0.64, 0.56, cv) * (gy > 0.02)
    grass = sample(W.color("grass", 0), X, Y)
    rock = mix(rock, shade(grass, 0.05), lip[..., None] * 0.8 if lip.ndim == 2 else lip)
    L.over(rock, ca, oy, ox)


def _wall(L, W, X, Y):
    wa, wv = organic(sample(W.field("wall", 0.5), X, Y), X, Y, 151, amp=0.12, scale=26, edge=0.04)
    bb = bbox(wa, 8)
    if not bb:
        return
    X, Y, wa, wv, oy, ox = X[bb], Y[bb], wa[bb], wv[bb], bb[0].start, bb[1].start
    snow_w = _name_w(W, "snow", X, Y, 0.6)
    # 생울타리 밑(덤불은 나무 겹에서 그린다): 그늘진 짙은 풀
    gc = sample(W.color("grass", 0), X, Y)
    leaf = shade(gc, -0.35 + (fbm(X, Y, 14, 154, 2) - 0.5) * 0.15)
    # 성벽: 고르지 않은 돌을 쌓은 벽, 위에는 눈
    row = np.floor(Y / 15.0)
    off = (row % 2) * 13
    bx = np.floor((X + off) / 26.0)
    from core import _hash
    bid = _hash(bx.astype(np.int64), row.astype(np.int64), 157)
    fx = (X + off) % 26.0
    fy = Y % 15.0
    seam = np.minimum(np.minimum(fx, 26 - fx), np.minimum(fy, 15 - fy))
    brick = mix(hexc("#b9b4ad"), hexc("#9a948d"), bid)
    brick = shade(brick, (fbm(X, Y, 8, 159, 2) - 0.5) * 0.18 - smooth(2.2, 0.3, seam + (vnoise(X, Y, 3, 161) - 0.5) * 2) * 0.35)
    f = sample(W.field("wall", 0.5), X, Y)
    gy = np.gradient(f, axis=0) * 40
    snowcap = smooth(0.0, 0.08, gy) * smooth(0.5, 0.58, wv)
    brick = mix(brick, hexc("#f6f9fd"), snowcap * 0.95)
    col = mix(leaf, brick, snow_w)
    # 아랫면 그림자
    col = shade(col, np.clip(gy * 0.8, -0.3, 0.2))
    L.over(col, wa, oy, ox)


def _water(L, W, X, Y, lava_w, snow_w):
    wf = sample(W.field("water", 0.62), X, Y)
    near = wf > 0.12
    bb = bbox(near.astype(np.float32), 24)
    if not bb:
        return
    X, Y, wf, lava_w, snow_w, oy, ox = X[bb], Y[bb], wf[bb], lava_w[bb], snow_w[bb], bb[0].start, bb[1].start
    wa, wv = organic(wf, X, Y, 171, amp=0.2, scale=44, edge=0.035)
    depth = sample(W.edt("water"), X, Y)
    w0 = sample(W.color("water", 0), X, Y)
    w1 = sample(W.color("water", 1), X, Y)
    dn = depth + (fbm(X, Y, 120, 173, 3) - 0.5) * 1.2
    shallow = shade(w0, 0.22)
    deep = shade(w1, -0.18)
    col = mix(shallow, deep, smooth(0.4, 4.0, dn))
    # 물가 얕은 옥빛 띠
    col = mix(col, shade(mix(w0, hexc("#bff0e6"), 0.5), 0.15), smooth(0.62, 0.5, wv) * 0.7)
    # 흐르는 빛줄기(가로로 긴 부드러운 결), 작은 반짝임
    Xw, Yw = warp(X, Y, 160, 40, 175)
    band = vnoise(Xw * 0.35, Yw * 1.8, 18, 177)
    col = shade(col, smooth(0.62, 0.9, band) * 0.18 - smooth(0.35, 0.1, band) * 0.06)
    spark = (vnoise(X * 0.5, Y * 2.2, 3, 179) > 0.95) & (dn > 0.8)
    col = np.where(spark[..., None], mix(col, hexc("#ffffff"), 0.7), col)
    # 용암: 식은 껍질 판 사이로 빛나는 용암
    d1, gap, pid = voronoi(*warp(X, Y, 60, 9, 181), 26, 183)
    crust = smooth(2.5, 6.0, gap)
    lava = mix(hexc("#ffd36b"), hexc("#ff7a2e"), smooth(0.0, 4.0, gap))
    lava = mix(lava, shade(hexc("#4b3a37"), (pid - 0.5) * 0.3), crust * smooth(0.3, 0.7, fbm(X, Y, 90, 185, 2)))
    col = mix(col, lava, lava_w)

    # 바닷가: 물에 닿은 땅은 모래 띠(눈 땅은 눈, 용암 지대는 검은 돌). 띠의 폭도 들쭉날쭉
    land_side = smooth(0.30, 0.46, wv + (fbm(X, Y, 30, 187, 2) - 0.5) * 0.12) * (1 - wa)
    sand = mix(hexc("#f2dfae"), hexc("#e6cd95"), fbm(X, Y, 12, 189, 2))
    sand = mix(sand, hexc("#f4f8fc"), snow_w)
    sand = mix(sand, hexc("#4f4240"), lava_w)
    wet = smooth(0.42, 0.5, wv)
    sand = shade(sand, -wet * 0.18)
    L.over(sand, land_side, oy, ox)
    # 용암 빛이 둘레 바위에 비친다
    L.over(hexc("#ff8a4a"), smooth(0.25, 0.5, wv) * (1 - wa) * lava_w * 0.35, oy, ox)
    # 물 본체
    L.over(col, wa, oy, ox)
    # 거품: 물가를 따라 끊어졌다 이어지는 흰 선
    foam = smooth(0.012, 0.0, np.abs(wv - 0.53)) * smooth(0.35, 0.6, fbm(X, Y, 26, 191, 2))
    L.over(mix(hexc("#ffffff"), hexc("#ffd59a"), lava_w), foam * 0.75, oy, ox)


def _bridges(L, W, X, Y):
    """다리: 나무판을 건너지르고 난간 기둥, 물 위에 그림자."""
    rows = W.rows
    h, w = L.a.shape
    ys, xs = np.nonzero(W.mask("bridge"))
    from core import hash1
    for cy, cx in zip(ys, xs):
        px0 = cx * TILE - L.x0
        py0 = cy * TILE - L.y0
        if px0 < -TILE or py0 < -TILE or px0 > w or py0 > h:
            continue
        walk = lambda y, x: 0 <= y < W.h and 0 <= x < W.w and rows[y, x] not in "~w"
        vertical = walk(cy - 1, cx) or walk(cy + 1, cx) or W.mask("bridge")[min(cy + 1, W.h - 1), cx] or W.mask("bridge")[max(cy - 1, 0), cx]
        yy, xx = np.mgrid[0:TILE + 24, 0:TILE + 24].astype(np.float32)
        lx = xx - 12
        ly = yy - 12
        along = ly if vertical else lx
        across = lx if vertical else ly
        half = 25 + (vnoise(along + cx * 64, across, 9, 201) - 0.5) * 3
        deck = np.clip(half - np.abs(across - 32), 0, 1) * ((along > -2) & (along < 66))
        plank = np.floor((along + 2) / 9.0)
        from core import _hash
        pid = _hash(plank.astype(np.int64) + cx * 7, np.zeros_like(plank, np.int64) + cy, 203)
        wood = mix(hexc("#c59a64"), hexc("#a77b4b"), pid)
        seam = np.abs(((along + 2) % 9.0) - 4.5)
        wood = shade(wood, (vnoise(across * 0.3, along, 3, 205) - 0.5) * 0.16 - smooth(4.5, 3.6, seam) * 0.3 + 0.05 * (across < 30))
        # 그림자(물 위, 오른쪽 아래)
        sh = np.clip(half - np.abs(across - 32 - 6), 0, 1) * ((along > 4) & (along < 72)) * 0.3
        L.over(hexc("#2d3550"), sh, py0 - 12 + (0 if vertical else 6), px0 - 12 + (6 if vertical else 0))
        L.over(wood, deck, py0 - 12, px0 - 12)
        # 난간: 양옆의 어두운 나무와 기둥
        rail = (np.abs(np.abs(across - 32) - half + 2) < 2.2) * ((along > -2) & (along < 66))
        L.over(hexc("#7a5636"), rail.astype(np.float32), py0 - 12, px0 - 12)


def _fences(L, W, X, Y):
    """울타리: 기둥과 가로대, 칸끼리 이어진다."""
    rows = W.rows
    h, w = L.a.shape
    ys, xs = np.nonzero(rows == "F")
    for cy, cx in zip(ys, xs):
        px0 = cx * TILE - L.x0
        py0 = cy * TILE - L.y0
        if px0 < -TILE or py0 < -TILE or px0 > w or py0 > h:
            continue
        horiz = (cx > 0 and rows[cy, cx - 1] == "F") or (cx + 1 < W.w and rows[cy, cx + 1] == "F")
        yy, xx = np.mgrid[0:TILE + 16, 0:TILE + 16].astype(np.float32)
        lx, ly = xx - 8, yy - 8
        a = np.zeros_like(lx)
        if horiz:
            for ry in (30, 42):
                a = np.maximum(a, np.clip(2.6 - np.abs(ly - ry - np.sin(lx / 13 + cx) * 1.2), 0, 1) * ((lx > -8) & (lx < 72)))
            for k in range(3):
                pxk = 6 + k * 22
                a = np.maximum(a, np.clip(3.5 - np.abs(lx - pxk), 0, 1) * ((ly > 22) & (ly < 50)))
        else:
            for rx in (26, 38):
                a = np.maximum(a, np.clip(2.6 - np.abs(lx - rx - np.sin(ly / 13 + cy) * 1.2), 0, 1) * ((ly > -8) & (ly < 72)))
            for k in range(3):
                pyk = 6 + k * 22
                a = np.maximum(a, np.clip(3.5 - np.abs(ly - pyk), 0, 1) * ((lx > 18) & (lx < 46)))
        wood = shade(hexc("#a8784a"), (vnoise(lx, ly, 4, 211 + cx) - 0.5) * 0.25 + 0.1 * (lx + ly < 60))
        L.over(hexc("#3b3049"), a * 0.22, py0 - 8 + 4, px0 - 8 + 3)
        L.over(wood, a, py0 - 8, px0 - 8)


def _fountains(L, W):
    """분수·우물(o): 둥근 돌 테두리 안의 맑은 물(움직이는 반짝임은 게임이 그린다)."""
    ys, xs = np.nonzero(W.rows == "o")
    if len(ys) == 0:
        return
    # 이어진 칸 무리마다 하나의 둥근 분수
    from scipy import ndimage
    lab, n = ndimage.label(W.rows == "o")
    for k in range(1, n + 1):
        cy, cx = ndimage.center_of_mass(lab == k)
        cnt = int((lab == k).sum())
        r = TILE * (0.42 + 0.32 * np.sqrt(cnt))
        lx = (cx + 0.5) * TILE - L.x0
        ly = (cy + 0.5) * TILE - L.y0
        S = int(r + 20)
        yy, xx = np.mgrid[0:2 * S, 0:2 * S].astype(np.float32)
        dx, dy = xx - S, yy - S
        d = np.hypot(dx, dy * 1.12)
        oy, ox = int(ly) - S, int(lx) - S
        L.over(hexc("#2b2f45"), aa(np.hypot(dx - 8, (dy - 8) * 1.12) - r - 4, 5) * 0.25, oy, ox)
        rim = shade(hexc("#c9c0b2"), np.clip(-(dx + dy) / r, -1, 1) * 0.2 + (vnoise(xx, yy, 4, 231) - 0.5) * 0.15)
        L.over(rim, aa(d - r, 1), oy, ox)
        water = mix(hexc("#bfe7f7"), hexc("#6fb4de"), smooth(-r, r, dy + dx * 0.3))
        L.over(water, aa(d - (r - 9), 1), oy, ox)
        L.over(hexc("#ffffff"), aa(np.abs(d - (r - 9) * 0.55) - 1.2, 0.8) * 0.45, oy, ox)
        L.over(shade(hexc("#d8d0c2"), 0.1), aa(np.hypot(dx, dy * 1.12) - r * 0.18, 1), oy, ox)
