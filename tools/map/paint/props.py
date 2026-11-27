"""마을 소품(바닥 그림에 함께 굽는다, 사용자 의견: 레퍼런스처럼 아늑한 마을): 가로등, 벤치, 나무통, 상자, 꽃 덤불,
깃발 기둥, 알림판, 말 뽑기 기계(분홍 구슬). 모두 사라지지 않고 움직이지 않는 것. 판정(칸)은 그대로(장식).
빛은 왼쪽 위, 외곽선은 진한 갈색, 그림자는 오른쪽 아래.
"""
import numpy as np

from core import TILE, aa, fbm, hash1, hexc, mix, shade, smooth, vnoise

OUT = hexc("#4a3424")
SH = hexc("#2b2f45")
WOOD = hexc("#a8744a")
WOOD_D = hexc("#7a5234")
IRON = hexc("#3f3a44")
LEAFC = hexc("#5f9f4f")


def _stamp(L, cx, cy, w, h):
    """도장 판: (oy, ox, xx, yy) — xx, yy는 도장 안 좌표(가운데 cx, 밑동 cy 기준)."""
    ox, oy = int(cx - w / 2), int(cy - h)
    yy, xx = np.mgrid[0:int(h) + 12, 0:int(w)].astype(np.float32)
    return oy, ox, xx - w / 2, yy - h


def _draw(L, col, sd, oy, ox, line=2.2):
    a = aa(sd, 0.9)
    edge = smooth(-line - 0.6, -0.4, sd)
    col = mix(col, OUT, edge[..., None] * 0.85)
    L.over(col, a, oy, ox)


def _shadow(L, cx, cy, rx, ry, a=0.28):
    S = int(max(rx, ry) + 8)
    yy, xx = np.mgrid[0:2 * S, 0:2 * S].astype(np.float32)
    d = np.hypot((xx - S) / rx, (yy - S) / ry) - 1
    L.over(SH, aa(d * min(rx, ry), 3) * a, int(cy - S + 3), int(cx - S + 8))


def lamp(L, cx, cy, seed=0):
    """가로등: 쇠기둥, 등갓, 따뜻한 불빛."""
    _shadow(L, cx, cy, 14, 6)
    oy, ox, x, y = _stamp(L, cx, cy, 44, 110)
    post = np.maximum(np.abs(x) - 3.5 - smooth(-10, 0, y) * 4, y - 2)
    post = np.minimum(post, np.maximum(np.abs(x) - 8, np.abs(y + 4) - 4))
    col = np.broadcast_to(shade(IRON, 0), x.shape + (3,)).copy()
    col = shade(col, -np.clip(x / 5, -1, 1)[..., None][..., 0] * 0.2)
    _draw(L, col, np.maximum(post, -y - 92), oy, ox)
    glow = aa(np.hypot(x, y + 96) - 30, 16) * 0.5
    L.over(hexc("#ffdf8a"), glow, oy, ox)
    head = np.maximum(np.abs(x) - 11 + (y + 96) * 0.0, np.abs(y + 96) - 12)
    lightc = mix(hexc("#fff3c4"), hexc("#ffc46b"), smooth(-108, -84, y))
    _draw(L, lightc, head, oy, ox, 2.0)
    cap = np.maximum(np.abs(x) - 15 + (y + 112) * 0.7, np.abs(y + 110) - 5)
    _draw(L, shade(IRON, 0.05), cap, oy, ox, 1.8)


def bench(L, cx, cy, seed=0):
    _shadow(L, cx, cy, 34, 9)
    oy, ox, x, y = _stamp(L, cx, cy, 80, 48)
    seat = np.maximum(np.abs(x) - 34, np.abs(y + 18) - 5)
    back = np.maximum(np.abs(x) - 32, np.abs(y + 34) - 6)
    legs = np.maximum(np.abs(np.abs(x) - 26) - 3, np.abs(y + 6) - 7)
    plank = 0.5 + 0.5 * np.sin(x * 0.9)
    col = shade(WOOD, (plank - 0.5) * 0.1 + (0.4 - (x + 34) / 68) * 0.25)
    _draw(L, shade(WOOD_D, 0), legs, oy, ox)
    _draw(L, col, back, oy, ox)
    _draw(L, shade(col, 0.08), seat, oy, ox)


