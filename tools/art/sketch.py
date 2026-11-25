"""그림 콘티의 도형 스케치(SVG). 스토리보드(docs/story/storyboard)와 같은 연필 선·파스텔·주황 효과 규칙.
build_conti.py가 쓴다. 모든 함수는 SVG 조각(문자열)을 돌려준다. 좌표는 각 그림의 viewBox 안.
"""
import math

INK = 'var(--ink)'
S = 'stroke="var(--ink)" stroke-width="1.6" fill="none" stroke-linecap="round" stroke-linejoin="round"'
P = 'stroke="var(--pencil)" stroke-width="1.1" fill="none" stroke-linecap="round" stroke-linejoin="round"'
M = 'stroke="var(--marker)" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"'
GREY = '#d9d6df'

UNIT_COL = {1: '#f0a35e', 2: '#b98c5a', 3: '#a88bd6', 4: '#6f9fd8', 5: '#f29bb8', 6: '#8fd3f0',
            7: '#7fb77e', 8: '#e0675a', 9: '#f2cf4a', 10: '#5cc2b0', 11: '#9aa3ad', 12: '#b0453f'}
ATTR_COL = ["f4a6a6", "c9b6e4", "a8d8ea", "ffd59e", "b5e5b5", "f7c59f", "d6d6b0", "f2b5d4", "aec6f0", "e8c8a0",
            "c4e8f2", "f0b8b8", "d8c4f0", "e0a0a0", "f5e3a3", "b8e0d2", "fff1a8", "cfd8a8", "c8b8a8", "b0c8e8"]


def svg(w, h, body, cls=''):
    return '<svg viewBox="0 0 %s %s" xmlns="http://www.w3.org/2000/svg" role="img"%s>%s</svg>' % (w, h, ' class="%s"' % cls if cls else '', body)


def txt(x, y, t, size=9, extra=''):
    return '<text x="%s" y="%s" font-size="%s" text-anchor="middle" fill="var(--ink)" font-family="Noto Sans KR,sans-serif" %s>%s</text>' % (x, y, size, extra, t)


def g(body, tx=0, ty=0, s=1.0, rot=0, sx=None, sy=None):
    sx = s if sx is None else sx
    sy = s if sy is None else sy
    return '<g transform="translate(%s %s) rotate(%s) scale(%s %s)">%s</g>' % (tx, ty, rot, sx, sy, body)


def shadow(cx, cy, rx=16):
    return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="var(--ink)" opacity=".08"/>' % (cx, cy, rx, rx * .28)


# ---------- 얼굴 ----------

def face(cx, cy, expr='normal', r=1.0, blush=True):
    e = ''
    d = 4.5 * r
    if expr == 'happy':
        e = '<path d="M%s %s q%s -%s %s 0 M%s %s q%s -%s %s 0" %s/>' % (cx - d - 2 * r, cy, 2 * r, 2.5 * r, 4 * r, cx + d - 2 * r, cy, 2 * r, 2.5 * r, 4 * r, S)
        e += '<path d="M%s %s q%s %s %s 0" %s/>' % (cx - 3 * r, cy + 5 * r, 3 * r, 3.5 * r, 6 * r, S)
    elif expr == 'surprised':
        e = '<circle cx="%s" cy="%s" r="%s" %s/><circle cx="%s" cy="%s" r="%s" %s/>' % (cx - d, cy, 2 * r, S, cx + d, cy, 2 * r, S)
        e += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" %s/>' % (cx, cy + 6 * r, 1.8 * r, 2.4 * r, S)
    elif expr == 'sad':
        e = '<path d="M%s %s l%s %s M%s %s l%s -%s" %s/>' % (cx - d - 2 * r, cy - 1 * r, 4 * r, 1.5 * r, cx + d - 2 * r, cy + .5 * r, 4 * r, 1.5 * r, S)
        e += '<path d="M%s %s q%s -%s %s 0" %s/>' % (cx - 3 * r, cy + 7 * r, 3 * r, 2.5 * r, 6 * r, S)
        e += '<path d="M%s %s v%s" stroke="#8cc6e8" stroke-width="%s" stroke-linecap="round"/>' % (cx - d, cy + 2.5 * r, 4 * r, 1.6 * r)
    elif expr == 'angry':
        e = '<path d="M%s %s l%s %s M%s %s l-%s %s" %s/>' % (cx - d - 2.5 * r, cy - 4 * r, 5 * r, 2 * r, cx + d + 2.5 * r, cy - 4 * r, 5 * r, 2 * r, S)
        e += '<circle cx="%s" cy="%s" r="%s" fill="var(--ink)"/><circle cx="%s" cy="%s" r="%s" fill="var(--ink)"/>' % (cx - d, cy, 1.3 * r, cx + d, cy, 1.3 * r)
        e += '<path d="M%s %s h%s" %s/>' % (cx - 3 * r, cy + 6 * r, 6 * r, S)
    elif expr == 'sleepy':
        e = '<path d="M%s %s q%s %s %s 0 M%s %s q%s %s %s 0" %s/>' % (cx - d - 2 * r, cy, 2 * r, 2 * r, 4 * r, cx + d - 2 * r, cy, 2 * r, 2 * r, 4 * r, S)
        e += '<path d="M%s %s q%s %s %s 0" %s/>' % (cx - 2 * r, cy + 5 * r, 2 * r, 1.8 * r, 4 * r, S)
    elif expr == 'scared':
        e = '<circle cx="%s" cy="%s" r="%s" fill="var(--sheet)" %s/><circle cx="%s" cy="%s" r="%s" fill="var(--sheet)" %s/>' % (cx - d, cy, 2.6 * r, S, cx + d, cy, 2.6 * r, S)
        e += '<circle cx="%s" cy="%s" r="%s" fill="var(--ink)"/><circle cx="%s" cy="%s" r="%s" fill="var(--ink)"/>' % (cx - d, cy, 1 * r, cx + d, cy, 1 * r)
        e += '<path d="M%s %s q%s -%s %s 0 q%s %s %s 0" %s/>' % (cx - 3 * r, cy + 7 * r, 1.5 * r, 2 * r, 3 * r, 1.5 * r, 2 * r, 3 * r, S)
    elif expr == 'fierce':
        e = '<path d="M%s %s l%s %s M%s %s l-%s %s" %s/>' % (cx - d - 3 * r, cy - 4.5 * r, 6 * r, 3 * r, cx + d + 3 * r, cy - 4.5 * r, 6 * r, 3 * r, S)
        e += '<path d="M%s %s h%s M%s %s h%s" %s/>' % (cx - d - 2 * r, cy, 4 * r, cx + d - 2 * r, cy, 4 * r, S)
        e += '<path d="M%s %s h%s" %s/><path d="M%s %s l%s %s l%s -%s" fill="var(--sheet)" %s/>' % (cx - 4 * r, cy + 6 * r, 8 * r, S, cx + 1 * r, cy + 6 * r, 1.5 * r, 3 * r, 1.5 * r, 3 * r, S)
    else:
        e = '<circle cx="%s" cy="%s" r="%s" fill="var(--ink)"/><circle cx="%s" cy="%s" r="%s" fill="var(--ink)"/>' % (cx - d, cy, 1.5 * r, cx + d, cy, 1.5 * r)
        e += '<path d="M%s %s q%s %s %s 0" %s/>' % (cx - 2 * r, cy + 5 * r, 2 * r, 2 * r, 4 * r, S)
    if blush and expr not in ('angry', 'fierce'):
        e += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="var(--blush)" opacity=".8"/><ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="var(--blush)" opacity=".8"/>' % (
            cx - d - 3.5 * r, cy + 3.5 * r, 2.4 * r, 1.4 * r, cx + d + 3.5 * r, cy + 3.5 * r, 2.4 * r, 1.4 * r)
    return e


# ---------- 주인공 ----------

CAPE = {1: '#a8d89a', 2: '#c9a874', 3: '#8fa7d6', 4: '#7fb77e', 5: '#f2cf4a'}


