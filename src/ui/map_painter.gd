class_name MapPainter
extends RefCounted
## 큰 지도 그리기(표현 층, 사용자 의견: 영역마다 특색 있는 파스텔 동화풍, 살아 있는 지도). 풍경은 data/map/biomes.json.
## 겹(draw_layer, MapView가 조각마다 한 번만 그린다):
## ground 바닥: 지역 색(경계는 섞는다), 얼룩, 사막 물결, 눈, 용암 금, 수정 반짝임, 물 바탕(깊을수록 진하게), 바닷가 모래, 길·다리
## grass 풀·꽃 / mtn 산: 칸마다 같은 세모가 아니라 산줄기 안쪽일수록 크고 높게 겹쳐 하나의 산맥처럼 / trees 숲
## 움직이는 물(draw_water_live)만 매 프레임: 찰랑이는 물결과 반짝임, 물가 거품, 끓는 용암
## 미리 계산(산·숲·물의 안쪽 깊이, 지역 색)은 지도마다 한 번만 한다.

const SEA := 0
const BUILDING_ROOF := {"forge": Color("c0634a"), "board": Color("6f8fd0"), "hospital": Color("f2f2f2"), "tree": Color("4f8f57")}
var map: WorldMap
var cfg: Dictionary
var bio := {}  ## 스테이지 -> 풍경 사전(색은 Color로 바꿔 둔다)
var _stage: PackedByteArray
var _ground: PackedColorArray
var _mtn: PackedByteArray  ## 산 안쪽 깊이(1 = 가장자리)
var _wood: PackedByteArray  ## 숲 안쪽 깊이
var _deep: PackedByteArray  ## 물 깊이(물가에서 떨어진 칸 수)
var _wind_speed := 0.9
var _wind_wave := 0.0025
var _sway := Vector2(2, 7)
var _open := {}  ## 모든 길목이 열린 상태(배경 그림은 사라지지 않는 모습만: 닫힌 길목은 그 위에 따로 그린다)
var _static := false  ## 조각 그림(MapView가 한 번만 그려 둔다)을 그리는 중: 흔들림·물결 없이
const LAYERS := ["ground", "grass", "mtn", "trees"]  ## 바닥, 풀·꽃, 산, 나무(아래부터)

static var _cache := {}


static func for_map(m: WorldMap) -> MapPainter:
	var key := m.get_instance_id()
	if not _cache.has(key):
		var p := MapPainter.new()
		p._setup(m)
		_cache[key] = p
	return _cache[key]


func _setup(m: WorldMap) -> void:
	map = m
	cfg = JsonFile.read("res://data/map/biomes.json")
	for k in cfg["biomes"]:
		var b: Dictionary = (cfg["biomes"][k] as Dictionary).duplicate(true)
		b["g0"] = Color(b["ground"][0])
		b["g1"] = Color(b["ground"][1])
		b["w0"] = Color(b["water"][0])
		b["w1"] = Color(b["water"][1])
		b["m0"] = Color(b["mountain"][0])
		b["m1"] = Color(b["mountain"][1])
		b["cap"] = String(b["mountain"][2])
		b["grass_c"] = Color(b["grass"]) if String(b["grass"]) != "" else Color.TRANSPARENT
		var fl: Array = []
		for c in b["flowers"]:
			fl.append(Color(c))
		b["fl"] = fl
		var tc: Array = []
		for c in b["tree"]["colors"]:
			tc.append(Color(c))
		b["tc"] = tc
		bio[int(k)] = b
	var sea: Array = cfg["sea"]
	bio[SEA] = {"g0": Color(sea[0]), "g1": Color(sea[1]), "w0": Color(sea[0]), "w1": Color(sea[1]), "m0": Color("c9bdb2"), "m1": Color("a3968b"),
		"cap": "snow", "grass_c": Color.TRANSPARENT, "fl": [], "tc": [Color("7fb77e")], "tree": {"kind": "round"}, "deco": "", "name": "sea"}
	var w: Dictionary = cfg.get("wind", {})
	_wind_speed = float(w.get("speed", 0.9))
	_wind_wave = float(w.get("wave", 0.0025))
	var sw: Array = w.get("sway", [2.0, 7.0])
	_sway = Vector2(float(sw[0]), float(sw[1]))
	for gid in m._gate.values():
		_open[gid] = true
	var n := m.w * m.h
	_stage.resize(n)
	for y in m.h:
		for x in m.w:
			_stage[y * m.w + x] = m.stage_of(Vector2i(x, y))
	_mtn = _depth("^c", 6)
	_wood = _depth("T", 4)
	_deep = _depth("~w", 6)
	_ground.resize(n)
	for y in m.h:
		for x in m.w:
			_ground[y * m.w + x] = _raw_ground(x, y)
	# 지역 경계는 5×5로 섞어 부드럽게
	var mixed := _ground.duplicate()
	for y in m.h:
		for x in m.w:
			var s := _stage[y * m.w + x]
			var edge := false
			for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < m.w and q.y < m.h and _stage[q.y * m.w + q.x] != s and _stage[q.y * m.w + q.x] != SEA and s != SEA:
					edge = true
			if not edge:
				continue
			var acc := Color(0, 0, 0, 0)
			var cnt := 0
			for yy in range(y - 2, y + 3):
				for xx in range(x - 2, x + 3):
					if xx >= 0 and yy >= 0 and xx < m.w and yy < m.h and _stage[yy * m.w + xx] != SEA:
						acc += _ground[yy * m.w + xx]
						cnt += 1
			if cnt > 0:
				mixed[y * m.w + x] = acc / cnt
	_ground = mixed


