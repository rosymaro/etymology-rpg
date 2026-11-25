"""그림 콘티(assets/art/README.md)를 디자이너에게 줄 HTML 한 장으로 만든다: docs/art/conti/index.html

- 바깥 파일 없이 한 장으로 열린다(내려받아 브라우저로 열거나 GitHub Pages로 본다).
- 색 코드(#rrggbb)는 색 견본, 유닛 번호는 유닛 대표 색, ★는 우선순위 표시로 그린다.
- README.md가 기준이다. 고칠 때는 README.md를 고치고 다시 만든다.

사용(저장소 루트에서): python3 tools/art/build_conti.py
"""
import html
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))

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


# ---------- 한 장마다 스케치(카드) ----------
import sketch as K

UNIT_NAME = ['뚝딱', '덥석', '힐끔', '척척', '조잘', '쌩', '영차', '대장', '휙', '빙글', '꿈쩍', '와장']
ATTR_NAME = ['생명', '영혼', '지혜', '파동', '자연', '원소', '일상', '창조', '공간', '시간', '바람', '유대', '권위', '파멸', '번영', '영감', '신성', '형상', '심판', '질서']
ATTR_MOTIF = ['새싹 씨앗', '유령 불꽃', '책장 몸·전구', '물결 고리·소리굽쇠 뿔', '잎 망토·꽃', '불·물·흙·바람 조각', '찻잔(생활 물건)', '붓끝 머리·물감',
              '별이 보이는 상자', '모래시계', '회오리 꼬리·깃털', '붙은 쌍둥이·리본', '왕관·망토 깃', '금 간 몸·조각', '동전 주머니', '번개 아이디어',
              '날개·빛고리', '도형 블록', '저울·판사 가발', '격자 무늬']
KIND = [('wander', '그냥 있는 애', '졸린 눈, 둥실'), ('chase', '덤비는 애', '치켜든 눈썹·송곳니, 앞으로'), ('flee', '피하는 애', '겁먹은 눈·땀, 뒤돌아 도망, 반짝이'),
        ('rush', '돌진하는 애', '웅크림·콧김, 머리를 앞으로')]
EXPR = [('normal', '보통'), ('happy', '기쁨'), ('surprised', '놀람'), ('sad', '슬픔'), ('angry', '화남')]
BOSSES = [('destroyer', 1, '큰 덩치 파괴자, 망치 주먹, 허당'), ('predator', 2, '앞에서 노리는 통통한 사냥 짐승'), ('wizard', 3, '책 더미 모자 마법사'),
          ('hurricane', 4, '소용돌이 구름 몸, 부푼 볼'), ('pirate', 5, '안대 해적, 단어 카드 자루'), ('dictator', 6, '확성기 독재자'),
          ('vortex', 7, '물 소용돌이 몸'), ('guardian', 8, '거인 갑옷, 사실은 착함'), ('dragon', 9, '광석 먹는 귀여운 용'), ('devil', 10, '갈라진 문양의 주인(마지막)')]
NPCS = [('blacksmith', '대장장이', ['normal', 'happy', 'surprised'], True), ('nurse', '간호사', ['normal'], True), ('kid', '마을 아이', ['normal', 'happy'], True),
        ('villager_a', '마을 사람 A', ['normal'], True), ('villager_b', '마을 사람 B', ['normal'], True), ('hunter', '사냥꾼', ['normal'], False),
        ('merchant', '상인', ['normal'], False), ('watchman', '망루지기', ['normal'], False), ('librarian', '사서', ['normal'], False),
        ('kite_elder', '연 할아버지', ['normal'], False), ('porter', '짐꾼', ['normal'], False), ('sailor', '늙은 선원', ['normal'], False),
        ('shipwright', '조선공', ['normal'], False), ('scribe', '서기', ['normal'], False), ('guard_castle', '성 경비', ['normal'], False),
        ('king', '왕', ['normal', 'sad'], False), ('miller', '방앗간 주인', ['normal'], False), ('sentry', '보초병', ['normal'], False),
        ('mason', '석공', ['normal'], False), ('miner', '광부', ['normal'], False), ('tower_child', '탑 아래 아이', ['normal'], False), ('gacha', '말 뽑기 주인', ['normal'], True)]
