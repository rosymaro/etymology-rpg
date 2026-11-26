class_name WorldMap
extends RefCounted
## 스테이지 1~10이 모두 있는 월드맵(data/map/world.json, tools/map/build_world.py가 만든다). 화면 없이 테스트한다.
## 타일 글자: . 풀  , 마을 바닥  p 고갯길  b 다리  = 스테이지 문  ^ 산  ~ 바다  w 호수·강  # 절벽  T 숲  H 성벽
## 스테이지 문(=)은 열린 스테이지(open_gates[stage] = true)만 지나간다.
## 퀘스트 길목(q)은 그 퀘스트(open_gates["s01_q_root"] = true …)를 마쳐야 지나간다. 나머지 막는 타일은 언제나 막는다.

const PATH := "res://data/map/world.json"

var tile := 64
var w := 0
var h := 0
var rows: PackedStringArray = []
var regions: Array = []  ## {stage, rect[x,y,w,h](타일), town[x,y,w,h](타일), spots{id: [px,py]}, start[px,py]}
var walk := ".,pb"
var zones: PackedStringArray = []  ## 칸마다 지역(스테이지 % 10, 바다 -). 지역 경계는 곧은 선이 아니다
var _gate := {}  ## Vector2i -> 스테이지(int, 그 보스를 이겨야 열리는 문) 또는 퀘스트 id(String)
var quest_gates: Array = []  ## {id, kind(bridge|cliff), tiles, spot}
var puzzles: Array = []  ## 돌 밀기 퍼즐(07-fun 3절) 원본 목록
var caves: Array = []  ## 동굴(07-fun 5절) {id, kind, mouths[[x,y]], outs[[x,y]]}: 큰 지도의 입구(c)와 그 바깥 칸
var cave_maps: Dictionary = {}  ## 동굴 id -> 따로 된 동굴 지도 원본
var items: Array = []  ## (동굴 지도) 퀘스트 물건 {id, cell}
var exits: Array = []  ## (동굴 지도) 나가는 곳(x) [[x,y]]: 순서가 큰 지도 입구 순서
var is_cave := false
var cave_kind := ""  ## (동굴 지도) pass·treasure·quest·castle. castle(성 안)은 어둡지 않다
var extra_block := {}  ## 지금 막힌 칸(퍼즐의 돌·상자): 화면이 채운다
var extra_walk := {}  ## 지금 지나갈 수 있게 된 칸(돌로 메운 물·구멍)

static var _cache: WorldMap
static var _caves := {}


static func load_default() -> WorldMap:
	if _cache == null:
		_cache = from_dict(JsonFile.read(PATH))
	return _cache


## 동굴 지도(큰 지도의 cave_maps[id]). 돌·상자 상태가 남게 한 번만 만든다.
static func load_cave(id: String) -> WorldMap:
	if not _caves.has(id):
		var d: Dictionary = load_default().cave_maps.get(id, {})
		if d.is_empty():
			return null
		var m := from_dict(d)
		m.is_cave = true
		_caves[id] = m
	return _caves[id]


static func from_dict(d: Dictionary) -> WorldMap:
	var m := WorldMap.new()
	m.tile = int(d.get("tile", 64))
	m.w = int(d["w"])
	m.h = int(d["h"])
	for r in d["rows"]:
		m.rows.append(String(r))
	m.regions = d.get("regions", [])
	for z in d.get("zones", []):
		m.zones.append(String(z))
	m.walk = String(d.get("walk", ".,pbsikc"))
	for gt in d.get("gates", []):
		for t in gt["tiles"]:
			m._gate[Vector2i(int(t[0]), int(t[1]))] = int(gt["stage"])
	m.puzzles = d.get("puzzles", [])
	m.caves = d.get("caves", [])
	m.items = d.get("items", [])
	m.cave_maps = d.get("cave_maps", {})
	m.exits = d.get("exits", [])
	m.cave_kind = String(d.get("kind", ""))
	m.quest_gates = d.get("quest_gates", [])
	for qg in m.quest_gates:
		for t in qg["tiles"]:
			m._gate[Vector2i(int(t[0]), int(t[1]))] = String(qg["id"])
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
## dynamic = false면 퍼즐 돌·상자·메운 칸(지금 상태)을 보지 않고 땅만 본다(path_len).
func walkable(c: Vector2i, open_gates: Dictionary = {}, dynamic := true) -> bool:
	if dynamic and extra_block.has(c):
		return false
	if dynamic and extra_walk.has(c):
		return true
	var k := ch(c)
	if k == "=" or k == "q":
		return bool(open_gates.get(_gate.get(c, 0), false))
	return walk.contains(k)


## 닫힌 스테이지 문 칸이면 그 스테이지, 아니면 0.
func closed_gate(c: Vector2i, open_gates: Dictionary = {}) -> int:
	if ch(c) == "=" and not bool(open_gates.get(_gate.get(c, 0), false)):
		return int(_gate.get(c, 0))
	return 0


## 닫힌 퀘스트 길목 칸이면 그 퀘스트 id, 아니면 "".
func closed_quest(c: Vector2i, open_gates: Dictionary = {}) -> String:
	if ch(c) == "q" and not bool(open_gates.get(_gate.get(c, ""), false)):
		return String(_gate.get(c, ""))
	return ""


## 원이 닿는 닫힌 퀘스트 길목(없으면 "").
func touching_quest(p: Vector2, r: float, open_gates: Dictionary = {}) -> String:
	for v in _probe(r + 8.0):
		var q := closed_quest(cell(p + v), open_gates)
		if q != "":
			return q
	return ""


## 문·길목 칸의 스테이지(int) 또는 퀘스트 id(String). 아니면 0.
func gate_id(c: Vector2i) -> Variant:
	return _gate.get(c, 0)


