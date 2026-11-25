"""그림 콘티(assets/art/README.md)를 디자이너에게 줄 HTML 한 장으로 만든다: docs/art/conti/index.html

- 바깥 파일 없이 한 장으로 열린다(내려받아 브라우저로 열거나 GitHub Pages로 본다).
- 색 코드(#rrggbb)는 색 견본, 유닛 번호는 유닛 대표 색, ★는 우선순위 표시로 그린다.
- README.md가 기준이다. 고칠 때는 README.md를 고치고 다시 만든다.

사용(저장소 루트에서): python3 tools/art/build_conti.py
"""
import html
import re

SRC = 'assets/art/README.md'
OUT = 'docs/art/conti/index.html'
REPO = 'https://github.com/rosymaro/etymology-rpg/blob/main/'
# 유닛 대표 색(src/ui/pal_art.gd와 같다)
UNIT_COL = {'01': '#f0a35e', '02': '#b98c5a', '03': '#a88bd6', '04': '#6f9fd8', '05': '#f29bb8', '06': '#8fd3f0',
            '07': '#7fb77e', '08': '#e0675a', '09': '#f2cf4a', '10': '#5cc2b0', '11': '#9aa3ad', '12': '#b0453f'}


def link(path):
    """README 안의 상대 경로를 GitHub 주소로."""
    if path.startswith('http'):
        return path
    base = 'assets/art/'
    parts = (base + path).split('/')
    out = []
    for p in parts:
        if p == '..':
            out.pop()
        elif p != '.':
            out.append(p)
    return REPO + '/'.join(out)


