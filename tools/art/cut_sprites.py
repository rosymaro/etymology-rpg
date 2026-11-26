#!/usr/bin/env python3
"""사용자가 준 캐릭터 시트(docs/art/source/*.png)를 잘라 게임 그림으로 넣는다.

시트는 연한 모눈 바탕 위에 캐릭터가 3줄 × 6칸으로 있고, 칸 아래에 글씨(IDLE 01 …)가 있다.
1) 바탕: 밝고 색이 옅은 픽셀 중 그림 가장자리와 이어진 것(캐릭터 외곽선이 막아 줘서 흰 옷은 남는다)
2) 덩어리: 바탕이 아닌 큰 덩어리 하나가 캐릭터 한 명(글씨·하트·음표 같은 떨어진 작은 것은 버린다)
3) 위→아래, 왼쪽→오른쪽 순서로 번호를 매기고, 아래 FRAMES 표대로 이름을 붙인다
4) 같은 캐릭터의 그림은 한 크기 캔버스에 발끝(아래 가운데)을 맞춰 넣는다(움직일 때 흔들리지 않게)

결과(assets/art, src/ui/art.gd가 읽는다):
  hero/<m|f>_<동작>_<n>.png    필드 주인공(동작: idle, walk, joy, action, think)
  pal/<NN>_<동작>_<n>.png      필드 동행 유닛
  unit/uNN.png                 전투·도감 유닛 그림(정사각형)
  face/<인물>_normal.png       대화 얼굴(머리와 어깨)
쓰는 법(저장소 루트): python3 tools/art/cut_sprites.py
필요한 것: Pillow, numpy, scipy
"""
import os

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "docs/art/source")
OUT = os.path.join(ROOT, "assets/art")

# 시트 번호(위 줄부터 0..5, 6..11, 12..17) → 캐릭터와 동작. 시트에서 어색한 칸(남자 머리에 치마 등)은 쓰지 않는다.
FRAMES = {
    "heroes_sheet.png": {
        "hero/m": {"idle": [0], "walk": [6, 7], "joy": [3], "action": [11], "think": [2]},
        "hero/f": {"idle": [12], "walk": [12, 14], "joy": [16], "action": [17], "think": [15]},
    },
    "penguins_sheet.png": {
        "pal/01": {"idle": [0], "walk": [13], "joy": [12], "action": [1]},  # 뚝딱(만들기): 안전모, 망치
        "pal/04": {"idle": [2], "walk": [2], "joy": [14], "action": [8], "think": [3]},  # 척척(알기): 학자 모자, 돋보기, 책
        "pal/05": {"idle": [4], "walk": [17], "joy": [16], "action": [10]},  # 조잘(말하기): 헤드폰, 마이크
    },
}
FACES = {"hero/m": "hero_m", "hero/f": "hero_f", "pal/01": "ttukttak", "pal/04": "cheokcheok", "pal/05": "jojal"}
UNITS = {"pal/01": "u01", "pal/04": "u04", "pal/05": "u05"}
PAD = 6


def sprites(path):
    a = np.asarray(Image.open(path).convert("RGB"))
    ai = a.astype(int)
    bglike = (ai.min(-1) > 190) & (np.ptp(ai, -1) < 34)
    lab, _ = ndimage.label(bglike)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    fg = ndimage.binary_opening(~np.isin(lab, list(edge)), iterations=1)
    fl, n = ndimage.label(fg)
    sizes = ndimage.sum(fg, fl, range(1, n + 1))
    objs = ndimage.find_objects(fl)
    big = [i for i in range(n) if sizes[i] > max(sizes) * 0.25]
    # 줄로 묶는다(세로 가운데가 크게 떨어지면 다음 줄)
    big.sort(key=lambda i: (objs[i][0].start + objs[i][0].stop) / 2)
    rows, last = [], None
    for i in big:
        cy = (objs[i][0].start + objs[i][0].stop) / 2
        if last is None or cy - last > 100:
            rows.append([])
        rows[-1].append(i)
        last = cy
    order = [i for r in rows for i in sorted(r, key=lambda i: objs[i][1].start)]
    out = []
    for i in order:
        sl = objs[i]
        m = ndimage.binary_fill_holes(fl[sl] == i + 1)
        al = ndimage.gaussian_filter(m.astype(np.float32), 0.6)  # 가장자리를 살짝 부드럽게
        rgba = np.dstack([a[sl], (np.clip(al * 1.6 - 0.3, 0, 1) * 255).astype(np.uint8)])
        out.append(Image.fromarray(rgba, "RGBA"))
    return out


def save(img, rel):
    p = os.path.join(OUT, rel + ".png")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p, optimize=True)


def main():
    n = 0
    for sheet, chars in FRAMES.items():
        sp = sprites(os.path.join(SRC, sheet))
        assert len(sp) == 18, "%s: 캐릭터 %d개(18개여야 한다)" % (sheet, len(sp))
        for cid, anims in chars.items():
            used = sorted({k for v in anims.values() for k in v})
            w = max(sp[k].width for k in used) + PAD * 2
            h = max(sp[k].height for k in used) + PAD * 2

            def canvas(k):
                c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
                s = sp[k]
                c.alpha_composite(s, ((w - s.width) // 2, h - PAD - s.height))
                return c
            for anim, ks in anims.items():
                for j, k in enumerate(ks):
                    save(canvas(k), "%s_%s_%d" % (cid, anim, j + 1))
                    n += 1
            idle = canvas(anims["idle"][0])
            side = max(w, h)
            sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            sq.alpha_composite(idle, ((side - w) // 2, side - h))
            if cid in UNITS:
                save(sq, "unit/" + UNITS[cid])
            bb = idle.getbbox()  # 얼굴: 사람은 위에서 폭만큼(머리와 어깨), 펭귄은 몸 전체(머리가 곧 몸)
            fw = bb[2] - bb[0]
            face = idle.crop((bb[0], bb[1], bb[2], bb[1] + int(fw * 0.95))) if cid.startswith("hero") else idle.crop(bb)
            save(face, "face/%s_normal" % FACES[cid])
    print("그림 %d장 → %s" % (n, OUT))


if __name__ == "__main__":
    main()