def hero(gender='m', facing='down', look=0, expr='normal', cx=60, cy=70):
    """2.5등신 견습생. gender m(짧은 머리) / f(양갈래). facing down/up/left/right. look 0~5 칭호 옷."""
    o = shadow(cx, cy + 42, 18)
    hx, hy = cx, cy - 14
    if look:
        col = CAPE[look]
        if look == 3:  # 학자 로브(길다)
            o += '<path d="M%s %s l-6 46 h40 l-6 -46 z" fill="%s" fill-opacity=".7" %s/>' % (cx - 14, cy + 2, col, S)
        else:
            o += '<path d="M%s %s q-12 22 -8 40 h44 q4 -18 -8 -40 z" fill="%s" fill-opacity=".75" %s/>' % (cx - 14, cy + 2, col, S)
        if look == 4:
            o += '<path d="M%s %s q4 -4 8 0 q-4 4 -8 0 M%s %s q4 -4 8 0 q-4 4 -8 0" %s/>' % (cx - 22, cy + 26, cx + 14, cy + 30, P)
        if look == 5:
            o += '<path d="M%s %s l2 4 4 1 -3 3 1 4 -4 -2 -4 2 1 -4 -3 -3 4 -1z" fill="#fff1a8" %s/>' % (cx + 14, cy + 22, S)
    # 몸(앞치마)
    o += '<path d="M%s %s q-4 18 -2 32 h28 q2 -14 -2 -32 z" fill="var(--sheet)" %s/>' % (cx - 12, cy + 4, S)
    o += '<path d="M%s %s h14 v18 h-14 z" fill="#fde3d6" %s/>' % (cx - 7, cy + 12, P)
    if look == 2:
        o += '<path d="M%s %s h8 v6 h-8 z M%s %s h8 v6 h-8 z" %s/>' % (cx - 11, cy + 14, cx + 3, cy + 14, S)
    o += '<path d="M%s %s v8 M%s %s v8" %s/>' % (cx - 6, cy + 36, cx + 6, cy + 36, S)
    # 머리
    o += '<circle cx="%s" cy="%s" r="16" fill="var(--sheet)" %s/>' % (hx, hy, S)
    if gender == 'f':
        o += '<path d="M%s %s q-8 4 -6 14 M%s %s q8 4 6 14" %s/>' % (hx - 15, hy - 2, hx + 15, hy - 2, S)
        o += '<circle cx="%s" cy="%s" r="5" fill="#f6b3c0" %s/><circle cx="%s" cy="%s" r="5" fill="#f6b3c0" %s/>' % (hx - 20, hy + 13, S, hx + 20, hy + 13, S)
    # 모자
    o += '<path d="M%s %s q16 -18 32 0 z" fill="#fde3d6" %s/><path d="M%s %s h36" %s/>' % (hx - 16, hy - 6, S, hx - 18, hy - 6, S)
    if gender == 'm':
        o += '<path d="M%s %s l3 4 l3 -4 l3 4" %s/>' % (hx - 6, hy - 5, S)
    if facing == 'down':
        o += face(hx, hy + 3, expr)
    elif facing == 'up':
        o += '<path d="M%s %s q14 8 28 0" %s/>' % (hx - 14, hy + 4, P)
    else:
        dx = -6 if facing == 'left' else 6
        o += '<circle cx="%s" cy="%s" r="1.6" fill="var(--ink)"/>' % (hx + dx, hy + 3)
        o += '<ellipse cx="%s" cy="%s" rx="2.4" ry="1.4" fill="var(--blush)"/>' % (hx + dx * .6, hy + 7)
        o += '<path d="M%s %s l%s 0" %s/>' % (hx + dx * 1.2, hy + 8, dx * .5, S)
    return o


def hero_bust(gender, expr, cx=60, cy=62):
    return g(hero(gender, 'down', 0, expr, 0, 0), cx, cy + 6, 1.45)


# ---------- 유닛(펭귄·병아리) ----------

def prop(u, cx, cy, s=1.0):
    """유닛 소품(오른쪽 손 자리에)."""
    p = ''
    if u == 1:  # 망치·자
        p = '<path d="M0 0 l12 -14" %s/><rect x="8" y="-22" width="12" height="8" rx="2" fill="#9a8f86" %s/>' % (S, S)
    elif u == 2:  # 큰 손
        p = '<circle cx="6" cy="-4" r="8" fill="#f3dcc0" %s/><path d="M1 -9 v-5 M5 -11 v-5 M9 -10 v-5" %s/>' % (S, S)
    elif u == 3:  # 잎
        p = '<path d="M-2 4 q10 -22 22 -14 q-6 18 -22 14 z" fill="#a8d89a" %s/>' % S
    elif u == 4:  # 책
        p = '<rect x="0" y="-10" width="14" height="16" rx="1" fill="#fff4dc" %s/><path d="M7 -10 v16" %s/>' % (S, P)
    elif u == 5:  # 말풍선·깃펜
        p = '<ellipse cx="10" cy="-14" rx="10" ry="7" fill="var(--sheet)" %s/><path d="M3 -9 l-3 6 l7 -4" fill="var(--sheet)" %s/><path d="M5 -14 h1 M10 -14 h1 M15 -14 h1" %s/>' % (S, S, S)
    elif u == 6:  # 바람 줄·날개
        p = '<path d="M-26 -6 h-12 M-24 2 h-16 M-26 10 h-10" %s/><path d="M-6 -22 q-10 -6 -14 4 q8 0 14 -4" fill="var(--sheet)" %s/>' % (P, S)
    elif u == 7:  # 등짐
        p = '<rect x="-34" y="-20" width="16" height="22" rx="4" fill="#c9a874" %s/><path d="M-26 -20 v-4" %s/>' % (S, S)
    elif u == 8:  # 깃발
        p = '<path d="M2 6 v-34" %s/><path d="M2 -28 l16 4 l-16 6 z" fill="#e0675a" %s/>' % (S, S)
    elif u == 9:  # 돌 든 팔
        p = '<path d="M0 0 l6 -16" %s/><circle cx="8" cy="-20" r="5" fill="#9a8f86" %s/><path d="M14 -26 l4 -3 M16 -20 h5" %s/>' % (S, S, M)
    elif u == 10:  # 도는 별
        p = '<path d="M-14 -40 l2 4 4 1 -3 3 1 4 -4 -2 -4 2 1 -4 -3 -3 4 -1z" fill="#fff1a8" %s/><path d="M-26 -36 q12 -10 24 0" %s/>' % (S, M)
    elif u == 11:  # 방패
        p = '<path d="M-2 -14 h18 v10 q0 10 -9 14 q-9 -4 -9 -14 z" fill="#d9d2c3" %s/><path d="M7 -12 v20" %s/>' % (S, P)
    elif u == 12:  # 큰 칼
        p = '<path d="M0 2 l4 -4" %s/><path d="M2 -2 l14 -26 l6 3 l-12 26 z" fill="#d9d2c3" %s/>' % (S, S)
    return g(p, cx, cy, s)


def head_mark(u, cx, cy):
    """머리 위 표시(왕관, 안경, 모자 등)."""
    if u == 4:
        return '<circle cx="%s" cy="%s" r="4" %s/><circle cx="%s" cy="%s" r="4" %s/><path d="M%s %s h2" %s/>' % (cx - 5, cy, S, cx + 5, cy, S, cx - 1, cy, S)
    if u == 8:
        return '<path d="M%s %s l3 -8 l4 5 l4 -5 l3 8 z" fill="#f5c542" %s/>' % (cx - 7, cy - 12, S)
    if u == 2:
        return '<path d="M%s %s q14 -6 28 0 M%s %s q6 -10 12 0" %s/>' % (cx - 14, cy - 10, cx - 6, cy - 11, S)
    if u == 5:
        return '<path d="M%s %s l6 -16 l6 16" fill="#8fa7d6" %s/>' % (cx - 6, cy - 9, S)
    if u == 3:
        return ''
    if u == 10:
        return '<path d="M%s %s a5 5 0 1 1 8 4" %s/>' % (cx - 4, cy + 10, P)
    if u == 12:
        return '<path d="M%s %s l4 6 l-3 4 l4 6" %s/>' % (cx + 4, cy - 6, S)
    return ''


def penguin(u, cx=60, cy=66, expr='normal', small=False):
    c = UNIT_COL[u]
    o = shadow(cx, cy + 34, 20)
    if u == 11:  # 꿈쩍: 네모난 몸
        o += '<rect x="%s" y="%s" width="44" height="56" rx="12" fill="#5b6787" %s/>' % (cx - 22, cy - 22, S)
    elif u == 7:
        o += '<rect x="%s" y="%s" width="46" height="54" rx="16" fill="#5b6787" %s/>' % (cx - 23, cy - 20, S)
    else:
        o += '<ellipse cx="%s" cy="%s" rx="22" ry="30" fill="#5b6787" %s/>' % (cx, cy + 4, S)
    o += '<ellipse cx="%s" cy="%s" rx="14" ry="20" fill="var(--sheet)"/>' % (cx, cy + 10)
    if u == 3:  # 큰 눈 하나
        o += '<circle cx="%s" cy="%s" r="7" fill="var(--sheet)" %s/><circle cx="%s" cy="%s" r="3" fill="var(--ink)"/>' % (cx, cy - 6, S, cx + 1, cy - 6)
    else:
        o += face(cx, cy - 6, expr, .9)
    o += '<path d="M%s %s l4 4 l4 -4 z" fill="#ef8a5e" %s/>' % (cx - 4, cy + 1, S)
    o += '<path d="M%s %s q12 -5 24 0" stroke="%s" stroke-width="5" fill="none" stroke-linecap="round"/>' % (cx - 12, cy + 12, c)  # 대표 색 목도리
    o += '<path d="M%s %s q-10 8 -6 20 M%s %s q10 8 6 20" %s/>' % (cx - 20, cy + 2, cx + 20, cy + 2, S)
    o += '<path d="M%s %s h8 M%s %s h8" stroke="#ef8a5e" stroke-width="3" stroke-linecap="round"/>' % (cx - 12, cy + 34, cx + 4, cy + 34)
    if u == 12:
        o += '<path d="M%s %s l6 -8 l5 6 l6 -9 l5 9 l6 -6" %s/>' % (cx - 14, cy - 18, S)
    if u == 10:
        o += '<path d="M%s %s q-8 4 0 8 q8 4 0 8" stroke="%s" stroke-width="2" fill="none"/>' % (cx, cy + 4, c)
    o += head_mark(u, cx, cy - 22)
    o += prop(u, cx + 22, cy + 6)
    return o


