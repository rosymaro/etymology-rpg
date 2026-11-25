class_name PalArt
extends RefCounted
## 필드에서 주인공을 따라다니는 유닛의 모습(07-fun 1절). 그림 파일(assets/art/pal/<번호>.png)이 있으면 그림을,
## 없으면 성격이 보이는 도형으로 그린다(00-overview: 계열 뜻이 곧 성격).

const COLORS := {
	1: Color("f0a35e"),  # 뚝딱: 앞치마와 망치
	2: Color("b98c5a"),  # 덥석: 커다란 두 손
	3: Color("a88bd6"),  # 힐끔: 큰 눈 하나, 수줍게 잎 뒤에
	4: Color("6f9fd8"),  # 척척: 동그란 안경과 책
	5: Color("f29bb8"),  # 조잘: 큰 입과 말풍선
	6: Color("8fd3f0"),  # 쌩: 앞으로 기운 물방울, 바람 줄
	7: Color("7fb77e"),  # 영차: 네모난 몸과 등짐
	8: Color("e0675a"),  # 대장: 깃발과 작은 왕관
	9: Color("f2cf4a"),  # 휙: 돌을 든 팔
	10: Color("5cc2b0"),  # 빙글: 몸의 소용돌이
	11: Color("9aa3ad"),  # 꿈쩍: 바위 같은 네모와 방패
	12: Color("b0453f"),  # 와장: 들쭉날쭉한 몸과 금
}
const R := 20.0


static func color(unit: int) -> Color:
	return COLORS.get(unit, Color("cccccc"))


