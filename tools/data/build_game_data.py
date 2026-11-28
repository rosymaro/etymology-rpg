"""게임용 단어 데이터 만들기: data/words_v2_plan.csv + 단어장 앱 words.json/roots.json(읽기만) → data/game/words.json.

사용: python3 tools/data/build_game_data.py [--vocab ../etymology-english-vocabulary]
단어장 저장소는 읽기만 한다. 결과 파일은 게임 저장소에 커밋한다(빌드 때 단어장 저장소가 없어도 되게).
"""
import argparse, csv, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, 'tools/balance'))
import skills  # 스킬 어근 65개
sys.path.insert(0, HERE)
import fit_forms  # 조각 모양을 철자에 맞춘다(사용자 의견: pre + sent + ation)

UNITS = ['만들기', '잡기', '보기', '알기', '말하기', '가기', '나르기·주기', '이끌기', '끌기·던지기', '돌리기', '서기·두기', '깨기·자르기']
SLOTS = {'무기': 'weapon', '머리': 'head', '가슴': 'chest', '장갑': 'hands', '신발': 'feet'}
OBTAIN = {'필드': 'field', '마을': 'town', '보스': 'boss'}
FAM = {1: 'fac struct form par nat ple', 2: 'cept tain pris hib quest', 3: 'spect vis sens', 4: 'lect cert not put equ',
       5: 'dict script sign leg jus', 6: 'cess ven it grad curr sequ loc', 7: 'fer port miss dit pend pay grat',
       8: 'duc rect act cur cap', 9: 'tract press ject tend pet', 10: 'vers turn plic mot',
       11: 'sta pos sid clos lig strict val fort', 12: 'rupt cis cid fin part'}

def modern_forms(word, root_ids, R):
    """어원마다 현대 영어 형태 하나(미니게임 칠판 'ab + duc = abduct'). 단어 안에서 앞에서부터 차례로 찾는다.
    같은 자리면 단어장에 먼저 적힌 형태. 단어에 없으면 첫 현대 형태(없으면 어근 자체)."""
    w = word.lower(); pos = 0; out = []
    for rid in root_ids:
        r = R.get(rid)
        if r is None:
            out.append(rid.strip('-').lower()); continue
        forms = []
        for f in list(r.get('modernEnglishForms') or []) + [r['root']]:
            f = f.strip('-').lower()
            if f and f.isalpha() and f not in forms: forms.append(f)
        if not forms: forms = [rid.lower()]
        best = None
        for k, f in enumerate(forms):
            i = w.find(f, pos)
            if i >= 0 and (best is None or (i, k) < (best[0], best[1])): best = (i, k, f)
        if best is None:
            for k, f in enumerate(forms):
                i = w.find(f)
                if i >= 0 and (best is None or (i, k) < (best[0], best[1])): best = (i, k, f)
        if best is None:
            out.append(forms[0])
        else:
            out.append(best[2]); pos = max(pos, best[0] + len(best[2]))
    return out