def barrel(L, cx, cy, seed=0):
    _shadow(L, cx, cy, 18, 7)
    oy, ox, x, y = _stamp(L, cx, cy, 44, 52)
    bulge = 16 + 3 * np.sin(np.clip(-y / 44, 0, 1) * np.pi)
    body = np.maximum(np.abs(x) - bulge, np.maximum(-y - 44, y))
    u = np.clip(x / 18, -1, 1)
    staves = (np.abs(((x + 30) % 8) - 4) < 0.6)
    col = shade(WOOD, -u * 0.35 + 0.05 - staves * 0.12)
    hoops = (np.abs(y + 10) < 2.5) | (np.abs(y + 34) < 2.5)
    col = np.where(hoops[..., None], shade(IRON, -u * 0.2 + 0.1), col)
    _draw(L, col, body, oy, ox)
    top = np.hypot(x / 15, (y + 44) / 5) - 1
    _draw(L, shade(WOOD, 0.15), top * 6, oy, ox, 1.5)


def crate(L, cx, cy, seed=0, s=1.0):
    _shadow(L, cx, cy, 22 * s, 8 * s)
    oy, ox, x, y = _stamp(L, cx, cy, 54 * s, 56 * s)
    face = np.maximum(np.abs(x) - 20 * s, np.maximum(-y - 34 * s, y))
    top = np.maximum(np.abs(x - (y + 34 * s) * -0.0) - 20 * s, np.abs(y + 40 * s) - 6 * s)
    col = shade(WOOD, (0.5 - (x + 20 * s) / (40 * s)) * 0.25)
    cross = (np.abs(np.abs(x) - np.abs(y + 17 * s) * 1.15) < 2.2) | (np.abs(np.abs(x) - 20 * s) < 3) | (np.abs(y + 2) < 3) | (np.abs(y + 32 * s) < 3)
    col = np.where(cross[..., None], shade(WOOD_D, 0.05), col)
    _draw(L, col, face, oy, ox)
    _draw(L, shade(WOOD, 0.2), top, oy, ox, 1.6)


def flowerbush(L, cx, cy, seed=0, r=30):
    """꽃 덤불: 둥근 잎 덩어리 두셋 + 흰·노랑·분홍 꽃."""
    g = np.random.default_rng(seed)
    _shadow(L, cx, cy, r * 1.3, r * 0.45, 0.25)
    oy, ox, x, y = _stamp(L, cx, cy, r * 3.2, r * 2.4)
    for k in range(3):
        bx = (k - 1) * r * 0.7 + g.uniform(-3, 3)
        by = -r * 0.75 - (k == 1) * r * 0.25
        rr = r * (0.7 + 0.25 * (k == 1))
        d = np.hypot(x - bx, y - by)
        ang = np.arctan2(y - by, x - bx)
        sd = d - rr * (1 + 0.1 * np.sin(ang * 7 + seed + k))
        lt = -((x - bx) * 0.55 + (y - by) * 0.65) / rr
        col = mix(shade(LEAFC, -0.3), shade(LEAFC, 0.18), smooth(-0.5, 0.6, lt))[..., :3] if False else mix(shade(LEAFC, -0.3), shade(LEAFC, 0.18), smooth(-0.5, 0.6, lt))
        col = shade(col, (vnoise(x + cx, y + cy, 3, 1001 + k) - 0.5) * 0.18)
        _draw(L, col, sd, oy, ox, 1.6)
    cols = [hexc("#ffffff"), hexc("#fff1a8"), hexc("#f6b3c0")]
    for k in range(int(r * 0.7)):  # 다섯 꽃잎 꽃(레퍼런스처럼 풍성하게)
        fx = g.uniform(-r * 1.3, r * 1.3)
        fy = g.uniform(-r * 1.65, -r * 0.35)
        c = cols[int(g.integers(3))]
        pa = np.zeros_like(x)
        for p in range(5):
            an = p * 1.2566 + seed
            pa = np.maximum(pa, aa(np.hypot(x - fx - np.cos(an) * 2.6, y - fy - np.sin(an) * 2.6) - 2.3, 0.6))
        L.over(shade(c, -0.25), aa(np.hypot(x - fx, y - fy) - 5.6, 0.8) * 0.6, oy, ox)
        L.over(c, pa, oy, ox)
        L.over(hexc("#f2b33a"), aa(np.hypot(x - fx, y - fy) - 1.4, 0.6), oy, ox)