static func draw(ci: CanvasItem, unit: int, p: Vector2, facing: Vector2) -> void:
	if Art.draw(ci, "pal", "%02d" % unit, p + Vector2(0, -6), Vector2(R * 3, R * 3.2)):
		return
	var c := color(unit)
	var ink := UiKit.INK
	var t := Time.get_ticks_msec() / 1000.0
	var bob := Vector2(0, sin(t * 6.0 + unit) * 2.0)
	p += bob
	var side := 1.0 if facing.x >= 0.0 else -1.0
	ci.draw_circle(p + Vector2(0, R * 0.9), R * 0.8, Color(0, 0, 0, 0.12))  # 그림자
	match unit:
		1:  # 뚝딱
			_body(ci, p, c)
			ci.draw_rect(Rect2(p + Vector2(-10, 2), Vector2(20, 14)), Color("fff4dc"))
			ci.draw_line(p + Vector2(side * 16, 4), p + Vector2(side * 28, -14), Color("8b6640"), 4)
			ci.draw_rect(Rect2(p + Vector2(side * 28 - 8, -22), Vector2(16, 10)), Color("6f6257"))
			_eyes(ci, p, facing)
		2:  # 덥석
			_body(ci, p, c)
			for sx in [-1.0, 1.0]:
				ci.draw_circle(p + Vector2(sx * (R + 6), 6), 10, c.lightened(0.15))
				ci.draw_arc(p + Vector2(sx * (R + 6), 6), 10, 0, TAU, 14, ink, 2)
			_eyes(ci, p, facing)
		3:  # 힐끔: 잎 뒤에서 큰 눈 하나
			_body(ci, p, c)
			ci.draw_circle(p + Vector2(0, -3), 10, Color.WHITE)
			ci.draw_circle(p + Vector2(0, -3) + facing * 4.0, 5, ink)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-side * 6, 18), p + Vector2(-side * 30, 4), p + Vector2(-side * 22, 22)]), Color("6fae74"))
		4:  # 척척: 안경과 책
			_body(ci, p, c)
			for sx in [-7.0, 7.0]:
				ci.draw_arc(p + Vector2(sx, -4), 6, 0, TAU, 12, ink, 2)
				ci.draw_circle(p + Vector2(sx, -4) + facing * 1.5, 2, ink)
			ci.draw_line(p + Vector2(-1, -4), p + Vector2(1, -4), ink, 2)
			ci.draw_rect(Rect2(p + Vector2(side * 14, 4), Vector2(side * 14, 16)), Color("fff4dc"))
			ci.draw_rect(Rect2(p + Vector2(side * 14, 4), Vector2(side * 14, 16)), Color("6f9fd8").darkened(0.3), false, 2)
		5:  # 조잘: 큰 입과 말풍선
			_body(ci, p, c)
			_eyes(ci, p + Vector2(0, -4), facing)
			ci.draw_circle(p + Vector2(0, 8), 6 + 2 * absf(sin(t * 10.0)), Color("8c3b4a"))
			var bp := p + Vector2(side * 22, -26)
			ci.draw_circle(bp, 11, Color.WHITE)
			ci.draw_arc(bp, 11, 0, TAU, 14, ink, 2)
			for k in 3:
				ci.draw_circle(bp + Vector2(-5 + k * 5, 0), 1.6, ink)
		6:  # 쌩: 앞으로 기운 물방울과 바람 줄
			var f := facing
			ci.draw_colored_polygon(PackedVector2Array([p + f * (R + 8), p + f.orthogonal() * R, p - f * R * 0.8, p - f.orthogonal() * R]), c)
			for k in 3:
				var o := -f * (R + 8 + k * 6) + f.orthogonal() * (k - 1) * 10
				ci.draw_line(p + o, p + o - f * 12, Color(1, 1, 1, 0.8), 3)
			_eyes(ci, p, facing)
		7:  # 영차: 네모난 몸과 등짐
			ci.draw_rect(Rect2(p + Vector2(-side * 26, -12), Vector2(side * 12, 24)), Color("c9a874"))
			ci.draw_rect(Rect2(p - Vector2(R, R), Vector2(R * 2, R * 2)), c)
			ci.draw_rect(Rect2(p - Vector2(R, R), Vector2(R * 2, R * 2)), ink, false, 3)
			_eyes(ci, p, facing)
		8:  # 대장: 깃발과 왕관
			ci.draw_line(p + Vector2(side * 18, 14), p + Vector2(side * 18, -36), Color("8b6640"), 3)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(side * 18, -36), p + Vector2(side * (34 + 3 * sin(t * 8.0)), -30), p + Vector2(side * 18, -22)]), c)
			_body(ci, p, c)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -R + 2), p + Vector2(-10, -R - 10), p + Vector2(-4, -R - 4), p + Vector2(0, -R - 12), p + Vector2(4, -R - 4), p + Vector2(10, -R - 10), p + Vector2(10, -R + 2)]), Color("f5c542"))
			_eyes(ci, p, facing)
		9:  # 휙: 돌을 든 팔
			_body(ci, p, c)
			var arm := p + Vector2(side * 14, -8)
			var hand := arm + Vector2(side * 10, -16 - 4 * sin(t * 7.0))
			ci.draw_line(arm, hand, c.darkened(0.2), 6)
			ci.draw_circle(hand, 7, Color("9a8f86"))
			_eyes(ci, p, facing)
		10:  # 빙글: 소용돌이
			_body(ci, p, c)
			var a := t * 4.0
			for k in 3:
				ci.draw_arc(p, 6 + k * 5, a + k, a + k + PI * 1.2, 10, Color(1, 1, 1, 0.85), 3)
			_eyes(ci, p + Vector2(0, -10), facing)
		11:  # 꿈쩍: 바위 같은 네모와 방패
			ci.draw_rect(Rect2(p - Vector2(R + 2, R), Vector2(R * 2 + 4, R * 2)), c)
			ci.draw_rect(Rect2(p - Vector2(R + 2, R), Vector2(R * 2 + 4, R * 2)), ink, false, 3)
			_eyes(ci, p + Vector2(0, -6), facing)
			var sp := p + facing * (R + 4)
			ci.draw_colored_polygon(PackedVector2Array([sp + Vector2(-11, -12), sp + Vector2(11, -12), sp + Vector2(11, 4), sp + Vector2(0, 14), sp + Vector2(-11, 4)]), Color("d9d2c3"))
			ci.draw_line(sp + Vector2(0, -10), sp + Vector2(0, 10), Color("6f6257"), 3)
		12:  # 와장: 들쭉날쭉한 몸과 금
			var pts := PackedVector2Array()
			for k in 10:
				var rr := R + (6.0 if k % 2 == 0 else -2.0)
				pts.append(p + Vector2.from_angle(k * TAU / 10.0 + 0.3) * rr)
			ci.draw_colored_polygon(pts, c)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), ink, 2)
			ci.draw_polyline(PackedVector2Array([p + Vector2(-4, -R), p + Vector2(2, -8), p + Vector2(-3, 0), p + Vector2(4, 10)]), ink, 2)
			_eyes(ci, p, facing)
		_:
			_body(ci, p, c)
			_eyes(ci, p, facing)


static func _body(ci: CanvasItem, p: Vector2, c: Color) -> void:
	ci.draw_circle(p, R, c)
	ci.draw_arc(p, R, 0, TAU, 24, UiKit.INK, 3)


static func _eyes(ci: CanvasItem, p: Vector2, facing: Vector2) -> void:
	var f := facing * 2.5
	ci.draw_circle(p + Vector2(-6, -4) + f, 2.8, UiKit.INK)
	ci.draw_circle(p + Vector2(6, -4) + f, 2.8, UiKit.INK)