def chick(u, cx=60, cy=66, expr='normal'):
    c = UNIT_COL[u]
    o = shadow(cx, cy + 34, 20)
    if u in (7, 11):
        o += '<rect x="%s" y="%s" width="46" height="52" rx="18" fill="#ffe27a" %s/>' % (cx - 23, cy - 18, S)
    else:
        o += '<circle cx="%s" cy="%s" r="27" fill="#ffe27a" %s/>' % (cx, cy + 6, S)
    o += '<path d="M%s %s q4 -10 8 -2 q2 -8 6 0" %s/>' % (cx - 6, cy - 20, S)  # 머리 깃
    if u == 3:
        o += '<circle cx="%s" cy="%s" r="7" fill="var(--sheet)" %s/><circle cx="%s" cy="%s" r="3" fill="var(--ink)"/>' % (cx, cy - 2, S, cx + 1, cy - 2)
    else:
        o += face(cx, cy - 2, expr, .9)
    o += '<path d="M%s %s l4 5 l4 -5 z" fill="#ef8a5e" %s/>' % (cx - 4, cy + 4, S)
    o += '<path d="M%s %s q12 -5 24 0" stroke="%s" stroke-width="5" fill="none" stroke-linecap="round"/>' % (cx - 12, cy + 15, c)
    o += '<path d="M%s %s q-10 4 -8 14 M%s %s q10 4 8 14" %s/>' % (cx - 24, cy + 8, cx + 24, cy + 8, S)
    o += '<path d="M%s %s v6 l-3 2 M%s %s v6 l3 2" stroke="#ef8a5e" stroke-width="2" fill="none" stroke-linecap="round"/>' % (cx - 7, cy + 32, cx + 7, cy + 32)
    if u == 12:
        o += '<path d="M%s %s l4 6 l-3 4 l4 6" %s/>' % (cx + 8, cy - 4, S)
    o += head_mark(u, cx, cy - 18)
    o += prop(u, cx + 24, cy + 10)
    return o


# ---------- 보스 ----------

def crack(cx, cy, r=8, col='#8a86a8'):
    return '<path d="M%s %s l-%s %s l%s %s l-%s %s M%s %s h%s" stroke="%s" stroke-width="1.8" fill="none" stroke-linecap="round" stroke-dasharray="1 0"/>' % (
        cx, cy - r, r * .5, r * .6, r * .7, r * .3, r * .6, r * .9, cx - r, cy, r * 2, col)


def boss(bid, down=False, cx=60, cy=64, expr=None):
    o = shadow(cx, cy + 46, 34)
    body = {'destroyer': '#d9b8a0', 'predator': '#c9b089', 'wizard': '#b8a8e0', 'hurricane': '#cfe6f2', 'pirate': '#d0c4b0',
            'dictator': '#d8c4f0', 'vortex': '#a8d0e8', 'guardian': '#c4c8d0', 'dragon': '#b5d6a0', 'devil': '#b0aac4'}[bid]
    if bid == 'hurricane':
        o += '<path d="M%s %s q-30 -6 -22 -30 q6 -26 34 -22 q30 -2 30 24 q8 24 -20 30 z" fill="%s" %s/>' % (cx - 10, cy + 40, body, S)
        o += '<path d="M%s %s q14 -10 26 0 q-12 8 -26 0" %s/>' % (cx - 13, cy + 24, P)
    elif bid == 'vortex':
        o += '<path d="M%s %s q-36 -40 0 -76 q36 36 0 76 z" fill="%s" %s/>' % (cx, cy + 44, body, S)
        o += '<path d="M%s %s q12 -8 0 -16 q-16 -6 -16 12 q2 18 22 14" %s/>' % (cx, cy + 22, P)
    else:
        o += '<path d="M%s %s q-8 -56 12 -84 q22 -16 44 0 q18 30 10 84 z" fill="%s" %s/>' % (cx - 32, cy + 44, body, S)
    fy = cy - 14
    if down:
        o += '<path d="M%s %s l6 6 m0 -6 l-6 6 M%s %s l6 6 m0 -6 l-6 6" %s/>' % (cx - 14, fy, cx + 8, fy, S)
        o += '<path d="M%s %s q10 6 20 0" %s/>' % (cx - 10, fy + 14, S)
        o += '<path d="M%s %s l4 -4 M%s %s l5 2 M%s %s l3 5" %s/>' % (cx - 20, cy + 18, cx + 14, cy + 22, cx - 2, cy + 30, M)
        o += '<path d="M%s %s q-4 -10 4 -14 M%s %s q4 -10 -4 -14" stroke="#a8d89a" stroke-width="2" fill="none"/>' % (cx - 30, cy + 44, cx + 32, cy + 44)
    else:
        o += face(cx, fy, expr or ('angry' if bid in ('predator', 'dictator', 'pirate') else ('surprised' if bid == 'hurricane' else 'normal')), 1.5, blush=bid != 'devil')
        o += crack(cx + 12, cy + 22, 9)
    # 특징
    if bid == 'destroyer':
        o += '<circle cx="%s" cy="%s" r="10" fill="#9a8f86" %s/><circle cx="%s" cy="%s" r="10" fill="#9a8f86" %s/>' % (cx - 40, cy + 18, S, cx + 40, cy + 18, S)
    elif bid == 'predator':
        o += '<path d="M%s %s l-6 -14 l12 6 M%s %s l6 -14 l-12 6" fill="%s" %s/>' % (cx - 18, cy - 34, cx + 18, cy - 34, body, S)
    elif bid == 'wizard':
        o += '<rect x="%s" y="%s" width="30" height="8" fill="#fff4dc" %s/><rect x="%s" y="%s" width="26" height="8" fill="#f2b5d4" %s/><rect x="%s" y="%s" width="22" height="8" fill="#a8d8ea" %s/>' % (
            cx - 15, cy - 46, S, cx - 13, cy - 54, S, cx - 11, cy - 62, S)
    elif bid == 'pirate':
        o += '<path d="M%s %s h14" %s/><ellipse cx="%s" cy="%s" rx="5" ry="4" fill="var(--ink)"/>' % (cx + 2, fy - 4, S, cx + 7, fy)
        o += '<path d="M%s %s q-12 10 0 20 q12 -10 0 -20" fill="#c9a874" %s/>' % (cx - 42, cy + 10, S)
    elif bid == 'dictator':
        o += '<path d="M%s %s l18 -8 v24 l-18 -8 z" fill="#f5e3a3" %s/>' % (cx + 34, cy + 4, S)
    elif bid == 'guardian':
        o += '<path d="M%s %s q30 -20 60 0" %s/><path d="M%s %s h20 v14 q0 12 -10 16 q-10 -4 -10 -16 z" fill="#d9d2c3" %s/>' % (cx - 30, cy - 30, S, cx + 30, cy, S)
    elif bid == 'dragon':
        o += '<path d="M%s %s q-20 -20 -6 -30 q0 14 10 18" fill="#b5d6a0" %s/><path d="M%s %s l-4 -10 M%s %s l4 -10" %s/>' % (cx - 30, cy, S, cx - 10, cy - 36, cx + 10, cy - 36, S)
    elif bid == 'devil':
        o += '<path d="M%s %s l-8 -16 l12 8 M%s %s l8 -16 l-12 8" %s/>' % (cx - 18, cy - 34, cx + 18, cy - 34, S)
        if not down:
            o += crack(cx - 14, cy + 10, 10) + crack(cx + 2, cy - 30, 6)
    return o


# ---------- 사람(NPC) ----------

NPC_LOOK = {'blacksmith': 'beard_apron', 'nurse': 'nurse', 'kid': 'kid', 'villager_a': '', 'villager_b': 'scarf', 'hunter': 'brim',
            'merchant': 'cap_bag', 'watchman': 'brim_closed', 'librarian': 'bun_glasses', 'kite_elder': 'beard_kite', 'porter': 'cap_box',
            'sailor': 'cap_pipe', 'shipwright': 'cap_hammer', 'scribe': 'bun_scroll', 'guard_castle': 'helm_spear', 'king': 'crown',
            'miller': 'cap', 'sentry': 'helm', 'mason': 'cap_hammer', 'miner': 'lamp', 'tower_child': 'kid', 'gacha': 'gacha'}


