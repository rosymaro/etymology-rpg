"""마을 건물(바닥 겹 위): 기와·나무판 지붕의 결, 회벽·돌·나무 벽, 창틀과 덧문, 꽃 상자, 아치 문, 굴뚝, 화단, 그림자.

건물 자리(rect)와 문 자리(door)는 data/map/world.json 그대로. 건물마다 조금씩 다른 모양.
이름표·굴뚝 연기는 게임이 위에 그린다(움직이거나 글씨라서).
"""
import numpy as np

from core import TILE, _hash, aa, fbm, hexc, mix, shade, smooth, vnoise

SH = hexc("#2b2f45")
STYLE = {
    "forge": {"roof": "#c0634a", "wall": "stone", "chimney": True},
    "board": {"roof": "#6f8fd0", "wall": "wood", "chimney": False},
    "hospital": {"roof": "#e8e2ea", "wall": "plaster", "chimney": False, "cross": True},
    "house1": {"roof": "#b86f4c", "wall": "timber", "chimney": True},
    "house2": {"roof": "#8a6aa4", "wall": "plaster", "chimney": False},
    "house3": {"roof": "#a4744a", "wall": "timber", "chimney": False, "thatch": True},
    "house4": {"roof": "#7f9a5a", "wall": "plaster", "chimney": True},
}


def paint(W, L, X, Y):
    for bd in W.buildings():
        if bd["id"] in ("tree", "castle"):
            continue  # 큰 나무는 나무 겹(trees.py), 성은 산 겹(castle.py)
        rc = bd["rect"]
        px, py = rc[0] * TILE - L.x0, rc[1] * TILE - L.y0
        if px > L.w + 100 or py > L.h + 100 or px + rc[2] * TILE < -100 or py + rc[3] * TILE < -100:
            continue
        _house(L, bd, px, py, rc[2] * TILE, rc[3] * TILE)


def _wob(x, seed, amp=1.6, scale=9):
    return (vnoise(x, np.zeros_like(x) + seed, scale, 601) - 0.5) * 2 * amp


