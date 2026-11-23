class_name SlotIcon
extends Control
## 착용 부위 아이콘. 그림(assets/art/slot/<부위>.png)이 있으면 그것을, 없으면 선으로 그린다.

const SLOTS := ["weapon", "head", "chest", "hands", "feet"]

var slot := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	if Art.draw(self, "slot", slot, c, Vector2(s, s)):
		return
	var k := s / 24.0  # 24칸 기준으로 그린다
	var o := c - Vector2(12, 12) * k
	var ink := UiKit.INK
	var fill := Color(1, 1, 1, 0.85)
	var P := func(pts: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in pts:
			out.append(o + (p as Vector2) * k)
		return out
	match slot:
		"head":  # 투구
			var dome := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				dome.append(o + (Vector2(12, 15) + Vector2(cos(a), sin(a)) * 9.0) * k)
			_poly(dome, fill, ink)
			draw_line(o + Vector2(1, 16) * k, o + Vector2(23, 16) * k, ink, 2.0 * k)
			draw_line(o + Vector2(12, 6) * k, o + Vector2(12, 2) * k, ink, 2.0 * k)
		"chest":  # 갑옷 상의
			_poly(P.call([Vector2(7, 3), Vector2(10, 5), Vector2(14, 5), Vector2(17, 3), Vector2(22, 8), Vector2(19, 11),
				Vector2(18, 21), Vector2(6, 21), Vector2(5, 11), Vector2(2, 8)]), fill, ink)
		"hands":  # 장갑
			_poly(P.call([Vector2(6, 22), Vector2(6, 10), Vector2(8, 4), Vector2(10, 10), Vector2(11, 3), Vector2(13, 10),
				Vector2(14, 3), Vector2(16, 10), Vector2(17, 5), Vector2(19, 11), Vector2(22, 9), Vector2(18, 17), Vector2(18, 22)]), fill, ink)
		"feet":  # 장화
			_poly(P.call([Vector2(7, 2), Vector2(14, 2), Vector2(14, 14), Vector2(21, 16), Vector2(22, 21), Vector2(6, 21)]), fill, ink)
		"weapon":  # 검
			draw_line(o + Vector2(5, 19) * k, o + Vector2(19, 5) * k, ink, 3.0 * k)
			draw_line(o + Vector2(19, 5) * k, o + Vector2(21, 3) * k, ink, 2.0 * k)
			draw_line(o + Vector2(4, 14) * k, o + Vector2(10, 20) * k, ink, 2.5 * k)
			draw_line(o + Vector2(5, 19) * k, o + Vector2(2, 22) * k, ink, 3.5 * k)


func _poly(pts: PackedVector2Array, fill: Color, line: Color) -> void:
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, line, maxf(1.5, size.x / 14.0))