## 그 글자들로 된 덩어리 안에서, 바깥 칸에서 떨어진 거리(가장자리 = 1, 최대 cap).
func _depth(chars: String, cap: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(map.w * map.h)
	var q: Array[Vector2i] = []
	for y in map.h:
		for x in map.w:
			if chars.contains(map.rows[y][x]):
				var edge := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if not chars.contains(map.ch(Vector2i(x, y) + d)):
						edge = true
				if edge:
					out[y * map.w + x] = 1
					q.append(Vector2i(x, y))
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		var v := out[c.y * map.w + c.x]
		if v >= cap:
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x >= 0 and n.y >= 0 and n.x < map.w and n.y < map.h and out[n.y * map.w + n.x] == 0 and chars.contains(map.rows[n.y][n.x]):
				out[n.y * map.w + n.x] = v + 1
				q.append(n)
	return out


static func _h(x: int, y: int) -> int:
	return absi((x * 73856093) ^ (y * 19349663) ^ (x * y * 83492791))


func _noise(x: int, y: int) -> float:
	# 부드러운 얼룩: 네 칸 단위 값 잡음을 겹친다
	var a := _h(x / 4, y / 4) % 1000 / 1000.0
	var b := _h(x / 4 + 1, y / 4) % 1000 / 1000.0
	var fx := (x % 4) / 4.0
	return lerpf(a, b, fx) * 0.7 + (_h(x, y) % 100) / 100.0 * 0.3


func biome_at(c: Vector2i) -> Dictionary:
	if c.x < 0 or c.y < 0 or c.x >= map.w or c.y >= map.h:
		return bio[SEA]
	return bio.get(int(_stage[c.y * map.w + c.x]), bio[SEA])


func _raw_ground(x: int, y: int) -> Color:
	var b := biome_at(Vector2i(x, y))
	var g := (b["g0"] as Color).lerp(b["g1"], _noise(x, y))
	var k := map.rows[y][x]
	if k == "^" or k == "c":
		g = (b["m1"] as Color).lerp(g, 0.35)
	elif k == "T":
		g = g.darkened(0.12)
	return g


## 위치의 바람 세기 0~1: 지도 위를 돌풍이 물결처럼 지나간다.
func wind(px: float, py: float, t: float) -> float:
	return 0.5 + 0.5 * sin(t * _wind_speed - (px + py * 0.4) * _wind_wave + sin(t * 0.37) * 1.5)


func sway(px: float, py: float, t: float, phase: float) -> float:
	if _static:  # 조각 그림은 멈춘 모습(흔들림은 MapView 셰이더가 한다)
		return 0.0
	var w := wind(px, py, t)
	return sin(t * 2.6 + phase) * lerpf(_sway.x, _sway.y, w) + w * _sway.y * 0.6


## 미니맵 한 점의 색.
func mini_color(x: int, y: int, gates: Dictionary) -> Color:
	var b := biome_at(Vector2i(x, y))
	var k := map.rows[y][x]
	match k:
		"~", "w":
			return (b["w0"] as Color).lerp(b["w1"], minf(1.0, _deep[y * map.w + x] / 4.0))
		"^", "c":
			return (b["m0"] as Color).lerp(b["m1"], 0.4) if b["cap"] != "snow" or _mtn[y * map.w + x] < 3 else Color("f4f1ec")
		"T":
			return (b["tc"][0] as Color)
		",", "s", "h", "F", "o", "f":
			return Color("f3ead8") if k != "f" else Color("b9d77e")
		"p", "b":
			return Color("d9c59a") if k == "p" else Color("b98c5a")
		"#":
			return Color("6f6257")
		"H":
			return Color("a7a7b4")
		"=":
			return Color("e9876a")
		"q":
			return Color("d9c59a") if map.walkable(Vector2i(x, y), gates) else Color("e9876a")
	return _ground[y * map.w + x]


# ---------- 그리기 ----------

## 한 겹을 칸 범위(x0..x1, y0..y1, 끝 제외)만 움직임 없이 그린다(MapView 조각, 지도 그림 내보내기).
## 산·나무는 아래 칸에서 위로 솟으니 부르는 쪽이 범위를 넉넉히(MARGIN) 잡는다.
## 사라지지 않고 움직이지 않는 것만 그린다(사용자 의견): 길목은 열린 모습, 마을 건물은 그린다.
## 닫힌 길목·상자·퍼즐 돌·몹·사람·글씨는 게임이 위에 따로 그린다.
func draw_layer(ci: CanvasItem, layer: String, o: Vector2, x0: int, y0: int, x1: int, y1: int) -> void:
	var gates := _open
	_static = true
	var ts := float(map.tile)
	x0 = maxi(0, x0)
	y0 = maxi(0, y0)
	x1 = mini(map.w, x1)
	y1 = mini(map.h, y1)
	for y in range(y0, y1):
		var row := map.rows[y]
		for x in range(x0, x1):
			var k := row[x]
			match layer:
				"ground":
					_ground_cell(ci, o, x, y, k, ts, 0.0, gates)
				"grass":
					if k == ".":
						_grass(ci, Rect2(o + Vector2(x, y) * ts, Vector2(ts, ts)), x, y, biome_at(Vector2i(x, y)), 0.0, _h(x, y))
				"mtn":
					if k == "^" or k == "c":
						_mountain(ci, o, x, y, ts, 0.0, k == "c")
				"trees":
					if k == "T":
						_trees(ci, o, x, y, ts, 0.0)
	if layer == "ground":
		for y in range(y0, y1):
			var row := map.rows[y]
			for x in range(x0, x1):
				if row[x] == ".":
					_beach(ci, Rect2(o + Vector2(x, y) * ts, Vector2(ts, ts)), x, y, biome_at(Vector2i(x, y)), 0.0)
		var area := Rect2(Vector2(x0, y0) * ts, Vector2(x1 - x0, y1 - y0) * ts).grow(ts * 2)
		for rg in map.regions:
			for bd in rg.get("buildings", []):
				var rc: Array = bd["rect"]
				if area.intersects(Rect2(Vector2(float(rc[0]), float(rc[1])) * ts, Vector2(float(rc[2]), float(rc[3])) * ts)):
					_building(ci, o, bd, ts)
	_static = false


## 마을 건물(사라지지 않는 것). 이름표·굴뚝 연기는 FieldScreen이 위에 그린다.
func _building(ci: CanvasItem, o: Vector2, b: Dictionary, ts: float) -> void:
	var rc: Array = b["rect"]
	var r := Rect2(o + Vector2(float(rc[0]), float(rc[1])) * ts, Vector2(float(rc[2]), float(rc[3])) * ts)
	var id := String(b["id"])
	if id == "tree":
		var c := r.get_center()
		ci.draw_rect(Rect2(c + Vector2(-14, 0), Vector2(28, ts)), Color("7a5a3a"))
		ci.draw_circle(c + Vector2(0, -20), ts * 1.1, Color("4f8f57"))
		ci.draw_circle(c + Vector2(-40, 0), ts * 0.7, Color("5f9f67"))
		ci.draw_circle(c + Vector2(40, 0), ts * 0.7, Color("5f9f67"))
		return
	var roof: Color = BUILDING_ROOF.get(id, Color("a46a4a") if id.ends_with("1") or id.ends_with("3") else Color("8a6aa4"))
	ci.draw_rect(r, Color("efe3cf"))
	ci.draw_rect(r, UiKit.INK, false, 3)
	var top := Rect2(r.position - Vector2(10, 0), Vector2(r.size.x + 20, r.size.y * 0.45))
	var roof_pts := PackedVector2Array([top.position + Vector2(0, top.size.y), top.position + Vector2(top.size.x / 2, -ts * 0.5), top.end])
	ci.draw_colored_polygon(roof_pts, roof)
	ci.draw_polyline(roof_pts, UiKit.INK, 3)
	var dp: Array = b["door"]
	var door := o + Vector2(float(dp[0]), float(dp[1])) - Vector2(ts * 0.3, ts * 0.9)
	ci.draw_rect(Rect2(door, Vector2(ts * 0.6, ts * 0.8)), Color("8b6640"))
	for k in 2:  # 창
		var wx := r.position.x + (k + 0.5) * r.size.x / 2.0 - ts * 0.25
		if absf(wx + ts * 0.25 - (door.x + ts * 0.3)) > ts * 0.6:
			ci.draw_rect(Rect2(Vector2(wx, r.position.y + r.size.y * 0.55), Vector2(ts * 0.5, ts * 0.4)), Color("bfe3f5"))
	if id == "hospital":
		var c := Vector2(r.get_center().x, r.position.y + r.size.y * 0.2)
		ci.draw_rect(Rect2(c - Vector2(8, 22), Vector2(16, 44)), UiKit.BAD)
		ci.draw_rect(Rect2(c - Vector2(22, 8), Vector2(44, 16)), UiKit.BAD)
	if id == "forge":  # 굴뚝(연기는 움직이니 게임이 그린다)
		ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.8, -ts * 0.2), Vector2(18, 30)), Color("6f6257"))