def etym_of(word, v, s, R):
    if v:
        ids = [x['rootId'] for x in v['roots']]
        fs = modern_forms(word, ids, R)
        return [{'root': R[x['rootId']]['root'] if x['rootId'] in R else x['rootId'], 'meaning': x.get('derivedMeaning', ''), 'form': f}
                for x, f in zip(v['roots'], fs)]
    out = []
    for x in (s or {}).get('roots', []):
        y = dict(x); y.setdefault('form', str(x.get('root', '')).strip('-').lower()); out.append(y)
    return out

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--vocab', default=os.path.join(os.path.dirname(ROOT), 'etymology-english-vocabulary'))
    a = ap.parse_args()
    vw = json.load(open(os.path.join(a.vocab, 'app/src/main/assets/data/words.json'), encoding='utf-8'))['words']
    vr = json.load(open(os.path.join(a.vocab, 'app/src/main/assets/data/roots.json'), encoding='utf-8'))['roots']
    V = {w['word']: w for w in vw}; R = {r['id']: r for r in vr}
    # 단어장 앱에 없는 단어(비속어 자리를 바꾼 25개)는 게임 저장소의 보충 파일에서
    sup = {w['word']: w for w in json.load(open(os.path.join(ROOT, 'data/words_supplement.json'), encoding='utf-8'))['words']}
    skill_roots = [s[0] for s in skills.S]
    # 단어장 어근 id → 스킬 어근 이름(modernEnglishForms에 그 이름이 있으면)
    to_skill = {}
    for r in vr:
        forms = set(r.get('modernEnglishForms') or []) | {r['id'], r['root'].strip('-')}
        for s in skill_roots:
            if s in forms: to_skill.setdefault(r['id'], s)
    attr_id = {}
    for line in open(os.path.join(ROOT, 'locale/names.csv'), encoding='utf-8'):
        if line.startswith('name.attr.'):
            k, v = line.strip().split(',', 1); attr_id[v] = int(k.split('.')[-1])
    rows = list(csv.DictReader(open(os.path.join(ROOT, 'data/words_v2_plan.csv'), encoding='utf-8-sig')))
    out = []; missing = []
    for r in rows:
        v = V.get(r['word'])
        s = sup.get(r['word'])
        if v is None and s is None: missing.append(r['word'])
        tier = 0 if r['차수'] == '보스' else int(r['차수'])
        roots = [x['rootId'] for x in (v['roots'] if v else [])]
        sk = sorted({to_skill[x] for x in roots if x in to_skill})
        out.append({
            'id': r['word'],
            'meaning': r['meaning'],
            'freq': int(r['frequency'] or 5),
            'attrs': [attr_id[x] for x in r['속성(주/보조)'].split('/') if x],
            'tier': tier,
            'unit': UNITS.index(r['유닛']) + 1 if r['유닛'] else 0,
            'slot': SLOTS.get(r['부위'], ''),
            'tree': int(r['트리']) if r['트리'] else 0,
            'to': r['진화해서 되는 단어'],
            'mats': [m.strip() for m in r['재료(아래 차수 2개)'].split('+')] if r['재료(아래 차수 2개)'] else [],
            'stage': int(r['스테이지']) if r['스테이지'] else 0,
            'obtain': OBTAIN.get(r['얻는 방법'], ''),
            'skill_roots': sk,
            'etym': fit_forms.fit(r['word'], etym_of(r['word'], v, s, R)),
            'example': (v or s or {}).get('example', {}),
            'ipa': (v or s or {}).get('ipa', ''),
        })
    os.makedirs(os.path.join(ROOT, 'data/game'), exist_ok=True)
    json.dump({'version': 1, 'source': 'words_v2_plan.csv + etymology-english-vocabulary', 'words': out},
              open(os.path.join(ROOT, 'data/game/words.json'), 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    fam = {s: f for f, v in FAM.items() for s in v.split()}
    # 검토용: 철자에 맞춰 바꾼 조각 모양(사용자 의견). 단어 / 어근 / 원래 형태 / 단어 속 글자(사라짐이면 빈칸)
    with open(os.path.join(ROOT, 'docs/data/etym_variants.tsv'), 'w', encoding='utf-8') as fh:
        fh.write('word\troot\tbase\tform\tlost\n')
        for w in out:
            for e in w['etym']:
                if 'base' in e:
                    fh.write('%s\t%s\t%s\t%s\t%s\n' % (w['id'], e['root'], e['base'], e.get('form', ''), 'lost' if e.get('lost') else ''))
    json.dump({'version': 1, 'roots': [{'id': s, 'family': fam[s], 'tier': t} for s, t, _ in skills.S]},
              open(os.path.join(ROOT, 'data/game/skill_roots.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    assert not missing, ('뜻·어원이 없는 단어', missing)
    print('words', len(out), 'missing', len(missing), 'with skill roots', sum(1 for o in out if o['skill_roots']))

if __name__ == '__main__':
    main()
