"""마지막 전투(devil) 레벨 디자인 확인.

플레이어 4명을 레벨 L, 다섯 부위 모두 차수 T 장비로 두고 boss.json의 final 설정으로 싸운다.
목표(사용자 요청): 60레벨·4차 = 어렵게 이김, 60레벨·3차 = 꽤 어려움, 55레벨·3차 = 거의 불가능.
사용: python3 tools/balance/final.py [--trials N] [--search]
"""
import argparse, random, itertools
import sim10 as S
import progress as PG
from full import U

def gear_of(T):
    return {sl: (T, ['-']) for sl in PG.SLOTS}

def make_party(L, T):
    out = []
    a, d, h, _ = PG.gear_stats(gear_of(T))
    for u in random.sample([u for u in PG.JOIN if u != 7], 4):
        x = U(u, L); x.bA += a; x.bD += d; x.bH += h; out.append(x)
    return out

def make_final(cfg, L, T):
    bdef = S.BAL('boss.json')['bosses']; ba, bd, bh = cfg['stat_bonus']
    others = random.sample([b for b in bdef if b['stage'] < 10], 2)
    en = [S.enemy(cfg['other_level'], 5, S.BOSS_KEY[o['id']], random.choice([9, 12]), bonus=(ba, bd, bh)) for o in others]
    a, d, h, _ = PG.gear_stats(gear_of(T))
    yc = S.enemy(L, 5, None, 7, bonus=(a + ba, d + bd, h + bh)); en.insert(1, yc)  # 영차: 플레이어와 같은 레벨·장비 + 보정
    dv = S.enemy(cfg['devil_level'], 5, 'devil', 12, bonus=(ba, bd, bh)); dv.gate = tuple(cfg['level_gate'])
    en.append(dv)
    return en

def rate(cfg, L, T, trials):
    res = {}
    for m in S.magics_at(10):
        w = 0
        for _ in range(trials):
            my = make_party(L, T); en = make_final(cfg, L, T)
            w += S.fight(my, en, m, eval(S.BAL('unit.json')['magic_power'], {}, {'L': L}), bossab=True)
        res[m] = w / trials
    return sum(res.values()) / len(res), max(res.values())

CASES = [(60, 4), (60, 3), (55, 4), (55, 3), (50, 3)]
if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--trials', type=int, default=200); ap.add_argument('--search', action='store_true')
    a = ap.parse_args(); random.seed(3)
    cfg = S.BAL('boss.json')['final']
    if a.search:
        for ba, bh, k in itertools.product([0, 4, 8], [0, 15], [0, 1, 2]):
            c = dict(cfg, stat_bonus=[ba, 0, bh], level_gate=[60, k])
            r = [round(rate(c, L, T, a.trials)[0] * 100) for L, T in CASES[:4]]
            print(ba, bh, k, r, flush=True)
    else:
        print('| 레벨 | 장비 | 마법 평균 | 최선 마법 |'); print('|---|---|---|---|')
        for L, T in CASES:
            av, bs = rate(cfg, L, T, a.trials); print('| %d | %d차 | %d%% | %d%% |' % (L, T, round(av * 100), round(bs * 100)))
