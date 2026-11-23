"""배정표의 단어 바꾸기: data/word_replacements.json의 짝을 data/words_v2_plan.csv에 적용한다.

단어장 앱이 일부러 뺀 성인·비속어 자리를 같은 자리(차수·유닛·부위·속성·트리·스테이지·재료 관계)를 지킨 채 다른 단어로 바꾼다.
뜻과 빈도는 data/words_supplement.json에서 가져온다. assign_stages.py로 배정표를 다시 만들면 이것도 다시 돌린다.
사용: python3 tools/assign/replace_words.py
"""
import csv, json, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PLAN = os.path.join(ROOT, 'data/words_v2_plan.csv')

pairs = {p['old']: p['new'] for p in json.load(open(os.path.join(ROOT, 'data/word_replacements.json'), encoding='utf-8'))['pairs']}
sup = {w['word']: w for w in json.load(open(os.path.join(ROOT, 'data/words_supplement.json'), encoding='utf-8'))['words']}
rows = list(csv.DictReader(open(PLAN, encoding='utf-8-sig')))
fields = list(rows[0].keys())
sub = lambda w: pairs.get(w, w)
changed = 0
for r in rows:
    if r['word'] in pairs:
        new = pairs[r['word']]
        r['word'] = new
        r['meaning'] = sup[new]['meaning']
        r['frequency'] = str(sup[new]['frequency'])
        changed += 1
    r['진화해서 되는 단어'] = sub(r['진화해서 되는 단어'])
    if r['재료(아래 차수 2개)']:
        r['재료(아래 차수 2개)'] = ' + '.join(sub(m.strip()) for m in r['재료(아래 차수 2개)'].split('+'))
words = [r['word'] for r in rows]
assert len(words) == len(set(words)) == 10000, (len(words), len(set(words)))
with open(PLAN, 'w', newline='', encoding='utf-8-sig') as f:
    w = csv.DictWriter(f, fieldnames=fields)
    w.writeheader()
    w.writerows(rows)
print('바꾼 단어', changed, '/ 전체', len(words))
