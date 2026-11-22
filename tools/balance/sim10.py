"""10스테이지 전투 시뮬레이션.

engine.py(12지역 때 만든 전투 엔진)를 그대로 쓰고, 2차 설계의 성장(progress.py)과 밸런스 데이터를 얹는다.
사용: python3 tools/balance/sim10.py [--trials N] [--gear-scale X] [--tune]
결과는 표로 찍고, --tune이면 목표 승률에 맞춘 적 레벨 차(offset)와 보스 레벨 차(delta)를 찾는다.
"""
import argparse, json, os, random, sys, math
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from engine import battle
from full import U, kof
from full import ROLES
import progress as PG

ROOT = PG.ROOT
BAL = lambda f: json.load(open(os.path.join(ROOT, 'data/balance', f), encoding='utf-8'))
BOSS_KEY = {'destroyer': 'defect', 'predator': 'predator', 'wizard': 'wizard', 'hurricane': 'storm', 'pirate': 'pirate',
            'dictator': 'dictate', 'vortex': 'vortex', 'guardian': 'guardian', 'dragon': 'dragon', 'devil': 'devil'}
# 필드 마법을 얻는 순서 = 전투 마법을 쓸 수 있게 되는 순서 (data/field_magic.json)
GAIN = {1: ['de'], 2: ['sub', 're', 'com'], 3: ['ad', 'ob'], 4: ['prae', 'in'], 5: ['pro', 'ex'], 6: ['inneg', 'un'], 7: ['dis', 'inter']}
def magics_at(s):
    m = []
    for k in range(1, s + 1): m += GAIN.get(k, [])
    return m
# 속성 능력 중 엔진에 바로 얹을 수 있는 것만(능력치로 근사). 나머지는 0으로 본다(보수적).
ATTR_STAT = {'생명': ('hp', 2, 4), '영혼': ('hp', 2, 4), '원소': ('atk', 1, 2), '일상': ('def', 1, 3),
             '창조': ('hp', 2, 5), '형상': ('atk', 1, 3)}

def ally(unit_no, snap, scale):
    name = PG.UNITS[unit_no - 1]
    L = snap['level'][unit_no - 1]
    u = U(unit_no, L)
    a, d, h, (attr, n) = PG.gear_stats(snap['gear'][name])
    u.bA += round(a * scale); u.bD += round(d * scale); u.bH += round(h * scale)
    if attr in ATTR_STAT and n >= 3:
        k, w, st = ATTR_STAT[attr]; v = st if n >= 5 else w
        if k == 'hp': u.bH += v
        elif k == 'atk': u.bA += v
        else: u.bD += v
    return u

def party(s, snap, scale, n):
    pool = [u for u, st in PG.JOIN.items() if st <= s and not (s >= 9 and u == 7)]  # 9스테이지부터 나르기·주기 이탈
    return [ally(u, snap, scale) for u in random.sample(pool, min(n, len(pool)))]

def team_size(s):
    pool = [u for u, st in PG.JOIN.items() if st <= s]
    return min(4, len(pool))

def field_freq(s):
    import csv
    rows = csv.DictReader(open(os.path.join(ROOT, 'data/words_v2_plan.csv'), encoding='utf-8-sig'))
    return [int(r['frequency']) for r in rows if r['차수'] == '1' and r['스테이지'] == str(s) and r['얻는 방법'] == '필드']

