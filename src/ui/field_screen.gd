class_name FieldScreen
extends Screen
## 스테이지 1 필드(X·Y 탑다운): 왼쪽은 공방 마을, 오른쪽은 들판. 임시 도형으로 그린다(04-meta.md 6절).
## 조작: 화면 왼쪽을 누르고 끌면 가상 조이스틱, 키보드 방향키도 된다. 가까이 가면 '살펴보기' 버튼이 뜬다.

const WORLD := Vector2(2600, 1500)
const TOWN_W := 1000.0
const GATE := Vector2(650, 850)  ## 마을 울타리의 문 y 범위
const SPEED := 360.0
const HERO_R := 26.0
const ENEMY_R := 30.0
const ENEMY_COUNT := 6
const TOUCH_R := 110.0

var _hero := Vector2(500, 700)
var _cam := Vector2.ZERO
var _enemies: Array[Dictionary] = []  ## {pos, vel, words, t}
var _spots: Array[Dictionary] = []
var _near: Dictionary = {}
var _stick_on := false
var _stick_base := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _act_btn: Button
var _top: Label
var _toast: Label
var _toast_t := 0.0
var _busy := false
var _rng := RandomNumberGenerator.new()
var _decor: Array[Vector2] = []


func open(args: Dictionary) -> void:
	_rng.randomize()
	var s := GameData.state
	if s.pos != Vector2.ZERO:
		_hero = s.pos
	_spots = [
		{"id": "forge", "pos": Vector2(300, 420), "key": "ui.field.forge", "color": UiKit.APRICOT},
		{"id": "tree", "pos": Vector2(640, 260), "key": "ui.field.tree", "color": UiKit.LEAF},
		{"id": "board", "pos": Vector2(320, 1060), "key": "ui.field.order", "color": UiKit.PINK},
		{"id": "boss", "pos": Vector2(2450, 750), "key": "ui.field.boss", "color": UiKit.GRAY},
	]
	var drng := RandomNumberGenerator.new()
	drng.seed = 11
	for i in 70:
		_decor.append(Vector2(drng.randf_range(TOWN_W + 40, WORLD.x - 40), drng.randf_range(40, WORLD.y - 40)))
	for i in ENEMY_COUNT:
		_enemies.append(_new_enemy())
	_build_hud()
	if args.get("msg", "") != "":
		_show_toast(args["msg"])
	set_process(true)


func _build_hud() -> void:
	var bar := UiKit.hbox(10)
	bar.position = Vector2(16, 84)  # 세로 화면: 메뉴 버튼 줄 아래
	add_child(bar)
	_top = UiKit.label("", 22)
	var tc := UiKit.card()
	tc.add_child(_top)
	bar.add_child(tc)
	var right := UiKit.hbox(8)
	add_child(right)
	UiKit.pin(right, 1, 0, -16, 12)
	right.add_child(UiKit.button(t("ui.menu.dex"), func() -> void: _go(main.flow.go_dex), UiKit.LEAF, 22))
	right.add_child(UiKit.button(t("ui.menu.party"), func() -> void: _go(main.flow.go_party), UiKit.SKY, 22))
	right.add_child(UiKit.button(t("ui.menu.save"), func() -> void:
		_remember()
		GameData.save()
		_show_toast(t("ui.menu.saved")), UiKit.PINK, 22))
	right.add_child(UiKit.button(t("ui.menu.option"), func() -> void:
		_go(func() -> void: main.flow.go_options(main.flow.go_field)), UiKit.PAPER, 22))
	_act_btn = UiKit.button("", _act, UiKit.ACCENT.lightened(0.4), 28)
	_act_btn.custom_minimum_size = Vector2(260, 80)
	_act_btn.visible = false
	add_child(_act_btn)
	UiKit.pin(_act_btn, 1, 1, -24, -24)
	_toast = UiKit.label("", 26)
	_toast.custom_minimum_size = Vector2(640, 0)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)
	UiKit.pin(_toast, 0.5, 0, 0, 160)
	_update_top()