## 사라지는 지형(배경 그림에는 없다): 닫힌 길목(열리면 사라진다), 구멍(돌로 메우면 사라진다). 매 프레임 덮어 그린다.
func draw_changing(ci: CanvasItem, o: Vector2, cam: Vector2, view: Vector2, bleed: float, gates: Dictionary) -> void:
	var ts := float(map.tile)
	var c0 := map.cell(cam - Vector2(0, bleed)) - Vector2i(1, 1)
	var c1 := map.cell(cam + view + Vector2(0, bleed)) + Vector2i(1, 1)
	for y in range(maxi(0, c0.y), mini(map.h, c1.y + 1)):
		var row := map.rows[y]
		for x in range(maxi(0, c0.x), mini(map.w, c1.x + 1)):
			var k := row[x]
			if k == "O" or ((k == "=" or k == "q") and not map.walkable(Vector2i(x, y), gates, false)):
				_ground_cell(ci, o, x, y, k, ts, 0.0, gates)


## 움직이는 물만(조각 그림 위에 매 프레임): 물결·반짝임·물가 거품, 용암은 숨 쉬는 빛·떠다니는 껍질·거품.
func draw_water_live(ci: CanvasItem, o: Vector2, cam: Vector2, view: Vector2, t: float, bleed: float) -> void:
	var ts := float(map.tile)
	var c0 := map.cell(cam - Vector2(0, bleed)) - Vector2i(1, 1)
	var c1 := map.cell(cam + view + Vector2(0, bleed)) + Vector2i(1, 1)
	for y in range(maxi(0, c0.y), mini(map.h, c1.y + 1)):
		var row := map.rows[y]
		for x in range(maxi(0, c0.x), mini(map.w, c1.x + 1)):
			var k := row[x]
			var r := Rect2(o + Vector2(x, y) * ts, Vector2(ts, ts))
			if k == "~" or k == "w":
				_water_live(ci, r, x, y, biome_at(Vector2i(x, y)), t, _h(x, y))
			elif k == ".":
				_foam(ci, r, x, y, biome_at(Vector2i(x, y)), t)