TILES = [('grass', '풀(+grass2, grass3 변형)'), ('town', '마을 바닥'), ('road', '마을 돌길'), ('pass', '고갯길'), ('bridge', '다리'), ('bridge_broken', '무너진 다리'),
         ('gate', '스테이지 문(닫힘)'), ('crop', '밭'), ('hole', '구멍'), ('sea', '바다'), ('water', '호수·강'), ('cliff', '절벽'), ('forest', '숲'),
         ('mountain', '산'), ('wall', '성벽'), ('fence', '울타리'), ('ice', '얼음'), ('cave_floor', '동굴 바닥'), ('cave_wall', '동굴 바위벽'),
         ('cave_exit', '동굴 나가는 곳'), ('cave_mouth', '동굴 입구'), ('fountain', '분수·우물(2×2칸, 256×256)')]
BUILDINGS = [('forge', '대장간(진화)', '512×512'), ('board', '주문 제작소', '512×512'), ('hospital', '병원', '512×512'), ('tree', '말뿌리 나무', '768×768'),
             ('notice', '마을 알림판', '256×256'), ('gacha', '말 뽑기 가게', '384×384'), ('house_1', '집 1', '384×384'), ('house_2', '집 2', '384×384'),
             ('house_3', '집 3', '384×384'), ('boss_gate', '보스 바위 문(문양)', '512×512'), ('boss_gate_open', '보스 문(꽃 핀 뒤)', '512×512')]
PROPS = [('rock', '미는 돌', '128'), ('rock_heavy', '무거운 돌(com-)', '128'), ('plate', '발판 꺼짐', '128'), ('plate_on', '발판 켜짐', '128'),
         ('chest', '보물 상자', '128'), ('chest_open', '열린 상자', '128'), ('lock_chest', '조각 자물쇠 상자', '128'), ('note', '돌 밑 쪽지', '96'),
         ('toy_hammer', '장난감 망치', '96'), ('orb', '구슬', '64'), ('coin', '코인', '64'), ('word_drop', '떨어진 단어', '64'), ('sign', '표지판', '128'), ('crates', '상자 더미', '128')]
MAGIC = [('de', 'de- 내리꽂는 화살'), ('un', 'un- X자 긋기'), ('in_neg', 'in-(아닌) 오그라드는 고리'), ('ob', 'ob- 되미는 충격파'), ('com', 'com- 둥근 방패'),
         ('re', 're- 도는 화살표'), ('ad', 'ad- 모여드는 빛'), ('sub', 'sub- 밑에서 받치는 물결'), ('prae', 'prae- 앞으로 번쩍'), ('inter', 'inter- 가운데 벽'),
         ('in', 'in- 빨려 드는 금빛'), ('dis', 'dis- 흩어지는 조각'), ('ex', 'ex- 갈라지는 화살표'), ('pro', 'pro- 앞으로 달리는 겹화살표')]
MINI = [('order_belt', 1280, 200), ('order_card', 230, 130), ('furnace', 160, 100), ('anvil', 160, 68), ('order_hero', 64, 64), ('fish_word', 240, 80),
        ('fish_top', 150, 54), ('fish_bait', 60, 60), ('guard_wall', 1280, 190), ('guard_traveler', 240, 110), ('guard_climber', 180, 70),
        ('guard_unit', 200, 90), ('sprout', 60, 60), ('root_wisp', 190, 70), ('trap_critter', 130, 56), ('trap_snare', 170, 60), ('trap_hunter', 56, 56),
        ('moat_soldier', 150, 60), ('waterwheel', 110, 110), ('ore_vein', 128, 128), ('ore_rock', 128, 128), ('order_ticket', 64, 64)]


def item(svg_s, file, size, note=''):
    return {'svg': svg_s, 'file': file, 'size': size, 'note': note}


def sq(body, vb='0 0 120 120'):
    return K.svgvb(vb, body)


