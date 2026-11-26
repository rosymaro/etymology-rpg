"""지도 데이터(data/map/world.json, data/map/biomes.json)를 읽어 그림에 쓸 칸 판을 미리 만든다.

칸(게임 판정)은 그대로 두고, 그림만 그 위에서 부드럽고 불규칙하게 그린다.
"""
import json
import os

import numpy as np
from scipy import ndimage

from core import TILE, cell_field, hexc

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

# 지역마다 그림 결(biomes.json의 name에 더해 그림 쪽에서만 쓰는 것)
STYLE = {
    "meadow": {"path": "#d8bf8c", "dry": False},
    "prairie": {"path": "#d9bd84", "dry": False},
    "autumn": {"path": "#d6b68a", "dry": False},
    "desert": {"path": "#dcb379", "dry": True},
    "tropical": {"path": "#e8d6a6", "dry": False},
    "blossom": {"path": "#dcc49a", "dry": False},
    "jungle": {"path": "#b99c6c", "dry": False},
    "snow": {"path": "#d6dfe9", "dry": True},
    "lava": {"path": "#857169", "dry": True},
    "twilight": {"path": "#cfc0dc", "dry": False},
    "sea": {"path": "#d8bf8c", "dry": False},
}


def biome_color(b, key, idx=0):
    """지역 풍경의 색 하나. key: ground, water, mountain, grass, tree, flowers, style:path"""
    if key.startswith("style:"):
        return hexc(STYLE[b["name"]][key[6:]])
    v = b.get(key, "")
    if isinstance(v, dict):
        v = v["colors"]
    if isinstance(v, list):
        v = v[min(idx, len(v) - 1)]
    if not v:
        v = "#8fbf7a" if key == "grass" else "#cccccc"
    return hexc(v)


class World:
    def __init__(self):
        d = json.load(open(os.path.join(ROOT, "data/map/world.json"), encoding="utf-8"))
        b = json.load(open(os.path.join(ROOT, "data/map/biomes.json"), encoding="utf-8"))
        self.d = d
        self.w, self.h = d["w"], d["h"]
        self.rows = np.array([list(r) for r in d["rows"]])
        z = np.array([list(r) for r in d["zones"]])
        self.stage = np.zeros((self.h, self.w), np.int32)
        for y in range(self.h):
            for x in range(self.w):
                c = z[y, x]
                if c.isdigit():
                    self.stage[y, x] = 10 if c == "0" else int(c)
        self.bio = {}
        for k, v in b["biomes"].items():
            self.bio[int(k)] = v
        self.bio[0] = dict(self.bio[1], name="sea")
        self.sea = [hexc(c) for c in b["sea"]]
        # 퀘스트 길목: 다리(bridge)는 물 위 다리로, 절벽(cliff)은 길로 그린다(열린 모습, 배경은 사라지지 않는 것만)
        self.qkind = {}
        for qg in d["quest_gates"]:
            for t in qg["tiles"]:
                self.qkind[(t[1], t[0])] = qg["kind"]
        self._fields = {}
        self._colors = {}

    def is_(self, chars):
        return np.isin(self.rows, list(chars))

    def mask(self, name):
        r = self.rows
        q_bridge = np.zeros_like(r, bool)
        q_path = np.zeros_like(r, bool)
        for (y, x), k in self.qkind.items():
            (q_bridge if k == "bridge" else q_path)[y, x] = True
        return {
            "water": self.is_("~wb") | q_bridge,
            "sea": self.is_("~"),
            "path": self.is_("p=") | q_path,
            "plaza": self.is_(",hosKM"),
            "stone": self.is_("s"),
            "farm": self.is_("f"),
            "ice": self.is_("i"),
            "cliff": self.is_("#"),
            "wall": self.is_("H"),
            "mtn": self.is_("^c"),
            "forest": self.is_("T"),
            "fence": self.is_("F"),
            "bridge": self.is_("b") | q_bridge,
            "land": ~(self.is_("~wb") | q_bridge),
        }[name]

    def field(self, name, sigma):
        """칸 판을 흐린 것(지도 전체, 한 번만)."""
        k = (name, sigma)
        if k not in self._fields:
            self._fields[k] = cell_field(self.mask(name), sigma)
        return self._fields[k]

    def edt(self, name):
        """그 칸 무리의 가장자리에서 안쪽으로 몇 칸인가(지도 전체)."""
        k = ("edt", name)
        if k not in self._fields:
            m = self.mask(name)
            self._fields[k] = ndimage.gaussian_filter(ndimage.distance_transform_edt(m).astype(np.float32), 0.8)
        return self._fields[k]

    def color(self, key, idx=0, sigma=2.2):
        """지역 색(biomes.json)을 지역 경계에서 부드럽게 섞은 칸 판(3채널)."""
        k = (key, idx, sigma)
        if k in self._colors:
            return self._colors[k]
        acc = np.zeros((self.h, self.w, 3), np.float32)
        wsum = np.zeros((self.h, self.w), np.float32)
        for s, b in self.bio.items():
            m = self.stage == s
            if not m.any():
                continue
            c = biome_color(b, key, idx) if not (key == "water" and s == 0) else self.sea[idx]
            wgt = ndimage.gaussian_filter(m.astype(np.float32), sigma, mode="nearest")
            acc += wgt[..., None] * c
            wsum += wgt
        out = acc / np.maximum(wsum, 1e-6)[..., None]
        self._colors[k] = out
        return out

    def biome_at(self, cy, cx):
        cy = min(max(cy, 0), self.h - 1)
        cx = min(max(cx, 0), self.w - 1)
        s = int(self.stage[cy, cx])
        if s == 0:  # 바다 칸에 붙은 땅(섬 가장자리)은 가장 가까운 지역
            ys, xs = np.nonzero(self.stage[max(0, cy - 6):cy + 7, max(0, cx - 6):cx + 7])
            if len(ys):
                s = int(self.stage[max(0, cy - 6) + ys[0], max(0, cx - 6) + xs[0]])
        return self.bio.get(s, self.bio[1])

    def buildings(self):
        out = []
        for rg in self.d["regions"]:
            for bd in rg.get("buildings", []):
                out.append(bd)
        return out

    def px_size(self):
        return self.w * TILE, self.h * TILE
