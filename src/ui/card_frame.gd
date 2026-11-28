class_name CardFrame
extends Control
## 전투 카드 테두리: 속성마다 다르다(사용자 의견). 카드 위에 겹쳐 그리고 누름은 지나간다.
## 속성 색의 진한 테두리 + 속성마다 다른 테두리 무늬(5가지) × 모서리 장식(그 속성 몹의 몸 모양, mob_attrs.json shape).
## attr 0(속성 없음)은 얇은 먹선만.

const PATTERNS := ["double", "beads", "zigzag", "dash", "rope"]

var attr := 0:
	set(v):
		attr = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func pattern_of(a: int) -> String:
	return PATTERNS[(a - 1) % PATTERNS.size()] if a > 0 else ""


static func shape_of(a: int) -> String:
	var at: Dictionary = GameData.mob_attrs.get("attrs", {}).get(str(a), {})
	return String(at.get("shape", "circle"))


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(-3)
	if r.size.x <= 0.0:
		return
	if attr <= 0:
		draw_rect(r, UiKit.INK, false, 3.0)
		return
	var base := MinigameScreen.attr_color(attr)
	var dark := base.darkened(0.55)
	var mid := base.darkened(0.25)
	draw_rect(r, dark, false, 6.0)
	var inner := r.grow(-9)
	match pattern_of(attr):
		"double":
			draw_rect(inner, mid, false, 2.0)
			draw_rect(inner.grow(-5), mid, false, 1.5)
		"beads":
			_along(inner, 18.0, func(p: Vector2, _n: Vector2) -> void: draw_circle(p, 3.2, mid))
		"zigzag":
			_zig(inner, 14.0, 4.0, mid)
		"dash":
			_along(inner, 16.0, func(p: Vector2, n: Vector2) -> void:
				var tng := Vector2(-n.y, n.x)
				draw_line(p - tng * 5.0, p + tng * 5.0, mid, 3.0))
		"rope":
			_along(inner, 12.0, func(p: Vector2, n: Vector2) -> void:
				var tng := Vector2(-n.y, n.x)
				draw_line(p - tng * 4.0 - n * 3.0, p + tng * 4.0 + n * 3.0, mid, 2.5))
	# 모서리: 그 속성 몹의 몸 모양
	var shape := shape_of(attr)
	for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var p: Vector2 = (c as Vector2) + ((r.get_center() - c) as Vector2).sign() * 4.0
		draw_circle(p, 13.0, dark)
		MobArt.draw(self, shape, p, 9.0, base.lightened(0.2), dark)
	# 위 가운데 보석
	var top := Vector2(r.get_center().x, r.position.y)
	draw_circle(top, 15.0, dark)
	MobArt.draw(self, shape, top, 10.0, base, dark)


## 사각형 둘레를 따라 step마다 f(점, 안쪽 법선)을 부른다.
func _along(r: Rect2, step: float, f: Callable) -> void:
	var sides := [[r.position, Vector2(r.end.x, r.position.y), Vector2.DOWN], [Vector2(r.end.x, r.position.y), r.end, Vector2.LEFT],
		[r.end, Vector2(r.position.x, r.end.y), Vector2.UP], [Vector2(r.position.x, r.end.y), r.position, Vector2.RIGHT]]
	for s in sides:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var n := int(a.distance_to(b) / step)
		for k in range(1, n):
			f.call(a.lerp(b, float(k) / n), s[2])


func _zig(r: Rect2, step: float, amp: float, col: Color) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var n := maxi(2, int(a.distance_to(b) / step))
		var nrm := (b - a).normalized().orthogonal()
		var pts := PackedVector2Array()
		for k in n + 1:
			pts.append(a.lerp(b, float(k) / n) + nrm * (amp if k % 2 == 1 else 0.0))
		draw_polyline(pts, col, 2.0, true)