func _ground_cell(ci: CanvasItem, o: Vector2, x: int, y: int, k: String, ts: float, t: float, gates: Dictionary) -> void:
	var r := Rect2(o + Vector2(x, y) * ts, Vector2(ts, ts))
	var b := biome_at(Vector2i(x, y))
	var hsh := _h(x, y)
	var c := r.get_center()
	if k == "~" or k == "w":
		_water(ci, r, x, y, b, t, hsh)
		return
	ci.draw_rect(r, _ground[y * map.w + x])
	match k:
		".":
			_deco(ci, r, x, y, b, t, hsh)
		",":
			ci.draw_rect(r, Color("f3ead8"))
			if hsh % 5 == 0:
				ci.draw_circle(c + Vector2(hsh % 20 - 10, (hsh / 7) % 20 - 10), 2.5, Color("e3d6bc"))
		"s":
			ci.draw_rect(r, Color("dcd5c6"))
			for k2 in 3:
				var hh := _h(x * 3 + k2, y)
				ci.draw_rect(Rect2(r.position + Vector2(4 + hh % 30, 4 + (hh / 3) % 44), Vector2(20, 12)), Color("cbc3b2"))
		"p":
			ci.draw_rect(r, Color("dcc8a0"))
			ci.draw_line(r.position + Vector2(6, ts * 0.7), r.position + Vector2(ts - 6, ts * 0.65), Color("c4ad84"), 2)
		"b":
			_water(ci, r, x, y, b, t, hsh)
			for k2 in 4:
				ci.draw_rect(Rect2(r.position + Vector2(3 + k2 * 15.5, 2), Vector2(12, ts - 4)), Color("c49a68"))
				ci.draw_line(r.position + Vector2(3 + k2 * 15.5, 2), r.position + Vector2(3 + k2 * 15.5, ts - 2), Color("8b6640"), 1.5)
			ci.draw_line(r.position + Vector2(0, 3), r.position + Vector2(ts, 3), Color("8b6640"), 3)
			ci.draw_line(r.position + Vector2(0, ts - 3), r.position + Vector2(ts, ts - 3), Color("8b6640"), 3)
		"q":
			var qid := map.closed_quest(Vector2i(x, y), gates)
			var kind: String = map.quest_gate(String(map.gate_id(Vector2i(x, y)))).get("kind", "")
			if kind == "bridge":
				_water(ci, r, x, y, b, t, hsh)
				for k2 in 4:
					if qid == "" or (hsh + k2) % 3 != 0:
						ci.draw_rect(Rect2(r.position + Vector2(4 + k2 * 15, 4), Vector2(10, ts - 8)), Color("c49a68") if qid == "" else Color("7a5a3a"))
			else:
				ci.draw_rect(r, Color("dcc8a0") if qid == "" else Color("7d6f63"))
				for k2 in 4:
					if qid != "":
						ci.draw_line(r.position + Vector2(4, 12 + k2 * 14), r.position + Vector2(ts - 4, 6 + k2 * 14), Color("4a3f36"), 3)
					else:
						ci.draw_line(r.position + Vector2(6, 10 + k2 * 14), r.position + Vector2(ts - 6, 10 + k2 * 14), Color("b8a27a"), 3)
		"#":  # 절벽: 층층이 진 바위 벽
			ci.draw_rect(r, (b["m1"] as Color).darkened(0.08))
			for k2 in 3:
				var yy := r.position.y + 10 + k2 * 18 + (hsh >> k2) % 5
				ci.draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy + 3), (b["m1"] as Color).darkened(0.22), 3)
				ci.draw_line(Vector2(r.position.x, yy - 3), Vector2(r.end.x, yy), (b["m0"] as Color).lightened(0.05), 1.5)
			ci.draw_line(r.position + Vector2(0, 2), Vector2(r.end.x, r.position.y + 2), (b["m0"] as Color), 4)
		"H":
			ci.draw_rect(r, Color("b4b4c2"))
			for k2 in 3:
				ci.draw_line(r.position + Vector2(0, 16 + k2 * 16), r.position + Vector2(ts, 16 + k2 * 16), Color("9090a0"), 2)
				var off := 0.0 if k2 % 2 == 0 else ts / 2
				ci.draw_line(r.position + Vector2(off + 16, k2 * 16), r.position + Vector2(off + 16, k2 * 16 + 16), Color("9090a0"), 2)
			ci.draw_rect(Rect2(r.position, Vector2(ts, 6)), Color("cfcfdc"))
		"F":
			ci.draw_rect(Rect2(r.position + Vector2(0, ts * 0.35), Vector2(ts, 7)), Color("a88758"))
			ci.draw_rect(Rect2(r.position + Vector2(0, ts * 0.62), Vector2(ts, 7)), Color("a88758"))
			for k2 in 2:
				ci.draw_rect(Rect2(r.position + Vector2(10 + k2 * 32, ts * 0.2), Vector2(9, ts * 0.65)), Color("8b6640"))
		"o":
			ci.draw_rect(r, Color("c8c4cf"))
			var inner := r.grow(-8)
			for d in [[Vector2i(-1, 0), SIDE_LEFT], [Vector2i(1, 0), SIDE_RIGHT], [Vector2i(0, -1), SIDE_TOP], [Vector2i(0, 1), SIDE_BOTTOM]]:
				if map.ch(Vector2i(x, y) + d[0]) == "o":
					inner = inner.grow_side(d[1], 8)
			ci.draw_rect(inner, Color("8cc6e8"))
			if hsh % 2 == 0:
				ci.draw_circle(c + Vector2(0, -6 + sin(t * 5.0) * 3), 4, Color(1, 1, 1, 0.8))
		"f":
			ci.draw_rect(r, Color("c4dc8e"))
			for k2 in 3:
				var bx := r.position.x + 10 + k2 * 22
				var sw := sway(bx, r.position.y, t, k2 + x) * 0.4
				ci.draw_line(Vector2(bx, r.end.y - 8), Vector2(bx + sw, r.position.y + 10), Color("6f9a3a"), 4)
				ci.draw_circle(Vector2(bx + sw, r.position.y + 10), 4, Color("f2cf4a"))
		"=":
			ci.draw_rect(r, Color("e9a088"))
			if not map.walkable(Vector2i(x, y), gates):
				for k2 in 4:
					ci.draw_line(r.position + Vector2(8 + k2 * 16, 0), r.position + Vector2(8 + k2 * 16, ts), UiKit.INK, 4)
		"i":
			ci.draw_rect(r, Color("d6eef8"))
			ci.draw_line(r.position + Vector2(10, ts - 14), r.position + Vector2(26, ts - 30), Color(1, 1, 1, 0.9), 3)
			ci.draw_line(r.position + Vector2(34, 28), r.position + Vector2(48, 14), Color(1, 1, 1, 0.9), 3)
		"O":  # 구멍(돌로 메우면 사라진다): 배경에는 안 넣고 draw_changing이 그린다
			if _static:
				return
			ci.draw_circle(c, ts * 0.42, Color("3d3530"))
			ci.draw_circle(c + Vector2(0, 3), ts * 0.34, Color("221d1a"))
		"h":
			ci.draw_rect(r, Color("c9b49a"))


