#!/usr/bin/env python3
"""지도 배경을 동화책 삽화풍으로 그린다(사용자 의견: 기하학적인 느낌을 없애고, 경계는 자연스럽게, 하나의 화풍으로).

칸(data/map/world.json)은 게임 판정 그대로 두고, 그림만 그 위에서 불규칙하고 부드럽게 그린다.
결과는 게임이 읽는 그림 파일: assets/map/<겹>/<열>_<행>.webp (1024×1536, 지도 끝 장은 더 작다)
  ground 바닥(땅·길·물·건물), grass 풀·꽃·자갈(바람에 흔들림), mtn 산·바위, trees 나무(바람에 흔들림)

쓰는 법(저장소 루트에서):
  python3 tools/map/paint/paint_map.py                 # 지도 전체(몇 분)
  python3 tools/map/paint/paint_map.py --only 7_3,8_3  # 몇 장만
  python3 tools/map/paint/paint_map.py --out /tmp/x    # 다른 폴더로(미리보기)
필요한 것: numpy, scipy, Pillow
"""
import argparse
import os
import sys
import time
from multiprocessing import Pool

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from core import TILE, Layer  # noqa: E402
from world import ROOT, World  # noqa: E402

PW, PH = 1024, 1536
MARGIN = 160  # 이웃 장까지 넘어오는 그림(나무, 산 그림자)을 위해 둘레를 더 그리고 잘라 낸다
LAYERS = ["ground", "grass", "mtn", "trees"]
_W = None


def piece_size(W, cx, cy):
    w, h = W.px_size()
    return min(PW, w - cx * PW), min(PH, h - cy * PH)


def paint_piece(args):
    cx, cy, out, which = args
    global _W
    if _W is None:
        _W = World()
    W = _W
    import ground
    import grass
    import mountains
    import trees
    import buildings
    t0 = time.time()
    pw, ph = piece_size(W, cx, cy)
    x0, y0 = cx * PW - MARGIN, cy * PH - MARGIN
    w, h = pw + MARGIN * 2, ph + MARGIN * 2
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    X = xx + x0
    Y = yy + y0
    crop = (MARGIN, MARGIN, pw, ph)
    res = {}
    if "ground" in which:
        L = Layer(x0, y0, w, h)
        ground.paint(W, L, X, Y)
        buildings.paint(W, L, X, Y)
        res["ground"] = L.rgba8(crop)
    if "mtn" in which:
        L = Layer(x0, y0, w, h)
        mountains.paint(W, L, X, Y)
        res["mtn"] = L.rgba8(crop)
    if "grass" in which:
        L = Layer(x0, y0, w, h)
        grass.paint(W, L, X, Y)
        res["grass"] = L.rgba8(crop)
    if "trees" in which:
        L = Layer(x0, y0, w, h)
        trees.paint(W, L, X, Y)
        res["trees"] = L.rgba8(crop)
    for k, a in res.items():
        d = os.path.join(out, k)
        os.makedirs(d, exist_ok=True)
        p = os.path.join(d, "%d_%d.webp" % (cx, cy))
        if k != "ground" and a[..., 3].max() == 0:
            if os.path.exists(p):
                os.remove(p)
            continue  # 빈 투명 조각은 파일을 두지 않는다(게임이 그 겹을 비워 둔다)
        img = Image.fromarray(a, "RGBA" if k != "ground" else None)
        if k == "ground":
            img = Image.fromarray(a[..., :3], "RGB")
        img.save(p, "WEBP", quality=86, method=5)
        imp = p + ".import"
        if not os.path.exists(imp):  # 게임에 넣을 때 손실 압축(APK 크기). Godot가 가져오며 나머지를 채운다
            with open(imp, "w") as f:
                f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=1\ncompress/lossy_quality=0.85\nmipmaps/generate=false\n')
    return "%d_%d %.1fs" % (cx, cy, time.time() - t0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "assets/map"))
    ap.add_argument("--only", default="")
    ap.add_argument("--layers", default=",".join(LAYERS))
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    a = ap.parse_args()
    W = World()
    w, h = W.px_size()
    cols, rows = -(-w // PW), -(-h // PH)
    only = set(s for s in a.only.split(",") if s)
    which = set(a.layers.split(","))
    jobs = [(cx, cy, a.out, which) for cy in range(rows) for cx in range(cols) if not only or "%d_%d" % (cx, cy) in only]
    t0 = time.time()
    with Pool(min(a.jobs, len(jobs))) as pool:
        for r in pool.imap_unordered(paint_piece, jobs):
            print(r, flush=True)
    print("%d장, %.0f초 → %s" % (len(jobs), time.time() - t0, a.out))


if __name__ == "__main__":
    main()
