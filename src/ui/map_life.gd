class_name MapLife
extends RefCounted
## 지도의 살아 있는 것(표현 층, 사용자 의견): 화면 둘레를 뛰어다니는 작은 동물과 바람에 날리는 것.
## 동물은 지역 풍경(data/map/biomes.json critters)에서 고르고, 주인공이 가까이 오면 달아난다. 막지도 않고 싸우지도 않는다(장식).
## 날리는 것(particle)은 화면 안에서 돈다: 꽃잎·씨앗·낙엽·모래·눈·불씨·반딧불이·반짝이.

var painter: MapPainter
var critters: Array[Dictionary] = []  ## {kind, pos, vel, t, hop, flee}
var parts: Array[Dictionary] = []  ## {pos(화면 좌표), vel, t, life, kind}
var _rng := RandomNumberGenerator.new()
var _n_critters := 7
var _n_parts := 34
var _flee := 170.0
var _kind := ""


func _init(p: MapPainter) -> void:
	painter = p
	_rng.randomize()
	var life: Dictionary = p.cfg.get("life", {})
	_n_critters = int(life.get("critters", 7))
	_n_parts = int(life.get("particles", 34))
	_flee = float(life.get("flee", 170))


func update(delta: float, hero: Vector2, cam: Vector2, view: Vector2, t: float) -> void:
	var m := painter.map
	var area := Rect2(cam - Vector2(160, 160), view + Vector2(320, 320))
	# 동물
	for c in critters.duplicate():
		if not area.has_point(c["pos"]):
			critters.erase(c)
	while critters.size() < _n_critters:
		var c := _spawn(area, hero)
		if c.is_empty():
			break
		critters.append(c)
	for c in critters:
		_move(c, delta, hero, t)
	# 날리는 것: 지금 화면 가운데 지역의 것
	var b := painter.biome_at(m.cell(cam + view / 2))
	var kind := String(b.get("particle", ""))
	if kind != _kind:
		_kind = kind
		parts.clear()
	if kind == "":
		return
	while parts.size() < _n_parts:
		parts.append(_part(kind, view, true))
	for p in parts:
		p["t"] = float(p["t"]) + delta
		var w := painter.wind(cam.x + (p["pos"] as Vector2).x, cam.y + (p["pos"] as Vector2).y, t)
		var v: Vector2 = p["vel"]
		if kind in ["petal", "leaf", "seed", "sand", "snow"]:
			v = v + Vector2(w * 60.0, 0)
		p["pos"] = (p["pos"] as Vector2) + v * delta + Vector2(sin(float(p["t"]) * 2.0 + float(p["ph"])) * 12.0 * delta, 0)
		var pp: Vector2 = p["pos"]
		if float(p["t"]) > float(p["life"]) or pp.x < -40 or pp.x > view.x + 40 or pp.y < -60 or pp.y > view.y + 60:
			var np := _part(kind, view, false)
			p.merge(np, true)


func _spawn(area: Rect2, hero: Vector2) -> Dictionary:
	var m := painter.map
	for k in 12:
		var p := area.position + Vector2(_rng.randf() * area.size.x, _rng.randf() * area.size.y)
		var c := m.cell(p)
		if m.ch(c) != "." or m.is_town(p) or p.distance_to(hero) < 240:
			continue
		var b := painter.biome_at(c)
		var list: Array = b.get("critters", [])
		if list.is_empty():
			continue
		var kind := String(list[_rng.randi_range(0, list.size() - 1)])
		return {"kind": kind, "pos": p, "vel": Vector2.ZERO, "t": _rng.randf() * 3.0, "hop": 0.0, "flee": 0.0, "face": 1.0, "ph": _rng.randf() * TAU}
	return {}


func _move(c: Dictionary, delta: float, hero: Vector2, t: float) -> void:
	var m := painter.map
	var kind := String(c["kind"])
	c["t"] = float(c["t"]) - delta
	var p: Vector2 = c["pos"]
	var flying := kind in ["bird", "butterfly", "parrot"]
	if p.distance_to(hero) < _flee:  # 달아난다
		c["vel"] = (p - hero).normalized() * (260.0 if flying else 220.0)
		c["flee"] = 0.8
		c["t"] = 0.6
	elif float(c["t"]) <= 0.0:
		c["t"] = _rng.randf_range(0.8, 2.6)
		if _rng.randf() < 0.45 and not flying:
			c["vel"] = Vector2.ZERO  # 잠깐 멈춰 두리번
		else:
			c["vel"] = Vector2.from_angle(_rng.randf() * TAU) * (_rng.randf_range(40, 90) if not flying else _rng.randf_range(50, 110))
	c["flee"] = maxf(0.0, float(c["flee"]) - delta)
	var v: Vector2 = c["vel"]
	if absf(v.x) > 1.0:
		c["face"] = signf(v.x)
	var np := p + v * delta
	if flying or (m.ch(m.cell(np)) == "." and not m.is_town(np)):
		c["pos"] = np
	else:
		c["vel"] = -v
	if v.length() > 1.0 and not flying:
		c["hop"] = absf(sin(t * (14.0 if float(c["flee"]) > 0.0 else 9.0) + float(c["ph"])))
	else:
		c["hop"] = 0.0