## 바닷가: 물에 닿은 풀 칸은 물 쪽에 모래(용암 지대는 검은 돌, 눈 땅은 눈 둔덕). 물 쪽 가장자리는 물결 모양.
func _beach(ci: CanvasItem, r: Rect2, x: int, y: int, b: Dictionary, t: float) -> void:
	var ts := r.size.x
	var col := Color("f3e3b8")
	if b.get("lava", false):
		col = Color("8a7a74")
	elif b["name"] == "snow":
		col = Color("ffffff")
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var k := map.ch(Vector2i(x, y) + d)
		if k == "~" or k == "w":
			var n := Vector2(d)
			var along := Vector2(-n.y, n.x)
			var edge := r.get_center() + n * ts * 0.5
			var poly := PackedVector2Array([edge + along * -0.5 * ts, edge + along * 0.5 * ts])
			for i in range(8, -1, -1):
				var f := i / 8.0 - 0.5
				var wv := sin(f * 7.0 + x * 1.3 + y * 0.7) * 3.0
				poly.append(edge + along * f * ts - n * (ts * 0.2 + wv))
			ci.draw_colored_polygon(poly, col)


## 물가 거품(움직임): 모래 띠 바깥(물 위)에 밀려왔다 간다.
func _foam(ci: CanvasItem, r: Rect2, x: int, y: int, b: Dictionary, t: float) -> void:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var k := map.ch(Vector2i(x, y) + d)
		if k == "~" or k == "w":
			var n := Vector2(d)
			_foam_side(ci, r.get_center() + n * r.size.x * 0.5, n, Vector2(-n.y, n.x), r.size.x, x, y, b, t)


func _foam_side(ci: CanvasItem, edge: Vector2, n: Vector2, along: Vector2, ts: float, x: int, y: int, b: Dictionary, t: float) -> void:
	var foam := PackedVector2Array()
	var tide := 2.0 + 2.0 * sin(t * 1.6 + x * 0.6 + y * 0.4)
	for i in 9:
		var f := i / 8.0 - 0.5
		var wv := sin(f * 7.0 + x * 1.3 + y * 0.7) * 3.0
		foam.append(edge + along * f * ts + n * (tide + wv * 0.5))
	ci.draw_polyline(foam, Color(1, 1, 1, 0.55 if not b.get("lava", false) else 0.25), 3)

## 바닥 장식(풀·꽃은 _grass): 지역마다(사막 물결, 눈, 용암 금, 양치식물, 수정 반짝임).
func _deco(ci: CanvasItem, r: Rect2, x: int, y: int, b: Dictionary, t: float, hsh: int) -> void:
	var ts := r.size.x
	var fl: Array = b["fl"]
	var deco := String(b.get("deco", ""))
	match deco:
		"dunes":  # 사막: 바람 결 모래 물결, 작은 돌
			for k in 2:
				var yy := r.position.y + 18 + k * 24 + (hsh >> k) % 6
				ci.draw_arc(Vector2(r.position.x + ts * 0.5 + (hsh % 10 - 5), yy + 18), ts * 0.55, PI * 1.2, PI * 1.8, 10, (b["g1"] as Color).darkened(0.08), 2)
			if hsh % 11 == 0:
				ci.draw_circle(r.position + Vector2(20 + hsh % 24, 40), 3, Color("d6b98a"))
			if hsh % 31 == 0:
				ci.draw_circle(r.position + Vector2(32, 32), 5, (fl[0] as Color))  # 사막 꽃
		"snow":  # 눈: 반짝이는 눈송이, 눈 둔덕
			if hsh % 4 == 0:
				var sp := r.position + Vector2(8 + hsh % 48, 8 + (hsh / 49) % 48)
				var tw := 0.5 + 0.5 * sin(t * 3.0 + hsh)
				ci.draw_line(sp - Vector2(3, 0), sp + Vector2(3, 0), Color(1, 1, 1, tw), 1.5)
				ci.draw_line(sp - Vector2(0, 3), sp + Vector2(0, 3), Color(1, 1, 1, tw), 1.5)
			if hsh % 7 == 0:
				ci.draw_arc(r.position + Vector2(32, 48), 18, PI * 1.15, PI * 1.85, 10, Color("dbe6f2"), 3)
		"cracks":  # 용암 지대: 빛나는 금이 숨 쉬듯
			if hsh % 3 == 0:
				var a := 0.45 + 0.35 * sin(t * 2.2 + hsh % 10)
				var p0 := r.position + Vector2(6 + hsh % 20, 10 + (hsh / 3) % 20)
				var pts := PackedVector2Array([p0, p0 + Vector2(14, 8), p0 + Vector2(20, 22), p0 + Vector2(34, 26)])
				ci.draw_polyline(pts, Color(1.0, 0.55, 0.3, a), 3.0)
				ci.draw_polyline(pts, Color(1.0, 0.85, 0.5, a * 0.8), 1.2)
			if hsh % 13 == 0:
				ci.draw_circle(r.position + Vector2(40, 40), 5, Color("8a7a74"))
		"glints":
			if hsh % 5 == 0:
				var gp := r.position + Vector2(10 + hsh % 44, 10 + (hsh / 45) % 44)
				var a2 := maxf(0.0, sin(t * 2.0 + hsh))
				ci.draw_colored_polygon(PackedVector2Array([gp + Vector2(0, -5), gp + Vector2(2, 0), gp + Vector2(0, 5), gp + Vector2(-2, 0)]), Color(1, 1, 1, a2))
		"leaves":
			if hsh % 6 == 0:
				ci.draw_circle(r.position + Vector2(14 + hsh % 36, 20 + (hsh / 37) % 30), 3, (b["tc"][hsh % 3] as Color))
		"flowers":
			if hsh % 13 == 0:
				ci.draw_circle(r.position + Vector2(36, 24), 7, (b["g1"] as Color).darkened(0.06))