func _update_top() -> void:
	var g := GameData.rules.boss_gate(GameData.state, GameFlow.STAGE)
	_top.text = t("ui.field.top").format({"stage": t("name.stage.s01"), "have": g["have"],
		"total": GameData.repo.first_tier(GameFlow.STAGE).size(), "need": g["need"],
		"title": t("ui.dev.badge") if GameData.state.dev_mode else t("name.title.none")})


func _go(f: Callable) -> void:
	_remember()
	f.call()


func _remember() -> void:
	GameData.state.pos = _hero
	GameData.state.place = "town" if _hero.x < TOWN_W else "field"


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_t = 2.5


# ----- 적 -----

func _new_enemy() -> Dictionary:
	var p := _hero
	while p.distance_to(_hero) < 320.0:
		p = Vector2(_rng.randf_range(TOWN_W + 200, WORLD.x - 250), _rng.randf_range(80, WORLD.y - 80))
	return {"pos": p, "vel": Vector2.ZERO, "t": 0.0, "words": _pick_words()}


## 조우 단어: 그 스테이지 필드 1차, 빈도가 높을수록 자주(01-rpg-base '희귀도'). 다시 잡을 단어가 있으면 섞는다.
func _pick_words() -> Array[String]:
	var pool := GameData.repo.first_tier(GameFlow.STAGE, "field")
	var n := GameData.rules.team_size(GameData.state)
	var out: Array[String] = []
	var targets: Array = GameData.state.recapture.values()
	if not targets.is_empty() and _rng.randf() < 0.5:
		out.append(str(targets[_rng.randi_range(0, targets.size() - 1)]))
	var total := 0
	for w in pool:
		total += w.freq
	var guard := 0
	while out.size() < n and guard < 100:
		guard += 1
		var r := _rng.randi_range(1, total)
		for w in pool:
			r -= w.freq
			if r <= 0:
				if not w.id in out:
					out.append(w.id)
				break
	return out


# ----- 움직임 -----

func _process(delta: float) -> void:
	if _busy:
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if _stick_on:
		dir = _stick_vec
	var was_town := _hero.x < TOWN_W
	_hero = _move(_hero, dir * SPEED * delta)
	if was_town and _hero.x >= TOWN_W:
		main.flow.entered_field()
	for e in _enemies:
		e["t"] -= delta
		if e["t"] <= 0.0:
			e["t"] = _rng.randf_range(1.0, 2.5)
			e["vel"] = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0, 120)
		var np: Vector2 = e["pos"] + e["vel"] * delta
		if np.x > TOWN_W + 60 and np.x < WORLD.x - 40 and np.y > 40 and np.y < WORLD.y - 40:
			e["pos"] = np
		if (e["pos"] as Vector2).distance_to(_hero) < HERO_R + ENEMY_R:
			_busy = true
			_remember()
			main.flow.encounter(e["words"])
			return
	_near = {}
	for sp in _spots:
		if (sp["pos"] as Vector2).distance_to(_hero) < TOUCH_R:
			_near = sp
	_act_btn.visible = not _near.is_empty()
	if _act_btn.visible:
		_act_btn.text = t("ui.field.act").format({"place": t(_near["key"])})
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
	var view := size
	_cam = (_hero - view / 2).clamp(Vector2.ZERO, (WORLD - view).max(Vector2.ZERO))
	queue_redraw()


## 마을 울타리는 문으로만 지나간다.
func _move(p: Vector2, d: Vector2) -> Vector2:
	var n := (p + d).clamp(Vector2(HERO_R, HERO_R), WORLD - Vector2(HERO_R, HERO_R))
	var crossing := (p.x < TOWN_W) != (n.x < TOWN_W)
	if crossing and not (n.y > GATE.x and n.y < GATE.y):
		n.x = p.x
	return n


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and ev.position.x < size.x * 0.5:
			_stick_on = true
			_stick_base = ev.position
			_stick_vec = Vector2.ZERO
		elif not ev.pressed:
			_stick_on = false
	elif ev is InputEventMouseMotion and _stick_on:
		var d: Vector2 = ev.position - _stick_base
		_stick_vec = d.limit_length(90.0) / 90.0