def banner_pole(L, cx, cy, seed=0):
    _shadow(L, cx, cy, 12, 5)
    oy, ox, x, y = _stamp(L, cx, cy, 50, 130)
    pole = np.maximum(np.abs(x + 12) - 2.5, np.maximum(-y - 120, y))
    _draw(L, shade(WOOD_D, -np.clip((x + 12) / 3, -1, 1)[..., None][..., 0] * 0.2), pole, oy, ox, 1.4)
    ban = np.maximum(np.maximum(np.abs(x + 1) - 12, -y - 112), y + 60 - np.abs(x + 1) * 0.9)
    col = shade(hexc("#4f6fc0"), (np.sin(x * 0.5) * 0.1) + (0.5 - (x + 13) / 26) * 0.2)
    emb = np.hypot(x + 1, y + 88) < 6
    col = np.where(emb[..., None], hexc("#f2cf4a"), col)
    _draw(L, col, ban, oy, ox, 1.6)


def notice_board(L, cx, cy):
    """마을 알림판: 두 기둥, 지붕 달린 판자, 붙은 종이."""
    _shadow(L, cx, cy, 40, 10)
    oy, ox, x, y = _stamp(L, cx, cy, 110, 120)
    legs = np.maximum(np.abs(np.abs(x) - 34) - 4, np.maximum(-y - 90, y))
    _draw(L, shade(WOOD_D, 0), legs, oy, ox)
    board = np.maximum(np.abs(x) - 44, np.abs(y + 60) - 28)
    plank = (np.abs(((y + 100) % 12) - 6) < 0.8)
    col = shade(WOOD, (0.5 - (x + 44) / 88) * 0.25 - plank * 0.15)
    _draw(L, col, board, oy, ox)
    for k, (px, py, c) in enumerate(((-24, -66, "#fff8e8"), (4, -58, "#fff1c4"), (26, -70, "#e8f4ff"))):
        paper = np.maximum(np.abs(x - px) - 11, np.abs(y - py) - 13)
        lines = (np.abs(((y - py + 13) % 6) - 3) < 0.7) & (np.abs(x - px) < 7)
        pc = np.where(lines[..., None], hexc("#b8a48c"), hexc(c))
        _draw(L, pc, paper, oy, ox, 1.2)
        L.over(hexc("#e9576a"), aa(np.hypot(x - px, y - py + 11) - 2.2, 0.6), oy, ox)
    roof = np.maximum(np.abs(x) - 52 + (y + 96) * 0.9, np.maximum(-y - 104, y + 86))
    _draw(L, shade(hexc("#c9604f"), (0.5 - (x + 52) / 104) * 0.3), roof, oy, ox)


def gacha_orb(L, cx, cy):
    """말 뽑기 기계: 나무 받침 위의 분홍 수정 구슬(반짝임)."""
    _shadow(L, cx, cy, 46, 12)
    oy, ox, x, y = _stamp(L, cx, cy, 130, 150)
    stand = np.maximum(np.abs(x) - 50 + np.clip(-y - 30, 0, 30) * 0.3, np.maximum(-y - 40, y))
    col = shade(WOOD, (0.5 - (x + 50) / 100) * 0.3 + (np.abs(((y + 40) % 13) - 6.5) < 0.8) * -0.15)
    _draw(L, col, stand, oy, ox)
    flowers = [(-44, -38), (-30, -44), (40, -40), (30, -46)]
    for (fx, fy) in flowers:
        _draw(L, shade(LEAFC, 0.05), np.hypot(x - fx, y - fy) - 9, oy, ox, 1.4)
        L.over(hexc("#fff1a8"), aa(np.hypot(x - fx, y - fy - 2) - 3, 0.7), oy, ox)
    ring = np.maximum(np.abs(x) - 34, np.abs(y + 46) - 6)
    _draw(L, shade(hexc("#c9a227"), (0.5 - (x + 34) / 68) * 0.3), ring, oy, ox)
    r = 40
    d = np.hypot(x, y + 92) - r
    lt = -(x * 0.55 + (y + 92) * 0.65) / r
    orb = mix(hexc("#e86fae"), hexc("#ffd0ec"), smooth(-0.6, 0.8, lt))
    orb = mix(orb, hexc("#ffffff"), aa(np.hypot(x + 14, y + 108) - 8, 3)[..., None] * 0.9)
    L.over(hexc("#ffb6dc"), aa(d - 10, 10) * 0.35, oy, ox)
    _draw(L, orb, d, oy, ox, 2.0)
    for (sx, sy, s) in ((-6, -96, 7), (12, -84, 5), (4, -110, 4)):
        spark = (np.abs(x - sx) * np.abs(y - sy) < s * 1.2) & (np.hypot(x - sx, y - sy) < s)
        L.over(hexc("#ffffff"), spark.astype(np.float32), oy, ox)


