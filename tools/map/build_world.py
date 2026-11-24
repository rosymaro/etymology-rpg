"""스테이지 1~10이 모두 들어 있는 월드맵(data/map/world.json)을 만든다. 저장소 루트에서: python3 tools/map/build_world.py

젤다의 전설 꿈꾸는 섬의 들판처럼: 자연스러운 지형(호수·산·숲)이 길을 가르고, 지역을 가로지르는 강과 산줄기는
다리·고갯길로만 건넌다. 마을·명소·보스를 구불구불한 길이 잇는다. 미로는 지역 한 군데에만(2 사냥꾼 숲, 6 왕성 정원, 9 광산 갱도).
- 지도는 황금비(가로가 긴 직사각형): 지역 10개를 5열 × 2줄로 놓는다(위 줄 1 → 5 오른쪽, 5 → 6 아래, 아래 줄 6 → 10 왼쪽).
- 다음 지역으로 가는 문(=)은 그 스테이지 보스를 이기고, 다음 스테이지가 열려 있어야 지나간다(게임이 판정).
글자: . 풀  , 마을 바닥  p 길·고갯길  b 다리  = 스테이지 문  ^ 산  ~ 바다  w 호수·강  # 절벽  T 숲  H 성벽·생울타리
"""
import json, os, random, heapq, collections, math
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RW, RH = 52, 80          # 지역 하나(타일). 5열 × 2줄이면 260 × 160 = 1.625(황금비)
COLS, ROWS = 5, 2
TILE = 64
BORDER = 2
# 스테이지 풍경: (높은 땅, 낮은 땅, 숲 쓰기, 강, 산줄기, 미로 벽)
THEME = {
    1: ('^', 'w', True, True, True, None),    # 공방 마을: 언덕, 개울, 숲
    2: ('^', 'w', True, True, False, 'T'),    # 사냥꾼 초원: 숲 미로
    3: ('#', 'w', True, False, True, None),   # 망루 도서관: 절벽
    4: ('#', 'w', False, True, True, None),   # 바람 협곡: 절벽 협곡과 강
    5: ('^', '~', False, False, True, None),  # 항구 도시: 바다
    6: ('H', 'w', True, True, False, 'H'),    # 왕성: 해자, 생울타리 미로
    7: ('^', 'w', True, False, True, None),   # 소용돌이 호수: 큰 호수
    8: ('H', 'w', False, True, True, None),   # 성벽 요새
    9: ('^', 'w', False, False, True, '^'),   # 부서진 광산: 갱도 미로
    10: ('#', 'w', False, False, True, None), # 갈라진 탑: 절벽
}
LAKE = {7: 0.40, 5: 0.34}  # 물이 많은 지역(낮은 땅 기준)

def origin(i):
    row = i // COLS
    col = i % COLS if row == 0 else COLS - 1 - (i % COLS)
    return col * RW, row * RH

def exit_dir(i):
    if i == 9: return None
    if i == 4: return 'S'
    return 'E' if i < 4 else 'W'

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

