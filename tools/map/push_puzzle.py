"""돌 밀기 퍼즐 규칙과 풀이 찾기(07-fun.md 3절). 게임의 src/domain/puzzle/push_puzzle.gd와 같은 규칙이다.
판: 글자 줄 목록. T 벽 . 바닥 R 돌 H 무거운 돌 P 발판 w 물 O 구멍 i 얼음 C 상자 L 자물쇠 상자 Q 돌 밑 숨은 쪽지 E 입구
"""
import collections

WALK = set('.PiSE')
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


def parse(rows):
    base, rocks, info = {}, {}, collections.defaultdict(list)
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in 'RHQ':  # Q = 돌 밑에 숨은 쪽지
                rocks[(x, y)] = 'H' if c == 'H' else 'R'
                base[(x, y)] = 'S' if c == 'Q' else '.'
                if c == 'Q': info['secret'].append((x, y))
            elif c in 'CL':
                base[(x, y)] = c
                info['chest'].append((x, y))
            else:
                base[(x, y)] = c
            if c == 'P': info['plates'].append((x, y))
            if c == 'S': info['secret'].append((x, y))
            if c == 'E': info['entry'].append((x, y))
    return base, rocks, info


def free(base, filled, rocks, c):
    k = base.get(c, 'T')
    return c not in rocks and (k in WALK or ((k in 'wO') and c in filled))


def push(base, filled, rocks, rock, d, heavy_ok):
    """돌을 d 쪽으로 민다. 새 (rocks, filled) 또는 None."""
    kind = rocks[rock]
    if kind == 'H' and not heavy_ok:
        return None
    t = (rock[0] + d[0], rock[1] + d[1])
    k = base.get(t, 'T')
    if t in rocks or k in 'TCL' or (k not in WALK and k not in 'wO'):
        return None
    rocks = dict(rocks); filled = set(filled)
    del rocks[rock]
    while True:
        if k in 'wO' and t not in filled:  # 물·구멍에 빠져 메운다
            filled.add(t)
            return rocks, frozenset(filled)
        if k != 'i':
            break
        n = (t[0] + d[0], t[1] + d[1])  # 얼음: 막힐 때까지 미끄러진다
        nk = base.get(n, 'T')
        if n in rocks or nk in 'TCL' or (nk not in WALK and not (nk in 'wO')):
            break
        t, k = n, nk
    rocks[t] = kind
    return rocks, frozenset(filled)


def reach(base, filled, rocks, start):
    seen = {start}; q = collections.deque([start])
    while q:
        c = q.popleft()
        for d in N4:
            n = (c[0] + d[0], c[1] + d[1])
            if n not in seen and free(base, filled, rocks, n):
                seen.add(n); q.append(n)
    return seen


def goal(base, filled, rocks, info, area):
    if info['plates']:
        return all(p in rocks for p in info['plates'])
    if info['secret'] and not info['chest']:
        return any(s in area and s not in rocks for s in info['secret'])
    want = info['chest']
    ok_chest = any((c[0] + d[0], c[1] + d[1]) in area for c in want for d in N4)
    if info['secret']:
        return ok_chest and any(s in area and s not in rocks for s in info['secret'])
    return ok_chest


def solve(rows, heavy_ok=True, limit=200000):
    base, rocks, info = parse(rows)
    start = info['entry'][0]
    s0 = (frozenset(rocks.items()), frozenset())
    seen = {s0}; q = collections.deque([(s0, 0)])
    while q and len(seen) < limit:
        (rk, filled), n = q.popleft()
        rocks = dict(rk)
        area = reach(base, filled, rocks, start)
        if goal(base, filled, rocks, info, area):
            return n
        for r in list(rocks):
            for d in N4:
                stand = (r[0] - d[0], r[1] - d[1])
                if stand not in area:
                    continue
                got = push(base, filled, rocks, r, d, heavy_ok)
                if got:
                    st = (frozenset(got[0].items()), got[1])
                    if st not in seen:
                        seen.add(st); q.append((st, n + 1))
    return None


def load(path):
    boards, cur = [], None
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n')
        if line.startswith('#') or not line.strip():
            continue
        if line.startswith('=='):
            parts = [p.strip() for p in line[2:].split('|')]
            cur = {'id': parts[0], 'kind': parts[1], 'reward': parts[2],
                   'answer': parts[3] if len(parts) > 3 else '', 'note': parts[4] if len(parts) > 4 else '', 'rows': []}
            boards.append(cur)
        else:
            cur['rows'].append(line)
    return boards


if __name__ == '__main__':
    import os, sys
    here = os.path.dirname(os.path.abspath(__file__))
    for b in load(os.path.join(here, 'puzzles', 's01.txt')):
        w = {len(r) for r in b['rows']}
        print(b['id'], b['kind'], 'width', w, 'moves', solve(b['rows']), 'no-heavy', solve(b['rows'], heavy_ok=False) if 'H' in ''.join(b['rows']) else '-')