## 풀잎·꽃(바람에 나부낀다). 조각 그림에서는 따로 한 겹(grass)으로 그리고, 흔들림은 셰이더가 한다.
func _grass(ci: CanvasItem, r: Rect2, x: int, y: int, b: Dictionary, t: float, hsh: int) -> void:
	var gc: Color = b["grass_c"]
	var deco := String(b.get("deco", ""))
	if gc.a > 0.0:  # 바람에 나부끼는 풀잎
		var n := 3 if deco == "tallgrass" or deco == "ferns" else 2
		var hgt := 16.0 if deco == "tallgrass" else 10.0
		for k in n:
			var hh := _h(x * 7 + k, y * 3 + k)
			var bp := r.position + Vector2(6 + hh % 52, 14 + (hh / 53) % 44)
			var sw := sway(bp.x, bp.y, t, float(hh % 7))
			var tip := bp + Vector2(sw, -hgt - hh % 6)
			ci.draw_line(bp, tip, gc, 2.2)
			ci.draw_line(bp + Vector2(4, 0), tip + Vector2(5, 4), gc.lightened(0.15), 1.8)
			if deco == "ferns" and k == 0:
				for j in 3:
					ci.draw_line(bp.lerp(tip, 0.3 + j * 0.25), bp.lerp(tip, 0.3 + j * 0.25) + Vector2(-6 + sw * 0.3, -3), gc.darkened(0.1), 1.6)
	var fl: Array = b["fl"]
	if not fl.is_empty() and hsh % 9 == 0 and deco != "cracks" and deco != "snow" and deco != "dunes":
		var fp := r.position + Vector2(10 + hsh % 40, 12 + (hsh / 41) % 36)
		var sw2 := sway(fp.x, fp.y, t, 1.0) * 0.35
		var fc: Color = fl[hsh % fl.size()]
		ci.draw_line(fp + Vector2(0, 8), fp + Vector2(sw2, 0), (gc if gc.a > 0 else Color("8fbf7a")).darkened(0.1), 1.6)
		for a in 5:
			ci.draw_circle(fp + Vector2(sw2, 0) + Vector2.from_angle(a * TAU / 5 + t * 0.2) * 3.2, 2.4, fc)
		ci.draw_circle(fp + Vector2(sw2, 0), 1.8, Color("f2cf4a"))

## 물(멈춘 부분): 깊을수록 진하게. 용암은 주황빛. 움직이는 부분은 _water_live.
func _water(ci: CanvasItem, r: Rect2, x: int, y: int, b: Dictionary, t: float, hsh: int) -> void:
	var dp := float(_deep[y * map.w + x]) if map.ch(Vector2i(x, y)) in ["~", "w"] else 1.0
	var col := (b["w0"] as Color).lerp(b["w1"], minf(0.75, (dp - 1.0) / 5.0) + (hsh % 10) / 200.0)
	if b.get("lava", false):
		col = col.lerp(Color("ffc27a"), 0.25)
	ci.draw_rect(r, col)


## 물(움직이는 부분, 매 프레임): 찰랑이는 물결과 반짝임. 용암은 숨 쉬는 빛, 떠다니는 껍질, 부글부글.
func _water_live(ci: CanvasItem, r: Rect2, x: int, y: int, b: Dictionary, t: float, hsh: int) -> void:
	var ts := r.size.x
	if b.get("lava", false):
		ci.draw_rect(r, Color(1.0, 0.76, 0.48, 0.25 * (0.5 + 0.5 * sin(t * 1.6 + x * 0.4 + y * 0.3))))
		if hsh % 3 == 0:  # 식은 껍질이 떠다닌다
			var cp := r.position + Vector2(fposmod(hsh % 40 + t * 6.0, ts), 20 + (hsh / 7) % 30)
			ci.draw_circle(cp, 9, Color("b06a4a"))
		var ph := fposmod(t * 0.8 + (hsh % 100) / 37.0, 1.0)  # 부글부글
		if hsh % 4 == 0:
			ci.draw_arc(r.position + Vector2(16 + hsh % 30, 16 + (hsh / 31) % 30), 2 + ph * 7, 0, TAU, 12, Color(1, 0.95, 0.7, 1.0 - ph), 2)
		return
	for k in 2:  # 찰랑이는 물결(두 줄, 옆으로 흐른다)
		var hh := _h(x + k * 31, y * 2 + k)
		var px := fposmod(hh % 64 + t * (10.0 + k * 6.0), ts + 30.0) - 15.0
		var py := r.position.y + 14 + k * 26 + hh % 8
		var wy := sin(t * 2.0 + hh) * 2.0
		ci.draw_arc(Vector2(r.position.x + px, py + wy + 8), 9, PI * 1.15, PI * 1.85, 8, Color(1, 1, 1, 0.45), 2)
	if (hsh + int(t * 1.5)) % 11 == 0:  # 반짝임
		var sp := r.position + Vector2(10 + hsh % 44, 10 + (hsh / 45) % 44)
		var a := 1.0 - fposmod(t * 1.5, 1.0)
		ci.draw_line(sp - Vector2(4, 0), sp + Vector2(4, 0), Color(1, 1, 1, a), 2)
		ci.draw_line(sp - Vector2(0, 4), sp + Vector2(0, 4), Color(1, 1, 1, a), 2)