def person(pid, cx=60, cy=64, expr=None):
    look = NPC_LOOK.get(pid, '')
    big = pid == 'blacksmith'
    kid = look == 'kid'
    sc = .8 if kid else (1.15 if big else 1.0)
    o = ''
    b = '<path d="M-12 4 q-4 20 -2 34 h28 q2 -14 -2 -34 z" fill="var(--sheet)" %s/>' % S
    if big:
        b = '<path d="M-18 4 q-6 20 -2 34 h40 q4 -14 -2 -34 z" fill="var(--sheet)" %s/>' % S
    b += '<path d="M-6 38 v8 M6 38 v8" %s/>' % S
    b += '<circle cx="0" cy="-12" r="15" fill="var(--sheet)" %s/>' % S
    expr = expr or ('sleepy' if 'closed' in look else 'normal')
    b += face(0, -10, expr)
    if 'beard' in look:
        b += '<path d="M-10 -2 q10 12 20 0" fill="var(--sheet)" %s/>' % S
    if 'apron' in look:
        b += '<rect x="-8" y="10" width="16" height="22" fill="#c9a874" fill-opacity=".6" %s/>' % P
    if look == 'nurse':
        b += '<path d="M-10 -24 h20 l-3 -8 h-14 z" fill="var(--sheet)" %s/><path d="M0 -30 v4 M-2 -28 h4" %s/>' % (S, M)
    if look.startswith('brim'):
        b += '<path d="M-18 -22 h36 M-9 -22 v-9 h18 v9" %s/>' % S
    if look.startswith('cap'):
        b += '<path d="M-14 -20 q14 -16 28 0 h6" %s/>' % S
    if 'bun' in look:
        b += '<circle cx="0" cy="-30" r="5" %s/>' % S
    if 'glasses' in look:
        b += '<circle cx="-5" cy="-10" r="4" %s/><circle cx="5" cy="-10" r="4" %s/>' % (S, S)
    if look.startswith('helm'):
        b += '<path d="M-15 -14 q15 -24 30 0 z" fill="#d9d2c3" %s/>' % S
    if look == 'crown':
        b += '<path d="M-10 -26 l3 -9 l7 6 l7 -6 l3 9 z" fill="#f5c542" %s/>' % S
    if look == 'lamp':
        b += '<path d="M-14 -20 q14 -14 28 0" %s/><circle cx="0" cy="-27" r="4" fill="#f5c542" %s/>' % (S, S)
    if look == 'scarf':
        b += '<path d="M-10 4 q10 6 20 0" stroke="#f0b8b8" stroke-width="5" fill="none" stroke-linecap="round"/>'
    if look == 'kid':
        b += '<path d="M-6 -27 q6 -6 12 0" %s/>' % S
    if look == 'gacha':
        b += '<circle cx="30" cy="14" r="12" fill="#fde3d6" %s/><rect x="22" y="24" width="16" height="14" %s/>' % (S, S)
    if 'kite' in look:
        b += '<path d="M20 -30 l10 10 l-10 10 l-10 -10 z" fill="#f2b5d4" %s/><path d="M20 -10 q-2 20 -8 30" %s/>' % (S, P)
    if 'bag' in look:
        b += '<rect x="14" y="10" width="12" height="14" rx="3" fill="#c9a874" %s/>' % S
    if 'box' in look:
        b += '<rect x="-14" y="-52" width="28" height="18" fill="#c9a874" %s/>' % S
    if 'pipe' in look:
        b += '<path d="M6 -4 h8 v-4" %s/>' % S
    if 'hammer' in look:
        b += '<path d="M16 20 l10 -14" %s/><rect x="22" y="-2" width="10" height="7" fill="#9a8f86" %s/>' % (S, S)
    if 'scroll' in look:
        b += '<rect x="14" y="8" width="8" height="20" rx="3" fill="#fff4dc" %s/>' % S
    if 'spear' in look:
        b += '<path d="M22 44 v-70 M18 -22 l4 -8 l4 8" %s/>' % S
    o += shadow(cx, cy + 46 * sc, 16 * sc)
    o += g(b, cx, cy + (8 if kid else 0), sc)
    return o


# ---------- 몹(단어 요정): 속성 모티프 × 성격 ----------

def mob_body(a):
    """a: 1~20. 중심 (0,0), 반지름 24쯤. 회색 몸 + 속성 색 장식."""
    c = '#' + ATTR_COL[a - 1]
    G = GREY
    band = '<rect x="-14" y="4" width="28" height="8" rx="3" fill="var(--sheet)" %s/>' % P
    o = ''
    if a == 1:  # 생명: 새싹 씨앗
        o = '<ellipse cx="0" cy="4" rx="22" ry="20" fill="%s" %s/><path d="M0 -16 q-10 -12 -16 -4 q8 4 16 4 q4 -10 14 -10 q-2 10 -14 10" fill="%s" %s/>' % (G, S, c, S)
    elif a == 2:  # 영혼: 유령 불꽃
        o = '<path d="M-20 18 q-6 -26 8 -38 q8 -8 12 -18 q14 16 16 34 q4 18 -8 26 q10 6 22 2 q-14 14 -30 6 q-12 2 -20 -12 z" fill="%s" %s/><path d="M8 -24 q4 8 0 14" stroke="%s" stroke-width="3" fill="none"/>' % (G, S, c)
    elif a == 3:  # 지혜: 책장 몸 + 전구
        o = '<path d="M-22 -16 h22 v38 h-22 z M0 -16 h22 v38 h-22 z" fill="%s" %s/><circle cx="0" cy="-28" r="7" fill="%s" %s/><path d="M-3 -21 h6" %s/>' % (G, S, c, S, S)
    elif a == 4:  # 파동: 물결 고리 + 소리굽쇠 뿔
        o = '<circle cx="0" cy="2" r="21" fill="%s" %s/><path d="M-10 -18 v-12 M-14 -30 h8 M10 -18 v-12 M6 -30 h8" %s/><path d="M-30 -4 q-6 8 0 16 M30 -4 q6 8 0 16 M-36 -8 q-8 12 0 24 M36 -8 q8 12 0 24" stroke="%s" stroke-width="2.2" fill="none" stroke-linecap="round"/>' % (G, S, S, c)
    elif a == 5:  # 자연: 잎 망토 + 꽃
        o = '<circle cx="0" cy="4" r="20" fill="%s" %s/><path d="M-22 -2 q-6 22 10 26 M22 -2 q6 22 -10 26" fill="%s" %s/><circle cx="0" cy="-20" r="4" fill="#f2b5d4" %s/>' % (G, S, c, S, S)
    elif a == 6:  # 원소: 네 조각
        o = '<circle cx="0" cy="2" r="21" fill="%s" %s/><path d="M0 -19 v42 M-21 2 h42" %s/><path d="M-21 2 a21 21 0 0 1 21 -21 v21 z" fill="#f7c59f"/><path d="M0 23 a21 21 0 0 1 -21 -21 h21 z" fill="#a8d8ea"/><path d="M16 -24 q4 8 0 12 q-6 -4 0 -12" fill="%s" %s/>' % (G, S, P, c, S)
    elif a == 7:  # 일상: 찻잔
        o = '<path d="M-22 -8 h40 q0 32 -20 32 q-20 0 -20 -32 z" fill="%s" %s/><path d="M18 -2 q12 0 10 10 q-2 6 -10 4" %s/><path d="M-12 -14 q2 -6 0 -10 M2 -14 q2 -6 0 -10" stroke="%s" stroke-width="2" fill="none"/>' % (G, S, S, c)
    elif a == 8:  # 창조: 붓끝 머리 + 물감
        o = '<path d="M-20 22 q-6 -28 10 -36 q6 -12 10 -22 q4 10 10 22 q16 8 10 36 z" fill="%s" %s/><circle cx="-10" cy="14" r="3" fill="%s"/><circle cx="12" cy="8" r="4" fill="#a8d8ea"/><path d="M0 -36 q2 -6 0 -6" stroke="%s" stroke-width="4"/>' % (G, S, c, c)
    elif a == 9:  # 공간: 상자 + 별 구멍
        o = '<rect x="-22" y="-18" width="44" height="42" rx="6" fill="%s" %s/><circle cx="10" cy="-6" r="6" fill="#3d4a78"/><circle cx="12" cy="-8" r="1.2" fill="#fff"/><path d="M-18 -18 l6 -8 h36 l-2 8" fill="%s" %s/>' % (G, S, c, S)
    elif a == 10:  # 시간: 모래시계
        o = '<path d="M-20 -22 h40 q0 14 -14 22 q14 8 14 22 h-40 q0 -14 14 -22 q-14 -8 -14 -22 z" fill="%s" %s/><path d="M-6 16 h12 l-6 -6 z" fill="%s"/><path d="M-22 -22 h44 M-22 22 h44" stroke="%s" stroke-width="3"/>' % (G, S, c, c)
    elif a == 11:  # 바람: 회오리 꼬리 + 깃털
        o = '<circle cx="-2" cy="0" r="19" fill="%s" %s/><path d="M14 10 q20 -2 14 -16 q-6 -8 -12 0" %s/><path d="M-6 -18 q-6 -16 6 -18 q0 10 -6 18" fill="%s" %s/>' % (G, S, S, c, S)
    elif a == 12:  # 유대: 쌍둥이 + 리본
        o = '<circle cx="-11" cy="4" r="15" fill="%s" %s/><circle cx="11" cy="4" r="15" fill="%s" %s/><path d="M-4 -12 l-6 -6 v12 z M4 -12 l6 -6 v12 z" fill="%s" %s/>' % (G, S, G, S, c, S)
    elif a == 13:  # 권위: 왕관 + 망토 깃
        o = '<circle cx="0" cy="4" r="20" fill="%s" %s/><path d="M-10 -14 l3 -10 l7 6 l7 -6 l3 10 z" fill="%s" %s/><path d="M-20 8 l-6 -10 l8 2 M20 8 l6 -10 l-8 2" fill="%s" %s/>' % (G, S, c, S, c, S)
    elif a == 14:  # 파멸: 금 간 몸 + 조각
        o = '<path d="M-20 -14 l12 -6 l6 6 l10 -8 l12 10 v26 l-10 10 h-24 l-8 -12 z" fill="%s" %s/>%s<path d="M24 -24 l6 2 l-2 6 z M-28 -22 l5 -3 l2 6 z" fill="%s" %s/>' % (G, S, crack(0, 2, 10, c), c, S)
    elif a == 15:  # 번영: 동전 주머니
        o = '<path d="M-20 20 q-6 -24 8 -32 l-4 -6 h32 l-4 6 q14 8 8 32 z" fill="%s" %s/><circle cx="20" cy="-14" r="6" fill="%s" %s/><path d="M-12 -18 q12 6 24 0" %s/>' % (G, S, c, S, S)
    elif a == 16:  # 영감: 머리 위 번개 별
        o = '<circle cx="0" cy="4" r="20" fill="%s" %s/><path d="M0 -36 l-6 12 h8 l-6 12" stroke="%s" stroke-width="3" fill="none" stroke-linejoin="round"/><path d="M14 -28 l1 3 3 1 -3 1 -1 3 -1 -3 -3 -1 3 -1z" fill="%s"/>' % (G, S, c, c)
    elif a == 17:  # 신성: 날개 + 빛고리
        o = '<circle cx="0" cy="4" r="19" fill="%s" %s/><ellipse cx="0" cy="-22" rx="12" ry="4" stroke="%s" stroke-width="3" fill="none"/><path d="M-18 0 q-18 -10 -14 8 q6 4 14 0 M18 0 q18 -10 14 8 q-6 4 -14 0" fill="var(--sheet)" %s/>' % (G, S, '#e8c840', S)
    elif a == 18:  # 형상: 블록
        o = '<rect x="-20" y="-4" width="20" height="26" fill="%s" %s/><rect x="0" y="-4" width="20" height="26" fill="%s" %s/><rect x="-12" y="-24" width="24" height="20" fill="%s" %s/><path d="M-20 10 h40" %s/>' % (G, S, G, S, c, S, P)
    elif a == 19:  # 심판: 저울 + 가발
        o = '<circle cx="0" cy="6" r="19" fill="%s" %s/><path d="M-16 -8 q-6 -10 2 -16 q6 -8 14 -4 q8 -4 14 4 q8 6 2 16" fill="var(--sheet)" %s/><path d="M22 -10 v24 M14 -10 h16 M14 -10 l-3 8 h6 z M30 -10 l-3 8 h6 z" stroke="%s" stroke-width="1.8" fill="none"/>' % (G, S, S, '#8a7a5a')
    else:  # 20 질서: 격자
        o = '<rect x="-20" y="-20" width="40" height="44" rx="4" fill="%s" %s/><path d="M-20 -6 h40 M-20 8 h40 M-6 -20 v44 M8 -20 v44" stroke="%s" stroke-width="1.6"/>' % (G, S, c)
    return o + band


