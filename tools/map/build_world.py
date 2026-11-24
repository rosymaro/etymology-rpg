"""스테이지 1~10이 모두 들어 있는 월드맵(data/map/world.json)을 만든다. 저장소 루트에서: python3 tools/map/build_world.py

- 지도는 가로가 긴 황금비(260 × 160). 가장자리는 들쭉날쭉한 바다.
- 스테이지 1(공방 마을)이 한가운데이고, 다른 지역은 시계 방향 자리에 둘러 있다:
  2 → 2시, 3 → 4시, 4 → 10시, 5 → 6시, 6 → 8시, 7 → 12시, 8 → 3시, 9 → 9시, 10 → 5시.
  지역 경계는 곧은 선이 아니라 들쭉날쭉한 산줄기·숲·절벽·물길이다(넘어갈 수 없다).
- 스테이지 k 보스를 이기면 가운데 지역에서 지역 k+1로 가는 문(=)이 열린다(게임이 판정). 둘레 지역끼리는 막혀 있다.
- 지역 안은 젤다의 전설 꿈꾸는 섬의 들판처럼: 호수·언덕·숲이 길을 가르고, 강은 다리 하나로만 건넌다.
  미로는 세 지역에만(2 사냥꾼 숲, 6 왕성 정원, 9 광산 갱도). 보스는 들어온 곳에서 걸어서 가장 먼 쪽.
글자: . 풀  , 마을 바닥  p 길·고갯길  b 다리  = 스테이지 문  ^ 산  ~ 바다  w 호수·강  # 절벽  T 숲  H 성벽·생울타리
"""
import json, os, random, heapq, collections, math
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
W, H = 260, 160
TILE = 64
HOURS = {2: 2, 3: 4, 4: 10, 5: 6, 6: 8, 7: 12, 8: 3, 9: 9, 10: 5}  # 스테이지 → 시계 방향
#        높은 땅, 낮은 땅, 숲, 강, 미로 벽
THEME = {1: ('^', 'w', True, True, None), 2: ('^', 'w', True, True, 'T'), 3: ('#', 'w', True, False, None),
         4: ('#', 'w', False, True, None), 5: ('^', '~', False, False, None), 6: ('H', 'w', True, True, 'H'),
         7: ('^', 'w', True, False, None), 8: ('H', 'w', False, True, None), 9: ('^', 'w', False, False, '^'),
         10: ('#', 'w', False, False, None)}
LAKE = {7: 0.40, 5: 0.33}

def noise(rnd, w, h, step):
    gw, gh = w // step + 2, h // step + 2
    grid = [[rnd.random() for _ in range(gw)] for _ in range(gh)]
    out = [[0.0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            gx, gy = x / step, y / step
            x0, y0 = int(gx), int(gy); fx, fy = gx - x0, gy - y0
            fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
            a = grid[y0][x0] * (1 - fx) + grid[y0][x0 + 1] * fx
            b = grid[y0 + 1][x0] * (1 - fx) + grid[y0 + 1][x0 + 1] * fx
            out[y][x] = a * (1 - fy) + b * fy
    return out

N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))

