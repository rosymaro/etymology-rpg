#!/usr/bin/env python3
"""그린 지도 배경 그림을 게임에 넣기(export_map.py의 반대). assets/map/README.md

<폴더>의 <열>_<행>.psd(겹 ground, grass, mtn, trees)를 assets/map/<겹>/<열>_<행>.png로 푼다.
- PSD에 없는 겹은 빈(투명) 그림으로 쓴다: 그 조각은 게임이 그 겹을 코드로 그리지 않는다.
- <열>_<행>.png(겹을 합친 한 장)도 받는다: 바닥(ground)으로 쓰고 나머지 겹은 비운다.
- 크기는 export_map.py가 낸 것과 같아야 한다(보통 1024×1536, 지도 끝 조각은 더 작다).

쓰는 법: python3 tools/map/import_map.py <그린 파일 폴더> [--only 7_3,8_3]
"""
import argparse
import json
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_map import LAYERS, ROOT, size_of  # noqa: E402

Image.MAX_IMAGE_PIXELS = None


def layers_of(path, size):
    if path.lower().endswith(".png"):
        out = {"ground": Image.open(path).convert("RGBA")}
    else:
        from psd_tools import PSDImage
        psd = PSDImage.open(path)
        out = {}
        for layer in psd.descendants():
            name = layer.name.strip().lower().split(" ")[0]
            if name in LAYERS and not layer.is_group():
                img = layer.composite(viewport=(0, 0, psd.width, psd.height), force=True)
                if img is not None:
                    out[name] = img.convert("RGBA")
    for k in LAYERS:
        if k not in out:
            out[k] = Image.new("RGBA", size, (0, 0, 0, 0))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    world = json.load(open(os.path.join(ROOT, "data/map/world.json"), encoding="utf-8"))
    only = set(s for s in a.only.split(",") if s)
    n = 0
    for name in sorted(os.listdir(a.src)):
        m = re.fullmatch(r"(\d+)_(\d+)\.(psd|png)", name, re.I)
        if not m or (only and "%s_%s" % (m[1], m[2]) not in only):
            continue
        cx, cy = int(m[1]), int(m[2])
        size = size_of(world, cx, cy)
        if size[0] <= 0 or size[1] <= 0:
            print("건너뜀(지도 밖):", name)
            continue
        ls = layers_of(os.path.join(a.src, name), size)
        for k, img in ls.items():
            if img.size != size:
                sys.exit("%s의 %s 겹 크기가 %s인데 %s여야 한다" % (name, k, img.size, size))
            if k == "ground" and img.getextrema()[3][0] < 255:
                print("주의: %s 바닥(ground)에 투명한 곳이 있다(그 자리는 바다색으로 보인다)" % name)
            d = os.path.join(ROOT, "assets/map", k)
            os.makedirs(d, exist_ok=True)
            img.save(os.path.join(d, "%d_%d.png" % (cx, cy)), optimize=True)
            for old in ("%d_%d.webp" % (cx, cy), "%d_%d.webp.import" % (cx, cy)):  # 그린 그림이 지도 그리개 그림을 대신한다
                if os.path.exists(os.path.join(d, old)):
                    os.remove(os.path.join(d, old))
        n += 1
    print("넣은 조각 %d장 → assets/map/<겹>/" % n)


if __name__ == "__main__":
    sys.exit(main())