def mob(a, kind, cx=50, cy=52):
    """kind: wander / chase / flee / rush."""
    expr = {'wander': 'sleepy', 'chase': 'angry', 'flee': 'scared', 'rush': 'fierce'}[kind]
    fy = -6 if a not in (7, 9, 18, 20) else -8
    body = mob_body(a) + face(0, fy, expr, .85, blush=kind in ('wander', 'flee'))
    o = shadow(cx, cy + 30, 18 if kind != 'rush' else 24)
    if kind == 'wander':
        o += g(body, cx, cy - 4)
        o += '<path d="M%s %s q-3 -4 0 -8 M%s %s q3 -4 0 -8" %s/>' % (cx - 30, cy + 20, cx + 30, cy + 20, P)
    elif kind == 'chase':
        o += g(body, cx, cy, 1, 12)
        o += '<path d="M%s %s l-6 -10 M%s %s l6 -12" %s/>' % (cx - 18, cy - 12, cx + 22, cy - 10, S)
    elif kind == 'flee':
        o += g(body, cx, cy, 1, -14)
        o += '<path d="M%s %s h14 M%s %s h18 M%s %s h12" %s/>' % (cx + 26, cy - 6, cx + 28, cy + 4, cx + 26, cy + 14, P)
        o += '<path d="M%s %s q4 6 0 9 q-4 -3 0 -9" fill="#cde8f6" stroke="#8cc6e8" stroke-width="1.2"/>' % (cx - 22, cy - 26)
        o += '<path d="M%s %s l1 3 3 1 -3 1 -1 3 -1 -3 -3 -1 3 -1z M%s %s l1 2 2 1 -2 1 -1 2 -1 -2 -2 -1 2 -1z" fill="#f5c542"/>' % (cx - 32, cy + 4, cx + 30, cy - 26)
    else:
        o += g(body, cx, cy + 6, 1, 18, 1.15, .8)
        o += '<path d="M%s %s q-6 -4 -12 0 q2 -6 -4 -8 M%s %s q-4 -6 -10 -4" %s/>' % (cx - 30, cy + 22, cx - 34, cy + 12, P)
    return o


def eater(cx=60, cy=60):
    o = shadow(cx, cy + 34, 34)
    for k in range(6):
        ang = k * math.pi / 3 + .3
        x2, y2 = cx + math.cos(ang) * 48, cy + math.sin(ang) * 40
        o += '<path d="M%s %s q%s %s %s %s" stroke="#5a2a3a" stroke-width="5" fill="none" stroke-linecap="round"/>' % (cx, cy, (x2 - cx) * .4 + 8, (y2 - cy) * .4 - 8, x2 - cx, y2 - cy)
    o += '<circle cx="%s" cy="%s" r="30" fill="#7a2a3a" %s/>' % (cx, cy, S)
    o += '<circle cx="%s" cy="%s" r="5" fill="#f5c542"/><circle cx="%s" cy="%s" r="5" fill="#f5c542"/>' % (cx - 11, cy - 6, cx + 11, cy - 6)
    o += '<path d="M%s %s l4 4 l4 -4 l4 4 l4 -4" stroke="#f5c542" stroke-width="1.6" fill="none"/>' % (cx - 8, cy + 10)
    return o


# ---------- 타일·건물·물건 ----------

def tile(name):
    """64×64 칸 하나."""
    bgc = {'grass': '#d8eec9', 'town': '#f3ead8', 'road': '#d9d2c3', 'pass': '#d9c59a', 'bridge': '#b98c5a', 'bridge_broken': '#8c6a4a',
           'gate': '#e9876a', 'crop': '#b9d77e', 'hole': '#3d3530', 'sea': '#6fa8dc', 'water': '#8cc6e8', 'cliff': '#6f6257',
           'forest': '#6fae74', 'mountain': '#9a8f86', 'wall': '#a7a7b4', 'fence': '#d8eec9', 'ice': '#cfe9f5',
           'cave_floor': '#8a7d6e', 'cave_wall': '#3f3934', 'cave_exit': '#f5e7a8', 'cave_mouth': '#9a8f86', 'fountain': '#f3ead8'}[name]
    o = '<rect x="0" y="0" width="64" height="64" fill="%s"/>' % bgc
    if name == 'grass':
        o += '<path d="M14 40 l3 -8 l3 8 M40 22 l3 -8 l3 8" stroke="#8fbf7a" stroke-width="1.6" fill="none"/><circle cx="46" cy="46" r="2.5" fill="#f6b3c0"/>'
    elif name == 'town':
        o += '<circle cx="18" cy="20" r="2" fill="#e0d3b8"/><circle cx="44" cy="44" r="2" fill="#e0d3b8"/>'
    elif name == 'road':
        o += ''.join('<rect x="%s" y="%s" width="24" height="12" rx="4" fill="#cbc3b2"/>' % (x, y) for x, y in [(4, 6), (34, 10), (12, 28), (40, 32), (6, 48), (34, 50)])
    elif name == 'pass':
        o += '<path d="M8 50 q24 -10 48 0" stroke="#b9a578" stroke-width="2" fill="none"/>'
    elif name == 'bridge':
        o += ''.join('<path d="M%s 4 v56" stroke="#8b6640" stroke-width="2"/>' % x for x in (12, 26, 40, 54))
    elif name == 'bridge_broken':
        o += '<path d="M12 4 v20 M26 4 v14 M40 40 v20 M54 34 v26" stroke="#5a4030" stroke-width="2"/><path d="M0 32 h64" stroke="#8cc6e8" stroke-width="8"/>'
    elif name == 'gate':
        o += ''.join('<path d="M%s 6 v52" stroke="#a04a3a" stroke-width="3"/>' % x for x in (12, 26, 40, 54))
    elif name == 'crop':
        o += ''.join('<path d="M6 %s h52" stroke="#8fae5a" stroke-width="3" stroke-dasharray="6 4"/>' % y for y in (14, 30, 46))
    elif name == 'hole':
        o += '<ellipse cx="32" cy="34" rx="24" ry="18" fill="#221d1a"/>'
    elif name in ('sea', 'water'):
        o += '<path d="M8 24 q8 -6 16 0 t16 0 M24 44 q8 -6 16 0 t16 0" stroke="#fff" stroke-width="2" fill="none" opacity=".7"/>'
    elif name == 'cliff':
        o += '<path d="M10 0 v64 M30 0 v64 M50 0 v64" stroke="#5a4e45" stroke-width="2"/>'
    elif name == 'forest':
        o += '<circle cx="20" cy="22" r="14" fill="#4f8f57"/><circle cx="44" cy="40" r="16" fill="#5f9f67"/>'
    elif name == 'mountain':
        o += '<path d="M6 58 L32 10 L58 58 z" fill="#857a71"/><path d="M24 24 L32 10 L40 24 z" fill="#f4f1ec"/>'
    elif name == 'wall':
        o += '<path d="M0 16 h64 M0 32 h64 M0 48 h64 M20 0 v16 M44 16 v16 M20 32 v16 M44 48 v16" stroke="#8a8a98" stroke-width="2"/>'
    elif name == 'fence':
        o += '<path d="M0 28 h64 M0 40 h64 M10 20 v28 M32 20 v28 M54 20 v28" stroke="#a88758" stroke-width="3"/>'
    elif name == 'ice':
        o += '<path d="M12 50 l14 -14 M34 28 l14 -14" stroke="#fff" stroke-width="3"/>'
    elif name == 'cave_floor':
        o += '<circle cx="20" cy="40" r="3" fill="#7a6e60"/><circle cx="44" cy="18" r="2" fill="#7a6e60"/>'
    elif name == 'cave_wall':
        o += '<circle cx="26" cy="30" r="18" fill="#4a433d"/>'
    elif name == 'cave_exit':
        o += '<path d="M10 64 q0 -50 22 -50 q22 0 22 50" fill="#fff8d0"/>'
    elif name == 'cave_mouth':
        o += '<path d="M6 58 L32 14 L58 58 z" fill="#857a71"/><path d="M20 58 q0 -24 12 -24 q12 0 12 24 z" fill="#221d1a"/>'
    elif name == 'fountain':
        o += '<circle cx="32" cy="34" r="22" fill="#d9d2c3"/><circle cx="32" cy="34" r="16" fill="#8cc6e8"/><path d="M32 30 v-14 q-6 4 -8 10 M32 16 q6 4 8 10" stroke="#fff" stroke-width="2" fill="none"/>'
    return svg(64, 64, o, 'tile')


