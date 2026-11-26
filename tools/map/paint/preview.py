#!/usr/bin/env python3
"""그린 지도(겹 webp)를 합쳐 미리보기를 만든다: 전체(1/8, 장 번호 격자)와 장마다 원래 크기.

쓰는 법: python3 tools/map/paint/preview.py [--src assets/map] [--out docs/art/map] [--pieces]
"""
import argparse
import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
LAYERS = ["ground", "grass", "mtn", "trees"]
PW, PH = 1024, 1536


def piece(src, name):
    p = os.path.join(src, "ground", name + ".webp")
    if not os.path.exists(p):
        return None
    im = Image.open(p).convert("RGBA")
    for l in LAYERS[1:]:
        q = os.path.join(src, l, name + ".webp")
        if os.path.exists(q):
            im.alpha_composite(Image.open(q).convert("RGBA"))
    return im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default=os.path.join(ROOT, "assets/map"))
    ap.add_argument("--out", default=os.path.join(ROOT, "docs/art/map"))
    ap.add_argument("--pieces", action="store_true", help="장마다 원래 크기 미리보기도(preview/<열>_<행>.png)")
    a = ap.parse_args()
    d = json.load(open(os.path.join(ROOT, "data/map/world.json"), encoding="utf-8"))
    w, h = d["w"] * d["tile"], d["h"] * d["tile"]
    cols, rows = -(-w // PW), -(-h // PH)
    k = 8
    over = Image.new("RGBA", (w // k, h // k), (250, 245, 235, 255))
    os.makedirs(a.out, exist_ok=True)
    if a.pieces:
        os.makedirs(os.path.join(a.out, "preview"), exist_ok=True)
    for cy in range(rows):
        for cx in range(cols):
            name = "%d_%d" % (cx, cy)
            im = piece(a.src, name)
            if im is None:
                continue
            if a.pieces:
                im.convert("RGB").save(os.path.join(a.out, "preview", name + ".jpg"), quality=88)
            over.alpha_composite(im.resize((im.width // k, im.height // k), Image.LANCZOS), (cx * PW // k, cy * PH // k))
    plain = over.copy()
    dr = ImageDraw.Draw(over)
    for cy in range(rows):
        for cx in range(cols):
            dr.rectangle([cx * PW // k, cy * PH // k, min(w, (cx + 1) * PW) // k - 1, min(h, (cy + 1) * PH) // k - 1], outline=(75, 63, 114, 180), width=2)
            dr.text((cx * PW // k + 5, cy * PH // k + 4), "%d_%d" % (cx, cy), fill=(75, 63, 114, 255))
    over.convert("RGB").save(os.path.join(a.out, "overview.jpg"), quality=90)
    plain.convert("RGB").save(os.path.join(a.out, "overview_plain.jpg"), quality=90)
    print("→", a.out)


if __name__ == "__main__":
    main()
