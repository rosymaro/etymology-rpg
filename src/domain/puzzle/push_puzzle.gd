class_name PushPuzzle
extends RefCounted
## 돌 밀기 퍼즐 하나(07-fun.md 3·4절). tools/map/push_puzzle.py와 같은 규칙이다. 노드·화면을 모른다.
## 칸 좌표는 월드맵 칸(Vector2i). 바탕 글자는 판(rows)에서 읽는다: T 벽 . 바닥 P 발판 w 물 O 구멍 i 얼음 C·L 상자 Q 쪽지 E 입구.
## 돌(R)은 밀 수 있고, 무거운 돌(H)은 com-이 있어야 밀린다. 물·구멍에 밀어 넣으면 메워져 지나갈 수 있다. 얼음 위 돌은 막힐 때까지 미끄러진다.

const WALK := ".PiSE"
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var id := ""
var kind := ""
var reward := ""
var answer := ""  ## 조각 자물쇠의 답 단어
var note := ""  ## 숨은 쪽지의 조각 id
var origin := Vector2i.ZERO
var size := Vector2i.ZERO
var base := {}  ## Vector2i -> 바탕 글자
var rocks := {}  ## Vector2i -> "R" | "H"
var filled := {}  ## 메운 물·구멍
var plates: Array[Vector2i] = []
var chests: Array[Vector2i] = []
var secrets: Array[Vector2i] = []
var entry := Vector2i.ZERO
var _start_rocks := {}


static func from_dict(q: Dictionary) -> PushPuzzle:
	var p := PushPuzzle.new()
	p.id = q["id"]
	p.kind = q["kind"]
	p.reward = q.get("reward", "")
	p.answer = q.get("answer", "")
	p.note = q.get("note", "")
	p.origin = Vector2i(int(q["origin"][0]), int(q["origin"][1]))
	p.size = Vector2i(int(q["size"][0]), int(q["size"][1]))
	var rows: Array = q["rows"]
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			var c := row[x]
			var at := p.origin + Vector2i(x, y)
			match c:
				"R", "H":
					p.base[at] = "."
				"Q":
					p.base[at] = "S"
				_:
					p.base[at] = c
	for r in q["rocks"]:
		p._start_rocks[Vector2i(int(r[0]), int(r[1]))] = String(r[2])
	for c in q["plates"]:
		p.plates.append(Vector2i(int(c[0]), int(c[1])))
	for c in q["chest"]:
		p.chests.append(Vector2i(int(c[0]), int(c[1])))
	for c in q["secret"]:
		p.secrets.append(Vector2i(int(c[0]), int(c[1])))
	p.entry = Vector2i(int(q["entry"][0]), int(q["entry"][1]))
	p.reset()
	return p


func reset() -> void:
	rocks = _start_rocks.duplicate()
	filled = {}


func contains(c: Vector2i) -> bool:
	return base.has(c)


func ch(c: Vector2i) -> String:
	return String(base.get(c, "T"))


## 사람이 설 수 있는 칸인가(퍼즐 안만).
func open_cell(c: Vector2i) -> bool:
	var k := ch(c)
	return not rocks.has(c) and (WALK.contains(k) or ((k == "w" or k == "O") and filled.has(c)))


## 돌을 d쪽으로 민다. 밀렸으면 true.
func push(rock: Vector2i, d: Vector2i, heavy_ok: bool) -> bool:
	if not rocks.has(rock):
		return false
	var kind_r: String = rocks[rock]
	if kind_r == "H" and not heavy_ok:
		return false
	var t := rock + d
	var k := ch(t)
	if rocks.has(t) or "TCL".contains(k) or not (WALK.contains(k) or k == "w" or k == "O"):
		return false
	rocks.erase(rock)
	while true:
		if (k == "w" or k == "O") and not filled.has(t):  # 빠져서 메운다
			filled[t] = true
			return true
		if k != "i":
			break
		var n := t + d  # 얼음: 막힐 때까지 미끄러진다
		var nk := ch(n)
		if rocks.has(n) or "TCL".contains(nk) or not (WALK.contains(nk) or nk == "w" or nk == "O"):
			break
		t = n
		k = nk
	rocks[t] = kind_r
	return true


func plates_done() -> bool:
	for p in plates:
		if not rocks.has(p):
			return false
	return true


## 숨은 쪽지가 드러났는가(돌이 비켰다).
func secret_open() -> bool:
	for s in secrets:
		if not rocks.has(s):
			return true
	return false


## 상자를 열 수 있는가: 발판 퍼즐은 발판을 다 채웠을 때, 그 밖은 상자 곁에 닿기만 하면(그게 퍼즐이다).
func chest_ready() -> bool:
	return plates.is_empty() or plates_done()


## 입구에서 사람이 닿는 칸(돌이 막는 것 포함). 풀 수 있는지 확인(테스트)에 쓴다.
func reach(from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var q: Array[Vector2i] = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in DIRS:
			var n: Vector2i = c + d
			if not seen.has(n) and open_cell(n):
				seen[n] = true
				q.append(n)
	return seen