def _house(L, bd, px, py, bw, bh):
    st = STYLE.get(bd["id"], STYLE["house2"])
    seed = sum(ord(c) for c in bd["id"]) * 31
    g = np.random.default_rng(seed)
    M = 40
    H, Wd = int(bh + M * 2), int(bw + M * 2)
    yy, xx = np.mgrid[0:H, 0:Wd].astype(np.float32)
    lx, ly = xx - M, yy - M  # 건물 왼쪽 위 기준
    oy, ox = int(py) - M, int(px) - M
    door_x = bd["door"][0] - L.x0 - px
    roof_c = hexc(st["roof"])

    # 그림자(오른쪽 아래로 부드럽게)
    sd = np.maximum(np.abs(lx - bw / 2 - 12) - bw / 2, np.abs(ly - bh * 0.62 - 12) - bh * 0.42)
    L.over(SH, aa(sd, 7) * 0.3, oy, ox)

    # ---- 벽(앞면): 아래 45%
    wall_top = bh * 0.5
    wl, wr = 8 + _wob(ly, seed), bw - 8 + _wob(ly, seed + 1)
    wall_sd = np.maximum(np.maximum(wl - lx, lx - wr), np.maximum(wall_top - ly, ly - (bh - 2 + _wob(lx, seed + 2, 1.2))))
    wa = aa(wall_sd, 0.9)
    tex = fbm(xx + px, yy + py, 6, 603, 3)
    if st["wall"] == "stone":
        row = np.floor((ly - wall_top) / 10)
        off = (row % 2) * 9
        bx = np.floor((lx + off) / 18)
        bid = _hash(bx.astype(np.int64) + seed, row.astype(np.int64), 605)
        fx, fy = (lx + off) % 18, (ly - wall_top) % 10
        seam = np.minimum(np.minimum(fx, 18 - fx), np.minimum(fy, 10 - fy))
        wc = shade(mix(hexc("#b8aea0"), hexc("#9d9284"), bid), (tex - 0.5) * 0.2 - smooth(1.8, 0.2, seam) * 0.3)
    elif st["wall"] == "wood":
        plank = np.floor(lx / 9)
        pid = _hash(plank.astype(np.int64) + seed, np.zeros_like(plank, np.int64), 607)
        seam = np.abs((lx % 9) - 4.5)
        wc = shade(mix(hexc("#c79a68"), hexc("#a97c4e"), pid), (vnoise(lx * 0.3, ly, 3, 609) - 0.5) * 0.18 - smooth(4.5, 3.6, seam) * 0.25)
    else:
        wc = shade(hexc("#f1e6d2"), (tex - 0.5) * 0.12)
        if st["wall"] == "timber":  # 나무 뼈대: 모서리 기둥, 가운데 띠, 엇갈린 버팀목
            beam = (np.abs(lx - wl) < 4) | (np.abs(lx - wr) < 4) | (np.abs(ly - (wall_top + (bh - wall_top) * 0.5)) < 2.5) \
                | (np.abs(ly - wall_top - 3) < 3)
            mid = bw / 2
            beam |= (np.abs((lx - wl) - (ly - wall_top) * 1.2) < 2.2) & (lx < mid - 14)
            beam |= (np.abs((wr - lx) - (ly - wall_top) * 1.2) < 2.2) & (lx > mid + 14)
            wc = np.where(beam[..., None], shade(hexc("#7a5636"), (tex - 0.5) * 0.2), wc)
    # 벽 빛: 왼쪽이 밝고 지붕 밑은 그늘
    wc = shade(wc, -smooth(wall_top + 14, wall_top, ly) * 0.25 + (0.5 - lx / bw) * 0.1)
    wc = mix(wc, shade(wc, -0.55), smooth(-2.0, -0.2, wall_sd)[..., None] * 0.6)
    L.over(wc, wa, oy, ox)

    # ---- 창: 나무 창틀, 하늘빛 유리와 반사, 덧문, 꽃 상자
    nwin = max(1, int(bw // 110))
    spots = []
    for k in range(nwin * 2):
        cxw = wl + (k + 0.5) * (wr - wl) / (nwin * 2)
        if abs(cxw.mean() - door_x) > 36:
            spots.append(float(cxw.mean()))
    wy = wall_top + (bh - wall_top) * 0.38
    for cxw in spots:
        ww, wh = 20, 18
        win_sd = np.maximum(np.abs(lx - cxw) - ww / 2, np.abs(ly - wy) - wh / 2)
        L.over(hexc("#6e4d32"), aa(win_sd - 3, 0.8), oy, ox)
        glass = mix(hexc("#d9f1fb"), hexc("#8fc4e4"), smooth(-wh / 2, wh / 2, ly - wy + (lx - cxw) * 0.6))
        glass = mix(glass, hexc("#fff7d6"), (np.abs((lx - cxw) + (ly - wy) - 2) < 2.5)[..., None] * 0.6)
        L.over(glass, aa(win_sd, 0.8), oy, ox)
        L.over(hexc("#6e4d32"), aa(np.minimum(np.abs(lx - cxw), np.abs(ly - wy)) - 1.2, 0.6) * aa(win_sd, 0.8), oy, ox)
        sc = shade(roof_c, -0.1)
        for s in (-1, 1):  # 덧문
            sh_sd = np.maximum(np.abs(lx - cxw - s * (ww / 2 + 7)) - 5, np.abs(ly - wy) - wh / 2 - 1)
            L.over(shade(sc, (vnoise(lx, ly * 0.2, 2, 611) - 0.5) * 0.2 + (0.1 if s < 0 else -0.1)), aa(sh_sd, 0.8), oy, ox)
        box_sd = np.maximum(np.abs(lx - cxw) - ww / 2 - 3, np.abs(ly - wy - wh / 2 - 5) - 3.5)
        L.over(hexc("#8b6640"), aa(box_sd, 0.8), oy, ox)
        for f in range(4):
            fxp = cxw - 9 + f * 6 + g.uniform(-1, 1)
            fc = hexc(["#f6b3c0", "#fff1a8", "#ffffff", "#f29bb8"][int(g.integers(4))])
            L.over(hexc("#6f9a4a"), aa(np.hypot(lx - fxp, ly - (wy + wh / 2 + 1)) - 3.2, 0.7), oy, ox)
            L.over(fc, aa(np.hypot(lx - fxp, ly - (wy + wh / 2 - 1)) - 2.0, 0.7), oy, ox)

    # ---- 문: 아치 꼭대기, 세로 나무판, 손잡이, 앞의 디딤돌
    dw, dh = 26, 34
    dtop = bh - 2 - dh
    dsd = np.where(ly < dtop + dw / 2, np.hypot(lx - door_x, ly - (dtop + dw / 2)) - dw / 2, np.abs(lx - door_x) - dw / 2)
    dsd = np.maximum(dsd, ly - (bh - 1))
    L.over(hexc("#5e4330"), aa(dsd - 3, 0.8), oy, ox)
    plank = np.abs(((lx - door_x + 13) % 6.5) - 3.25)
    dc = shade(hexc("#9a6a3e"), -smooth(3.25, 2.5, plank) * 0.25 + (door_x - lx) / 60)
    L.over(dc, aa(dsd, 0.8), oy, ox)
    L.over(hexc("#f2cf4a"), aa(np.hypot(lx - door_x - 7, ly - (bh - dh * 0.45)) - 2.0, 0.6), oy, ox)
    step = np.hypot((lx - door_x) / 22, (ly - bh - 5) / 6) - 1
    L.over(shade(hexc("#c9c0b2"), (vnoise(lx, ly, 4, 613) - 0.5) * 0.2), aa(step * 6, 0.9), oy, ox)

    # ---- 지붕: 처마가 살짝 휘고, 기와(물고기 비늘)·초가 결. 왼쪽이 밝다
    ridge_y = bh * 0.04 + _wob(lx, seed + 3, 1.5)
    eave_y = bh * 0.6 + _wob(lx, seed + 4, 2.0) + 4 * np.sin(np.clip((lx + 10) / (bw + 20), 0, 1) * np.pi)  # 처마가 아래로 처진다
    inset = bw * 0.1
    t = np.clip((ly - ridge_y) / np.maximum(eave_y - ridge_y, 1), 0, 1)
    left = inset * (1 - t) - 12 * t + _wob(ly, seed + 5, 1.4)
    right = bw - inset * (1 - t) + 12 * t + _wob(ly, seed + 6, 1.4)
    roof_sd = np.maximum(np.maximum(left - lx, lx - right), np.maximum(ridge_y - ly, ly - eave_y))
    ra = aa(roof_sd, 0.9)
    if st.get("thatch"):
        strand = vnoise(lx * 1.6, ly * 0.25, 2.5, 615)
        rc = shade(hexc("#d8b46a"), (strand - 0.5) * 0.35)
        rows = np.abs(((ly - ridge_y) % 14) - 7)
        rc = shade(rc, -smooth(7, 5, rows) * 0.18)
    else:
        rowh = 9.0
        row = np.floor((ly - ridge_y) / rowh)
        off = (row % 2) * 7
        tx = (lx + off) % 14 - 7
        ty = (ly - ridge_y) % rowh
        tile_id = _hash(np.floor((lx + off) / 14).astype(np.int64) + seed, row.astype(np.int64), 617)
        scallop = ty - (rowh - 2.5 * np.sqrt(np.clip(1 - (tx / 7) ** 2, 0, 1)))
        rc = shade(roof_c, (tile_id - 0.5) * 0.14 - smooth(-2.5, 0.5, scallop) * 0.22 + (fbm(xx + px, yy + py, 5, 619, 2) - 0.5) * 0.1)
    rc = shade(rc, (0.5 - lx / bw) * 0.22 + (1 - t) * 0.06 - smooth(0.82, 1.0, t) * 0.15)
    rc = mix(rc, shade(roof_c, -0.55), smooth(-2.4, -0.2, roof_sd)[..., None] * 0.65)
    # 처마 밑 그늘(벽 위)
    L.over(SH, aa(np.maximum(np.abs(lx - bw / 2) - bw / 2, np.abs(ly - eave_y - 6) - 5), 3) * 0.25 * (ly > eave_y), oy, ox)
    L.over(rc, ra, oy, ox)
    # 용마루
    L.over(shade(roof_c, 0.25), aa(np.abs(ly - ridge_y - 2) - 2.2, 0.8) * (lx > inset) * (lx < bw - inset), oy, ox)

    if st.get("cross"):  # 병원: 지붕 위 붉은 십자 표지
        cxp, cyp = bw / 2, bh * 0.28
        cr = np.minimum(np.maximum(np.abs(lx - cxp) - 6, np.abs(ly - cyp) - 16), np.maximum(np.abs(lx - cxp) - 16, np.abs(ly - cyp) - 6))
        L.over(hexc("#ffffff"), aa(np.hypot(lx - cxp, ly - cyp) - 22, 1), oy, ox)
        L.over(hexc("#e9576a"), aa(cr, 0.8), oy, ox)
    if st["chimney"]:  # 굴뚝(연기는 게임이 그린다)
        cx_ = bw * 0.8
        ch_sd = np.maximum(np.abs(lx - cx_ - 9) - 9, np.abs(ly - (-bh * 0.02)) - 16)
        row = np.floor(ly / 6)
        seam = np.abs(((lx + (row % 2) * 5) % 10) - 5)
        cc = shade(hexc("#8f7f72"), -smooth(1.5, 0, np.minimum(seam, np.abs((ly % 6) - 3))) * 0.2 + (cx_ + 9 - lx) / 40)
        L.over(cc, aa(ch_sd, 0.8), oy, ox)
        L.over(hexc("#5e4f46"), aa(np.maximum(np.abs(lx - cx_ - 9) - 10, np.abs(ly + bh * 0.02 + 16) - 3), 0.8), oy, ox)
    # 화단: 벽 앞 모서리에 꽃무더기
    for s in (0, 1):
        if g.random() < 0.8:
            fx = 14 if s == 0 else bw - 14
            if abs(fx - door_x) < 30:
                continue
            L.over(hexc("#5f8f4a"), aa(np.hypot((lx - fx) / 14, (ly - bh - 2) / 7) - 1, 1) * 1.0, oy, ox)
            for f in range(5):
                fxp = fx + g.uniform(-10, 10)
                fyp = bh - 2 + g.uniform(-4, 3)
                fc = hexc(["#f6b3c0", "#fff1a8", "#ffffff", "#c9b3f0"][int(g.integers(4))])
                L.over(fc, aa(np.hypot(lx - fxp, ly - fyp) - 2.4, 0.7), oy, ox)
