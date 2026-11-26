#!/usr/bin/env python3
"""화면 아이콘을 그린다(사용자 의견: 레퍼런스처럼 갈색 외곽선, 통통하고 따뜻한 동화풍).

결과: assets/ui/icons/<이름>.png (128×128, 투명). 다시 그리려면 저장소 루트에서
  python3 tools/ui/make_icons.py
사람이 그린 같은 이름의 PNG로 바꿔 넣어도 된다(크기는 정사각형이면 된다).
필요한 것: Pillow
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets/ui/icons")
S = 128
K = 4  # 4배로 그려 줄인다(부드러운 가장자리)
N = S * K
LINE = (92, 58, 36)  # 갈색 외곽선(UiKit.INK와 같은 색)
OW = 7 * K  # 외곽선 두께


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def shift(img, dx, dy):
    return ImageChops.offset(img, dx, dy)


class Icon:
    def __init__(self):
        self.parts = []  # (mask, 색)

    def part(self, color, fn, round_px=4):
        m = Image.new("L", (N, N), 0)
        fn(ImageDraw.Draw(m))
        if round_px:  # 뾰족한 모서리를 둥글게(흐린 뒤 반으로 자른다)
            m = m.filter(ImageFilter.GaussianBlur(round_px * K)).point(lambda v: 255 if v > 127 else 0)
        self.parts.append((m, rgb(color)))
        return m

    def render(self, path):
        union = Image.new("L", (N, N), 0)
        for m, _ in self.parts:
            union = ImageChops.lighter(union, m)
        out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        ol = union.filter(ImageFilter.MaxFilter(OW | 1))
        # 아래로 살짝 그림자
        sh = shift(ol, 0, 3 * K).filter(ImageFilter.GaussianBlur(2 * K))
        out.paste((60, 36, 20, 90), (0, 0), sh.point(lambda v: v * 0.5))
        out.paste(LINE + (255,), (0, 0), ol)
        for m, c in self.parts:
            # 칸 사이에도 갈색 선이 남게 조금 깎아 칠한다
            inner = m.filter(ImageFilter.MinFilter(int(OW * 0.55) | 1))
            out.paste(c + (255,), (0, 0), inner)
            # 오른쪽 아래 그늘, 왼쪽 위 빛
            dark = ImageChops.subtract(inner, shift(inner, -5 * K, -5 * K))
            out.paste(tuple(int(v * 0.8) for v in c) + (255,), (0, 0), dark.filter(ImageFilter.GaussianBlur(K)))
            lite = ImageChops.subtract(inner, shift(inner, 4 * K, 4 * K))
            out.paste(tuple(min(255, int(v + (255 - v) * 0.45)) for v in c) + (255,), (0, 0), lite.filter(ImageFilter.GaussianBlur(K)))
        out = out.resize((S, S), Image.LANCZOS)
        out.save(path)


def P(x, y):
    return (x * K, y * K)


def box(x0, y0, x1, y1):
    return [x0 * K, y0 * K, x1 * K, y1 * K]


def star_pts(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append(P(cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def rounded_poly(d, pts, r):
    d.polygon(pts, fill=255)  # 둥글리기는 Icon.part가 한다


def icons():
    out = {}

    i = Icon()  # 깃발(퀘스트)
    i.part("#c9a06a", lambda d: d.rounded_rectangle(box(30, 18, 40, 112), 5 * K, fill=255))
    i.part("#f06a5a", lambda d: d.polygon([P(40, 22), P(98, 30), P(84, 50), P(100, 70), P(40, 66)], fill=255))
    i.part("#ffd75e", lambda d: d.ellipse(box(26, 10, 44, 28), fill=255))
    out["flag"] = i

    i = Icon()  # 가방(도감)
    i.part("#c98a4b", lambda d: d.rounded_rectangle(box(42, 14, 86, 44), 14 * K, fill=255, outline=0, width=0))
    i.part("#e7a35a", lambda d: d.rounded_rectangle(box(20, 30, 108, 114), 26 * K, fill=255))
    i.part("#f6c87a", lambda d: d.rounded_rectangle(box(36, 64, 92, 104), 12 * K, fill=255))
    i.part("#ffe08a", lambda d: d.rounded_rectangle(box(56, 56, 72, 74), 5 * K, fill=255))
    out["bag"] = i

    i = Icon()  # 별(파티)
    i.part("#ffd24d", lambda d: rounded_poly(d, star_pts(64, 68, 56, 27), 6))
    out["star"] = i

    i = Icon()  # 하트(저장)
    def heart(d):
        d.ellipse(box(14, 22, 66, 74), fill=255)
        d.ellipse(box(62, 22, 114, 74), fill=255)
        d.polygon([P(18, 60), P(110, 60), P(64, 112)], fill=255)
    i.part("#f47a96", heart)
    out["heart"] = i

    i = Icon()  # 톱니(옵션)
    def gear(d):
        for k in range(8):
            a = k * math.pi / 4
            ca, sa = math.cos(a), math.sin(a)
            pts = [(-11, 30), (11, 30), (9, 58), (-9, 58)]
            d.polygon([P(64 + x * -sa + y * ca, 64 + x * ca + y * sa) for x, y in pts], fill=255)
        d.ellipse(box(18, 18, 110, 110), fill=255)
    i.part("#9fb4c8", gear)
    i.part("#e9eef3", lambda d: d.ellipse(box(48, 48, 80, 80), fill=255))
    out["gear"] = i

    i = Icon()  # 핀(위치)
    def pin(d):
        d.ellipse(box(24, 10, 104, 90), fill=255)
        d.polygon([P(30, 66), P(98, 66), P(64, 118)], fill=255)
    i.part("#f06a5a", pin)
    i.part("#fff4e0", lambda d: d.ellipse(box(48, 32, 80, 64), fill=255))
    out["pin"] = i

    i = Icon()  # 코인
    i.part("#f2b330", lambda d: d.ellipse(box(12, 12, 116, 116), fill=255))
    i.part("#ffd75e", lambda d: d.ellipse(box(28, 28, 100, 100), fill=255))
    i.part("#f2b330", lambda d: rounded_poly(d, star_pts(64, 66, 24, 11), 2))
    out["coin"] = i

    i = Icon()  # ! (할 일)
    i.part("#ff9f45", lambda d: d.ellipse(box(10, 10, 118, 118), fill=255))
    i.part("#fffaf0", lambda d: d.rounded_rectangle(box(55, 28, 73, 78), 9 * K, fill=255))
    i.part("#fffaf0", lambda d: d.ellipse(box(54, 84, 74, 104), fill=255))
    out["alert"] = i

    i = Icon()  # 집(마을로)
    i.part("#fbe7c6", lambda d: d.rectangle(box(28, 56, 100, 112), fill=255))
    i.part("#f06a5a", lambda d: rounded_poly(d, [P(14, 62), P(64, 16), P(114, 62)], 5))
    i.part("#b9764a", lambda d: d.rounded_rectangle(box(54, 78, 76, 112), 8 * K, fill=255))
    out["house"] = i

    i = Icon()  # 발바닥(FPS)
    def paw(d):
        d.ellipse(box(30, 58, 98, 112), fill=255)
        for (x, y) in ((18, 46), (44, 20), (84, 20), (110, 46)):
            d.ellipse(box(x - 12, y - 14, x + 12, y + 14), fill=255)
    i.part("#c98a5a", paw)
    out["paw"] = i

    i = Icon()  # 반짝(필드 마법)
    i.part("#b9a4f2", lambda d: rounded_poly(d, star_pts(64, 64, 54, 16, 4, -90), 4))
    i.part("#fff4a8", lambda d: rounded_poly(d, star_pts(98, 26, 18, 6, 4, -90), 2))
    out["magic"] = i

    i = Icon()  # 더하기
    i.part("#8fd18a", lambda d: d.ellipse(box(8, 8, 120, 120), fill=255))
    i.part("#fffaf0", lambda d: (d.rounded_rectangle(box(56, 30, 72, 98), 8 * K, fill=255), d.rounded_rectangle(box(30, 56, 98, 72), 8 * K, fill=255)))
    out["plus"] = i

    i = Icon()  # 빼기
    i.part("#fbe7c6", lambda d: d.ellipse(box(8, 8, 120, 120), fill=255))
    i.part("#b9764a", lambda d: d.rounded_rectangle(box(30, 56, 98, 72), 8 * K, fill=255))
    out["minus"] = i

    i = Icon()  # 잎 장식
    i.part("#7cc46a", lambda d: d.ellipse(box(14, 36, 70, 70), fill=255))
    i.part("#62ad5c", lambda d: d.ellipse(box(58, 50, 114, 84), fill=255))
    i.part("#f6a5c0", lambda d: d.ellipse(box(48, 20, 80, 52), fill=255))
    out["leaf"] = i
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, ic in icons().items():
        ic.render(os.path.join(OUT, name + ".png"))
    print("아이콘 %d개 → %s" % (len(icons()), OUT))


if __name__ == "__main__":
    main()
