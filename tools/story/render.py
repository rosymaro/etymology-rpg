"""장면 데이터(data/scenes)와 문장(locale)으로 검토용 문서를 만든다.

사용: python3 tools/story/render.py [언어코드]   (기본 ko, 저장소 루트에서 실행)
만드는 파일: docs/story/blueprint.md(장면 청사진), docs/story/script-<언어>.md(대본)
"""
import csv, glob, json, sys, collections

lang = sys.argv[1] if len(sys.argv) > 1 else 'ko'

def load(path):
    with open(path, encoding='utf-8') as f:
        return {r['keys']: r.get(lang, '') for r in csv.DictReader(f)}

text = load('locale/story.csv')
names = load('locale/names.csv')
stages = [json.load(open(p, encoding='utf-8')) for p in sorted(glob.glob('data/scenes/s*.json'))]

def who(sp):
    if sp == 'narr':
        return '(낭독)'
    return names.get(f'name.char.{sp}', sp).replace('{hero}', '주인공')

BEAT = {'intro': '시작', 'ki': '기', 'seung': '승', 'jeon': '전', 'jeon_a': '전 1', 'jeon_b': '전 2', 'gyeol': '결',
        'q_magic': '마법 퀘스트', 'q_root': '어근 퀘스트', 'q_word': '단어 퀘스트', 'epilogue': '엔딩 후'}
def beat(sid):
    k = sid.split('_', 1)[1]
    if k in BEAT: return BEAT[k]
    return {'skit': '동료 잡담', 'tut': '설명', 'town': '마을 이야기'}.get(k.split('_')[0], k)

def cell(s):
    return s.replace('|', '\\|').replace('\n', ' ')

bp = ['# 장면 청사진', '',
      '스테이지마다 장면의 장소, 등장인물, 연출(동선·카메라·효과), 게임과의 연결, 다른 게임에서 빌려 온 개념을 적었다. '
      '빌려 온 것은 규칙·연출 방식뿐이고, 이름·그림·음악은 쓰지 않는다. 대사는 [대본](script-%s.md)에 있다.' % lang, '',
      '콘티 그림과 빌려 온 개념 그림은 [스토리보드 페이지](storyboard/index.html)에 있다. 이 표는 각 컷의 설명이다.', '',
      '이 문서는 `tools/story/render.py`가 `data/scenes/*.json`으로 만든다. 고칠 때는 JSON을 고치고 다시 만든다.', '']
used = collections.defaultdict(list)
for st in stages:
    n = st['stage']
    bp += [f"## 스테이지 {n} {names.get(st['place'], '')}", '', st.get('theme_note', ''), '',
           '| 장면 | 제목 | 장소 | 등장 | 콘티(컷) | 게임 연결 | 빌려 온 개념 |', '|---|---|---|---|---|---|---|']
    for sc in st['scenes']:
        cast = ', '.join(who(c) for c in sc['cast'])
        bor = '<br>'.join(f"{b['game']}: {b['part']}" for b in sc['borrow']) or '—'
        for b in sc['borrow']:
            used[(b['game'], b['part'])].append(sc['id'])
        shot = {'wide': '와이드', 'mid': '미디엄', 'close': '클로즈업'}
        conti = '<br>'.join(f"#{i} {shot[c['shot']]}: {cell(c['note'])}" for i, c in enumerate(sc.get('conti', []), 1)) or cell(sc['staging_note'])
        bp.append('| ' + ' | '.join([cell(beat(sc['id']) + ' · ' + sc['id']), cell(text.get(sc['title'], '')), cell(sc['place_note']), cell(cast),
                                     conti, cell(sc['game_note']), bor]) + ' |')
    bp.append('')
bp += ['## 빌려 온 개념 모음', '', '| 게임 | 빌려 온 부분 | 쓰는 장면 |', '|---|---|---|']
for (g, part), ids in sorted(used.items()):
    show = ', '.join(ids[:6]) + (f' 외 {len(ids) - 6}곳' if len(ids) > 6 else '')
    bp.append(f'| {g} | {part} | {show} |')
open('docs/story/blueprint.md', 'w', encoding='utf-8').write('\n'.join(bp) + '\n')

sc_md = [f'# 대본 ({lang})', '', '장면 데이터와 `locale/story.csv`로 만든 읽기용 대본이다. 문장을 고칠 때는 `locale/story.csv`를 고친다. '
         '`_etym`이 붙은 줄은 어원 풀이, `_pun`이 붙은 줄은 말장난이라 언어마다 새로 써야 한다.', '']
for st in stages:
    sc_md += [f"## 스테이지 {st['stage']} {names.get(st['place'], '')}", '']
    for sc in st['scenes']:
        sc_md += [f"### {beat(sc['id'])} · {text.get(sc['title'], '')} ({sc['id']})", '', f"*{sc['staging_note']}*", '']
        for l in sc['lines']:
            t = text.get(l['text'], '').replace('{hero}', '주인공')
            mark = ' `어원`' if l['text'].endswith('_etym') else (' `말장난`' if l['text'].endswith('_pun') else '')
            sc_md.append(f"- **{who(l['speaker'])}:** {t}{mark}")
        sc_md.append('')
open(f'docs/story/script-{lang}.md', 'w', encoding='utf-8').write('\n'.join(sc_md) + '\n')
print('ok', len(stages), 'stages')
