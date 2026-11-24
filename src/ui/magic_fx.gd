class_name MagicFx
extends Control
## 전투 마법 이펙트(data/magic_fx.json의 style). 놓인 자리(position)를 가운데로 그리고, 다 그리면 스스로 사라진다.
## 그림(Art "fx/magic_<id>")이 있으면 그림을 쓴다.

const LIFE := 0.9

var style := "drop"
var col := Color.WHITE
var id := ""
var _t := 0.0

static var _defs: Dictionary = {}


static func def_of(magic_id: String) -> Dictionary:
	if _defs.is_empty():
		_defs = JsonFile.read("res://data/magic_fx.json")["fx"]
	return _defs.get(magic_id, {"style": "sparkle", "color": "f5c542"})


## 마법 종류(battle_magic.json kind)에 따라 놓일 자리: 공격 → 적 카드 위, 방어 → 아군 카드 위, 효과·순서 → 가운데.
## a, b = 아군·적 카드의 화면 사각형. 돌려주는 값은 마법 카드의 가운데(카드 위쪽 가장자리 근처).
static func anchor(kind: String, a: Rect2, b: Rect2) -> Vector2:
	var top := minf(a.position.y, b.position.y)
	match kind:
		"attack":
			return Vector2(b.get_center().x, b.position.y + b.size.y * 0.3)
		"defense":
			return Vector2(a.get_center().x, a.position.y + a.size.y * 0.3)
	return Vector2((a.get_center().x + b.get_center().x) / 2.0, top + (a.size.y + b.size.y) * 0.15)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 14


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= LIFE:
		queue_free()


func _draw() -> void:
	var k := clampf(_t / LIFE, 0.0, 1.0)
	var a := 1.0 - k * k
	var c := Color(col, a)
	if Art.draw(self, "fx", "magic_" + id, Vector2.ZERO, Vector2(220, 220) * (0.8 + 0.4 * k), Color(1, 1, 1, a)):
		return
	match style:
		"drop":  # 위에서 내리꽂히는 화살 셋
			for i in 3:
				var x := (i - 1) * 46.0
				var y := lerpf(-170.0, 40.0, clampf(k * 1.6 - i * 0.15, 0.0, 1.0))
				_arrow(Vector2(x, y - 60), Vector2(x, y), c, 7.0)
			if k > 0.5:
				draw_arc(Vector2(0, 50), lerpf(20, 110, (k - 0.5) * 2.0), PI, TAU, 24, c, 5)
		"cross":  # X자로 긋기
			var s1 := clampf(k * 2.0, 0.0, 1.0)
			var s2 := clampf(k * 2.0 - 0.5, 0.0, 1.0)
			draw_line(Vector2(-90, -90), Vector2(-90, -90).lerp(Vector2(90, 90), s1), c, 12)
			draw_line(Vector2(90, -90), Vector2(90, -90).lerp(Vector2(-90, 90), s2), c, 12)
		"fade":  # 오그라드는 고리들
			for i in 3:
				draw_arc(Vector2.ZERO, lerpf(130, 10, fmod(k + i / 3.0, 1.0)), 0, TAU, 40, c, 5)
		"push":  # 되밀어내는 반원 충격파
			for i in 3:
				var r := lerpf(20, 160, clampf(k * 1.3 - i * 0.15, 0.0, 1.0))
				draw_arc(Vector2(-60, 0), r, -PI / 3.0, PI / 3.0, 20, c, 8 - i * 2)
		"ring":  # 둥근 방패
			var r := lerpf(40, 110, minf(1.0, k * 2.0))
			draw_circle(Vector2.ZERO, r, Color(col, a * 0.25))
			draw_arc(Vector2.ZERO, r, 0, TAU, 48, c, 7)
			draw_arc(Vector2.ZERO, r * 0.75, k * TAU, k * TAU + PI, 24, c, 4)
		"spin":  # 도는 화살표 둘
			for i in 2:
				var st := k * TAU * 1.5 + i * PI
				draw_arc(Vector2.ZERO, 90, st, st + PI * 0.7, 20, c, 7)
				var tip := Vector2.from_angle(st + PI * 0.7) * 90
				draw_circle(tip, 10, c)
		"converge":  # 모여드는 빛 알갱이
			for i in 12:
				var ang := TAU * i / 12.0
				draw_circle(Vector2.from_angle(ang) * lerpf(150, 20, k), 8 * (1.0 - k * 0.5), c)
			if k > 0.6:
				draw_arc(Vector2.ZERO, 80, 0, TAU, 40, c, 6)
		"rise":  # 밑에서 올라오는 물결
			for i in 3:
				var y := lerpf(110, -60, clampf(k * 1.4 - i * 0.12, 0.0, 1.0))
				var pts := PackedVector2Array()
				for x in 13:
					pts.append(Vector2(-120 + x * 20, y + sin(x * 0.9 + k * 8.0) * 10))
				draw_polyline(pts, c, 6)
		"flash":  # 앞으로 번쩍이는 빛줄기
			for i in 8:
				var ang := TAU * i / 8.0 + k
				draw_line(Vector2.from_angle(ang) * 20, Vector2.from_angle(ang) * lerpf(40, 150, k), c, 6)
			draw_circle(Vector2.ZERO, 30 * (1.0 - k) + 10, c)
		"wall":  # 가운데 벽
			var h := lerpf(0, 200, minf(1.0, k * 2.5))
			draw_rect(Rect2(-18, 100 - h, 36, h), Color(col, a * 0.8))
			for j in int(h / 30.0):
				draw_line(Vector2(-18, 100 - j * 30), Vector2(18, 100 - j * 30), Color(UiKit.INK, a * 0.5), 2)
		"sparkle":  # 빨려 드는 금빛 반짝이
			for i in 10:
				var ang := TAU * i / 10.0 + k * 3.0
				_star(Vector2.from_angle(ang) * lerpf(140, 10, k), 12 * (1.0 - k * 0.6), c)
		"shatter":  # 흩어지는 조각
			for i in 10:
				var ang := TAU * i / 10.0
				var p := Vector2.from_angle(ang) * lerpf(10, 160, k)
				draw_colored_polygon(PackedVector2Array([p, p + Vector2.from_angle(ang + 1.0) * 22, p + Vector2.from_angle(ang - 0.8) * 16]), c)
		"swap":  # 양쪽으로 갈라지는 화살표
			var d := lerpf(10, 120, k)
			_arrow(Vector2(-10, -20), Vector2(-d - 10, -20), c, 8)
			_arrow(Vector2(10, 20), Vector2(d + 10, 20), c, 8)
		"forward":  # 앞으로 달리는 겹화살표
			for i in 3:
				var x := lerpf(-120, 120, clampf(k * 1.3 - i * 0.15, 0.0, 1.0))
				draw_polyline(PackedVector2Array([Vector2(x - 30, -40), Vector2(x, 0), Vector2(x - 30, 40)]), c, 9)
		_:
			draw_circle(Vector2.ZERO, lerpf(20, 120, k), Color(col, a * 0.4))


func _arrow(from: Vector2, to: Vector2, c: Color, w: float) -> void:
	draw_line(from, to, c, w)
	var d := (to - from).normalized()
	draw_colored_polygon(PackedVector2Array([to + d * 16, to + d.rotated(2.5) * 18, to + d.rotated(-2.5) * 18]), c)


func _star(p: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var ang := i * TAU / 8.0 - PI / 2.0
		pts.append(p + Vector2(cos(ang), sin(ang)) * (r if i % 2 == 0 else r * 0.4))
	draw_colored_polygon(pts, c)
