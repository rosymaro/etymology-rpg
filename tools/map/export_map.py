#!/usr/bin/env python3
"""지도 배경 그림 내보내기(사용자 의견: 배경을 같은 크기로 새로 그린다. 1024×1536px로 잘라서, 한 장에 겹을 다 담아서).

사라지지 않고 움직이지 않는 것만 담는다: 땅·물 바탕·바닷가·길·다리(열린 모습)·마을 건물·풀·꽃·산·나무.
닫힌 길목, 상자, 퍼즐 돌, 몹, 사람, 글씨, 물결 같은 움직이는 것은 게임이 위에 그린다.

1) Godot로 겹마다 1024×1536 조각을 찍는다(tests/visual/export_map.gd). 지도 16640×10240px = 가로 17장 × 세로 7장.
2) 조각마다 PSD 한 파일(지도 끝 조각은 지도가 끝나는 칸까지만 잘라 더 작다): 겹 ground, grass, mtn, trees와 참고 겹(막힌 칸, 숨김). 이름은 <열>_<행>.psd
3) 전체 미리보기 overview.png(1/8 크기, 조각 번호 격자)와 조각마다 합친 모습 preview/<열>_<행>.png

쓰는 법: python3 tools/map/export_map.py <나갈 폴더> [--godot <godot>] [--pieces <Godot가 찍은 조각 폴더>]
되돌려 넣기: python3 tools/map/import_map.py <그린 PSD 폴더>  (assets/map/README.md)
필요한 것: Pillow, numpy, psd-tools (pip install psd-tools)
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw

Image.MAX_IMAGE_PIXELS = None
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LAYERS = ["ground", "grass", "mtn", "trees"]
LAYER_NAMES = {"ground": "ground", "grass": "grass", "mtn": "mtn", "trees": "trees"}  ## PSD 겹 이름은 영어만 된다(바닥, 풀·꽃, 산, 나무)
PW, PH = 1024, 1536


def run_godot(godot, out):
    cmd = [godot, "--path", ROOT, "--rendering-driver", "opengl3", "--resolution", "720x1280", "--", "--export-map=" + out]
    if shutil.which("xvfb-run") and not os.environ.get("DISPLAY"):
        cmd = ["xvfb-run", "-a", "-s", "-screen 0 720x1280x24"] + cmd
    subprocess.run(cmd, check=True)


def size_of(world, cx, cy):
    """조각 크기. 지도 끝(오른쪽 열, 아래 줄)은 지도가 끝나는 칸까지만 자른다(사용자 의견: 칸 중간에서 끊기지 않게)."""
    ts = world["tile"]
    return min(PW, world["w"] * ts - cx * PW), min(PH, world["h"] * ts - cy * PH)


def piece(pieces, layer, cx, cy, pw, ph):
    """조각 하나. 투명 겹은 Godot가 준 '알파만큼 곱한 색'을 바로잡는다. 없으면(빈 조각) 투명."""
    p = os.path.join(pieces, layer, "%d_%d.png" % (cx, cy))
    premul = True
    if not os.path.exists(p):  # 지도 그리개(tools/map/paint)가 그린 그림: 곧은 알파라 바로잡지 않는다
        p = os.path.join(pieces, layer, "%d_%d.webp" % (cx, cy))
        premul = False
    if not os.path.exists(p):
        return np.zeros((ph, pw, 4), np.uint8)
    a = np.asarray(Image.open(p).convert("RGBA"))[:ph, :pw].copy()
    if layer != "ground" and premul and not pieces.rstrip("/").endswith("assets/map"):
        al = a[..., 3:4].astype(np.uint16)
        part = (al > 0) & (al < 255)
        fixed = np.minimum(255, a[..., :3].astype(np.uint16) * 255 // np.maximum(al, 1)).astype(np.uint8)
        a[..., :3] = np.where(part, fixed, a[..., :3])
    return a


def guide(world, cx, cy, pw, ph):
    """참고 겹: 막힌 칸(다닐 수 없는 곳)은 옅은 빨강, 칸 격자는 옅은 선."""
    ts = world["tile"]
    walk = world["walk"] + "=q"  # 퀘스트 길목은 열리면 다닌다
    g = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    d = ImageDraw.Draw(g)
    x0, y0 = cx * PW // ts, cy * PH // ts
    for y in range(y0, y0 + ph // ts):
        for x in range(x0, x0 + pw // ts):
            r = [(x - x0) * ts, (y - y0) * ts, (x - x0) * ts + ts - 1, (y - y0) * ts + ts - 1]
            if world["rows"][y][x] not in walk:
                d.rectangle(r, fill=(255, 60, 60, 70))
            d.rectangle(r, outline=(75, 63, 114, 40))
    return g


def write_psd(path, layers, guide_img):
    from psd_tools import PSDImage
    from psd_tools.api.layers import PixelLayer
    psd = PSDImage.new("RGBA", guide_img.size)
    for key in LAYERS:
        psd.append(PixelLayer.frompil(Image.fromarray(layers[key], "RGBA"), psd, LAYER_NAMES[key]))
    gl = PixelLayer.frompil(guide_img, psd, "guide (blocked cells, not used in game)")
    gl.visible = False
    psd.append(gl)
    psd.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out", help="나갈 폴더")
    ap.add_argument("--godot", default=shutil.which("godot") or "godot")
    ap.add_argument("--pieces", help="이미 있는 조각 폴더(주면 Godot를 다시 돌리지 않는다). 지금 게임 그림은 assets/map")
    a = ap.parse_args()
    world = json.load(open(os.path.join(ROOT, "data/map/world.json"), encoding="utf-8"))
    w, h = world["w"] * world["tile"], world["h"] * world["tile"]
    cols, rows = -(-w // PW), -(-h // PH)
    painted = os.path.join(ROOT, "assets/map")
    if not a.pieces and os.path.exists(os.path.join(painted, "ground", "0_0.webp")):
        a.pieces = painted  # 지금 게임이 쓰는 그린 지도
    pieces = a.pieces or tempfile.mkdtemp(prefix="map_pieces_")
    if not a.pieces:
        run_godot(a.godot, pieces)
    out = os.path.abspath(a.out)
    os.makedirs(os.path.join(out, "preview"), exist_ok=True)
    k = 8
    over = Image.new("RGBA", (w // k, h // k), (250, 245, 235, 255))
    for cy in range(rows):
        for cx in range(cols):
            pw, ph = size_of(world, cx, cy)
            layers = {l: piece(pieces, l, cx, cy, pw, ph) for l in LAYERS}
            write_psd(os.path.join(out, "%d_%d.psd" % (cx, cy)), layers, guide(world, cx, cy, pw, ph))
            flat = Image.fromarray(layers["ground"], "RGBA")
            for l in LAYERS[1:]:
                flat.alpha_composite(Image.fromarray(layers[l], "RGBA"))
            flat.save(os.path.join(out, "preview", "%d_%d.png" % (cx, cy)), optimize=True)
            over.alpha_composite(flat.resize((pw // k, ph // k), Image.LANCZOS), (cx * PW // k, cy * PH // k))
    d = ImageDraw.Draw(over)
    for cy in range(rows):
        for cx in range(cols):
            pw, ph = size_of(world, cx, cy)
            d.rectangle([cx * PW // k, cy * PH // k, cx * PW // k + pw // k - 1, cy * PH // k + ph // k - 1], outline=(75, 63, 114, 200), width=2)
            d.text((cx * PW // k + 5, cy * PH // k + 4), "%d_%d" % (cx, cy), fill=(75, 63, 114, 255))
    over.save(os.path.join(out, "overview.png"))
    print("%s: %d×%d장(한 장 %d×%dpx, 오른쪽 열 %dpx 폭, 아래 줄 %dpx 높이), 지도 %d×%dpx" % (out, cols, rows, PW, PH, size_of(world, cols - 1, 0)[0], size_of(world, 0, rows - 1)[1], w, h))


if __name__ == "__main__":
    sys.exit(main())
