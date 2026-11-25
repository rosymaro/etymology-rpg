"""스테이지마다 새로 배울 어원 조각(06-learning.md 3절)을 단어 데이터에서 다시 세어 data/learning/curriculum.json에 넣는다.
저장소 루트에서: python3 tools/data/build_curriculum.py

- 조각 id는 단어 etym의 root 이름(facere, de- …). in-은 뜻이 "아닌"이면 따로 in_neg-로 본다(스테이지 9 함정).
- 조각 뜻은 그 조각이 든 단어들의 etym 뜻 중 가장 많은 것, 모양(forms)은 단어 속 현대 영어 모양들.
- 이야기의 잊힌 뿌리를 축으로 사람이 고른 STAGE_PIECES를 쓴다(스크립트가 고르지 않는다).
"""
import json, os, collections
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STAGE_PIECES = {
    1: ['facere', 'forma', 'de-', 'in-', 'com-'],
    2: ['capere', 'quaerere', 'ex-', 're-'],
    3: ['videre', 'legere', 'prae-', 'pro-'],
    4: ['ire (exire)', 'cedere', 'ad-', 'sub-'],
    5: ['portare', 'ferre', 'dare (datum)', 'trans-'],
    6: ['dicere', 'regere', 'ducere', 'dis-'],
    7: ['vertere', 'tornare (tornus)', 'inter-', 'ob-'],
    8: ['stare', 'ligare', 'trahere', 'un-'],
    9: ['rumpere (rupta)', 'finis', 'pars', 'in_neg-'],
    10: ['mittere', 'tenere', 'spectare'],
}
NEG = ('아닌', '않', '없', '반대', '부정')


def piece_id(e):
    r = e.get('root', '')
    if r == 'in-' and any(k in e.get('meaning', '') for k in NEG):
        return 'in_neg-'
    return r


def main():
    words = json.load(open(os.path.join(ROOT, 'data/game/words.json'), encoding='utf-8'))['words']
    mean = collections.defaultdict(collections.Counter)
    forms = collections.defaultdict(collections.Counter)
    for w in words:
        for e in w.get('etym', []):
            p = piece_id(e)
            if e.get('meaning'):
                mean[p][e['meaning']] += 1
            if e.get('form'):
                forms[p][e['form'].lower()] += 1
    pieces, stages = {}, []
    for st in sorted(STAGE_PIECES):
        ids = STAGE_PIECES[st]
        assert 3 <= len(ids) <= 5, ('스테이지마다 3~5개', st)
        for p in ids:
            assert p in mean, ('단어 데이터에 없는 조각', p)
            pieces[p] = {'stage': st, 'kind': 'prefix' if p.endswith('-') else 'root',
                         'meaning': mean[p].most_common(1)[0][0],
                         'forms': [f for f, _ in forms[p].most_common(8)],
                         'name': p.split(' ')[0].replace('in_neg-', 'in-')}
        stages.append({'stage': st, 'pieces': ids})
    out = {'_doc': 'tools/data/build_curriculum.py가 만든다(06-learning.md 3절). 조각 id = 단어 etym의 root(in-이 "아닌"이면 in_neg-)',
           'stages': stages, 'pieces': pieces}
    json.dump(out, open(os.path.join(ROOT, 'data/learning/curriculum.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
    print('pieces', len(pieces))


if __name__ == '__main__':
    main()
