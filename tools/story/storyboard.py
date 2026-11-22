"""스토리보드 페이지의 데이터(storyboard.json)와 GitHub Pages용 index.html을 만든다.

page.html은 페이지 본문(Claude 아티팩트로 게시하는 원본)이고, index.html은 그 앞뒤에 HTML 뼈대를 붙인 것이다.

사용: python3 tools/story/storyboard.py [언어코드]   (저장소 루트에서 실행)
"""
import csv, glob, json, sys

lang = sys.argv[1] if len(sys.argv) > 1 else 'ko'
def load(path):
    with open(path, encoding='utf-8') as f:
        return {r['keys']: r.get(lang, '') for r in csv.DictReader(f)}
text, names = load('locale/story.csv'), load('locale/names.csv')
KEY = {  # 빌려 온 게임 → 스토리보드의 개념 그림 키
 '포켓몬스터 시리즈': 'poke', '크로노 트리거·파이널 판타지 VI': 'snes', '테일즈 오브 시리즈': 'skit',
 '몬스터 헌터 시리즈': 'mh', '오오카미': 'okami', '역전재판 시리즈': 'ace', '파이널 판타지 IV': 'ff4',
 'MOTHER 2': 'mother2', '테트리스': 'tetris', '지뢰찾기': 'mine', '단어 찾기(워드 서치) 퍼즐': 'wsearch',
 '파이프 매니아': 'pipe', '비주얼드·캔디 크러시': 'match3', '애너그램 퍼즐': 'anagram', '15 퍼즐': 'fifteen',
 '볼 소트 퍼즐': 'ballsort', '2048': '2048', '플로우 프리': 'flow'}
out = {'names': {k[10:]: v for k, v in names.items() if k.startswith('name.char.')}, 'stages': [], 'borrow': {}}
for p in sorted(glob.glob('data/scenes/s*.json')):
    st = json.load(open(p, encoding='utf-8'))
    s = {'stage': st['stage'], 'name': names.get(st['place'], ''), 'theme': st.get('theme_note', ''), 'scenes': []}
    for sc in st['scenes']:
        bks = []
        for b in sc['borrow']:
            k = KEY[b['game']]; bks.append(k)
            out['borrow'].setdefault(k, {'game': b['game'], 'part': b['part'], 'scenes': []})['scenes'].append(sc['id'])
        s['scenes'].append({'id': sc['id'], 'title': text.get(sc['title'], ''), 'place': sc['place_note'], 'cast': sc['cast'],
            'staging': sc['staging_note'], 'game': sc['game_note'], 'borrow': bks, 'conti': sc.get('conti', []),
            'lines': [{'sp': l['speaker'], 't': text.get(l['text'], ''), 'k': l['text']} for l in sc['lines']]})
    out['stages'].append(s)
json.dump(out, open('docs/story/storyboard/storyboard.json', 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
print('ok', sum(len(s['scenes']) for s in out['stages']), 'scenes')

page = open('docs/story/storyboard/page.html', encoding='utf-8').read()
open('docs/story/storyboard/index.html', 'w', encoding='utf-8').write(
    '<!doctype html>\n<html lang="ko">\n<head>\n<meta charset="utf-8">\n'
    '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n</head>\n<body>\n'
    + page + '\n</body>\n</html>\n')