def main():
    W, H = COLS * RW, ROWS * RH
    g = [['^'] * W for _ in range(H)]
    regions, gates = [], []
    entry = (BORDER, RH // 2)  # 지역 안 좌표(지역 1은 왼쪽 가운데로 들어온다)
    for i in range(10):
        st = i + 1
        rnd = random.Random(2000 + st)
        ox, oy = origin(i)
        hi, lo, forest, river, ridge, maze_wall = THEME[st]
        n1 = noise(rnd, RW, RH, 11); n2 = noise(rnd, RW, RH, 5); nf = noise(rnd, RW, RH, 7)
        lake_th = LAKE.get(st, 0.27)
        L = [['.'] * RW for _ in range(RH)]
        for y in range(RH):
            for x in range(RW):
                h = n1[y][x] * 0.7 + n2[y][x] * 0.3
                if h < lake_th: L[y][x] = lo
                elif h > 0.71: L[y][x] = hi
                elif forest and nf[y][x] > 0.64: L[y][x] = 'T'
        # 지역을 가로지르는 강(위 → 아래로 굽이친다)과 산줄기(왼 → 오른쪽). 건너는 곳은 정해 둔 다리·고갯길뿐이고,
        # 곧은 길에서 먼 끝쪽에 둔다(그래서 돌아가야 한다). 산줄기 고갯길은 강 양쪽에 하나씩(어느 땅도 갇히지 않게).
        barrier = set()
        river_x = {}
        if river:
            x = rnd.randint(RW // 3, 2 * RW // 3)
            for y in range(RH):
                x = max(6, min(RW - 7, x + rnd.choice((-1, 0, 0, 1))))
                river_x[y] = x
                for k in range(3):
                    L[y][x + k] = 'w'; barrier.add((x + k, y))
        ridge_y = {}
        if ridge:
            cand_y = [yy for yy in range(RH // 3, 2 * RH // 3) if abs(yy - entry[1]) >= 14] or [RH // 2]
            y = rnd.choice(cand_y)  # 마을(들어오는 자리)과 겹치지 않게
            y0_ridge = y
            for x in range(RW):
                y = max(8, min(RH - 9, y + rnd.choice((-1, 0, 0, 1))))
                th_ = rnd.randint(2, 4)
                ridge_y[x] = (y, th_)
                for k in range(th_):
                    L[y + k][x] = hi; barrier.add((x, y + k))
        if river:
            by_ = rnd.choice([rnd.randint(6, 14), rnd.randint(RH - 15, RH - 7)])
            for yy in range(by_ - 1, by_ + 2):
                rx = river_x[yy]
                for k in range(-1, 4):
                    if (rx + k, yy) in barrier or L[yy][rx + k] == 'w':
                        L[yy][rx + k] = 'b'
                    barrier.discard((rx + k, yy))
        if ridge:
            mid = (min(river_x.values()) + max(river_x.values())) // 2 if river else RW // 2
            sides = [(4, max(5, mid - 6)), (min(RW - 6, mid + 6), RW - 5)] if river else [(4, RW - 5)]
            for a, b in sides:
                px_ = rnd.choice([a, b]) if b - a > 4 else a
                for xx in range(px_ - 1, px_ + 2):
                    yy0, th_ = ridge_y[xx]
                    for k in range(-1, th_ + 1):
                        if L[yy0 + k][xx] != 'b':
                            L[yy0 + k][xx] = 'p'
                        barrier.discard((xx, yy0 + k))
        # 미로 구역(한 군데)
        maze = None
        if maze_wall:
            mw, mh = 5, 6  # 칸 수
            pitch = 5      # 통로 3 + 벽 2
            zw, zh = mw * pitch + 2, mh * pitch + 2
            mx0 = (RW - zw) // 2; my0 = rnd.randint(RH // 2 - zh // 2 - 6, RH // 2 - zh // 2 + 6)
            for y in range(my0, my0 + zh):
                for x in range(mx0, mx0 + zw): L[y][x] = maze_wall
            cells = {}
            def cxy(cx, cy): return mx0 + 2 + cx * pitch, my0 + 2 + cy * pitch
            for cy in range(mh):
                for cx in range(mw):
                    x, y = cxy(cx, cy)
                    for yy in range(y, y + 3):
                        for xx in range(x, x + 3): L[yy][xx] = 'p'
            seen = {(0, 0)}; stack = [(0, 0)]
            while stack:
                c = stack[-1]
                nb = [(c[0] + dx, c[1] + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                      if 0 <= c[0] + dx < mw and 0 <= c[1] + dy < mh and (c[0] + dx, c[1] + dy) not in seen]
                if not nb: stack.pop(); continue
                n = rnd.choice(nb); seen.add(n); stack.append(n)
                ax, ay = cxy(*c); bx, by = cxy(*n)
                for yy in range(min(ay, by), max(ay, by) + 3):
                    for xx in range(min(ax, bx), max(ax, bx) + 3): L[yy][xx] = 'p'
            # 들어가는 곳(위 가운데 줄 왼쪽 칸)과 나오는 곳(아래 오른쪽 칸)
            ex0, ey0 = cxy(0, 0); ex1, ey1 = cxy(mw - 1, mh - 1)
            for yy in range(my0, ey0): 
                for xx in range(ex0, ex0 + 3): L[yy][xx] = 'p'
            for yy in range(ey1 + 3, my0 + zh):
                for xx in range(ex1, ex1 + 3): L[yy][xx] = 'p'
            maze = (mx0, my0, zw, zh, (ex0 + 1, my0 - 1), (ex1 + 1, my0 + zh))
        # 테두리
        for y in range(RH):
            for x in range(RW):
                if x < BORDER or y < BORDER or x >= RW - BORDER or y >= RH - BORDER:
                    L[y][x] = '~' if lo == '~' and (y >= RH - BORDER) else hi
        # 마을(들어오는 자리 옆, 16 × 12)
        ex, ey = entry
        tw, th = 16, 12
        tx = BORDER if ex <= BORDER else (RW - BORDER - tw if ex >= RW - BORDER - 1 else max(BORDER, min(RW - BORDER - tw, ex - tw // 2)))
        ty = BORDER if ey <= BORDER else max(BORDER, min(RH - BORDER - th, ey - th // 2))
        for y in range(ty, ty + th):
            for x in range(tx, tx + tw): L[y][x] = ','
        for y in range(ty, ty + th):  # 마을 안은 강·산줄기가 아니다
            for x in range(tx, tx + tw): barrier.discard((x, y))
        # 보스 자리: 다음 지역 쪽 가장자리, 마을에서 멀리(산줄기가 있으면 그 너머)
        d = exit_dir(i)
        far_y = RH - 14 if ey < RH // 2 else 13
        if ridge:
            far_y = rnd.randint(y0_ridge + 10, RH - 13) if ey < y0_ridge else rnd.randint(13, max(13, y0_ridge - 8))
        if i == 3:
            far_y = rnd.randint(12, 18)  # 다음 지역(5)이 아래로 내려가는 길을 길게
        if d == 'E': boss = (RW - BORDER - 4, far_y)
        elif d == 'W': boss = (BORDER + 3, far_y)
        elif d == 'S': boss = (RW - 12 if ex < RW // 2 else 11, RH - BORDER - 4)
        else: boss = (RW - 10 if ex < RW // 2 else 9, far_y)
        for t in range(40):  # 보스 둘레가 강·산줄기에 걸리지 않게
            if not any((boss[0] + dx, boss[1] + dy) in barrier for dx in range(-3, 4) for dy in range(-3, 4)):
                break
            boss = (boss[0], boss[1] + (1 if boss[1] < RH // 2 else -1)) if d in ('E', 'W') else (boss[0] + (1 if boss[0] < RW // 2 else -1), boss[1])
        # 명소 2~3곳(서로 멀리)
        marks = []
        for k in range(rnd.randint(2, 3)):
            best = None
            for t in range(40):
                p = (rnd.randint(6, RW - 7), rnd.randint(6, RH - 7))
                if any((p[0] + dx, p[1] + dy) in barrier for dx in range(-2, 3) for dy in range(-2, 3)):
                    continue
                if maze and maze[0] - 2 <= p[0] <= maze[0] + maze[2] + 2 and maze[1] - 2 <= p[1] <= maze[1] + maze[3] + 2:
                    continue
                dmin = min([abs(p[0] - q[0]) + abs(p[1] - q[1]) for q in marks + [boss, (tx + tw // 2, ty + th // 2)]])
                if best is None or dmin > best[0]: best = (dmin, p)
            marks.append(best[1])
        # 길: A*(풀 1, 숲 6, 높은 땅 40, 물 25, 미로 구역은 못 지남) + 굽이치게 무작위 값
        wob = noise(rnd, RW, RH, 4)
        def cost(x, y):
            c = L[y][x]
            if maze and maze[0] <= x < maze[0] + maze[2] and maze[1] <= y < maze[1] + maze[3]:
                return 1.0 if c == 'p' else None
            if x < BORDER or y < BORDER or x >= RW - BORDER or y >= RH - BORDER: return None
            if (x, y) in barrier: return None  # 강·산줄기는 정해 둔 곳으로만
            base = {'.': 1.0, ',': 1.0, 'p': 0.6, 'b': 0.6, 'T': 6.0, 'w': 25.0, '~': 40.0}.get(c, 40.0)
            return base + wob[y][x] * 3.0
        def astar(a, b):
            pq = [(0, a)]; came = {a: None}; gs = {a: 0}
            while pq:
                _, c = heapq.heappop(pq)
                if c == b: break
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = (c[0] + dx, c[1] + dy)
                    if not (0 <= n[0] < RW and 0 <= n[1] < RH): continue
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
                    if BORDER <= xx < RW - BORDER and BORDER <= yy < RH - BORDER and L[yy][xx] != ',' and (xx, yy) not in barrier:
                        if maze and maze[0] <= xx < maze[0] + maze[2] and maze[1] <= yy < maze[1] + maze[3]:
                            continue
                        L[yy][xx] = 'b' if L[yy][xx] in 'w~' else 'p'
        town_c = (tx + tw // 2, ty + th // 2)
        stops = [town_c] + marks
        if maze: stops += [maze[4], maze[5]]
        stops.append(boss)
        for a, b in zip(stops, stops[1:]):
            if maze and a == maze[4] and b == maze[5]:
                continue  # 미로 안은 걸어서 푼다
            carve(astar(a, b))
        # 마을 들어오는 길(입구에서 마을까지)
        carve(astar((min(max(ex, BORDER), RW - BORDER - 1), min(max(ey, BORDER), RH - BORDER - 1)), town_c))
        for x, y in [boss]:
            for yy in range(y - 2, y + 3):
                for xx in range(x - 2, x + 3):
                    if BORDER <= xx < RW - BORDER and BORDER <= yy < RH - BORDER: L[yy][xx] = 'p'
        # 걸어서 닿는지(문 없이)
        walk = set('.,pb')
        seen = {town_c}; q = collections.deque([town_c])
        while q:
            c = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (c[0] + dx, c[1] + dy)
                if 0 <= n[0] < RW and 0 <= n[1] < RH and n not in seen and L[n[1]][n[0]] in walk:
                    seen.add(n); q.append(n)
        assert boss in seen, ('보스에 못 간다', st)
        steps = 0
        # 지역을 지도에 옮긴다
        for y in range(RH):
            for x in range(RW): g[oy + y][ox + x] = L[y][x]
        def px(x, y): return [(ox + x + 0.5) * TILE, (oy + y + 0.5) * TILE]
        spots = {'boss': px(*boss)}
        if st == 1:
            spots['forge'] = px(tx + 3, ty + 3)
            spots['tree'] = px(tx + tw - 4, ty + 3)
            spots['board'] = px(tx + 3, ty + th - 3)
        regions.append({'stage': st, 'rect': [ox, oy, RW, RH], 'town': [ox + tx, oy + ty, tw, th], 'spots': spots,
                        'start': px(tx + tw // 2, ty + th // 2), 'marks': [px(*m) for m in marks],
                        'maze': [ox + maze[0], oy + maze[1], maze[2], maze[3]] if maze else []})
        # 다음 지역으로 가는 문(테두리 둘을 뚫는다)
        if d:
            bx, by = boss
            tiles = []
            if d == 'E':
                for yy in range(by - 1, by + 3):
                    for xx in range(RW - BORDER, RW + BORDER): tiles.append([ox + xx, oy + yy])
                for xx in range(bx, RW - BORDER):
                    for yy in range(by - 1, by + 3): g[oy + yy][ox + xx] = 'p'
                entry = (BORDER, by)
            elif d == 'W':
                for yy in range(by - 1, by + 3):
                    for xx in range(-BORDER, BORDER): tiles.append([ox + xx, oy + yy])
                for xx in range(BORDER, bx + 1):
                    for yy in range(by - 1, by + 3): g[oy + yy][ox + xx] = 'p'
                entry = (RW - BORDER - 1, by)
            else:
                for xx in range(bx - 1, bx + 3):
                    for yy in range(RH - BORDER, RH + BORDER): tiles.append([ox + xx, oy + yy])
                for yy in range(by, RH - BORDER):
                    for xx in range(bx - 1, bx + 3): g[oy + yy][ox + xx] = 'p'
                entry = (bx, BORDER)
            gates.append({'stage': st, 'tiles': tiles})
    for gt in gates:  # 다음 지역을 그린 뒤에 문을 뚫는다
        for xx, yy in gt['tiles']: g[yy][xx] = '='
    out = {'_doc': 'tools/map/build_world.py가 만든다(손으로 고치지 않는다). 글자 뜻은 그 스크립트 머리말.',
           'tile': TILE, 'w': W, 'h': H, 'rows': [''.join(r) for r in g], 'regions': regions, 'gates': gates,
           'walk': '.,pb', 'gate': '='}
    json.dump(out, open(os.path.join(ROOT, 'data/map/world.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print('world', W, 'x', H, 'ratio %.3f' % (W / H))

if __name__ == '__main__':
    main()