## 산: 산줄기 안쪽일수록 크고 높은 봉우리를 겹쳐 그린다(밝은 면·그늘 면). 꼭대기는 눈(snow), 불(lava), 없음(none).
func _mountain(ci: CanvasItem, o: Vector2, x: int, y: int, ts: float, t: float, mouth: bool) -> void:
	var b := biome_at(Vector2i(x, y))
	var hgt := int(_mtn[y * map.w + x])
	var hsh := _h(x, y)
	if hgt >= 3 and (x + y) % 2 == 1 and not mouth:
		return  # 안쪽은 큰 봉우리가 덮는다
	var hf := float(mini(hgt, 5))
	var base := o + Vector2(x + 0.5, y + 1.0) * ts + Vector2((hsh % 17) - 8, 4)
	var w := ts * (1.0 + 0.42 * hf) * (0.9 + (hsh % 20) / 100.0)
	var ht := ts * (0.75 + 0.55 * hf) * (0.9 + ((hsh >> 3) % 25) / 100.0)
	var apex := base + Vector2(((hsh >> 5) % 15) - 7, -ht)
	var left := base + Vector2(-w / 2, 0)
	var right := base + Vector2(w / 2, 0)
	var mid := base + Vector2((apex.x - base.x) * 0.3 + 4, 0)
	var light: Color = b["m0"]
	var dark: Color = b["m1"]
	var desert := String(b["name"]) == "desert"
	if desert:  # 사막: 꼭대기가 평평한 붉은 바위 언덕(메사)과 층 무늬
		var tw := w * 0.28
		var p := PackedVector2Array([left, apex + Vector2(-tw, ht * 0.15), apex + Vector2(tw, ht * 0.15), right])
		ci.draw_colored_polygon(p, light)
		ci.draw_colored_polygon(PackedVector2Array([apex + Vector2(tw * 0.2, ht * 0.15), apex + Vector2(tw, ht * 0.15), right, mid]), dark)
		for k in 3:
			var f := 0.35 + k * 0.2
			ci.draw_line(left.lerp(apex + Vector2(-tw, ht * 0.15), 1.0 - f), right.lerp(apex + Vector2(tw, ht * 0.15), 1.0 - f), light.darkened(0.12), 2)
	else:
		# 비탈을 살짝 부풀려 둥근 산(동화풍)
		var lp := PackedVector2Array([left])
		var rp := PackedVector2Array([mid])
		for k in range(1, 6):
			var f := k / 6.0
			lp.append(left.lerp(apex, f) + Vector2(-w * 0.06, -ht * 0.05) * sin(f * PI))
		lp.append(apex)
		lp.append(mid)
		rp.append(apex)
		for k in range(1, 6):
			var f := k / 6.0
			rp.append(apex.lerp(right, f) + Vector2(w * 0.06, -ht * 0.05) * sin(f * PI))
		rp.append(right)
		ci.draw_colored_polygon(lp, light)
		ci.draw_colored_polygon(rp, dark)
		if hsh % 3 == 0:  # 산자락 바위
			ci.draw_circle(base + Vector2(-w * 0.3, -4), 5, dark.darkened(0.1))
		ci.draw_line(apex, mid, light.lightened(0.15), 1.5)
		var cap := String(b["cap"])
		if cap == "snow" and hgt >= 2:
			var k := 0.3 if hgt >= 3 else 0.2
			var sl := apex.lerp(left, k)
			var sr := apex.lerp(right, k)
			var snow := PackedVector2Array([apex, sr, sl.lerp(sr, 0.75) + Vector2(0, 6), sl.lerp(sr, 0.5), sl.lerp(sr, 0.25) + Vector2(0, 6), sl])
			ci.draw_colored_polygon(snow, Color("fbfcff"))
			ci.draw_colored_polygon(PackedVector2Array([apex, sr, sl.lerp(sr, 0.75) + Vector2(0, 6), apex.lerp(base, k * 0.6)]), Color("e4ebf5"))
		elif cap == "lava" and hgt >= 3:  # 화산: 빛나는 입과 피어오르는 연기
			var glow := 0.6 + 0.4 * sin(t * 2.0 + hsh)
			ci.draw_colored_polygon(PackedVector2Array([apex + Vector2(-10, 4), apex + Vector2(10, 4), apex + Vector2(6, 14), apex + Vector2(-6, 14)]), Color(1.0, 0.55, 0.3, glow))
			ci.draw_line(apex + Vector2(-2, 10), apex.lerp(left, 0.45), Color(1.0, 0.6, 0.35, glow * 0.8), 3)
			for k2 in 3:
				var ph := fposmod(t * 0.25 + k2 / 3.0 + (hsh % 10) / 10.0, 1.0)
				ci.draw_circle(apex + Vector2(sin(ph * 6.0 + k2) * 8, -ph * 70), 7 + ph * 12, Color(0.75, 0.7, 0.72, 0.5 * (1.0 - ph)))
	if mouth:  # 동굴 입구
		var mc := base + Vector2(0, -ts * 0.35)
		ci.draw_circle(mc, ts * 0.32, Color("2a2328"))
		ci.draw_rect(Rect2(mc + Vector2(-ts * 0.32, 0), Vector2(ts * 0.64, ts * 0.33)), Color("2a2328"))


