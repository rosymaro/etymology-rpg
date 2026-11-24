class_name FieldScreen
extends Screen
## 월드맵(X·Y 탑다운): 스테이지 1~10이 한 지도에 있다(data/map/world.json, 04-meta.md 6절). 임시 도형으로 그린다.
## 지역마다 미로처럼 산·바다·호수·절벽·숲·성벽이 길을 가른다. 다음 지역으로 가는 문은 스토리가 열어 줘야 지나간다.
## 조작: 화면 어디든 누르고 끌면 가상 조이스틱, 키보드 방향키도 된다. 가까이 가면 '살펴보기' 버튼이 뜬다.
## 왼쪽 위 미니맵을 누르면 전체 지도가 펼쳐진다.

const SPEED := 380.0
const HERO_R := 26.0
const ENEMY_R := 30.0
const ENEMY_COUNT := 10
const ENEMY_NEAR := Vector2(500, 1500)  ## 적이 생기는 거리(주인공에서)
const ENEMY_FAR := 2600.0  ## 이보다 멀어지면 주인공 가까이에 다시 생긴다
const TOUCH_R := 110.0
const MINI_SCALE := 0.9  ## 미니맵: 타일 하나당 픽셀
const TILE_COL := {".": Color("d8eec9"), ",": Color("f3ead8"), "p": Color("d9c59a"), "b": Color("b98c5a"), "=": Color("e9876a"),
	"^": Color("9a8f86"), "~": Color("6fa8dc"), "w": Color("8cc6e8"), "#": Color("6f6257"), "T": Color("6fae74"), "H": Color("a7a7b4")}

var map: WorldMap
var _hero := Vector2.ZERO
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
var _gates := {}
var _mini: TextureRect
var _full: Control
var _gate_t := 0.0

static var _map_tex: ImageTexture


func open(args: Dictionary) -> void:
	_rng.randomize()
	map = WorldMap.load_default()
	_gates = main.flow.open_gates()
	var s := GameData.state
	_hero = s.pos
	if _hero == Vector2.ZERO or not map.fits(_hero, HERO_R, _gates):
		_hero = map.start(GameFlow.STAGE)  # 처음이거나 옛 지도 자리면 마을에서
	_spots = [
		{"id": "forge", "pos": map.spot(1, "forge"), "key": "ui.field.forge", "color": UiKit.APRICOT},
		{"id": "tree", "pos": map.spot(1, "tree"), "key": "ui.field.tree", "color": UiKit.LEAF},
		{"id": "board", "pos": map.spot(1, "board"), "key": "ui.field.order", "color": UiKit.PINK},
		{"id": "boss", "pos": map.spot(1, "boss"), "key": "ui.field.boss", "color": UiKit.GRAY},
	]
	for i in ENEMY_COUNT:
		var e := _new_enemy()
		if not e.is_empty():
			_enemies.append(e)
	_build_hud()
	_build_minimap()
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
	GameData.state.place = "town" if map.is_town(_hero) else "field"


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_t = 2.5


# ----- 적 -----

func _new_enemy() -> Dictionary:
	var p := map.random_field_spot(GameFlow.STAGE, _rng, _hero, ENEMY_NEAR.x, ENEMY_NEAR.y, ENEMY_R)
	if p == Vector2.INF:
		return {}
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
	if _busy or _full:
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if _stick_on:
		dir = _stick_vec
	var was_town := map.is_town(_hero)
	var before := _hero
	_hero = map.move(_hero, dir * SPEED * delta, HERO_R, _gates)
	if was_town and not map.is_town(_hero) and map.stage_at(_hero) == GameFlow.STAGE:
		main.flow.entered_field()
	# 닫힌 스테이지 문에 막히면 알려 준다
	_gate_t -= delta
	if dir.length() > 0.1 and _hero.distance_to(before) < 1.0 and _gate_t <= 0.0 and map.touching_gate(_hero, HERO_R, _gates) > 0:
		_gate_t = 3.0
		_show_toast(t("ui.field.gate_closed"))
	for i in _enemies.size():
		var e: Dictionary = _enemies[i]
		if (e["pos"] as Vector2).distance_to(_hero) > ENEMY_FAR:  # 멀어진 적은 가까이에 다시
			var ne := _new_enemy()
			if not ne.is_empty():
				_enemies[i] = ne
			continue
		e["t"] -= delta
		if e["t"] <= 0.0:
			e["t"] = _rng.randf_range(1.0, 2.5)
			e["vel"] = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0, 120)
		var np: Vector2 = map.move(e["pos"], e["vel"] * delta, ENEMY_R)
		if not map.is_town(np) and map.stage_at(np) == GameFlow.STAGE:
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
	_cam = (_hero - view / 2).clamp(Vector2.ZERO, (map.size_px() - view).max(Vector2.ZERO))
	_mini.queue_redraw()
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:  # 화면 어디를 눌러도(오른손으로도) 그 자리에 조이스틱
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
	# 화면 위아래 여백(Main)까지 땅색으로
	draw_rect(Rect2(-20, -UiKit.BG_BLEED, size.x + 40, size.y + UiKit.BG_BLEED * 2), TILE_COL["^"])
	_draw_tiles(o)
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