func _part(kind: String, view: Vector2, anywhere: bool) -> Dictionary:
	var pos := Vector2(_rng.randf() * view.x, _rng.randf() * view.y)
	var vel := Vector2.ZERO
	match kind:
		"snow":
			vel = Vector2(_rng.randf_range(-10, 10), _rng.randf_range(40, 80))
			if not anywhere:
				pos.y = -20
		"ember":
			vel = Vector2(_rng.randf_range(-12, 12), -_rng.randf_range(30, 70))
			if not anywhere:
				pos.y = view.y + 20
		"petal", "leaf", "seed":
			vel = Vector2(_rng.randf_range(10, 40), _rng.randf_range(15, 40))
			if not anywhere:
				pos = Vector2(-20, _rng.randf() * view.y * 0.8)
		"sand":
			vel = Vector2(_rng.randf_range(160, 260), _rng.randf_range(-10, 10))
			if not anywhere:
				pos.x = -30
		"firefly", "sparkle":
			vel = Vector2(_rng.randf_range(-15, 15), _rng.randf_range(-15, 15))
	return {"pos": pos, "vel": vel, "t": 0.0, "life": _rng.randf_range(4.0, 9.0), "kind": kind, "ph": _rng.randf() * TAU,
		"size": _rng.randf_range(0.7, 1.3)}


## 땅의 동물(그림자 포함). 지도 그리기 다음, 인물 앞에 부른다.
func draw_critters(ci: CanvasItem, o: Vector2, t: float) -> void:
	for c in critters:
		var p: Vector2 = o + c["pos"]
		var kind := String(c["kind"])
		var f := float(c["face"])
		var up := float(c["hop"]) * 7.0
		ci.draw_circle(p + Vector2(0, 8), 7, Color(0, 0, 0, 0.08))
		match kind:
			"rabbit", "hare":
				var col := Color("ffffff") if kind == "hare" else Color("f3e6d6")
				var q := p - Vector2(0, up)
				ci.draw_circle(q, 7, col)
				ci.draw_circle(q + Vector2(6 * f, -5), 5, col)
				ci.draw_line(q + Vector2(5 * f, -9), q + Vector2(3 * f, -18), col, 3)
				ci.draw_line(q + Vector2(8 * f, -9), q + Vector2(9 * f, -17), col, 3)
				ci.draw_circle(q + Vector2(8 * f, -6), 1.2, UiKit.INK)
				ci.draw_circle(q + Vector2(-7 * f, 0), 2.5, Color.WHITE)
			"squirrel":
				var q := p - Vector2(0, up)
				ci.draw_circle(q, 6, Color("d08a5a"))
				ci.draw_circle(q + Vector2(5 * f, -5), 4.5, Color("d08a5a"))
				ci.draw_arc(q + Vector2(-8 * f, -6), 7, 0, TAU, 12, Color("c07a4a"), 4)
				ci.draw_circle(q + Vector2(7 * f, -6), 1.1, UiKit.INK)
			"deer":
				var q := p - Vector2(0, up * 0.6)
				ci.draw_rect(Rect2(q + Vector2(-9, -6), Vector2(18, 9)), Color("c9a074"))
				ci.draw_circle(q + Vector2(11 * f, -11), 5, Color("c9a074"))
				ci.draw_line(q + Vector2(-7, 3), q + Vector2(-7, 10), Color("a88058"), 2)
				ci.draw_line(q + Vector2(7, 3), q + Vector2(7, 10), Color("a88058"), 2)
				ci.draw_line(q + Vector2(11 * f, -15), q + Vector2(14 * f, -21), Color("8b6640"), 1.5)
			"fox":
				var q := p - Vector2(0, up * 0.6)
				ci.draw_circle(q, 7, Color("f0a35e"))
				ci.draw_circle(q + Vector2(7 * f, -5), 5, Color("f0a35e"))
				ci.draw_colored_polygon(PackedVector2Array([q + Vector2(5 * f, -9), q + Vector2(6 * f, -15), q + Vector2(9 * f, -9)]), Color("f0a35e"))
				ci.draw_line(q + Vector2(-6 * f, 0), q + Vector2(-16 * f, -6), Color("f0a35e"), 5)
				ci.draw_circle(q + Vector2(-16 * f, -6), 2.5, Color.WHITE)
			"lizard", "salamander":
				var col := Color("8fbf7a") if kind == "lizard" else Color("ff9a5c")
				var wig := sin(t * 12.0 + float(c["ph"])) * (3.0 if (c["vel"] as Vector2).length() > 1 else 0.0)
				ci.draw_polyline(PackedVector2Array([p + Vector2(-12 * f, wig), p + Vector2(-4 * f, -wig), p + Vector2(4 * f, wig * 0.5), p + Vector2(10 * f, 0)]), col, 4)
				ci.draw_circle(p + Vector2(10 * f, 0), 3, col)
				if kind == "salamander":
					ci.draw_circle(p + Vector2(10 * f, 0), 6, Color(1, 0.6, 0.3, 0.25))
			"crab":
				ci.draw_circle(p, 6, Color("ef8a5e"))
				ci.draw_line(p + Vector2(-6, 0), p + Vector2(-11, -5), Color("ef8a5e"), 2)
				ci.draw_line(p + Vector2(6, 0), p + Vector2(11, -5), Color("ef8a5e"), 2)
				ci.draw_circle(p + Vector2(-2, -5), 1.2, UiKit.INK)
				ci.draw_circle(p + Vector2(2, -5), 1.2, UiKit.INK)
			"frog":
				var q := p - Vector2(0, up)
				ci.draw_circle(q, 6, Color("7fc07a"))
				ci.draw_circle(q + Vector2(-3, -5), 2.5, Color("7fc07a"))
				ci.draw_circle(q + Vector2(3, -5), 2.5, Color("7fc07a"))
				ci.draw_circle(q + Vector2(-3, -5), 1, UiKit.INK)
				ci.draw_circle(q + Vector2(3, -5), 1, UiKit.INK)
			"butterfly":
				var flap := absf(sin(t * 14.0 + float(c["ph"])))
				var q := p - Vector2(0, 18 + sin(t * 3.0 + float(c["ph"])) * 4)
				var col2 := Color("f2b5d4") if int(float(c["ph"]) * 10) % 2 == 0 else Color("fff1a8")
				ci.draw_set_transform(q, 0.0, Vector2(maxf(0.15, flap), 1.0))
				ci.draw_circle(Vector2(-4, 0), 4, col2)
				ci.draw_circle(Vector2(4, 0), 4, col2)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				ci.draw_line(q + Vector2(0, -3), q + Vector2(0, 3), UiKit.INK, 1.5)
			"bird", "parrot":
				var flap := sin(t * 10.0 + float(c["ph"])) * 5
				var q := p - Vector2(0, 40)
				var col3 := Color("ffffff") if kind == "bird" else Color("ef6a5e")
				ci.draw_circle(p + Vector2(0, 10), 5, Color(0, 0, 0, 0.06))  # 땅의 그림자
				ci.draw_polyline(PackedVector2Array([q + Vector2(-10, flap), q, q + Vector2(10, flap)]), col3, 3)
				ci.draw_circle(q, 2.5, col3)
				if kind == "parrot":
					ci.draw_line(q, q + Vector2(-6 * f, 6), Color("5cc2b0"), 3)