def main():
    rnd = random.Random(31)
    cx, cy = W // 2, H // 2
    seeds = {1: (cx, cy)}
    for st, hr in HOURS.items():
        a = math.radians(hr * 30)
        seeds[st] = (cx + math.sin(a) * 92, cy - math.cos(a) * 56)
    weight = {st: (0.78 if st == 1 else 1.0) for st in seeds}
    # 지역 나누기: 좌표를 잡음으로 휘게 한 뒤 가장 가까운 씨앗(경계가 곧은 선이 되지 않게)
    w1 = noise(rnd, W, H, 22); w2 = noise(rnd, W, H, 22); w3 = noise(rnd, W, H, 8); w4 = noise(rnd, W, H, 8)
    zone = [[0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            qx = x + (w1[y][x] - 0.5) * 46 + (w3[y][x] - 0.5) * 14
            qy = y + (w2[y][x] - 0.5) * 34 + (w4[y][x] - 0.5) * 10
            best = None
            for st, (sx, sy) in seeds.items():
                d = math.hypot((qx - sx), (qy - sy) * 1.25) * weight[st]
                if best is None or d < best[0]: best = (d, st)
            zone[y][x] = best[1]
    # 작은 조각(다른 지역 안에 떨어진 섬)은 둘레 지역으로
    for it in range(3):
        for y in range(1, H - 1):
            for x in range(1, W - 1):
                cnt = collections.Counter(zone[y + dy][x + dx] for dx in (-1, 0, 1) for dy in (-1, 0, 1))
                top, n = cnt.most_common(1)[0]
                if n >= 6: zone[y][x] = top
    # 가장자리 바다(들쭉날쭉)
    coast = noise(rnd, W, H, 9)
    sea = [[False] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            e = min(x, y, W - 1 - x, H - 1 - y)
            if e < 2 + coast[y][x] * 7:
                sea[y][x] = True
    g = [['.'] * W for _ in range(H)]
    # 경계: 다른 지역과 맞닿은 칸은 벽(산·숲·절벽·물 중 하나, 잡음으로 섞는다)
    wn = noise(rnd, W, H, 8)
    def wall_kind(x, y, a, b):
        pick = THEME[a][0] if wn[y][x] < 0.5 else THEME[b][0]
        v = wn[y][x]
        if 0.42 < v < 0.5: return 'T'
        if 0.5 <= v < 0.56: return 'w'
        return pick
    wall = [[False] * W for _ in range(H)]
    thick = noise(rnd, W, H, 6)
    for y in range(H):
        for x in range(W):
            if sea[y][x]:
                g[y][x] = '~'; continue
            z = zone[y][x]
            rr = 1 + int(thick[y][x] * 2.99)  # 경계 두께 1~3(들쭉날쭉)
            for dx in range(-rr, rr + 1):
                for dy in range(-rr, rr + 1):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < W and 0 <= yy < H and zone[yy][xx] != z and dx * dx + dy * dy <= rr * rr + 1:
                        wall[y][x] = True
            if wall[y][x]:
                other = [zone[y + dy][x + dx] for dx, dy in N4 if 0 <= x + dx < W and 0 <= y + dy < H and zone[y + dy][x + dx] != z]
                g[y][x] = wall_kind(x, y, z, other[0] if other else z)
    # 지역 안 지형
    n1 = noise(rnd, W, H, 11); n2 = noise(rnd, W, H, 5); nf = noise(rnd, W, H, 7); wob = noise(rnd, W, H, 4)
    for y in range(H):
        for x in range(W):
            if sea[y][x] or wall[y][x]: continue
            st = zone[y][x]
            hi, lo, forest, _, _ = THEME[st]
            h = n1[y][x] * 0.7 + n2[y][x] * 0.3
            if h < LAKE.get(st, 0.27): g[y][x] = lo
            elif h > 0.72: g[y][x] = hi
            elif forest and nf[y][x] > 0.64: g[y][x] = 'T'
    def inside(st, x, y):
        return 0 <= x < W and 0 <= y < H and zone[y][x] == st and not wall[y][x] and not sea[y][x]
    # 문: 가운데(1) ↔ 지역 k+1. 가운데 지역 안쪽에서 두 지역의 벽만 지나 지역 k+1 안쪽에 닿는 가장 짧은 곳(씨앗 쪽)을 뚫는다
    gates = []
    entries = {1: (cx, cy)}
    gate_src = {}
    for k in range(1, 10):
        tgt = k + 1
        sx, sy = seeds[tgt]
        src = [(x, y) for y in range(H) for x in range(W) if inside(1, x, y)]
        src.sort(key=lambda c: (c[0] - sx) ** 2 + ((c[1] - sy) * 1.25) ** 2)
        src = src[:60]
        prev = {c: None for c in src}; q = collections.deque(src); hit = None
        while q and hit is None:
            c = q.popleft()
            for dx, dy in N4:
                n = (c[0] + dx, c[1] + dy)
                if n in prev or not (0 <= n[0] < W and 0 <= n[1] < H): continue
                if inside(tgt, *n):
                    prev[n] = c; hit = n; break
                if wall[n[1]][n[0]] and zone[n[1]][n[0]] in (1, tgt) and not sea[n[1]][n[0]]:
                    prev[n] = c; q.append(n)
        assert hit, ('문 자리를 못 찾음', tgt)
        path = []; c = prev[hit]
        while c is not None and prev[c] is not None:
            path.append(c); c = prev[c]
        tiles = set()
        for (x, y) in path:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    xx, yy = x + dx, y + dy
                    if wall[yy][xx] and zone[yy][xx] in (1, tgt):
                        tiles.add((xx, yy))
        mid = path[len(path) // 2] if path else hit
        gates.append({'stage': k, 'tiles': [list(t) for t in sorted(tiles)], 'pos': [mid[0], mid[1]]})
        # 문 앞뒤는 걸을 수 있게
        for (x, y) in [hit, c if c else hit]:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    xx, yy = x + dx, y + dy
                    if not wall[yy][xx] and not sea[yy][xx] and g[yy][xx] not in '.,pb':
                        g[yy][xx] = 'p'
        entries[tgt] = hit
        gate_src[tgt] = c if c else hit
    regions = []
    for st in range(1, 11):
        r = random.Random(4000 + st)
        hi, lo, forest, river, maze_wall = THEME[st]
        cells = [(x, y) for y in range(H) for x in range(W) if inside(st, x, y)]
        xs = [c[0] for c in cells]; ys = [c[1] for c in cells]
        bx0, by0, bx1, by1 = min(xs), min(ys), max(xs), max(ys)
        ex, ey = entries[st]
        # 마을(들어오는 자리 가까이, 지역 안에 다 들어가는 14 × 10)
        tw, th = 14, 10
        best = None
        for (x, y) in cells[::3]:
            if all(inside(st, x + dx, y + dy) for dx in (0, tw - 1) for dy in (0, th - 1)) and \
               all(inside(st, x + dx, y + th // 2) for dx in range(0, tw, 3)):
                d = abs(x + tw // 2 - ex) + abs(y + th // 2 - ey)
                if best is None or d < best[0]: best = (d, x, y)
        _, tx, ty = best
        for y in range(ty, ty + th):
            for x in range(tx, tx + tw):
                if inside(st, x, y): g[y][x] = ','
        town_c = (tx + tw // 2, ty + th // 2)
        barrier = set()
        # 강: 지역을 가로지르고 다리 하나
        if river:
            horiz = (bx1 - bx0) < (by1 - by0)
            line = []
            if horiz:
                y = r.randint(by0 + (by1 - by0) // 3, by1 - (by1 - by0) // 3)
                for x in range(bx0, bx1 + 1):
                    y = max(by0, min(by1, y + r.choice((-1, 0, 0, 1)))); line.append((x, y))
            else:
                x = r.randint(bx0 + (bx1 - bx0) // 3, bx1 - (bx1 - bx0) // 3)
                for y in range(by0, by1 + 1):
                    x = max(bx0, min(bx1, x + r.choice((-1, 0, 0, 1)))); line.append((x, y))
            on = [(x, y) for (x, y) in line if inside(st, x, y) and g[y][x] != ',']
            for (x, y) in on:
                for k in range(3):
                    xx, yy = (x, y + k) if horiz else (x + k, y)
                    if inside(st, xx, yy) and g[yy][xx] != ',':
                        g[yy][xx] = 'w'; barrier.add((xx, yy))
            if on:
                bx, by = on[r.choice([len(on) // 6, 5 * len(on) // 6])]
                for dx in range(-2, 4):
                    for dy in range(-2, 4):
                        xx, yy = (bx + dx, by + dy)
                        if (xx, yy) in barrier and (abs(dx if horiz else dy) <= 1):
                            g[yy][xx] = 'b'; barrier.discard((xx, yy))
        # 미로 구역(세 지역만): 지역 씨앗 쪽(바깥쪽)에
        maze = None
        if maze_wall:
            sx, sy = seeds[st]
            best = None
            for mw, mh in ((5, 4), (4, 4), (4, 3), (3, 3)):  # 들어가는 가장 큰 미로
                pitch = 5
                zw, zh = mw * pitch + 2, mh * pitch + 2
                for (x, y) in cells[::2]:
                    if all(inside(st, x + dx, y + dy) for dx in range(0, zw, 3) for dy in (0, zh - 1)) and \
                       all(inside(st, x + dx, y + dy) for dx in (0, zw - 1) for dy in range(0, zh, 3)) and \
                       all(g[y + dy][x + dx] != ',' for dx in range(0, zw, 4) for dy in range(0, zh, 4)):
                        d = abs(x + zw / 2 - sx) + abs(y + zh / 2 - sy)
                        if best is None or d < best[0]: best = (d, x, y)
                if best:
                    break
            if best:
                _, mx0, my0 = best
                for y in range(my0, my0 + zh):
                    for x in range(mx0, mx0 + zw): g[y][x] = maze_wall; barrier.discard((x, y))
                def cxy(a, b): return mx0 + 2 + a * pitch, my0 + 2 + b * pitch
                for b in range(mh):
                    for a in range(mw):
                        x, y = cxy(a, b)
                        for yy in range(y, y + 3):
                            for xx in range(x, x + 3): g[yy][xx] = 'p'
                seen = {(0, 0)}; stack = [(0, 0)]
                while stack:
                    c = stack[-1]
                    nb = [(c[0] + dx, c[1] + dy) for dx, dy in N4 if 0 <= c[0] + dx < mw and 0 <= c[1] + dy < mh and (c[0] + dx, c[1] + dy) not in seen]
                    if not nb: stack.pop(); continue
                    n = r.choice(nb); seen.add(n); stack.append(n)
                    ax, ay = cxy(*c); bx2, by2 = cxy(*n)
                    for yy in range(min(ay, by2), max(ay, by2) + 3):
                        for xx in range(min(ax, bx2), max(ax, bx2) + 3): g[yy][xx] = 'p'
                e0 = cxy(0, 0); e1 = cxy(mw - 1, mh - 1)
                for yy in range(my0, e0[1]):
                    for xx in range(e0[0], e0[0] + 3): g[yy][xx] = 'p'
                for yy in range(e1[1] + 3, my0 + zh):
                    for xx in range(e1[0], e1[0] + 3): g[yy][xx] = 'p'
                maze = (mx0, my0, zw, zh, (e0[0] + 1, my0 - 1), (e1[0] + 1, my0 + zh))
        def in_maze(x, y):
            return maze and maze[0] <= x < maze[0] + maze[2] and maze[1] <= y < maze[1] + maze[3]
        def cost(x, y):
            if not inside(st, x, y) or (x, y) in barrier: return None
            c = g[y][x]
            if in_maze(x, y): return 1.0 if c == 'p' else None
            return {'.': 1.0, ',': 1.0, 'p': 0.6, 'b': 0.6, 'T': 6.0, 'w': 25.0, '~': 40.0}.get(c, 30.0) + wob[y][x] * 3
        def astar(a, b):
            pq = [(0, a)]; came = {a: None}; gs = {a: 0}
            while pq:
                _, c = heapq.heappop(pq)
                if c == b: break
                for dx, dy in N4:
                    n = (c[0] + dx, c[1] + dy)
                    k = cost(*n)
                    if k is None: continue
                    ng = gs[c] + k
                    if n not in gs or ng < gs[n]:
                        gs[n] = ng; came[n] = c
                        heapq.heappush(pq, (ng + abs(n[0] - b[0]) + abs(n[1] - b[1]), n))
            path = []; c = b
            while c is not None and c in came:
                path.append(c); c = came[c]
            return path[::-1]
        def carve(path):
            for x, y in path:
                for dx, dy in ((0, 0), (1, 0), (0, 1)):
                    xx, yy = x + dx, y + dy
                    if inside(st, xx, yy) and g[yy][xx] != ',' and (xx, yy) not in barrier and not in_maze(xx, yy):
                        g[yy][xx] = 'b' if g[yy][xx] in 'w~' else 'p'
        # 보스: 들어온 곳에서 (지형을 건너는 값으로) 가장 먼 곳
        dist = {town_c: 0}; pq = [(0, town_c)]
        while pq:
            d0, c = heapq.heappop(pq)
            if d0 > dist[c]: continue
            for dx, dy in N4:
                n = (c[0] + dx, c[1] + dy); k = cost(*n)
                if k is None: continue
                if d0 + k < dist.get(n, 1e9):
                    dist[n] = d0 + k; heapq.heappush(pq, (d0 + k, n))
        far = [c for c in dist if all(inside(st, c[0] + dx, c[1] + dy) and (c[0] + dx, c[1] + dy) not in barrier
                                      for dx in range(-3, 4) for dy in range(-3, 4)) and not in_maze(*c)]
        boss = max(far, key=lambda c: dist[c] - (20 if g[c[1]][c[0]] in '^#Hw~T' else 0))
        # 명소 2곳(마을·보스와 멀리)
        marks = []
        for k in range(2):
            cand = [c for c in far[::7] if g[c[1]][c[0]] in '.p']
            p = max(cand, key=lambda c: min(abs(c[0] - q[0]) + abs(c[1] - q[1]) for q in marks + [boss, town_c]))
            marks.append(p)
        stops = [town_c] + marks + ([maze[4], maze[5]] if maze else []) + [boss]
        for a, b in zip(stops, stops[1:]):
            if maze and a == maze[4] and b == maze[5]: continue
            carve(astar(a, b))
        if st > 1:
            carve(astar(entries[st], town_c))
        else:  # 가운데 마을에서 문마다 길
            for t2 in range(2, 11):
                carve(astar(town_c, gate_src[t2]))
        for yy in range(boss[1] - 2, boss[1] + 3):
            for xx in range(boss[0] - 2, boss[0] + 3):
                if inside(st, xx, yy) and (xx, yy) not in barrier: g[yy][xx] = 'p'
        def px(x, y): return [(x + 0.5) * TILE, (y + 0.5) * TILE]
        spots = {'boss': px(*boss)}
        if st == 1:
            spots['forge'] = px(tx + 3, ty + 3)
            spots['tree'] = px(tx + tw - 4, ty + 3)
            spots['board'] = px(tx + 3, ty + th - 3)
        regions.append({'stage': st, 'rect': [bx0, by0, bx1 - bx0 + 1, by1 - by0 + 1], 'town': [tx, ty, tw, th],
                        'spots': spots, 'start': px(*town_c), 'marks': [px(*m) for m in marks],
                        'maze': [maze[0], maze[1], maze[2], maze[3]] if maze else [], 'hour': HOURS.get(st, 0)})
    for gt in gates:
        for x, y in gt['tiles']: g[y][x] = '='
    # 지나갈 수 있는지 확인(문 없이 지역마다 마을 → 보스, 문을 다 열면 가운데 → 모든 지역)
    walk = set('.,pb')
    def reach(a, allow):
        seen = {a}; q = collections.deque([a])
        while q:
            c = q.popleft()
            for dx, dy in N4:
                n = (c[0] + dx, c[1] + dy)
                if 0 <= n[0] < W and 0 <= n[1] < H and n not in seen and g[n[1]][n[0]] in allow:
                    seen.add(n); q.append(n)
        return seen
    for rg in regions:
        s = tuple(int(v // TILE) for v in rg['start']); b = tuple(int(v // TILE) for v in rg['spots']['boss'])
        assert b in reach(s, walk), ('보스에 못 간다', rg['stage'])
    closed = reach(tuple(int(v // TILE) for v in regions[0]['start']), walk)
    for rg in regions[1:]:
        assert tuple(int(v // TILE) for v in rg['start']) not in closed, ('문 없이 다른 지역으로 간다', rg['stage'])
    for gt in gates:
        st_k = gt['stage']
        rows_open = set(map(tuple, gt['tiles']))
        def reach2(a):
            seen = {a}; q = collections.deque([a])
            while q:
                c = q.popleft()
                for dx, dy in N4:
                    n = (c[0] + dx, c[1] + dy)
                    if 0 <= n[0] < W and 0 <= n[1] < H and n not in seen and (g[n[1]][n[0]] in walk or n in rows_open):
                        seen.add(n); q.append(n)
            return seen
        got = reach2(tuple(int(v // TILE) for v in regions[0]['start']))
        zs = {zone[y][x] for (x, y) in got if not wall[y][x]}
        assert zs <= {1, st_k + 1}, ('문 하나로 다른 지역까지 간다', st_k, zs)
        assert tuple(int(v // TILE) for v in regions[st_k]['start']) in got, ('문을 열어도 못 간다', st_k)
    zones = [''.join(str(zone[y][x] % 10) if not sea[y][x] else '-' for x in range(W)) for y in range(H)]
    out = {'_doc': 'tools/map/build_world.py가 만든다(손으로 고치지 않는다). 글자 뜻은 그 스크립트 머리말. zones = 칸마다 지역(스테이지 % 10, 바다 -).',
           'tile': TILE, 'w': W, 'h': H, 'rows': [''.join(r) for r in g], 'zones': zones, 'regions': regions, 'gates': gates,
           'walk': '.,pb', 'gate': '='}
    json.dump(out, open(os.path.join(ROOT, 'data/map/world.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('world', W, 'x', H)

if __name__ == '__main__':
    main()
