class_name MobArt
extends RefCounted
## 필드 몹 몸 모양(속성마다, data/balance/mob_attrs.json shape. 사용자 의견: 모양도 속성마다 다르게).
## 몸 색은 속성 색(MinigameScreen.attr_color). 그림 파일 enemy/attr_NN.png가 있으면 그것이 먼저(field_screen).


static func points(shape: String, p: Vector2, r: float, t: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		"triangle": return _ngon(p + Vector2(0, 3), r * 1.15, 3, -PI / 2.0)
		"square": return _ngon(p, r * 1.2, 4, PI / 4.0)
		"diamond": return _ngon(p, r * 1.15, 4, 0.0)
		"pentagon": return _ngon(p, r * 1.1, 5, -PI / 2.0)
		"hexagon": return _ngon(p, r * 1.05, 6, 0.0)
		"star4": return _star(p, r * 1.25, r * 0.55, 4, t)
		"star5": return _star(p, r * 1.2, r * 0.6, 5, -PI / 2.0)
		"star6": return _star(p, r * 1.15, r * 0.7, 6, t * 0.5)
		"spike": return _star(p, r * 1.2, r * 0.82, 12, 0.0)
		"gear": return _star(p, r * 1.12, r * 0.9, 16, t * 0.8)
		"cross":
			var a := r * 0.42
			var b := r * 1.05
			for v in [Vector2(-a, -b), Vector2(a, -b), Vector2(a, -a), Vector2(b, -a), Vector2(b, a), Vector2(a, a), Vector2(a, b), Vector2(-a, b), Vector2(-a, a), Vector2(-b, a), Vector2(-b, -a), Vector2(-a, -a)]:
				pts.append(p + v)
			return pts
		"kite":
			for v in [Vector2(0, -r * 1.25), Vector2(r * 0.85, -r * 0.1), Vector2(0, r * 1.05), Vector2(-r * 0.85, -r * 0.1)]:
				pts.append(p + v)
			return pts
		"capsule":
			for k in 24:
				var a := TAU * k / 24.0
				var c := Vector2(cos(a), sin(a))
				pts.append(p + Vector2(c.x * r * 0.75, c.y * r * 0.75 + signf(c.y) * r * 0.35))
			return pts
		"heart":
			for k in 32:
				var a := TAU * k / 32.0
				var x := 16.0 * pow(sin(a), 3)
				var y := -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))
				pts.append(p + Vector2(x, y) * r / 15.0)
			return pts
		"flower", "bush":
			var lobes := 5 if shape == "flower" else 9
			for k in 40:
				var a := TAU * k / 40.0
				pts.append(p + Vector2.from_angle(a) * r * (1.0 + (0.22 if shape == "flower" else 0.1) * cos(a * lobes)))
			return pts
		"ghost":
			for k in 13:
				var a := PI + PI * k / 12.0
				pts.append(p + Vector2(cos(a), sin(a)) * r + Vector2(0, -2))
			for k in 7:  # 물결 치는 아랫자락
				var x := r - 2.0 * r * k / 6.0
				pts.append(p + Vector2(x, r * 0.9 + (6.0 if k % 2 == 0 else 0.0) + sin(t * 4.0 + k) * 2.0))
			return pts
		"crescent":
			for k in 20:
				var a := -PI * 0.85 + PI * 1.7 * k / 19.0
				pts.append(p + Vector2.from_angle(a + PI / 2.0) * r * 1.1)
			for k in 20:
				var a := PI * 0.75 - PI * 1.5 * k / 19.0
				pts.append(p + Vector2(r * 0.45, 0) + Vector2.from_angle(a + PI / 2.0) * r * 0.75)
			return pts
		"coin":
			return _ngon(p, r, 28, 0.0)
		_:  # drop(파동): 물방울
			for k in 28:
				var a := TAU * k / 28.0
				var c := Vector2(cos(a), sin(a))
				pts.append(p + Vector2(c.x * r, c.y * r) + Vector2(0, -r * 0.55 * maxf(0.0, -c.y) * (1.0 - absf(c.x))))
			return pts


static func _ngon(p: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		pts.append(p + Vector2.from_angle(rot + TAU * k / n) * r)
	return pts


static func _star(p: Vector2, r1: float, r2: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n * 2:
		pts.append(p + Vector2.from_angle(rot + PI * k / n) * (r1 if k % 2 == 0 else r2))
	return pts


static func draw(ci: CanvasItem, shape: String, p: Vector2, r: float, col: Color, ink: Color) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pts := points(shape, p, r, t)
	if Geometry2D.triangulate_polygon(pts).is_empty():
		ci.draw_circle(p, r, col)
	else:
		ci.draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, ink, 3.0, true)
	if shape == "coin":
		ci.draw_arc(p, r * 0.72, 0, TAU, 28, Color(1, 1, 1, 0.6), 2.0)