func _act() -> void:
	if _near.is_empty():
		return
	_remember()
	match _near["id"]:
		"forge":
			main.flow.go_forge()
		"tree":
			main.notice(t("ui.field.tree_msg"))
		"board":
			main.flow.town_minigame()
		"boss":
			main.flow.boss_gate()


# ----- 그리기 -----

func _draw() -> void:
	var o := -_cam
	if not Art.draw(self, "map", "s01_world", o + WORLD / 2, WORLD):
		draw_rect(Rect2(o, Vector2(TOWN_W, WORLD.y)), Color("f3ead8"))
		draw_rect(Rect2(o + Vector2(TOWN_W, 0), Vector2(WORLD.x - TOWN_W, WORLD.y)), Color("d8eec9"))
	# 울타리와 문
	draw_line(o + Vector2(TOWN_W, 0), o + Vector2(TOWN_W, GATE.x), UiKit.INK, 8)
	draw_line(o + Vector2(TOWN_W, GATE.y), o + Vector2(TOWN_W, WORLD.y), UiKit.INK, 8)
	for d in _decor:
		if not Art.draw(self, "map", "grass_tuft", o + d, Vector2(40, 40)):
			draw_circle(o + d, 10, Color("a9d59a"))
			draw_circle(o + d + Vector2(8, -6), 3, UiKit.PINK)
	var font := ThemeDB.fallback_font
	for sp in _spots:
		var p: Vector2 = o + sp["pos"]
		var col: Color = sp["color"]
		if sp["id"] == "boss" and main.flow.seen("boss_s01"):
			col = UiKit.LEAF
		var art_id: String = "boss_gate_open" if sp["id"] == "boss" and main.flow.seen("boss_s01") else str(sp["id"])
		if not Art.draw(self, "building", art_id, p, Vector2(160, 160)):
			draw_circle(p, 54, col)
			draw_arc(p, 54, 0, TAU, 40, UiKit.INK, 4)
		draw_string(font, p + Vector2(-80, 86), t(sp["key"]), HORIZONTAL_ALIGNMENT_CENTER, 160, 22, UiKit.INK)
	for e in _enemies:
		var p: Vector2 = o + e["pos"]
		if Art.draw(self, "enemy", "field_wanderer", p, Vector2(ENEMY_R * 2.6, ENEMY_R * 2.6)):
			continue
		draw_circle(p, ENEMY_R, Color("c7b8e0"))
		draw_arc(p, ENEMY_R, 0, TAU, 32, UiKit.INK, 3)
		draw_circle(p + Vector2(-9, -4), 3, UiKit.INK)
		draw_circle(p + Vector2(9, -4), 3, UiKit.INK)
	# 주인공과 칭호 리본(04-meta.md 5절)
	var h := o + _hero
	if not Art.draw(self, "hero", "look0", h + Vector2(0, -12), Vector2(HERO_R * 3.2, HERO_R * 3.6)):
		draw_circle(h, HERO_R, Color("fff3c4"))
		draw_arc(h, HERO_R, 0, TAU, 32, UiKit.INK, 4)
		draw_circle(h + Vector2(-9, -3), 3.5, UiKit.INK)
		draw_circle(h + Vector2(9, -3), 3.5, UiKit.INK)
		draw_circle(h + Vector2(-15, 6), 5, UiKit.PINK)
		draw_circle(h + Vector2(15, 6), 5, UiKit.PINK)
	var tag := t("name.title.none")
	draw_rect(Rect2(h + Vector2(-60, -64), Vector2(120, 26)), UiKit.PINK)
	draw_string(font, h + Vector2(-60, -45), tag, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, UiKit.INK)
	if _stick_on:
		draw_arc(_stick_base, 90, 0, TAU, 40, Color(UiKit.INK, 0.4), 4)
		draw_circle(_stick_base + _stick_vec * 90, 28, Color(UiKit.INK, 0.3))