## 보이는 타일만 그린다. 막는 타일은 모양을 조금씩 넣는다(산 ▲, 물결, 나무, 절벽 줄, 성벽 벽돌, 다리 널, 문 창살).
func _draw_tiles(o: Vector2) -> void:
	var ts := float(map.tile)
	# 화면 위아래 여백(Main)까지 타일로 채운다(그 자리에 바탕색 띠가 보이지 않게)
	var c0 := map.cell(_cam - Vector2(0, UiKit.BG_BLEED))
	var c1 := map.cell(_cam + size + Vector2(0, UiKit.BG_BLEED))
	for y in range(maxi(0, c0.y - 1), mini(map.h, c1.y + 2)):
		var row := map.rows[y]
		for x in range(maxi(0, c0.x - 1), mini(map.w, c1.x + 2)):
			var k := row[x]
			var r := Rect2(o + Vector2(x, y) * ts, Vector2(ts, ts))
			draw_rect(r, TILE_COL.get(k, Color.MAGENTA))
			var hsh := (x * 73856093) ^ (y * 19349663)
			var c := r.get_center()
			match k:
				".":
					if hsh % 7 == 0:
						draw_circle(c + Vector2((hsh % 20) - 10, ((hsh / 7) % 20) - 10), 7, Color("b8dca6"))
					elif hsh % 23 == 0:
						draw_circle(c, 4, UiKit.PINK)
				"^":
					draw_colored_polygon(PackedVector2Array([r.position + Vector2(6, ts - 6), Vector2(c.x, r.position.y + 8), r.end - Vector2(6, 6)]), Color("857a71"))
					draw_colored_polygon(PackedVector2Array([Vector2(c.x, r.position.y + 8), Vector2(c.x - 9, r.position.y + 24), Vector2(c.x + 9, r.position.y + 24)]), Color("f4f1ec"))
				"~", "w":
					var wy := c.y + sin((x + Time.get_ticks_msec() / 600.0)) * 4
					draw_line(Vector2(r.position.x + 10, wy), Vector2(r.end.x - 10, wy), Color(1, 1, 1, 0.55), 3)
				"T":
					draw_circle(c + Vector2(0, -4), ts * 0.36, Color("4f8f57"))
					draw_rect(Rect2(c + Vector2(-4, 10), Vector2(8, 14)), Color("7a5a3a"))
				"#":
					for k2 in 3:
						draw_line(r.position + Vector2(8 + k2 * 18, 6), r.position + Vector2(2 + k2 * 18, ts - 6), Color("554a40"), 3)
				"H":
					for k2 in 2:
						draw_line(r.position + Vector2(0, 21 + k2 * 21), r.position + Vector2(ts, 21 + k2 * 21), Color("8a8a98"), 2)
				"b":
					for k2 in 4:
						draw_line(r.position + Vector2(6 + k2 * 15, 4), r.position + Vector2(6 + k2 * 15, ts - 4), Color("8b6640"), 3)
				"=":
					var open: bool = map.walkable(Vector2i(x, y), _gates)
					if not open:
						for k2 in 4:
							draw_line(r.position + Vector2(8 + k2 * 16, 0), r.position + Vector2(8 + k2 * 16, ts), UiKit.INK, 4)
	# 지역 이름(마을 위)
	var font := ThemeDB.fallback_font
	for rg in map.regions:
		var tw: Array = rg["town"]
		var p := o + Vector2(float(tw[0]) * ts, float(tw[1]) * ts) + Vector2(16, 40)
		if Rect2(p - Vector2(0, 40), Vector2(600, 60)).intersects(Rect2(Vector2.ZERO, size)):
			draw_string(font, p, t("name.stage.s%02d" % int(rg["stage"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiKit.INK)
		if int(rg["stage"]) != GameFlow.STAGE:  # 다른 지역의 보스 자리(아직 열리지 않은 곳)
			var bp: Array = rg["spots"]["boss"]
			var q := o + Vector2(float(bp[0]), float(bp[1]))
			if Rect2(Vector2(-80, -80), size + Vector2(160, 160)).has_point(q):
				draw_circle(q, 46, UiKit.GRAY.darkened(0.2))
				draw_arc(q, 46, 0, TAU, 32, UiKit.INK, 3)
				draw_string(font, q + Vector2(-80, 76), t("ui.field.far_boss"), HORIZONTAL_ALIGNMENT_CENTER, 160, 20, UiKit.INK)


# ----- 미니맵·전체 지도 -----

static func map_texture(m: WorldMap) -> ImageTexture:
	if _map_tex == null:
		var img := Image.create(m.w, m.h, false, Image.FORMAT_RGB8)
		for y in m.h:
			var row := m.rows[y]
			for x in m.w:
				img.set_pixel(x, y, TILE_COL.get(row[x], Color.MAGENTA))
		_map_tex = ImageTexture.create_from_image(img)
	return _map_tex


func _build_minimap() -> void:
	_mini = TextureRect.new()
	_mini.texture = map_texture(map)
	_mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mini.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mini.custom_minimum_size = Vector2(map.w, map.h) * MINI_SCALE
	_mini.size = _mini.custom_minimum_size
	_mini.position = Vector2(16, 150)
	_mini.mouse_filter = Control.MOUSE_FILTER_STOP
	_mini.draw.connect(func() -> void: _draw_marks(_mini, MINI_SCALE, false))
	_mini.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_open_full())
	add_child(_mini)


## 지도 위 표시: 주인공(깜빡이는 점), 보이는 화면 테두리, 보스 자리, (전체 지도면) 지역 이름.
func _draw_marks(c: Control, k: float, names: bool) -> void:
	var ts := float(map.tile)
	c.draw_rect(Rect2(Vector2.ZERO, c.size), UiKit.INK, false, 2.0)
	c.draw_rect(Rect2(_cam / ts * k, size / ts * k), Color(1, 1, 1, 0.9), false, 1.5)
	var font := ThemeDB.fallback_font
	for rg in map.regions:
		var bp: Array = rg["spots"]["boss"]
		c.draw_circle(Vector2(float(bp[0]), float(bp[1])) / ts * k, maxf(2.0, k * 1.4), UiKit.BAD if int(rg["stage"]) == GameFlow.STAGE else UiKit.GRAY.darkened(0.3))
		if names:
			var rc: Array = rg["rect"]
			var p := Vector2(float(rc[0]) + 3, float(rc[1]) + 5) * k
			c.draw_string(font, p + Vector2(0, 14), "%d. %s" % [int(rg["stage"]), t("name.stage.s%02d" % int(rg["stage"]))], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiKit.INK)
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
	c.draw_circle(_hero / ts * k, maxf(3.0, k * 1.6), Color(UiKit.ACCENT, 0.5 + 0.5 * blink))


func _open_full() -> void:
	if _full:
		return
	_stick_on = false
	_full = Control.new()
	_full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_full.mouse_filter = Control.MOUSE_FILTER_STOP
	_full.z_index = 20
	add_child(_full)
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.13, 0.22, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_top = -UiKit.BG_BLEED
	dim.offset_bottom = UiKit.BG_BLEED
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full.add_child(dim)
	var k := minf((size.x - 40) / map.w, (size.y - 140) / map.h)
	var tex := TextureRect.new()
	tex.texture = map_texture(map)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.size = Vector2(map.w, map.h) * k
	tex.position = Vector2((size.x - tex.size.x) / 2, 70)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.draw.connect(func() -> void: _draw_marks(tex, k, true))
	_full.add_child(tex)
	var title := UiKit.label(t("ui.field.world_map"), 28, Color.WHITE)
	title.position = Vector2(20, 16)
	_full.add_child(title)
	var close := UiKit.button(t("ui.field.close_map"), _close_full, UiKit.PAPER, 22)
	_full.add_child(close)
	UiKit.pin(close, 1, 0, -20, 12)
	_full.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close_full())
	var tick := func() -> void: tex.queue_redraw()
	_full.set_meta("tick", tick)
	var timer := Timer.new()
	timer.wait_time = 0.1
	timer.autostart = true
	timer.timeout.connect(tick)
	_full.add_child(timer)


func _close_full() -> void:
	if _full:
		_full.queue_free()
		_full = null