ENEMY_BONUS = (0, 0, 0)  # 스테이지 곡선의 적 장비 몫(공, 방, 체). evaluate가 스테이지마다 채운다
def enemy(L, coins=None, boss=None, role=None, bonus=None):
    L = max(1, min(60, L))
    u = U(role or random.randint(1, 12), L, coins or min(5, L // 10 + 1), kof(L), side='B', boss=boss)
    a, d, h = bonus if bonus is not None else ENEMY_BONUS
    u.bA += a; u.bD += d; u.bH += h
    return u

def player_gear_avg(snap):
    g = [PG.gear_stats(snap['gear'][u]) for u in PG.UNITS]
    return tuple(sum(x[i] for x in g) / 12 for i in range(3))

def fight(my, en, m, P, bossab=False):
    return battle(my, en, m, quizok=random.random() < 0.8, P=P, bossab=bossab) == len(en)

def field_rate(s, base, coins, snap, scale, T, freq, magic):
    """필드 적: enemy.json stage_curve의 기준 레벨(절대값) + 빈도 보정."""
    n = team_size(s)
    win = 0
    for _ in range(T):
        my = party(s, snap, scale, n)
        en = [enemy(base + max(-2, min(3, 5 - random.choice(freq))), coins) for _ in range(n)]
        P = 2 + int(sum(u.L for u in my) / len(my)) // 6
        win += fight(my, en, magic, P)
    return win / T

def boss_rate(s, delta, snap, scale, T, freq, magic, bdef, minion_level, minion_coins):
    """보스: 보스전 때 플레이어 평균 레벨 + boss.json level_delta. 졸개는 2~3차라 필드 기준 + 2."""
    n = team_size(s); lv = sum(snap['level']) / 12
    win = 0
    for _ in range(T):
        my = party(s, snap, scale, n)
        BL = round(lv) + delta
        if s == 10:
            others = random.sample([b for b in bdef if b['stage'] < 10], 2)
            en = [enemy(BL - 2, 5, BOSS_KEY[o['id']], random.choice([9, 12])) for o in others[: n - 2]]
            yc = ally(7, snap, scale); yc.side = 'B'; en.append(yc)
            en.append(enemy(BL, 5, 'devil', 12))
        else:
            b = [x for x in bdef if x['stage'] == s][0]
            en = [enemy(minion_level, minion_coins) for _ in range(n - 1)]
            en.append(enemy(BL, b['coins'], BOSS_KEY[b['id']], random.choice([9, 12])))
        P = 2 + int(sum(u.L for u in my) / len(my)) // 6
        win += fight(my, en, magic, P, bossab=True)
    return win / T

def curve():
    return {c['stage']: c for c in BAL('enemy.json')['stage_curve']}

def evaluate(s, base=None, delta=None, scale=1.0, T=300, lazy=False, coins=None):
    W, leaves = DATA
    cv = curve()[s]; bdef = BAL('boss.json')['bosses']
    base = cv['base_level'] if base is None else base
    cv = dict(cv, coins=coins or cv['coins'])
    if delta is None: delta = [b for b in bdef if b['stage'] == s][0]['level_delta']
    snap_e = PG.snapshot(W, leaves, s, lazy=lazy); snap_b = PG.snapshot(W, leaves, s, 0.6, lazy=lazy)
    global ENEMY_BONUS
    if 'gear_bonus' in cv: ENEMY_BONUS = tuple(cv['gear_bonus'])
    else:  # 기본: 같은 스테이지 부지런한 플레이어 장비의 ratio배
        ratio = BAL('enemy.json').get('gear_bonus_ratio', 0.0)
        ENEMY_BONUS = tuple(round(v * ratio) for v in player_gear_avg(PG.snapshot(W, leaves, s)))
    freq = field_freq(s); ms = magics_at(s)
    f0 = field_rate(s, base, cv['coins'], snap_e, scale, T, freq, None)
    fr = [field_rate(s, base, cv['coins'], snap_e, scale, T, freq, m) for m in ms]
    br = [boss_rate(s, delta, snap_b, scale, T, freq, m, bdef, base + 2, cv['coins']) for m in ms]
    return {'stage': s, 'base': base, 'delta': delta, 'coins': cv['coins'], 'entry_lv': round(sum(snap_e['level']) / 12, 1),
            'boss_lv': round(sum(snap_b['level']) / 12, 1),
            'f_none': f0, 'f_avg': sum(fr) / len(fr), 'f_best': max(fr), 'b_avg': sum(br) / len(br), 'b_best': max(br)}

COIN_CURVE = [1, 1, 1, 2, 2, 2, 3, 3, 3, 4]  # 코인은 레벨보다 훨씬 세게 듣는다. 고르게 오르도록 고정하고 레벨로 맞춘다

def _closest(cands, key, target):
    return min(cands, key=lambda r: abs(r[key] - target))

def tune(s, scale, T, lazy=False, f_target=0.75, b_target=0.65):
    """필드: 코인은 COIN_CURVE로 두고 기준 레벨(1~60)을 찾는다. 보스: 레벨 차(-20~+20)를 찾는다."""
    c = COIN_CURVE[s - 1]
    fs = [evaluate(s, base, 0, scale, T, lazy, coins=c) for base in range(1, 61, 3)]
    best = _closest(fs, 'f_avg', f_target)
    bs = [evaluate(s, best['base'], d, scale, T, lazy, coins=c) for d in range(-20, 21, 4)]
    return _closest(bs, 'b_avg', b_target)

DATA = None
COLS = ('f_none', 'f_avg', 'f_best', 'b_avg', 'b_best')
def row(r):
    return '| %d | %s | %s | %d | %d | %+d | %s |' % (r['stage'], r['entry_lv'], r['boss_lv'], r['base'], r['coins'], r['delta'],
                                             ' | '.join(str(round(r[k] * 100)) for k in COLS))

if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--trials', type=int, default=300)
    ap.add_argument('--gear-scale', type=float, default=1.0)
    ap.add_argument('--tune', action='store_true', help='목표 승률에 맞는 base_level·level_delta를 찾는다')
    ap.add_argument('--lazy', action='store_true', help='진화를 안 하는 플레이어')
    ap.add_argument('--stages', default='1-10')
    ap.add_argument('--gear-model', default='light', choices=['light', 'v2'])
    a = ap.parse_args()
    random.seed(7); PG.GEAR_MODEL = a.gear_model
    DATA = PG.load()
    lo, hi = map(int, a.stages.split('-'))
    print('| 스테이지 | 입장 Lv | 보스전 Lv | 적 기준 Lv | 코인 | 보스 레벨 차 | 마법 없음 | 필드 평균 | 필드 최고 | 보스 평균 | 보스 최고 |')
    print('|---|---|---|---|---|---|---|---|---|---|---|')
    for s in range(lo, hi + 1):
        r = tune(s, a.gear_scale, a.trials, a.lazy) if a.tune else evaluate(s, scale=a.gear_scale, T=a.trials, lazy=a.lazy)
        print(row(r), flush=True)