def paint(W, L):
    """마을 소품을 칸 배치에서 정해(결정적) 그린다. 스테이지 1 공방 마을과 스테이지 2 사냥꾼 마을."""
    for rg in W.d["regions"]:
        if rg["stage"] in (1, 2) and rg.get("buildings"):
            _paint_town(W, L, rg)


def _paint_town(W, L, rg):
    tx, ty, tw, th = rg["town"]
    rows = W.rows
    sp = rg["spots"]
    items = []
    mx, my = tx + tw // 2, ty + th // 2

    def ok(x, y):
        return 0 <= y < W.h and 0 <= x < W.w and rows[y, x] == ","
    # 가로등: 큰길(돌길) 옆 칸, 광장 네 귀퉁이
    for (x, y) in ((mx - 5, my - 2), (mx + 5, my - 2), (mx - 5, my + 3), (mx + 5, my + 3), (tx + 3, my - 1), (tx + tw - 4, my - 1),
                   (mx - 2, ty + th - 3), (mx + 3, ty + th - 3), (mx - 2, ty + 8), (mx + 2, ty + 8)):
        if ok(x, y):
            items.append(((y + 0.85) * TILE, (x + 0.5) * TILE, "lamp", x * 7 + y))
    # 벤치: 광장 둘레
    for (x, y) in ((mx - 4, my - 3), (mx + 3, my + 4), (mx - 4, my + 4), (mx + 4, my - 3)):
        if ok(x, y):
            items.append(((y + 0.8) * TILE, (x + 0.5) * TILE, "bench", x + y))
    # 대장간 옆 나무통·상자
    for bd in rg["buildings"]:
        bx, by, bw, bh = bd["rect"]
        if bd["id"] in ("forge", "hunter_hut"):
            for k, (dx, kind) in enumerate(((bw, "barrel"), (bw, "crate"))):
                x, y = bx + dx, by + bh - 1 - k
                if ok(x, y):
                    items.append(((y + 0.85) * TILE, (x + 0.5) * TILE, kind, k))
        if bd["id"].startswith("house") or bd["id"] in ("board", "hospital", "hunter_hut"):
            for x in (bx - 1, bx + bw):
                y = by + bh - 1
                if ok(x, y) and hash1(x, y, 1011) < 0.75:
                    items.append(((y + 0.9) * TILE, (x + 0.5) * TILE, "bush", x * 13 + y))
    # 성벽 안쪽 둘레 꽃 덤불(드문드문)
    for x in range(tx + 1, tx + tw - 1):
        for y in (ty + 1, ty + th - 2):
            if ok(x, y) and hash1(x, y, 1013) < 0.32:
                items.append(((y + (0.9 if y == ty + 1 else 0.55)) * TILE, (x + 0.5) * TILE, "bush", x * 31 + y))
    for y in range(ty + 1, ty + th - 1):
        for x in (tx + 1, tx + tw - 2):
            if ok(x, y) and hash1(x, y, 1015) < 0.28:
                items.append(((y + 0.9) * TILE, (x + 0.5) * TILE, "bush", x * 17 + y))
    # 성 앞 깃발 기둥
    for bd in rg["buildings"]:
        if bd["id"] == "castle":
            bx, by, bw, bh = bd["rect"]
            for x in (bx - 1, bx + bw):
                if ok(x, by + bh):
                    items.append(((by + bh + 0.85) * TILE, (x + 0.5) * TILE, "pole", x))
    # 알림판·말 뽑기 기계(살펴보기 자리 바로 뒤)
    if "notice" in sp:
        items.append((sp["notice"][1] - 18, sp["notice"][0], "notice", 0))
    if "gacha" in sp:
        items.append((sp["gacha"][1] - 12, sp["gacha"][0], "gacha", 0))
    items.sort()
    fn = {"lamp": lamp, "bench": bench, "barrel": barrel, "crate": crate, "bush": flowerbush, "pole": banner_pole}
    for py, px, kind, seed in items:
        lx, ly = px - L.x0, py - L.y0
        if lx < -200 or ly < -200 or lx > L.w + 200 or ly > L.h + 300:
            continue
        if kind == "notice":
            notice_board(L, lx, ly)
        elif kind == "gacha":
            gacha_orb(L, lx, ly)
        else:
            fn[kind](L, lx, ly, seed)