def building(bid, cx=60, cy=70):
    o = shadow(cx, cy + 34, 46)
    if bid == 'tree':
        o += '<path d="M%s %s q-4 -30 4 -50 q8 20 4 50 z" fill="#8b6640" %s/>' % (cx - 4, cy + 34, S)
        o += '<circle cx="%s" cy="%s" r="34" fill="#7fb77e" %s/><circle cx="%s" cy="%s" r="20" fill="#8fc78e" %s/>' % (cx, cy - 26, S, cx - 26, cy - 8, S)
        for k, (dx, dy) in enumerate([(-30, 30), (-14, 36), (14, 36), (30, 30)]):
            o += '<path d="M%s %s q%s 4 %s %s" %s/><rect x="%s" y="%s" width="12" height="8" rx="2" fill="var(--sheet)" %s/>' % (cx, cy + 30, dx / 2, dx, dy - 30, P, cx + dx - 6, cy + dy, S)
        return o
    if bid == 'notice':
        o += '<path d="M%s %s v40 M%s %s v40" %s/><rect x="%s" y="%s" width="56" height="36" rx="4" fill="#c9a874" %s/>' % (cx - 22, cy, cx + 22, cy, S, cx - 28, cy - 20, S)
        o += ''.join('<rect x="%s" y="%s" width="12" height="10" fill="var(--sheet)" %s/>' % (cx - 22 + k * 16, cy - 8, P) for k in range(3))
        return o
    if bid == 'gacha':
        o += '<rect x="%s" y="%s" width="40" height="34" rx="6" fill="#f2b5d4" %s/><circle cx="%s" cy="%s" r="20" fill="#e6f4fb" %s/>' % (cx - 20, cy, S, cx, cy - 16, S)
        o += '<circle cx="%s" cy="%s" r="5" fill="#ffd59e"/><circle cx="%s" cy="%s" r="5" fill="#a8d8ea"/><circle cx="%s" cy="%s" r="5" fill="#b5e5b5"/>' % (cx - 8, cy - 12, cx + 6, cy - 18, cx + 2, cy - 6)
        return o
    if bid in ('boss_gate', 'boss_gate_open'):
        o += '<path d="M%s %s v-40 q0 -30 34 -30 q34 0 34 30 v40 z" fill="#c4bcb2" %s/><path d="M%s %s v-26 q0 -16 16 -16 q16 0 16 16 v26 z" fill="#5a5048" %s/>' % (cx - 34, cy + 34, S, cx - 16, cy + 34, S)
        if bid == 'boss_gate':
            o += crack(cx - 20, cy - 10, 10) + crack(cx + 22, cy + 6, 8)
        else:
            o += ''.join('<circle cx="%s" cy="%s" r="4" fill="%s" %s/>' % (cx + dx, cy + 30, c, S) for dx, c in [(-40, '#f2b5d4'), (-30, '#fff1a8'), (32, '#f2b5d4'), (42, '#b8e0d2')])
        return o
    roof = {'forge': '#c0634a', 'board': '#6f8fd0', 'hospital': '#f6f6f6', 'house_1': '#e9a07a', 'house_2': '#8fb8d8', 'house_3': '#a8c88a'}[bid]
    o += '<rect x="%s" y="%s" width="76" height="44" fill="#f3e6cf" %s/>' % (cx - 38, cy - 10, S)
    o += '<path d="M%s %s L%s %s L%s %s z" fill="%s" %s/>' % (cx - 46, cy - 8, cx, cy - 44, cx + 46, cy - 8, roof, S)
    o += '<path d="M%s %s v-18 q0 -8 8 -8 q8 0 8 8 v18" fill="#c9a874" %s/>' % (cx - 8, cy + 34, S)
    if bid == 'forge':
        o += '<rect x="%s" y="%s" width="10" height="20" fill="#9a8f86" %s/><path d="M%s %s q-6 -8 0 -12 q6 4 0 12" fill="#f6b3c0" %s/>' % (cx + 20, cy - 48, S, cx + 25, cy - 54, S)
        o += '<rect x="%s" y="%s" width="16" height="12" fill="#ffd59e" %s/><path d="M%s %s q4 -6 8 0" %s/>' % (cx - 32, cy + 2, S, cx - 28, cy + 12, M)
    elif bid == 'board':
        o += ''.join('<rect x="%s" y="%s" width="9" height="11" fill="var(--sheet)" %s/>' % (cx - 34 + k * 12, cy - 2, P) for k in range(2))
        o += '<path d="M%s %s h22" %s stroke-dasharray="3 2"/>' % (cx + 14, cy + 26, S)
    elif bid == 'hospital':
        o += '<circle cx="%s" cy="%s" r="9" fill="var(--sheet)" %s/><path d="M%s %s v-5 M%s %s h4" %s/>' % (cx, cy - 22, S, cx, cy - 22, cx, cy - 22, S)
        o += '<path d="M%s %s v10 M%s %s h10" stroke="#e0675a" stroke-width="3"/>' % (cx - 28, cy, cx - 33, cy + 5)
    else:
        o += '<rect x="%s" y="%s" width="14" height="12" fill="#cde8f6" %s/><rect x="%s" y="%s" width="14" height="12" fill="#cde8f6" %s/>' % (cx - 32, cy - 2, S, cx + 18, cy - 2, S)
    return o


def prop_item(pid, cx=40, cy=42):
    o = shadow(cx, cy + 18, 16)
    if pid in ('rock', 'rock_heavy'):
        o += '<circle cx="%s" cy="%s" r="18" fill="%s" %s/><circle cx="%s" cy="%s" r="5" fill="#fff" opacity=".3"/>' % (cx, cy, '#6f6a66' if pid == 'rock_heavy' else '#9a948e', S, cx - 6, cy - 6)
        if pid == 'rock_heavy':
            o += '<path d="M%s %s h20 M%s %s h16" %s/>' % (cx - 10, cy + 4, cx - 8, cy + 10, S)
    elif pid in ('plate', 'plate_on'):
        o += '<rect x="%s" y="%s" width="36" height="24" rx="3" fill="#c8c0b0" stroke="%s" stroke-width="2.5"/>' % (cx - 18, cy - 8, '#f5c542' if pid == 'plate_on' else 'var(--ink)')
    elif pid in ('chest', 'chest_open', 'lock_chest'):
        o += '<rect x="%s" y="%s" width="40" height="26" rx="3" fill="#a46a3a" %s/>' % (cx - 20, cy - 6, S)
        if pid == 'chest_open':
            o += '<path d="M%s %s h40 l-4 -14 h-32 z" fill="#c58a4a" %s/><path d="M%s %s l3 -8 M%s %s l0 -10 M%s %s l-3 -8" %s/>' % (cx - 20, cy - 6, S, cx - 8, cy - 22, cx, cy - 22, cx + 8, cy - 22, M)
        else:
            o += '<path d="M%s %s q20 -14 40 0" fill="#7a4a2a" %s/><circle cx="%s" cy="%s" r="4" fill="#f5c542" %s/>' % (cx - 20, cy - 6, S, cx, cy + 2, S)
        if pid == 'lock_chest':
            o += '<rect x="%s" y="%s" width="22" height="10" rx="2" fill="var(--sheet)" %s/>' % (cx - 11, cy + 4, P)
    elif pid == 'note':
        o += '<path d="M%s %s h22 v18 l-6 6 h-16 z" fill="#fff4dc" %s/><path d="M%s %s h12 M%s %s h8" %s/>' % (cx - 11, cy - 12, S, cx - 6, cy - 4, cx - 6, cy + 2, P)
    elif pid == 'toy_hammer':
        o += '<path d="M%s %s l18 -18" stroke="#8b6640" stroke-width="5" stroke-linecap="round"/><rect x="%s" y="%s" width="20" height="12" rx="3" fill="#e9876a" %s transform="rotate(-45 %s %s)"/>' % (cx - 10, cy + 12, cx + 2, cy - 20, S, cx + 12, cy - 14)
    elif pid == 'orb':
        o += '<circle cx="%s" cy="%s" r="10" fill="#cfe9ff" %s/><circle cx="%s" cy="%s" r="3" fill="#fff"/>' % (cx, cy, S, cx - 3, cy - 3)
    elif pid == 'coin':
        o += '<circle cx="%s" cy="%s" r="10" fill="#f5c542" stroke="#b8902a" stroke-width="2"/>' % (cx, cy)
    elif pid == 'word_drop':
        o += '<rect x="%s" y="%s" width="20" height="26" rx="2" fill="#fff4dc" stroke="#e9876a" stroke-width="2.5"/>' % (cx - 10, cy - 13)
    elif pid == 'sign':
        o += '<path d="M%s %s v-30" %s/><path d="M%s %s h30 l6 6 l-6 6 h-30 z" fill="#c9a874" %s/>' % (cx, cy + 18, S, cx - 16, cy - 20, S)
    elif pid == 'crates':
        o += '<rect x="%s" y="%s" width="22" height="20" fill="#c9a874" %s/><rect x="%s" y="%s" width="22" height="20" fill="#c9a874" %s/><rect x="%s" y="%s" width="22" height="20" fill="#d9b88a" %s/>' % (cx - 22, cy, S, cx, cy, S, cx - 11, cy - 20, S)
    return o


