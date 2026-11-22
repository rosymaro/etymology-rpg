"""스테이지별 플레이어 성장 추정: 레벨과 장비.

가정(docs/design/sim-10stage.md에 적음):
- 스테이지 s에 들어올 때: 앞 스테이지들의 1차 단어를 모두 얻었다(보스 보상으로 남은 단어를 받음).
- 진화는 재료(아래의 모든 1차)가 다 모이면 바로 한다(부지런한 플레이어). lazy=True면 진화를 안 한다.
- 보스와 싸울 때: 그 스테이지 1차 단어를 boss_ratio만큼 얻은 상태.
- 경험치: 1차 = 스테이지 번호 × 10, 진화 = 재료 1차의 가장 큰 스테이지 × 4 × 차수. 모든 유닛이 받고, 그 단어를 입는 유닛은 2배.
- 레벨 L의 누적 경험치 = 200 × L², 최대 60.
"""
import csv, math, os, random

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
UNITS = ['만들기', '잡기', '보기', '알기', '말하기', '가기', '나르기·주기', '이끌기', '끌기·던지기', '돌리기', '서기·두기', '깨기·자르기']  # CSV의 유닛 이름(유닛 번호 1~12 순서)
SLOTS = ['무기', '머리', '가슴', '장갑', '신발']
JOIN = {1: 1, 4: 1, 2: 2, 3: 3, 6: 4, 10: 4, 7: 5, 5: 5, 8: 6, 9: 8, 11: 8, 12: 9}  # 유닛 번호 → 합류 스테이지

def load():
    rows = list(csv.DictReader(open(os.path.join(ROOT, 'data/words_v2_plan.csv'), encoding='utf-8-sig')))
    W = {r['word']: r for r in rows}
    kids = {r['word']: [k.strip() for k in r['재료(아래 차수 2개)'].split('+')] if r['재료(아래 차수 2개)'] else [] for r in rows}
    leaves = {}
    def lv(w):
        if w in leaves: return leaves[w]
        k = kids[w]
        leaves[w] = [w] if not k else [x for c in k for x in lv(c)]
        return leaves[w]
    for w in W:
        if W[w]['차수'] in ('2', '3', '4'): lv(w)
    return W, leaves

_CACHE = {}
def snapshot(W, leaves, s, boss_ratio=None, lazy=False, seed=0):
    key = (s, boss_ratio, lazy, seed, GEAR_MODEL if 'GEAR_MODEL' in globals() else None)
    if key not in _CACHE: _CACHE[key] = _snapshot(W, leaves, s, boss_ratio, lazy, seed)
    return _CACHE[key]

def _snapshot(W, leaves, s, boss_ratio=None, lazy=False, seed=0):
    """스테이지 s에 들어올 때(boss_ratio=None) 또는 보스전 때의 상태."""
    rnd = random.Random(seed)
    got = {w for w, r in W.items() if r['차수'] == '1' and int(r['스테이지']) < s}
    if boss_ratio:
        cur = [w for w, r in W.items() if r['차수'] == '1' and int(r['스테이지']) == s]
        rnd.shuffle(cur); got |= set(cur[:int(len(cur) * boss_ratio)])
    evolved = set()
    if not lazy:
        for w, lv in leaves.items():
            if all(x in got for x in lv): evolved.add(w)
    exp = [0] * 12
    def give(base, unit):
        for u in range(12): exp[u] += base * (2 if UNITS[u] == unit else 1)
    for w in got:
        give(int(W[w]['스테이지']) * 10, W[w]['유닛'])
    for w in evolved:
        t = int(W[w]['차수']); mx = max(int(W[x]['스테이지']) for x in leaves[w])
        give(mx * 4 * t, W[w]['유닛'])
    level = [min(60, int(math.sqrt(e / 200))) if e > 0 else 1 for e in exp]
    level = [max(1, l) for l in level]
    # 장비: 유닛·부위마다 가장 높은 차수, 그 속성
    gear = {u: {} for u in UNITS}
    for w in got | evolved:
        r = W[w]; t = int(r['차수']); u, sl = r['유닛'], r['부위']
        if sl not in gear[u] or t > gear[u][sl][0]:
            gear[u][sl] = (t, r['속성(주/보조)'].split('/'))
    return {'level': level, 'gear': gear, 'got': len(got), 'evolved': len(evolved)}

GEAR_MODEL = 'light'
import json as _json
_GEAR = _json.load(open(os.path.join(ROOT, 'data/balance/gear.json'), encoding='utf-8'))

def gear_stats(g, model=None):
    """부위별 장비 능력치와 켜진 속성(이름, 개수). 수치는 data/balance/gear.json.
    light: slots(채택). v2: _v2_draft(02-rpg-v2 첫 가정, 비교용)."""
    model = model or GEAR_MODEL
    table = _GEAR['slots'] if model == 'light' else _GEAR['_v2_draft']
    st = {'atk': 0, 'def': 0, 'hp': 0}
    for sl, (t, _) in g.items():
        v = _GEAR['tier_value'][str(t)]
        for k, expr in table.get(sl, {}).items():
            st[k] += eval(expr, {}, {'v': v, 't': t})
    atk, df, hp = st['atk'], st['def'], st['hp']
    cnt = {}
    for sl in SLOTS:
        if sl in g:
            for a in g[sl][1]: cnt[a] = cnt.get(a, 0) + 1
    best = None
    if cnt:
        m = max(cnt.values())
        tied = [a for a, c in cnt.items() if c == m]
        for sl in SLOTS:  # 동점이면 무기 → 신발 순서로 주속성
            if sl in g and g[sl][1][0] in tied: best = g[sl][1][0]; break
        best = best or tied[0]
        if m < 3: best = None
    return atk, df, hp, (best, cnt.get(best, 0) if best else 0)

if __name__ == '__main__':
    W, leaves = load()
    for s in range(1, 11):
        e = snapshot(W, leaves, s); b = snapshot(W, leaves, s, 0.6); lz = snapshot(W, leaves, s, lazy=True)
        avg = lambda x: round(sum(x) / len(x), 1)
        ga = [gear_stats(e['gear'][u]) for u in UNITS]
        print(s, '입장 Lv', avg(e['level']), '보스 Lv', avg(b['level']), '진화 안 함 Lv', avg(lz['level']),
              '장비 공/방/체', avg([g[0] for g in ga]), avg([g[1] for g in ga]), avg([g[2] for g in ga]),
              '속성 켜진 유닛', sum(1 for g in ga if g[3][0]))