## 날리는 것(화면 좌표). 지도 위 모든 것 다음에 부른다.
func draw_particles(ci: CanvasItem, t: float) -> void:
	for p in parts:
		var pos: Vector2 = p["pos"]
		var s := float(p["size"])
		var life := float(p["life"])
		var a := clampf(minf(float(p["t"]) * 2.0, (life - float(p["t"])) * 1.5), 0.0, 1.0)
		match String(p["kind"]):
			"snow":
				ci.draw_circle(pos, 2.6 * s, Color(1, 1, 1, 0.9 * a))
			"ember":
				ci.draw_circle(pos, 4 * s, Color(1, 0.55, 0.3, 0.25 * a))
				ci.draw_circle(pos, 1.8 * s, Color(1, 0.8, 0.5, 0.9 * a))
			"petal":
				ci.draw_set_transform(pos, t * 2.0 + float(p["ph"]), Vector2(1.0, 0.55))
				ci.draw_circle(Vector2.ZERO, 3.5 * s, Color(0.96, 0.7, 0.78, 0.85 * a))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"leaf":
				ci.draw_set_transform(pos, t * 1.5 + float(p["ph"]), Vector2(1.0, 0.5))
				ci.draw_circle(Vector2.ZERO, 4 * s, Color(0.91, 0.55, 0.38, 0.85 * a))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"seed":
				ci.draw_circle(pos, 1.6 * s, Color(1, 1, 1, 0.8 * a))
				for k in 4:
					ci.draw_line(pos, pos + Vector2.from_angle(k * PI / 2 + float(p["ph"])) * 4 * s, Color(1, 1, 1, 0.6 * a), 1)
			"sand":
				ci.draw_line(pos, pos + Vector2(-18 * s, 0), Color(0.93, 0.84, 0.62, 0.55 * a), 2)
			"firefly":
				var g := 0.5 + 0.5 * sin(t * 3.0 + float(p["ph"]))
				ci.draw_circle(pos, 5 * s, Color(1, 0.95, 0.5, 0.2 * g * a))
				ci.draw_circle(pos, 1.8 * s, Color(1, 1, 0.7, g * a))
			"sparkle":
				var g2 := maxf(0.0, sin(t * 2.5 + float(p["ph"])))
				ci.draw_line(pos - Vector2(4, 0) * s, pos + Vector2(4, 0) * s, Color(1, 1, 1, g2 * a), 1.5)
				ci.draw_line(pos - Vector2(0, 4) * s, pos + Vector2(0, 4) * s, Color(1, 1, 1, g2 * a), 1.5)