def catalog():
    c = {}
    # A 오프닝·타이틀
    a = [item(K.cut('title_key_art'), 'title/key_art.png', '1440×2560', '말뿌리 나무 아래 주인공 둘과 뚝딱, 위 1/3은 제목 자리'),
         item(K.logo(), 'title/logo.png', '1200×520', '둥근 손글씨 제목, 뿌리가 글자를 감싼다(가칭)')]
    for cid, note in [('op01_tree', '#1 밤, 뿌리 끝 단어 카드가 등불처럼'), ('op02_crack', '#2 회색 문양이 번지고 뿌리가 끊어진다'),
                      ('op03_fall', '#3 색 잃은 카드가 낙엽처럼'), ('op04_village', '#4 아침 마을, 간판·게시판은 회색'),
                      ('op05_forge_front_m', '#5 대장간 앞: 대장장이가 뚝딱을 소개(남)'), ('op05_forge_front_f', '#5 같은 컷(여)'),
                      ('op06_hammer_m', '#6 첫 망치질, 불빛(남)'), ('op06_hammer_f', '#6 같은 컷(여)'), ('op07_defect', '#7 금이 가며 회색 카드가 튀어나온다'),
                      ('op08_split', '#8 뚝딱이 카드를 두 조각으로, 색이 번진다'), ('op09_choose', '주인공·유닛 모습 고르기 바탕')]:
        a.append(item(K.cut(cid), 'opening/%s.png' % cid, '1440×2560', note + ' · 아래 1/3은 글자 자리'))
    c['2'] = a
    # B 주인공
    b = []
    for gd, gn in [('m', '남'), ('f', '여')]:
        for d, dn in [('down', '앞'), ('up', '뒤'), ('left', '왼쪽'), ('right', '오른쪽')]:
            b.append(item(sq(K.hero(gd, d)), 'hero/%s_%s.png' % (gd, d), '256×288', '%s · 필드 %s' % (gn, dn)))
    for gd, gn in [('m', '남'), ('f', '여')]:
        for lk, ln in [(1, '새싹 망토'), (2, '탐험가 조끼'), (3, '학자 로브'), (4, '현자 망토'), (5, '금빛 망토')]:
            b.append(item(sq(K.hero(gd, 'down', lk)), 'hero/%s_look%d.png' % (gd, lk), '256×288', '%s · 칭호 옷 %d %s' % (gn, lk, ln)))
    for gd, gn in [('m', '남'), ('f', '여')]:
        for ex, en in EXPR:
            b.append(item(sq(K.hero(gd, 'down', 0, ex), '28 12 64 64'), 'face/hero_%s_%s.png' % (gd, ex), '512×512', '%s · 대화 얼굴 %s' % (gn, en)))
    for gd, gn in [('m', '남'), ('f', '여')]:
        b.append(item(sq(K.hero(gd, 'down', 0, 'happy'), '10 6 100 120'), 'hero/%s_stand.png' % gd, '768×1152', '%s · 서 있는 전신(오프닝·고르기·결과)' % gn))
    c['3'] = b
    # C 유닛
    u = []
    for skin, kname, fn in [('penguin', '펭귄', K.penguin), ('chick', '병아리', K.chick)]:
        sk = 'p' if skin == 'penguin' else 'c'
        for n in range(1, 13):
            nm = UNIT_NAME[n - 1]
            u.append(item(sq(fn(n)), 'unit/%s/u%02d.png' % (skin, n), '512×512', '%s %s · 전투 카드' % (nm, kname)))
            u.append(item(sq(K.walking(lambda n=n, fn=fn: fn(n, 0, 0))), 'unit/%s/pal%02d.png' % (skin, n), '192×192', '%s %s · 필드 동행(작게)' % (nm, kname)))
            exprs = [('normal', '보통'), ('happy', '기쁨')] + ([('surprised', '놀람'), ('sad', '슬픔')] if n == 1 else []) + ([('sad', '슬픔·후회'), ('angry', '화남')] if n == 7 else [])
            for ex, en in exprs:
                u.append(item(sq(fn(n, 60, 66, ex), '12 24 96 76'), 'face/u%02d_%s_%s.png' % (n, sk, ex), '512×512', '%s %s · 얼굴 %s' % (nm, kname, en)))
    c['4'] = u
    # D 보스
    d = []
    for bid, st, note in BOSSES:
        d.append(item(sq(K.boss(bid)), 'boss/%s.png' % bid, '1024×1024', '%d · %s' % (st, note)))
        d.append(item(sq(K.boss(bid, True)), 'boss/%s_down.png' % bid, '1024×1024', '%d · 졌을 때: 문양이 깨지고 색이 돌아옴' % st))
        d.append(item(sq(K.boss(bid), '10 10 100 76'), 'face/%s_normal.png' % bid, '512×512', '%d · 대화 얼굴' % st))
        if bid == 'guardian':
            d.append(item(sq(K.boss(bid, False, 60, 64, 'sad'), '10 10 100 76'), 'face/guardian_sad.png', '512×512', '8 · 진실 장면'))
        if bid == 'devil':
            d.append(item(sq(K.boss(bid, False, 60, 64, 'angry'), '10 10 100 76'), 'face/devil_angry.png', '512×512', '10 · 화남'))
            d.append(item(sq(K.boss(bid, False, 60, 64, 'sad'), '10 10 100 76'), 'face/devil_sad.png', '512×512', '10 · 슬픔'))
            dv = K.cut('op01_tree').replace('#7fb77e', '#56607a')
            d.append(item(K.svgvb('0 0 90 160', '<rect width="90" height="160" fill="#2e3560"/><path d="M30 160 L36 60 L54 60 L60 160 z" fill="#56607a"/>' + K.g(K.boss('devil', False, 0, 0), 45, 50, .45) + '<rect x=".5" y=".5" width="89" height="159" rx="4" fill="none" stroke="var(--ink)" stroke-width="1.5"/>', 'cut'),
                          'opening/devil_reveal.png', '1440×2560', '10 · 갈라진 탑 꼭대기, 정체 공개'))
    c['5'] = d
    # E NPC
    e = []
    for pid, nm, exprs, field in NPCS:
        for ex in exprs:
            e.append(item(sq(K.person(pid, 60, 70, ex), '26 22 68 60'), 'face/%s_%s.png' % (pid, ex), '512×512', '%s · 얼굴 %s' % (nm, dict(EXPR)[ex])))
        if field:
            e.append(item(sq(K.person(pid)), 'npc/%s.png' % pid, '192×224', '%s · 필드(마을에 서 있음)' % nm))
    c['6'] = e
    # F 몹
    f = []
    for a_ in range(1, 21):
        for kd, kn, kdesc in KIND:
            f.append(item(K.svgvb('0 0 100 100', K.mob(a_, kd)), 'enemy/a%02d_%s.png' % (a_, kd), '192×192',
                          '<span class="sw" style="background:#%s"></span>%s(%s) · %s: %s' % (K.ATTR_COL[a_ - 1], ATTR_NAME[a_ - 1], ATTR_MOTIF[a_ - 1], kn, kdesc)))
        f.append(item(K.svgvb('0 0 100 100', K.g(K.mob_body(a_) + K.face(0, -6, 'normal', .85), 50, 50, 1.2)), 'enemy/card_a%02d.png' % a_, '512×512',
                      '<span class="sw" style="background:#%s"></span>%s · 전투 적 카드(정면)' % (K.ATTR_COL[a_ - 1], ATTR_NAME[a_ - 1])))
    f.append(item(sq(K.eater()), 'enemy/eater.png', '320×320', '뿌리먹이: 검붉은 몸, 뿌리 촉수, 색을 입히지 않음'))
    c['7'] = f
    # G 지도·건물·물건
    gg = [item(K.tile(t), 'tile/%s.png' % t, '128×128', n) for t, n in TILES]
    gg += [item(sq(K.building(b_)), 'building/%s.png' % b_, sz, n) for b_, n, sz in BUILDINGS]
    gg += [item(K.svgvb('0 0 80 80', K.prop_item(p_)), 'prop/%s.png' % p_, '%s×%s' % (sz, sz), n) for p_, n, sz in PROPS]
    c['8'] = gg
    # H 효과·아이콘
    h = [item(K.svgvb('0 0 100 100', K.fx(m)), 'fx/magic_%s.png' % m, '512×512', n) for m, n in MAGIC]
    h.append(item(K.svgvb('0 0 100 100', K.fx('impact')), 'fx/impact.png', '256×256', '맞을 때 터짐'))
    h += [item(K.svgvb('-30 -40 60 60', K.prop(n, 0, 0, 1.2)), 'weapon/u%02d.png' % n, '96×96', '%s의 필드 무기' % UNIT_NAME[n - 1]) for n in range(1, 13)]
    h += [item(K.svgvb('0 0 60 60', K.slot_icon(sl)), 'slot/%s.png' % sl, '96×96', nm) for sl, nm in [('weapon', '무기(검)'), ('head', '머리(투구)'), ('chest', '가슴(갑옷)'), ('hands', '장갑'), ('feet', '신발(장화)')]]
    c['9'] = h
    c['부록'] = [item(K.mini_item(m, w, hh), ('ui/%s.png' if m == 'order_ticket' else 'mini/%s.png') % m, '%d×%d' % (w, hh), '') for m, w, hh in MINI]
    return c