def inline(s):
    s = html.escape(s, quote=False)
    s = s.replace('&#91;', '[')
    s = re.sub(r'`([^`]+)`', r'<code>\1</code>', s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', s)
    s = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', lambda m: '<a href="%s" target="_blank">%s</a>' % (link(m.group(2)), m.group(1)), s)
    s = re.sub(r'(?<![\w&])#([0-9a-fA-F]{6})\b', r'<span class="sw" style="background:#\1"></span>#\1', s)
    s = s.replace('★★★', '<span class="pri p3">★★★</span>').replace('★★', '<span class="pri p2">★★</span>')
    s = re.sub(r'(?<![">])★(?!★)', '<span class="pri p1">★</span>', s)
    s = s.replace('[사용자 의견]', '<span class="tag user">사용자 의견</span>').replace('[의견]', '<span class="tag opin">의견</span>')
    return s


def table(rows, section):
    head = [c.strip() for c in rows[0].strip().strip('|').split('|')]
    body = [[c.strip() for c in r.strip().strip('|').split('|')] for r in rows[2:]]
    out = ['<div class="tw"><table><thead><tr>' + ''.join('<th>%s</th>' % inline(h) for h in head) + '</tr></thead><tbody>']
    for r in body:
        cells = [inline(c) for c in r]
        if section.startswith('4.') and r and re.fullmatch(r'\d\d', r[0]) and r[0] in UNIT_COL:
            cells[0] = '<span class="chip" style="background:%s">%s</span>' % (UNIT_COL[r[0]], r[0])
        out.append('<tr>' + ''.join('<td>%s</td>' % c for c in cells) + '</tr>')
    out.append('</tbody></table></div>')
    return '\n'.join(out)


def convert(md):
    lines = md.split('\n')
    out, toc = [], []
    i = 0
    section = ''
    while i < len(lines):
        ln = lines[i]
        if ln.startswith('|'):
            rows = []
            while i < len(lines) and lines[i].startswith('|'):
                rows.append(lines[i])
                i += 1
            out.append(table(rows, section))
            continue
        m = re.match(r'^(#{1,3}) (.*)', ln)
        if m:
            lv, text = len(m.group(1)), m.group(2)
            if lv == 1:
                out.append('<h1>%s</h1>' % inline(text))
            else:
                hid = 's%d' % len(toc)
                if lv == 2:
                    section = re.sub(r'^[0-9]+\. ', lambda x: x.group(0), text)
                    section = text
                toc.append((lv, hid, text))
                out.append('<h%d id="%s">%s</h%d>' % (lv, hid, inline(text), lv))
            i += 1
            continue
        if ln.startswith('> '):
            buf = []
            while i < len(lines) and lines[i].startswith('> '):
                buf.append(lines[i][2:])
                i += 1
            out.append('<blockquote>%s</blockquote>' % inline(' '.join(buf)))
            continue
        if re.match(r'^\s*(- |\d+\. )', ln):
            ordered = bool(re.match(r'^\d+\. ', ln))
            items = []
            while i < len(lines) and re.match(r'^\s*(- |\d+\. )', lines[i]):
                indent = len(lines[i]) - len(lines[i].lstrip())
                text = re.sub(r'^\s*(- |\d+\. )', '', lines[i])
                items.append((indent, text))
                i += 1
            tag = 'ol' if ordered else 'ul'
            html_items = []
            for ind, t in items:
                cls = ' class="sub"' if ind >= 2 else ''
                html_items.append('<li%s>%s</li>' % (cls, inline(t)))
            out.append('<%s>%s</%s>' % (tag, ''.join(html_items), tag))
            continue
        if ln.strip() == '':
            i += 1
            continue
        buf = []
        while i < len(lines) and lines[i].strip() and not re.match(r'^(#|\||> |\s*- |\d+\. )', lines[i]):
            buf.append(lines[i])
            i += 1
        out.append('<p>%s</p>' % inline(' '.join(buf)))
    return '\n'.join(out), toc


CSS = '''
:root{--ink:#4b3f72;--paper:#fffaf2;--line:#e6dccb;--soft:#f3ecff;--acc:#e9876a;--mute:#7a7090}
*{box-sizing:border-box}
body{margin:0;background:var(--paper);color:var(--ink);font:15px/1.65 "Pretendard","Apple SD Gothic Neo","Noto Sans KR","Malgun Gothic",sans-serif}
.wrap{display:grid;grid-template-columns:260px 1fr;min-height:100vh}
nav{position:sticky;top:0;height:100vh;overflow:auto;padding:20px 14px;background:#fff;border-right:1px solid var(--line);font-size:13px}
nav b{display:block;margin-bottom:10px;font-size:15px}
nav a{display:block;color:var(--ink);text-decoration:none;padding:3px 6px;border-radius:6px}
nav a:hover{background:var(--soft)}
nav a.l3{padding-left:18px;color:var(--mute)}
main{padding:28px 40px 80px;max-width:1180px}
h1{font-size:28px;margin:0 0 6px}
h2{margin-top:44px;padding-bottom:6px;border-bottom:3px solid var(--line);font-size:22px}
h3{margin-top:26px;font-size:17px}
.meta{color:var(--mute);font-size:13px;margin-bottom:18px}
.tw{overflow-x:auto;margin:10px 0 16px;border:1px solid var(--line);border-radius:12px;background:#fff}
table{border-collapse:collapse;width:100%;font-size:14px}
th{background:var(--soft);text-align:left;white-space:nowrap}
th,td{padding:7px 10px;border-bottom:1px solid var(--line);vertical-align:top}
tr:last-child td{border-bottom:0}
code{background:#f1ebe0;border-radius:5px;padding:1px 5px;font-size:12.5px;white-space:nowrap}
.sw{display:inline-block;width:14px;height:14px;border-radius:4px;border:1px solid rgba(75,63,114,.4);vertical-align:-2px;margin-right:4px}
.chip{display:inline-block;min-width:30px;text-align:center;border-radius:8px;padding:0 6px;color:#fff;font-weight:700;text-shadow:0 1px 1px rgba(0,0,0,.25)}
.pri{color:var(--acc);font-weight:700;letter-spacing:-1px}
.tag{font-size:11px;padding:1px 6px;border-radius:8px;margin-right:4px;vertical-align:1px}
.tag.user{background:#ffe2d6;color:#a2482b}.tag.opin{background:#e3ecff;color:#3a5aa0}
blockquote{margin:12px 0;padding:10px 14px;background:#fff;border-left:4px solid var(--acc);border-radius:8px}
li.sub{margin-left:18px;list-style:circle}
a{color:#3a5aa0}
.legend{display:flex;flex-wrap:wrap;gap:8px 18px;margin:8px 0 6px;font-size:13px;color:var(--mute)}
@media (max-width:860px){.wrap{display:block}nav{position:static;height:auto;border-right:0;border-bottom:1px solid var(--line)}main{padding:18px 16px 60px}}
@media print{nav{display:none}.wrap{display:block}main{max-width:none;padding:0}h2{page-break-before:always}h2:first-of-type{page-break-before:avoid}}
'''


def main():
    md = open(SRC, encoding='utf-8').read()
    body, toc = convert(md)
    nav = '<b>그림 콘티</b>' + ''.join('<a class="l%d" href="#%s">%s</a>' % (lv, hid, html.escape(re.sub(r'\s*\(`[^)]*`\)|`', '', t))) for lv, hid, t in toc)
    legend = ('<div class="legend"><span><span class="pri p3">★★★</span> 가장 먼저</span><span><span class="pri p2">★★</span> 다음</span>'
              '<span><span class="pri p1">★</span> 스테이지 1에 바로 보임</span><span>크기 = 화면에 보이는 크기의 약 2배(세로 720×1280 화면)</span></div>')
    body = body.replace('</h1>', '</h1><div class="meta">어원 RPG(가칭) · 그림 목록과 느낌·크기·파일 이름 · 원본: '
                        '<a href="%sassets/art/README.md" target="_blank">assets/art/README.md</a></div>%s' % (REPO, legend), 1)
    page = ('<!doctype html>\n<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>그림 콘티</title><style>%s</style></head><body><div class="wrap"><nav>%s</nav><main>%s</main></div></body></html>\n') % (CSS, nav, body)
    import os
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w', encoding='utf-8').write(page)
    print(OUT, len(page))


if __name__ == '__main__':
    main()