## 숲: 한 칸에 나무 한두 그루, 숲 안쪽일수록 크다. 바람에 흔들린다(선인장·수정은 안 흔들린다).
func _trees(ci: CanvasItem, o: Vector2, x: int, y: int, ts: float, t: float) -> void:
	var b := biome_at(Vector2i(x, y))
	var hsh := _h(x, y)
	var depth := float(_wood[y * map.w + x])
	var kind := String(b["tree"]["kind"])
	var cols: Array = b["tc"]
	var n := 1 if hsh % 3 == 0 else 2
	for k in n:
		var hh := _h(x * 5 + k, y * 11 + k)
		var base := o + Vector2(x, y) * ts + Vector2(14 + hh % 36, ts - 6 - (hh / 37) % 14)
		var s := (0.75 + 0.12 * minf(depth, 3.0)) * (0.85 + (hh % 30) / 100.0)
		var sw := sway(base.x, base.y, t, float(hh % 9)) * (0.8 + 0.2 * s)
		var col: Color = cols[hh % cols.size()]
		ci.draw_circle(base + Vector2(4, 2), 14 * s, Color(0, 0, 0, 0.07))
		match kind:
			"pine":
				ci.draw_rect(Rect2(base + Vector2(-3, -8), Vector2(6, 10)), Color("7a5a3a"))
				for j in 3:
					var wj := (22.0 - j * 5.0) * s
					var yj := -8.0 - j * 13.0 * s
					var top := base + Vector2(sw * (0.3 + j * 0.3), yj - 18 * s)
					ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-wj, yj), top, base + Vector2(wj, yj)]), col.darkened(j * 0.04))
					if String(b["name"]) == "snow":
						ci.draw_colored_polygon(PackedVector2Array([top, top.lerp(base + Vector2(wj, yj), 0.35), top.lerp(base + Vector2(-wj, yj), 0.35)]), Color("fbfcff"))
			"palm":
				var top := base + Vector2(sw * 1.4 + 8 * s, -44 * s)
				ci.draw_polyline(PackedVector2Array([base, base.lerp(top, 0.5) + Vector2(-4, 0), top]), Color("b98c5a"), 5 * s)
				for j in 5:
					var a := -PI / 2 + (j - 2) * 0.62 + sin(t * 2.0 + hh) * 0.08
					var tip := top + Vector2.from_angle(a) * 26 * s + Vector2(sw * 0.6, 10)
					ci.draw_polyline(PackedVector2Array([top, top.lerp(tip, 0.5) + Vector2(0, -6), tip]), col, 5 * s)
				ci.draw_circle(top + Vector2(0, 3), 3.5 * s, Color("8b6640"))
			"cactus":
				var cc := col
				ci.draw_rect(Rect2(base + Vector2(-6 * s, -34 * s), Vector2(12 * s, 34 * s)), cc)
				ci.draw_circle(base + Vector2(0, -34 * s), 6 * s, cc)
				ci.draw_rect(Rect2(base + Vector2(-16 * s, -24 * s), Vector2(6 * s, 12 * s)), cc)
				ci.draw_circle(base + Vector2(-13 * s, -24 * s), 3 * s, cc)
				ci.draw_rect(Rect2(base + Vector2(6 * s, -18 * s), Vector2(10 * s, 5 * s)), cc)
				ci.draw_rect(Rect2(base + Vector2(11 * s, -28 * s), Vector2(5 * s, 14 * s)), cc)
				ci.draw_line(base + Vector2(-2 * s, -30 * s), base + Vector2(-2 * s, -4 * s), cc.lightened(0.2), 1.5)
				if hh % 4 == 0:
					ci.draw_circle(base + Vector2(0, -40 * s), 3.5 * s, Color("f2b5d4"))
			"dead":
				ci.draw_line(base, base + Vector2(sw * 0.2, -34 * s), col, 5 * s)
				ci.draw_line(base + Vector2(0, -18 * s), base + Vector2(-14 * s, -30 * s), col, 3 * s)
				ci.draw_line(base + Vector2(0, -24 * s), base + Vector2(12 * s, -36 * s), col, 3 * s)
				if hh % 3 == 0:
					ci.draw_circle(base + Vector2(12 * s, -36 * s), 2.5, Color(1, 0.6, 0.3, 0.5 + 0.5 * sin(t * 3.0 + hh)))
			"crystal":
				for j in 3:
					var a := -PI / 2 + (j - 1) * 0.45
					var tip := base + Vector2.from_angle(a) * (26 + j * 6) * s
					var side := Vector2.from_angle(a + PI / 2) * 6 * s
					var cj: Color = cols[(hh + j) % cols.size()]
					ci.draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), cj)
					ci.draw_line(base, tip, cj.lightened(0.35), 1.5)
				var tw := maxf(0.0, sin(t * 2.5 + hh))
				ci.draw_circle(base + Vector2(0, -32 * s), 2.5 * tw + 0.5, Color(1, 1, 1, tw))
			"jungle":
				ci.draw_rect(Rect2(base + Vector2(-4, -20 * s), Vector2(8, 22 * s)), Color("7a5a3a"))
				var top := base + Vector2(sw, -30 * s)
				for j in 4:
					var a := PI + j * PI / 3 + sin(t * 1.8 + hh + j) * 0.12
					var lp := top + Vector2.from_angle(a) * 4
					var tip := top + Vector2.from_angle(a) * 24 * s + Vector2(sw * 0.5, 6)
					ci.draw_colored_polygon(PackedVector2Array([lp, lp.lerp(tip, 0.5) + Vector2.from_angle(a + 1.4) * 8 * s, tip, lp.lerp(tip, 0.5) + Vector2.from_angle(a - 1.4) * 8 * s]), col.darkened(0.05 * j))
				ci.draw_circle(top, 14 * s, col)
				ci.draw_circle(top + Vector2(-4, -4), 6 * s, col.lightened(0.15))
				if hh % 5 == 0:
					ci.draw_line(top + Vector2(10 * s, 4), top + Vector2(12 * s + sw * 0.3, 26 * s), Color("4f8a4a"), 1.5)
			"acacia":
				ci.draw_line(base, base + Vector2(sw * 0.2, -26 * s), Color("8b6640"), 5 * s)
				var top := base + Vector2(sw, -32 * s)
				ci.draw_set_transform(top, 0.0, Vector2(1.0, 0.42))
				ci.draw_circle(Vector2.ZERO, 26 * s, col)
				ci.draw_circle(Vector2(-6, -10), 14 * s, col.lightened(0.12))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:  # round
				ci.draw_rect(Rect2(base + Vector2(-4 * s, -16 * s), Vector2(8 * s, 18 * s)), Color("8b6640"))
				var top := base + Vector2(sw, -28 * s)
				ci.draw_circle(top + Vector2(-9 * s, 4 * s), 12 * s, col.darkened(0.08))
				ci.draw_circle(top + Vector2(9 * s, 4 * s), 12 * s, col.darkened(0.08))
				ci.draw_circle(top, 15 * s, col)
				ci.draw_circle(top + Vector2(-5 * s, -6 * s), 6 * s, col.lightened(0.18))
				if String(b["name"]) == "autumn" and hh % 4 == 0:  # 떨어지는 잎
					var ph := fposmod(t * 0.4 + (hh % 10) / 10.0, 1.0)
					ci.draw_circle(top + Vector2(10 + sin(ph * 8.0) * 6, ph * 30), 2.5, col.lightened(0.1))