def grid(items):
    out = ['<div class="cards">']
    for it in items:
        out.append('<figure class="card"><div class="pic">%s</div><figcaption><code>%s</code><span class="size">%s</span><span class="note">%s</span></figcaption></figure>'
                   % (it['svg'], it['file'], it['size'], it['note']))
    out.append('</div>')
    return '\n'.join(out)


CSS = '''
:root{--pencil:#8a86a8;--marker:#ef8a5e;--sheet:#ffffff;--blush:#f6b3c0;--wash:#e6f1e3;--ink:#4b3f72;--paper:#fffaf2;--line:#e6dccb;--soft:#f3ecff;--acc:#e9876a;--mute:#7a7090}
*{box-sizing:border-box}
body{margin:0;background:var(--paper);color:var(--ink);font:15px/1.65 "Pretendard","Apple SD Gothic Neo","Noto Sans KR","Malgun Gothic",sans-serif}
.wrap{display:grid;grid-template-columns:260px 1fr;min-height:100vh}
nav{position:sticky;top:0;height:100vh;overflow:auto;padding:20px 14px;background:#fff;border-right:1px solid var(--line);font-size:13px}
nav b{display:block;margin-bottom:10px;font-size:15px}
nav a{display:block;color:var(--ink);text-decoration:none;padding:3px 6px;border-radius:6px}
nav a:hover{background:var(--soft)}
nav a.l3{padding-left:18px;color:var(--mute)}
.cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px;margin:12px 0 16px}
.card{margin:0;background:#fff;border:1px solid var(--line);border-radius:12px;padding:8px;min-width:0}
.card .pic svg{display:block;width:100%;height:auto;max-height:190px;border-radius:8px;background:#fbf8f2}
.card svg.tile{border:1px solid var(--line)}
.card figcaption{font-size:12px;line-height:1.4;margin-top:6px;display:flex;flex-direction:column;gap:2px}
.card code{white-space:normal;word-break:break-all;font-size:11.5px}
.card .size{color:var(--acc);font-weight:700;font-size:11.5px}
.card .note{color:var(--ink)}
.count{color:var(--mute);font-size:13px;margin:4px 0}
details{margin:8px 0 20px}summary{cursor:pointer;color:var(--mute);font-size:13px}
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
    cat = catalog()
    parts = re.split(r'(?m)^(?=## )', md)
    body, toc = convert(parts[0])
    n_items = 0
    for part in parts[1:]:
        head, _, rest = part.partition('\n')
        key = re.match(r'## (\d+|부록)', head)
        key = key.group(1) if key else ''
        h, t = convert(head)
        hid = 's%d' % len(toc)
        h = h.replace('id="s0"', 'id="%s"' % hid, 1)
        toc.append((2, hid, head[3:]))
        rb, rt = convert(rest)
        for lv, old, text in rt:  # 안쪽 작은 제목: 겹치지 않는 id로
            new = 's%d' % len(toc)
            rb = rb.replace('id="%s"' % old, 'id="%s"' % new, 1)
            toc.append((lv, new, text))
        if key in cat:
            n_items += len(cat[key])
            body += h + '<p class="count">%d장 · 한 장마다 개략 그림(도형). 실제 그림은 아래 설명과 그림 방향을 따른다</p>' % len(cat[key]) + grid(cat[key])
            body += '<details><summary>글로 된 설명과 표 보기</summary>%s</details>' % rb
        else:
            body += h + rb
    print('카드', n_items)
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