func quest_gate(id: String) -> Dictionary:
	for qg in quest_gates:
		if qg["id"] == id:
			return qg
	return {}


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


## 자유 탐험(개발자 모드): 벽·물·산·길목을 무시하고 지도 안이면 어디든 간다.
func move_free(p: Vector2, d: Vector2, r: float) -> Vector2:
	return (p + d).clamp(Vector2(r, r), size_px() - Vector2(r, r))


## a에서 b까지 벽(지나갈 수 없는 칸) 없이 곧게 보이는가. 무기가 벽 너머를 맞히지 않게(07-fun 1절).
func clear_line(a: Vector2, b: Vector2) -> bool:
	var n := int(ceil(a.distance_to(b) / (tile * 0.4)))
	for k in range(1, n):
		if not walkable(cell(a.lerp(b, float(k) / n)), {}, true):
			return false
	return true


## 무기가 지나가는 칸: 걸을 수 있는 칸과 마을 성벽(M) 위(사용자 의견: 마을 안에서 바깥으로 쏜다).
func shot_passes(c: Vector2i) -> bool:
	return walkable(c, {}, true) or ch(c) == "M"


## a에서 b까지 무기가 막히지 않는가(성벽 위로는 넘어간다).
func shot_line(a: Vector2, b: Vector2) -> bool:
	var n := int(ceil(a.distance_to(b) / (tile * 0.4)))
	for k in range(1, n):
		if not shot_passes(cell(a.lerp(b, float(k) / n))):
			return false
	return true


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


## 그 자리가 속한 스테이지(바다·지도 밖이면 0).
func stage_at(p: Vector2) -> int:
	return stage_of(cell(p))


func stage_of(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or zones.is_empty():
		return 0
	var k := zones[c.y][c.x]
	if k == "-":
		return 0
	var n := int(k)
	return 10 if n == 0 else n


## 마을 바닥(,)과 마을 돌길(s). 몹은 마을에 생기지 않고, 병원에서 쉬는 동안은 마을 밖으로 못 나간다.
## 어두운 동굴 안(동굴 지도 전체).
func in_cave(_p: Vector2 = Vector2.ZERO) -> bool:
	return is_cave and cave_kind != "castle"  # 어두운 동굴(성 안은 밝다)


## 큰 지도: 그 칸이 동굴 입구면 [동굴 id, 입구 번호], 아니면 [].
func mouth_at(c: Vector2i) -> Array:
	if ch(c) != "c":
		return []
	for cv in caves:
		for i in (cv["mouths"] as Array).size():
			var mo: Array = cv["mouths"][i]
			if Vector2i(int(mo[0]), int(mo[1])) == c:
				return [String(cv["id"]), i]
	return []


func cave_info(id: String) -> Dictionary:
	for cv in caves:
		if cv["id"] == id:
			return cv
	return {}


## 큰 지도: 동굴 id의 i번째 입구 바깥 풀칸 가운데(동굴에서 나오는 자리).
func cave_out(id: String, i: int) -> Vector2:
	var o: Array = cave_info(id)["outs"][i]
	return (Vector2(float(o[0]), float(o[1])) + Vector2(0.5, 0.5)) * tile


## 동굴 지도: i번째 나가는 곳 바로 안쪽 칸 가운데(들어온 자리).
func exit_inside(i: int) -> Vector2:
	var e: Array = exits[i]
	var c := Vector2i(int(e[0]), int(e[1]))
	if c.y == h - 1:  # 아래 가장자리(성문)
		c.y -= 1
	elif c.y == 0:
		c.y += 1
	else:
		c.x += 1 if c.x == 0 else -1
	return (Vector2(c) + Vector2(0.5, 0.5)) * tile


## 동굴 지도: 그 칸이 나가는 곳이면 번호, 아니면 -1.
func exit_at(c: Vector2i) -> int:
	for i in exits.size():
		if Vector2i(int(exits[i][0]), int(exits[i][1])) == c:
			return i
	return -1


## 동굴 지도: 가장 가까운 나가는 곳 번호(ex-).
func nearest_exit(p: Vector2) -> int:
	var best := 0
	var bd := INF
	for i in exits.size():
		var q := (Vector2(float(exits[i][0]), float(exits[i][1])) + Vector2(0.5, 0.5)) * tile
		if q.distance_to(p) < bd:
			bd = q.distance_to(p)
			best = i
	return best


func is_town(p: Vector2) -> bool:
	var k := ch(cell(p))
	return k == "," or k == "s"


func start(stage: int) -> Vector2:
	var r := region(stage)
	var s: Array = r.get("start", [0, 0])
	return Vector2(float(s[0]), float(s[1]))


func spot(stage: int, id: String) -> Vector2:
	var s: Array = region(stage).get("spots", {}).get(id, [0, 0])
	return Vector2(float(s[0]), float(s[1]))


## 그 스테이지 들판(마을 아님)에서 near로부터 거리 lo~hi 안의 서 있을 수 있는 자리(못 찾으면 Vector2.INF).
func random_field_spot(stage: int, rng: RandomNumberGenerator, near: Vector2, lo: float, hi: float, r: float) -> Vector2:
	for k in 60:
		var a := rng.randf() * TAU
		var p := near + Vector2.from_angle(a) * rng.randf_range(lo, hi)
		var c := cell(p)
		if stage_of(c) != stage:
			continue
		var snapped := (Vector2(c) + Vector2(0.5, 0.5)) * tile
		if not is_town(snapped) and fits(snapped, r):
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
			if not dist.has(n) and walkable(n, open_gates, false):
				dist[n] = int(dist[c]) + 1
				q.append(n)
	return -1
