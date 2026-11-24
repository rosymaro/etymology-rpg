class_name WorldMap
extends RefCounted
## 스테이지 1~10이 모두 있는 월드맵(data/map/world.json, tools/map/build_world.py가 만든다). 화면 없이 테스트한다.
## 타일 글자: . 풀  , 마을 바닥  p 고갯길  b 다리  = 스테이지 문  ^ 산  ~ 바다  w 호수·강  # 절벽  T 숲  H 성벽
## 스테이지 문(=)은 열린 스테이지(open_gates[stage] = true)만 지나간다. 나머지 막는 타일은 언제나 막는다.

const PATH := "res://data/map/world.json"

var tile := 64
var w := 0
var h := 0
var rows: PackedStringArray = []
var regions: Array = []  ## {stage, rect[x,y,w,h](타일), town[x,y,w,h](타일), spots{id: [px,py]}, start[px,py]}
var walk := ".,pb"
var _gate := {}  ## Vector2i -> 스테이지(그 스테이지 보스를 이겨야 열리는 문)

static var _cache: WorldMap


static func load_default() -> WorldMap:
	if _cache == null:
		_cache = from_dict(JsonFile.read(PATH))
	return _cache


static func from_dict(d: Dictionary) -> WorldMap:
	var m := WorldMap.new()
	m.tile = int(d.get("tile", 64))
	m.w = int(d["w"])
	m.h = int(d["h"])
	for r in d["rows"]:
		m.rows.append(String(r))
	m.regions = d.get("regions", [])
	m.walk = String(d.get("walk", ".,pb"))
	for gt in d.get("gates", []):
		for t in gt["tiles"]:
			m._gate[Vector2i(int(t[0]), int(t[1]))] = int(gt["stage"])
	return m


func size_px() -> Vector2:
	return Vector2(w * tile, h * tile)


func cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / tile)), int(floor(p.y / tile)))


func ch(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return "^"
	return rows[c.y][c.x]


## 그 칸을 지나갈 수 있는가. open_gates: 스테이지 -> true(그 스테이지에서 다음으로 가는 문이 열림)
func walkable(c: Vector2i, open_gates: Dictionary = {}) -> bool:
	var k := ch(c)
	if k == "=":
		return bool(open_gates.get(_gate.get(c, 0), false))
	return walk.contains(k)


## 닫힌 문 칸이면 그 스테이지, 아니면 0.
func closed_gate(c: Vector2i, open_gates: Dictionary = {}) -> int:
	if ch(c) == "=" and not bool(open_gates.get(_gate.get(c, 0), false)):
		return int(_gate.get(c, 0))
	return 0


## 반지름 r 원이 서 있을 수 있는가(둘레 8점과 가운데를 본다).
func fits(p: Vector2, r: float, open_gates: Dictionary = {}) -> bool:
	for v in _probe(r):
		if not walkable(cell(p + v), open_gates):
			return false
	return true


func _probe(r: float) -> Array[Vector2]:
	var k := r * 0.72
	return [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r), Vector2(k, k), Vector2(-k, k), Vector2(k, -k), Vector2(-k, -k)]


## 움직인다: 가로·세로를 따로 막아서 벽을 따라 미끄러진다.
func move(p: Vector2, d: Vector2, r: float, open_gates: Dictionary = {}) -> Vector2:
	var n := p
	if fits(Vector2(p.x + d.x, p.y), r, open_gates):
		n.x += d.x
	if fits(Vector2(n.x, p.y + d.y), r, open_gates):
		n.y += d.y
	return n


## 원이 닿는 닫힌 문의 스테이지(없으면 0). 막혔을 때 "아직 못 가는 길" 알림용.
func touching_gate(p: Vector2, r: float, open_gates: Dictionary = {}) -> int:
	for v in _probe(r + 6.0):
		var s := closed_gate(cell(p + v), open_gates)
		if s > 0:
			return s
	return 0


func region(stage: int) -> Dictionary:
	for r in regions:
		if int(r["stage"]) == stage:
			return r
	return {}


## 그 자리가 속한 스테이지(지역 밖이면 0).
func stage_at(p: Vector2) -> int:
	var c := cell(p)
	for r in regions:
		var rc: Array = r["rect"]
		if c.x >= int(rc[0]) and c.y >= int(rc[1]) and c.x < int(rc[0]) + int(rc[2]) and c.y < int(rc[1]) + int(rc[3]):
			return int(r["stage"])
	return 0


func is_town(p: Vector2) -> bool:
	return ch(cell(p)) == ","


func start(stage: int) -> Vector2:
	var r := region(stage)
	var s: Array = r.get("start", [0, 0])
	return Vector2(float(s[0]), float(s[1]))


func spot(stage: int, id: String) -> Vector2:
	var s: Array = region(stage).get("spots", {}).get(id, [0, 0])
	return Vector2(float(s[0]), float(s[1]))


## 그 스테이지 들판(마을 아님)에서 near로부터 거리 lo~hi 안의 서 있을 수 있는 자리(못 찾으면 Vector2.INF).
func random_field_spot(stage: int, rng: RandomNumberGenerator, near: Vector2, lo: float, hi: float, r: float) -> Vector2:
	var rc: Array = region(stage).get("rect", [0, 0, w, h])
	for k in 60:
		var a := rng.randf() * TAU
		var p := near + Vector2.from_angle(a) * rng.randf_range(lo, hi)
		var c := cell(p)
		if c.x < int(rc[0]) or c.y < int(rc[1]) or c.x >= int(rc[0]) + int(rc[2]) or c.y >= int(rc[1]) + int(rc[3]):
			continue
		var snapped := (Vector2(c) + Vector2(0.5, 0.5)) * tile
		if ch(c) != "," and fits(snapped, r):
			return snapped
	return Vector2.INF


## 걸어서 갈 수 있는 칸 수(가로세로 이웃)로 a → b 최단 거리. 못 가면 -1. 테스트와 연출용.
func path_len(a: Vector2, b: Vector2, open_gates: Dictionary = {}) -> int:
	var s := cell(a)
	var t := cell(b)
	var dist := {s: 0}
	var q: Array[Vector2i] = [s]
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		if c == t:
			return int(dist[c])
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not dist.has(n) and walkable(n, open_gates):
				dist[n] = int(dist[c]) + 1
				q.append(n)
	return -1