# ---------- 오프닝 컷(세로 9:16) ----------

def cut(cid):
    W, H = 90, 160
    sky = {'op01_tree': '#3d4a78', 'op02_crack': '#2e3560', 'op03_fall': '#cfd0d8', 'op04_village': '#fde3d6', 'title_key_art': '#fde3d6'}.get(cid, '#fff4e6')
    o = '<rect width="%s" height="%s" fill="%s"/>' % (W, H, sky)
    o += '<rect x="0" y="%s" width="%s" height="%s" fill="var(--ink)" opacity=".06"/>' % (H * 2 / 3, W, H / 3)  # 아래 1/3: 글자 자리
    sm = lambda s, x, y, k: g(s, x, y, k)
    if cid in ('op01_tree', 'op02_crack', 'title_key_art'):
        o += '<path d="M42 100 q-2 -30 3 -46 q5 16 3 46 z" fill="#8b6640"/><circle cx="45" cy="46" r="26" fill="%s"/>' % ('#7fb77e' if cid != 'op02_crack' else '#56607a')
        for k in range(7):
            x = 10 + k * 12
            o += '<path d="M45 100 q%s 6 %s 14" stroke="#8b6640" stroke-width="1.4" fill="none"/>' % ((x - 45) / 2, x - 45)
            if cid == 'op02_crack' and k % 2:
                o += '<path d="M%s 112 l2 4" %s/>' % (x - 1, M)
            else:
                o += '<rect x="%s" y="114" width="6" height="5" rx="1" fill="%s"/>' % (x - 3, '#ffd59e' if cid != 'op02_crack' else '#9a9aaa')
        if cid == 'op02_crack':
            o += crack(45, 70, 14, '#c9c9d6') + crack(30, 50, 8, '#c9c9d6')
        if cid == 'op01_tree':
            o += ''.join('<circle cx="%s" cy="%s" r=".8" fill="#fff"/>' % (x, y) for x, y in [(10, 10), (30, 18), (70, 8), (80, 24), (55, 14)])
        if cid == 'title_key_art':
            o += '<rect x="12" y="8" width="66" height="24" rx="6" fill="var(--sheet)" opacity=".6"/>' + txt(45, 24, '제목 자리', 7)
            o += sm(hero('m', 'down', 0, 'happy', 0, 0), 24, 96, .32) + sm(hero('f', 'down', 0, 'happy', 0, 0), 64, 96, .32) + sm(penguin(1, 0, 0), 44, 98, .3)
    elif cid == 'op03_fall':
        for k in range(14):
            x, y, r = (k * 37) % 84 + 4, (k * 53) % 96 + 6, (k * 29) % 40 - 20
            o += '<rect x="%s" y="%s" width="12" height="8" rx="1.5" fill="#bdbdc6" stroke="#8a86a8" stroke-width=".8" transform="rotate(%s %s %s)"/>' % (x, y, r, x + 6, y + 4)
    elif cid == 'op04_village':
        o += '<path d="M0 70 q45 -16 90 0 v40 h-90 z" fill="#d8eec9"/>'
        for x, c in [(14, '#e9a07a'), (40, '#c0634a'), (66, '#8fb8d8')]:
            o += '<rect x="%s" y="70" width="18" height="14" fill="#f3e6cf"/><path d="M%s 70 l11 -12 l11 12 z" fill="%s"/>' % (x - 9, x - 11, c)
        o += '<path d="M44 56 q-4 -8 2 -12 q-4 -6 2 -10" stroke="#b0b0bb" stroke-width="2" fill="none"/><rect x="60" y="88" width="12" height="8" fill="#c8c8d0"/>'
    elif cid.startswith('op05') or cid.startswith('op06') or cid.startswith('op09'):
        gen = 'f' if cid.endswith('_f') else 'm'
        o += '<rect x="0" y="0" width="90" height="106" fill="#f3e6cf"/><path d="M60 20 h24 v40 h-24 z" fill="#ffd59e" opacity=".6"/>'
        if cid.startswith('op05'):
            o += sm(person('blacksmith', 0, 0), 66, 64, .45) + sm(hero(gen, 'down', 0, 'normal', 0, 0), 22, 72, .42) + sm(penguin(1, 0, 0, 'happy'), 44, 82, .38)
            o += '<path d="M52 60 l4 -8" %s/>' % M
        elif cid.startswith('op06'):
            o += '<rect x="34" y="84" width="24" height="10" fill="#9a8f86"/>' + sm(hero(gen, 'down', 0, 'normal', 0, 0), 40, 66, .5) + '<path d="M58 40 l8 -10" %s/>' % M
        else:
            o += '<rect x="14" y="54" width="26" height="40" rx="6" fill="none" stroke="var(--pencil)" stroke-dasharray="3 2"/><rect x="50" y="54" width="26" height="40" rx="6" fill="none" stroke="var(--pencil)" stroke-dasharray="3 2"/>'
            o += txt(27, 78, '남', 8) + txt(63, 78, '여', 8)
    elif cid == 'op07_defect':
        o += '<rect x="0" y="0" width="90" height="106" fill="#f3e6cf"/><path d="M20 80 h50 l-6 12 h-38 z" fill="#9a8f86"/>'
        o += '<rect x="28" y="30" width="34" height="22" rx="3" fill="#cfcfd6" %s/>%s<path d="M24 26 l-6 -6 M66 26 l6 -6 M45 22 v-8" %s/>' % (S, crack(45, 66, 8, '#ef8a5e'), M)
    elif cid == 'op08_split':
        o += '<rect x="0" y="0" width="90" height="106" fill="#f3e6cf"/>' + sm(penguin(1, 0, 0, 'happy'), 45, 76, .5)
        o += '<rect x="14" y="22" width="24" height="18" rx="3" fill="#ffd59e" %s/><rect x="52" y="22" width="24" height="18" rx="3" fill="#cfcfd6" %s/>' % (S, S)
        o += '<path d="M40 30 l10 0" %s stroke-dasharray="2 2"/>' % M
    o += '<rect x="0.5" y="0.5" width="%s" height="%s" rx="4" fill="none" stroke="var(--ink)" stroke-width="1.5"/>' % (W - 1, H - 1)
    return svg(W, H, o, 'cut')


def logo():
    o = '<rect width="200" height="86" rx="10" fill="var(--sheet)"/>'
    o += '<path d="M20 70 q30 -20 60 -6 t70 -6 t40 4" stroke="#8b6640" stroke-width="2" fill="none"/>'
    o += txt(100, 50, '어원 RPG', 26, 'font-weight="700"') + txt(100, 74, '(가칭)', 9)
    return svg(200, 86, o)


def svgvb(vb, body, cls=''):
    return '<svg viewBox="%s" xmlns="http://www.w3.org/2000/svg" role="img"%s>%s</svg>' % (vb, ' class="%s"' % cls if cls else '', body)


def walking(body_svg_fn, cx=60, cy=66):
    """필드용 3/4 시점 걷는 모습: 살짝 기울이고 발밑 그림자·걸음 줄."""
    return g(body_svg_fn(), cx, cy, .9, -6) + '<path d="M%s %s h-12 M%s %s h-8" %s/>' % (cx - 30, cy + 30, cx - 28, cy + 36, P)


FX = {'de': 'down', 'un': 'x', 'in_neg': 'shrink', 'ob': 'shock', 'com': 'shield', 're': 'circle', 'ad': 'gather', 'sub': 'wave',
      'prae': 'flash', 'inter': 'wall', 'in': 'suck', 'dis': 'scatter', 'ex': 'split', 'pro': 'forward'}


