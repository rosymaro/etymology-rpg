"""스테이지 1~10이 모두 들어 있는 월드맵(data/map/world.json)을 만든다. 저장소 루트에서: python3 tools/map/build_world.py

- 지역 10개를 2열 × 5줄 뱀 모양(1→2 오른쪽, 2→3 아래, 3→4 왼쪽 …)으로 놓는다.
- 지역 안은 미로다. 통로(CORR칸)를 벽(WALL칸)이 가르고, 벽은 그 지역 풍경(산, 바다, 호수, 절벽, 숲, 성벽)으로 칠한다.
  완전 미로를 판 뒤 벽을 조금 더 허물어 갈림길을 만든다. 물 벽을 허문 곳은 다리, 산을 허문 곳은 고갯길.
- 마을은 들어오는 자리 둘레(칸 3×2)를 비워 모래 바닥으로. 보스는 다음 지역 쪽 가장자리 칸 중 마을에서 가장 먼 칸.
- 보스 칸에서 다음 지역으로 가는 문(=)은 그 스테이지 보스를 이기고, 다음 스테이지가 열려 있어야 지나간다(게임이 판정).
글자: . 풀  , 마을 바닥  p 고갯길  b 다리  = 스테이지 문  ^ 산  ~ 바다  w 호수·강  # 절벽  T 숲  H 성벽
"""
import json, os, random, collections
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CW, CH = 10, 8          # 지역 하나의 미로 칸 수
CORR, WALL = 4, 2       # 통로 폭, 벽 두께(타일)
PITCH = CORR + WALL
BORDER = 2
RW = CW * PITCH - WALL + BORDER * 2   # 지역 타일 너비
RH = CH * PITCH - WALL + BORDER * 2
COLS, ROWS = 2, 5
TILE = 64
# 스테이지 풍경(벽에 쓰는 타일과 비율)
THEME = {1: '^TT.', 2: 'TTw^', 3: '##^T', 4: '##^^', 5: '~~w^', 6: 'HHw#', 7: 'ww~T', 8: 'HH##', 9: '^^^#', 10: '##^H'}
BORDER_T = {1: '^', 2: 'T', 3: '#', 4: '^', 5: '~', 6: 'H', 7: 'w', 8: 'H', 9: '^', 10: '#'}

def region_origin(i):
    row = i // 2
    col = (i % 2) if row % 2 == 0 else 1 - (i % 2)
    return col * RW, row * RH, col, row

def next_dir(i):
    """지역 i에서 i+1로 가는 쪽: E W S"""
    _, _, c, r = region_origin(i); _, _, c2, r2 = region_origin(i + 1)
    return 'E' if c2 > c else ('W' if c2 < c else 'S')

def cell_rect(ox, oy, cx, cy):
    x = ox + BORDER + cx * PITCH; y = oy + BORDER + cy * PITCH
    return x, y