def fx(mid, cx=50, cy=50):
    k = FX.get(mid, '')
    o = '<circle cx="%s" cy="%s" r="40" fill="#fde3d6" opacity=".5"/>' % (cx, cy)
    if k == 'down':
        o += '<path d="M%s %s v44 M%s %s l12 12 l12 -12" %s/>' % (cx, cy - 26, cx - 12, cy + 6, M)
    elif k == 'x':
        o += '<path d="M%s %s l40 40 M%s %s l-40 40" %s/>' % (cx - 20, cy - 20, cx + 20, cy - 20, M)
    elif k == 'shrink':
        o += '<circle cx="%s" cy="%s" r="28" %s stroke-dasharray="4 4"/><circle cx="%s" cy="%s" r="14" %s/><path d="M%s %s l8 8 M%s %s l-8 8" %s/>' % (cx, cy, M, cx, cy, M, cx - 28, cy - 28, cx + 28, cy - 28, P)
    elif k == 'shock':
        o += ''.join('<path d="M%s %s q12 %s 0 %s" %s/>' % (cx - 10 + i * 12, cy - 20 - i * 4, 20 + i * 4, 40 + i * 8, M) for i in range(3))
    elif k == 'shield':
        o += '<path d="M%s %s q30 -10 60 0 q0 36 -30 48 q-30 -12 -30 -48" %s/>' % (cx - 30, cy - 22, M)
    elif k == 'circle':
        o += '<path d="M%s %s a24 24 0 1 1 -8 -18" %s/><path d="M%s %s l-2 -12 l12 2" %s/>' % (cx + 24, cy, M, cx + 14, cy - 18, M)
    elif k == 'gather':
        o += ''.join('<path d="M%s %s L%s %s" %s/>' % (cx + 36 * math.cos(a), cy + 36 * math.sin(a), cx + 12 * math.cos(a), cy + 12 * math.sin(a), M) for a in [i * math.pi / 4 for i in range(8)])
    elif k == 'wave':
        o += '<path d="M%s %s q10 -10 20 0 t20 0 t20 0" %s/><path d="M%s %s v-20" %s/>' % (cx - 30, cy + 22, M, cx, cy + 14, P)
    elif k == 'flash':
        o += '<path d="M%s %s l40 -6 l-10 -10 M%s %s l40 6 l-10 10" %s/>' % (cx - 20, cy, cx - 20, cy, M)
    elif k == 'wall':
        o += '<rect x="%s" y="%s" width="12" height="60" rx="3" fill="#fde3d6" %s/>' % (cx - 6, cy - 30, M)
    elif k == 'suck':
        o += '<path d="M%s %s q-30 -10 -20 -30 M%s %s q30 -6 26 -30 M%s %s q-10 30 20 30" stroke="#f5c542" stroke-width="2.5" fill="none"/><circle cx="%s" cy="%s" r="6" fill="#f5c542"/>' % (cx, cy, cx, cy, cx, cy, cx, cy)
    elif k == 'scatter':
        o += ''.join('<rect x="%s" y="%s" width="8" height="8" fill="#ef8a5e" transform="rotate(%s %s %s)"/>' % (cx + 30 * math.cos(a) - 4, cy + 30 * math.sin(a) - 4, a * 60, cx, cy) for a in [i * 1.1 for i in range(6)])
    elif k == 'split':
        o += '<path d="M%s %s h20 M%s %s l24 -18 M%s %s l24 18" %s/>' % (cx - 30, cy, cx - 10, cy, cx - 10, cy, M)
    elif k == 'forward':
        o += '<path d="M%s %s l18 18 l-18 18 M%s %s l18 18 l-18 18" %s/>' % (cx - 20, cy - 18, cx, cy - 18, M)
    else:  # impact
        o += '<path d="M%s %s l6 14 l14 -6 l-6 14 l14 6 l-14 6 l6 14 l-14 -6 l-6 14 l-6 -14 l-14 6 l6 -14 l-14 -6 l14 -6 l-6 -14 l14 6 z" fill="#ffd59e" %s/>' % (cx, cy - 34, M)
    return o


def slot_icon(sl, cx=30, cy=30):
    if sl == 'weapon':
        return '<path d="M%s %s l20 -20 l4 4 l-20 20 z M%s %s l6 6" fill="#d9d2c3" %s/>' % (cx - 10, cy + 10, cx - 14, cy + 6, S)
    if sl == 'head':
        return '<path d="M%s %s q0 -24 20 -24 q20 0 20 24 z" fill="#d9d2c3" %s/>' % (cx - 20, cy + 10, S)
    if sl == 'chest':
        return '<path d="M%s %s l8 -8 h16 l8 8 v22 h-32 z" fill="#d9d2c3" %s/>' % (cx - 16, cy - 8, S)
    if sl == 'hands':
        return '<path d="M%s %s v-14 q0 -6 4 -6 v8 v-10 q0 -4 4 -4 v14 v-12 q0 -4 4 -4 v16 q4 -6 8 -2 l-8 14 h-12 z" fill="#d9d2c3" %s/>' % (cx - 10, cy + 14, S)
    return '<path d="M%s %s v-20 h12 v14 h12 v6 z" fill="#d9d2c3" %s/>' % (cx - 12, cy + 12, S)


def mini_item(mid, w, h):
    """미니게임 조각: 크기 비율에 맞춘 개략 도형."""
    W, H = 120, max(30, 120 * h / w) if w >= h else 120
    if w < h:
        W, H = 120 * w / h, 120
    o = '<rect x="2" y="2" width="%s" height="%s" rx="8" fill="var(--sheet)" stroke="var(--pencil)" stroke-dasharray="3 2"/>' % (W - 4, H - 4)
    cx, cy = W / 2, H / 2
    label = {'order_belt': '벨트 ▶▶▶', 'order_card': '글자 자리', 'fish_word': '물고기 · 단어', 'fish_bait': '미끼', 'guard_wall': '성벽 · 문',
             'guard_traveler': '손님 · 팻말', 'guard_climber': '사다리 손님', 'guard_unit': '방패 유닛', 'sprout': '새싹', 'root_wisp': '말뿌리 정령',
             'fish_top': '위에서 본 물고기', 'trap_critter': '들짐승', 'trap_snare': '덫', 'trap_hunter': '사냥꾼(위)', 'furnace': '용광로', 'anvil': '모루',
             'order_hero': '주인공(위)', 'moat_soldier': '병사 · 깃발', 'waterwheel': '물레방아', 'ore_vein': '광석(흰색)', 'ore_rock': '돌', 'order_ticket': '주문서'}.get(mid, mid)
    if 'fish' in mid:
        o += '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#a8d8ea" %s/><path d="M%s %s l14 -10 v20 z" fill="#a8d8ea" %s/>' % (cx - 6, cy, W * .32, H * .28, S, cx + W * .26, cy, S)
    elif mid in ('furnace',):
        o += '<path d="M%s %s h40 v-20 q-20 -20 -40 0 z" fill="#c0634a" %s/><path d="M%s %s q6 -12 12 0" %s/>' % (cx - 20, cy + 14, S, cx - 6, cy + 6, M)
    elif mid in ('anvil',):
        o += '<path d="M%s %s h44 l-8 10 h-28 z" fill="#9a8f86" %s/>' % (cx - 22, cy - 6, S)
    elif mid in ('waterwheel',):
        o += '<circle cx="%s" cy="%s" r="%s" fill="#c9a874" %s/>' % (cx, cy, min(W, H) * .35, S) + ''.join('<path d="M%s %s L%s %s" %s/>' % (cx, cy, cx + min(W, H) * .35 * math.cos(a), cy + min(W, H) * .35 * math.sin(a), S) for a in [i * math.pi / 3 for i in range(6)])
    elif mid in ('sprout',):
        o += '<path d="M%s %s v-14 q-10 -6 -14 2 q8 4 14 -2 q4 -10 14 -6 q-4 8 -14 6" fill="#a8d89a" %s/>' % (cx, cy + 14, S)
    elif mid in ('order_ticket', 'order_card', 'ore_vein', 'ore_rock'):
        o += '<rect x="%s" y="%s" width="%s" height="%s" rx="6" fill="%s" %s/>' % (cx - W * .3, cy - H * .3, W * .6, H * .6, '#eeeeee' if mid != 'ore_rock' else '#9a948e', S)
    elif mid == 'order_belt' or mid == 'guard_wall':
        o += '<rect x="6" y="%s" width="%s" height="%s" fill="%s" %s/>' % (cy - H * .25, W - 12, H * .5, '#c4bcb2' if mid == 'guard_wall' else '#9a8f86', S)
    else:
        o += '<circle cx="%s" cy="%s" r="%s" fill="var(--sheet)" %s/>' % (cx - W * .2, cy, min(W, H) * .3, S) + face(cx - W * .2, cy, 'normal', .6)
        o += '<rect x="%s" y="%s" width="%s" height="%s" rx="4" fill="#fff4dc" %s/>' % (cx, cy - H * .18, W * .3, H * .36, P)
    o += txt(cx, H - 6, label, 8)
    return svgvb('0 0 %s %s' % (W, H), o)