def main():
    W, H = COLS * RW, ROWS * RH
    g = [['^'] * W for _ in range(H)]
    regions, gates = [], []
    entry = (0, 0)
    for i in range(10):
        st = i + 1
        rnd = random.Random(1000 + st)
        ox, oy, _, _ = region_origin(i)
        theme = THEME[st]
        # 지역 바깥 테두리
        for y in range(oy, oy + RH):
            for x in range(ox, ox + RW):
                g[y][x] = BORDER_T[st]
        # 미로 벽으로 채운 뒤 통로를 판다
        for y in range(oy + BORDER, oy + RH - BORDER):
            for x in range(ox + BORDER, ox + RW - BORDER):
                g[y][x] = 'X'
        def open_cell(cx, cy):
            x, y = cell_rect(ox, oy, cx, cy)
            for yy in range(y, y + CORR):
                for xx in range(x, x + CORR):
                    g[yy][xx] = '.'
        def open_between(a, b, kind='.'):
            (ax, ay), (bx, by) = a, b
            x, y = cell_rect(ox, oy, min(ax, bx), min(ay, by))
            if ax != bx:
                rng_x = range(x + CORR, x + CORR + WALL); rng_y = range(y, y + CORR)
            else:
                rng_x = range(x, x + CORR); rng_y = range(y + CORR, y + CORR + WALL)
            for yy in rng_y:
                for xx in rng_x:
                    g[yy][xx] = kind
        for cy in range(CH):
            for cx in range(CW):
                open_cell(cx, cy)
        # 큰 지형(호수·바다·산덩이): 여러 칸을 통째로 막는다. 마을 자리와 다음 지역 쪽 가장자리 절반은 남긴다
        ex, ey = entry
        tx0 = 0 if ex == 0 else (CW - 3 if ex == CW - 1 else ex - 1)
        ty0 = 0 if ey == 0 else (CH - 2 if ey >= CH - 1 else ey)
        protect = {(x, y) for x in range(tx0, tx0 + 3) for y in range(ty0, ty0 + 2)}
        nd = next_dir(i) if i < 9 else None
        edge = [(CW - 1, y) for y in range(CH)] if nd == 'E' else ([(0, y) for y in range(CH)] if nd == 'W' else
               ([(x, CH - 1) for x in range(CW)] if nd == 'S' else []))
        blob = {}  # 칸 -> 지형 글자
        big = [c for c in theme if c in '~w^#H'] or ['^']
        for k in range(rnd.randint(2, 4)):
            kind = rnd.choice(big)
            c = (rnd.randrange(CW), rnd.randrange(CH))
            for step in range(rnd.randint(3, 6)):
                if c not in protect and c not in blob and sum(1 for e in edge if e in blob or e == c) <= len(edge) // 2:
                    blob[c] = kind
                dx, dy = rnd.choice(((1, 0), (-1, 0), (0, 1), (0, -1)))
                c = (min(CW - 1, max(0, c[0] + dx)), min(CH - 1, max(0, c[1] + dy)))
        # 완전 미로(깊이 우선): 막힌 칸은 건너뛴다
        seen = {entry}; stack = [entry]; links = set()
        while stack:
            c = stack[-1]
            nb = [(c[0] + dx, c[1] + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                  if 0 <= c[0] + dx < CW and 0 <= c[1] + dy < CH and (c[0] + dx, c[1] + dy) not in seen
                  and (c[0] + dx, c[1] + dy) not in blob]
            if not nb:
                stack.pop(); continue
            n = rnd.choice(nb); seen.add(n); stack.append(n); links.add(frozenset((c, n)))
        for cy in range(CH):  # 미로에서 닿지 않는 칸은 둘레 지형으로 막는다
            for cx in range(CW):
                if (cx, cy) not in seen and (cx, cy) not in blob:
                    near = [blob[(cx + dx, cy + dy)] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if (cx + dx, cy + dy) in blob]
                    blob[(cx, cy)] = near[0] if near else rnd.choice(big)
        # 갈림길과 들판: 벽 몇 개를 더 허물고, 2×2 칸 들판을 한두 군데 튼다
        extra = []
        def free(c):
            return c in seen and c not in blob
        for cy in range(CH):
            for cx in range(CW):
                for dx, dy in ((1, 0), (0, 1)):
                    n = (cx + dx, cy + dy)
                    if n[0] < CW and n[1] < CH and free((cx, cy)) and free(n) and frozenset(((cx, cy), n)) not in links and rnd.random() < 0.035:
                        extra.append(frozenset(((cx, cy), n)))
        meadows = []
        for k in range(rnd.randint(1, 2)):
            mx, my = rnd.randrange(CW - 1), rnd.randrange(CH - 1)
            block = [(mx, my), (mx + 1, my), (mx, my + 1), (mx + 1, my + 1)]
            if all(free(c) for c in block):
                meadows.append(block)
                for a, b in (((mx, my), (mx + 1, my)), ((mx, my + 1), (mx + 1, my + 1)), ((mx, my), (mx, my + 1)), ((mx + 1, my), (mx + 1, my + 1))):
                    l = frozenset((a, b))
                    if l not in links and l not in extra:
                        extra.append(l)
        # 칠하기: 큰 지형 칸(과 그 사이 벽), 나머지 벽은 덩어리마다 한 풍경
        for (cx, cy), kind in blob.items():
            x, y = cell_rect(ox, oy, cx, cy)
            for yy in range(y, y + CORR):
                for xx in range(x, x + CORR):
                    g[yy][xx] = kind
            for dx, dy in ((1, 0), (0, 1)):
                if (cx + dx, cy + dy) in blob:
                    if dx: rx, ry = range(x + CORR, x + PITCH), range(y, y + CORR)
                    else: rx, ry = range(x, x + CORR), range(y + CORR, y + PITCH)
                    for yy in ry:
                        for xx in rx: g[yy][xx] = kind
            if (cx + 1, cy) in blob and (cx, cy + 1) in blob and (cx + 1, cy + 1) in blob:
                for yy in range(y + CORR, y + PITCH):
                    for xx in range(x + CORR, x + PITCH): g[yy][xx] = kind
        paint = {}
        for y in range(oy + BORDER, oy + RH - BORDER):
            for x in range(ox + BORDER, ox + RW - BORDER):
                if g[y][x] == 'X':
                    key = ((x - ox) // (PITCH * 2), (y - oy) // (PITCH * 2))
                    if key not in paint:
                        paint[key] = rnd.choice(theme.replace('.', '') or '^')
                    g[y][x] = paint[key]
        for l in links:
            a, b = tuple(l); open_between(a, b)
        for l in extra:
            a, b = tuple(l)
            x, y = cell_rect(ox, oy, min(a[0], b[0]), min(a[1], b[1]))
            probe = g[y + CORR if a[0] == b[0] else y][x + CORR if a[0] != b[0] else x]
            open_between(a, b, 'b' if probe in 'w~' else ('p' if probe in '^#' else '.'))
        for block in meadows:  # 들판 가운데 기둥도 없앤다
            (mx, my) = block[0]
            x, y = cell_rect(ox, oy, mx, my)
            for yy in range(y + CORR, y + PITCH):
                for xx in range(x + CORR, x + PITCH): g[yy][xx] = '.'
        # 큰 지형 가장자리를 들쭉날쭉하게: 맞닿은 통로 한 줄을 군데군데 물가·산기슭으로(통로는 3칸 이상 남는다)
        for (cx, cy), kind in blob.items():
            x, y = cell_rect(ox, oy, cx, cy)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (cx + dx, cy + dy)
                if not (0 <= n[0] < CW and 0 <= n[1] < CH) or n in blob or n in protect:
                    continue
                nx, ny = cell_rect(ox, oy, *n)
                for k in range(CORR):
                    if rnd.random() < 0.35:
                        if dx == 1: tx, ty = nx, ny + k
                        elif dx == -1: tx, ty = nx + CORR - 1, ny + k
                        elif dy == 1: tx, ty = nx + k, ny
                        else: tx, ty = nx + k, ny + CORR - 1
                        g[ty][tx] = kind
        # 마을: 들어오는 칸 둘레 3×2 칸
        x0, y0 = cell_rect(ox, oy, tx0, ty0)
        x1, y1 = cell_rect(ox, oy, tx0 + 2, ty0 + 1)
        for yy in range(y0, y1 + CORR):
            for xx in range(x0, x1 + CORR):
                g[yy][xx] = ','
        town = [x0, y0, x1 + CORR - x0, y1 + CORR - y0]
        # 마을에서 칸 거리(BFS)
        adj = collections.defaultdict(set)
        for l in list(links) + extra:
            a, b = tuple(l); adj[a].add(b); adj[b].add(a)
        for cy in range(ty0, ty0 + 2):
            for cx in range(tx0, tx0 + 3):
                for dx, dy in ((1, 0), (0, 1)):
                    n = (cx + dx, cy + dy)
                    if tx0 <= n[0] < tx0 + 3 and ty0 <= n[1] < ty0 + 2:
                        adj[(cx, cy)].add(n); adj[n].add((cx, cy))
        dist = {entry: 0}; q = collections.deque([entry])
        while q:
            c = q.popleft()
            for n in adj[c]:
                if n not in dist:
                    dist[n] = dist[c] + 1; q.append(n)
        d = nd
        if d == 'E': cand = [(CW - 1, y) for y in range(CH)]
        elif d == 'W': cand = [(0, y) for y in range(CH)]
        elif d == 'S': cand = [(x, CH - 1) for x in range(CW)]
        else: cand = list(dist)
        cand = [c for c in cand if c in dist]
        assert cand, ('다음 지역 쪽 가장자리에 닿는 칸이 없다', st)
        boss = max(cand, key=lambda c: dist[c])
        bx, by = cell_rect(ox, oy, *boss)
        def px(tx, ty):
            return [tx * TILE, ty * TILE]
        spots = {'boss': px(bx + CORR / 2, by + CORR / 2)}
        if st == 1:  # 스테이지 1 마을(공방 마을): 대장간, 말뿌리 나무, 주문 제작소
            spots['forge'] = px(x0 + 2, y0 + 2)
            spots['tree'] = px(x0 + 2 + PITCH * 2, y0 + 2)
            spots['board'] = px(x0 + 2, y0 + 2 + PITCH)
        regions.append({'stage': st, 'rect': [ox, oy, RW, RH], 'town': town, 'spots': spots,
                        'start': px(x0 + PITCH + 2, y0 + PITCH // 2 + 2), 'boss_cell': list(boss), 'steps': dist.get(boss, 0)})
        # 다음 지역으로 가는 문
        if d:
            tiles = []
            if d in 'EW':
                xs = range(bx + CORR, bx + CORR + BORDER * 2) if d == 'E' else range(bx - BORDER * 2, bx)
                for yy in range(by, by + CORR):
                    for xx in xs: tiles.append([xx, yy])
                entry = (0, boss[1]) if d == 'E' else (CW - 1, boss[1])
            else:
                for yy in range(by + CORR, by + CORR + BORDER * 2):
                    for xx in range(bx, bx + CORR): tiles.append([xx, yy])
                entry = (boss[0], 0)
            gates.append({'stage': st, 'tiles': tiles})
    for gt in gates:  # 다음 지역 테두리를 그린 뒤에 문을 뚫는다
        for xx, yy in gt['tiles']: g[yy][xx] = '='
    out = {'_doc': __doc__.strip().split('\n')[0] + ' tools/map/build_world.py가 만든다(손으로 고치지 않는다).',
           'tile': TILE, 'w': W, 'h': H, 'rows': [''.join(r) for r in g], 'regions': regions, 'gates': gates,
           'walk': '.,pb', 'gate': '='}
    json.dump(out, open(os.path.join(ROOT, 'data/map/world.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('world', W, 'x', H, 'tiles; steps to boss:', [r['steps'] for r in regions])

if __name__ == '__main__':
    main()
