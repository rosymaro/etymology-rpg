class_name FieldScreen
extends Screen
## 월드맵(X·Y 탑다운): 스테이지 1~10이 한 지도에 있다(data/map/world.json, 04-meta.md 6절). 임시 도형으로 그린다.
## 지역마다 미로처럼 산·바다·호수·절벽·숲·성벽이 길을 가른다. 다음 지역으로 가는 문은 스토리가 열어 줘야 지나간다.
## 조작: 화면 어디든 누르고 끌면 가상 조이스틱, 키보드 방향키도 된다. 가까이 가면 '살펴보기' 버튼이 뜬다.
## 왼쪽 위 미니맵을 누르면 전체 지도가 펼쳐진다.
## 몹은 배회·쫓기·도망 세 가지(FieldMob, data/balance/field.json). 퀘스트 길목(무너진 다리·절벽)은 퀘스트를 마쳐야 지나간다.

const HERO_R := 26.0
const ENEMY_R := 30.0
const MOB_COL := {"wander": Color("c7b8e0"), "chase": Color("f0a08c"), "flee": Color("9fd8c8")}
const TOUCH_R := 110.0
const MINI_SCALE := 0.9  ## 미니맵: 타일 하나당 픽셀
const TILE_COL := {".": Color("d8eec9"), ",": Color("f3ead8"), "p": Color("d9c59a"), "b": Color("b98c5a"), "=": Color("e9876a"), "q": Color("8c6a4a"),
	"s": Color("d9d2c3"), "F": Color("c9a874"), "h": Color("b7a48c"), "o": Color("8cc6e8"), "f": Color("b9d77e"),
	"^": Color("9a8f86"), "~": Color("6fa8dc"), "w": Color("8cc6e8"), "#": Color("6f6257"), "T": Color("6fae74"), "H": Color("a7a7b4")}

var map: WorldMap
var _f: Dictionary  ## data/balance/field.json
var _hero := Vector2.ZERO
var _cam := Vector2.ZERO
var _enemies: Array[FieldMob] = []
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
var _goal: Label
var _rest: Label  ## 병원에서 쉬는 남은 시간
var _rest_t := 0.0
var _was_resting := false
var _villagers: Array[FieldMob] = []
const BUILDING_ROOF := {"forge": Color("c0634a"), "board": Color("6f8fd0"), "hospital": Color("f2f2f2"), "tree": Color("4f8f57")}
var _quests: Control

static var _map_tex: ImageTexture


func open(args: Dictionary) -> void:
	_rng.randomize()
	map = WorldMap.load_default()
	_f = GameData.field
	_gates = main.flow.open_gates()
	var s := GameData.state
	_hero = s.pos
	if _hero == Vector2.ZERO or not map.fits(_hero, HERO_R, _gates):
		_hero = map.start(GameFlow.STAGE)  # 처음이거나 옛 지도 자리면 마을에서
	_spots = [
		{"id": "forge", "pos": map.spot(1, "forge"), "key": "ui.field.forge", "color": UiKit.APRICOT},
		{"id": "tree", "pos": map.spot(1, "tree"), "key": "ui.field.tree", "color": UiKit.LEAF},
		{"id": "board", "pos": map.spot(1, "board"), "key": "ui.field.order", "color": UiKit.PINK},
		{"id": "hospital", "pos": map.spot(1, "hospital"), "key": "ui.field.hospital", "color": UiKit.BAD},
		{"id": "notice", "pos": map.spot(1, "notice"), "key": "ui.field.notice", "color": UiKit.SKY},
		{"id": "boss", "pos": map.spot(1, "boss"), "key": "ui.field.boss", "color": UiKit.GRAY},
	]
	for i in int(_f["enemy_count"]):
		var e := _new_enemy()
		if e:
			_enemies.append(e)
	for i in int(_f.get("villagers", 0)):
		var v := FieldMob.new()
		v.kind = "wander"
		v.pos = _town_spot()
		v.words = [str(_rng.randi_range(1, 6))] as Array[String]  # 말버릇 번호
		_villagers.append(v)
	_was_resting = main.flow.rest_left() > 0
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
	right.add_child(UiKit.button(t("ui.menu.quest"), _open_quests, UiKit.APRICOT, 22))
	right.add_child(UiKit.button(t("ui.menu.dex"), func() -> void: _go(main.flow.go_dex), UiKit.LEAF, 22))
	right.add_child(UiKit.button(t("ui.menu.party"), func() -> void: _go(main.flow.go_party), UiKit.SKY, 22))
	right.add_child(UiKit.button(t("ui.menu.save"), func() -> void:
		_remember()
		GameData.save()
		_show_toast(t("ui.menu.saved")), UiKit.PINK, 22))
	right.add_child(UiKit.button(t("ui.menu.option"), func() -> void:
		_go(func() -> void: main.flow.go_options(main.flow.go_field)), UiKit.PAPER, 22))
	_goal = UiKit.label("", 20, UiKit.INK)
	var gc := UiKit.card()
	gc.add_child(_goal)
	add_child(gc)
	gc.position = Vector2(16, 150 + map.h * MINI_SCALE + 10)
	_rest = UiKit.label("", 22, UiKit.BAD.darkened(0.2))
	var rc := UiKit.card(Color("fff4dc"))
	rc.add_child(_rest)
	add_child(rc)
	rc.position = Vector2(16, 150 + map.h * MINI_SCALE + 10 + 48)
	rc.visible = false
	_rest.set_meta("card", rc)
	var home := UiKit.button(t("ui.field.home"), _go_home, UiKit.PAPER, 24)
	home.custom_minimum_size = Vector2(150, 70)
	add_child(home)
	UiKit.thumb(home, 0.0)  # 엄지 자리 왼쪽
	_act_btn = UiKit.button("", _act, UiKit.ACCENT.lightened(0.4), 28)
	_act_btn.custom_minimum_size = Vector2(260, 80)
	_act_btn.visible = false
	add_child(_act_btn)
	UiKit.thumb(_act_btn, 1.0)  # 엄지 자리
	_toast = UiKit.label("", 26)
	_toast.custom_minimum_size = Vector2(640, 0)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)
	UiKit.pin(_toast, 0.5, 0, 0, 150 + map.h * MINI_SCALE + 70)  # 미니맵·할 일 아래(가리지 않게)
	_update_top()


func _update_top() -> void:
	var g := GameData.rules.boss_gate(GameData.state, GameFlow.STAGE)
	_top.text = t("ui.field.top").format({"stage": t("name.stage.s01"), "have": g["have"],
		"total": GameData.repo.first_tier(GameFlow.STAGE).size(), "need": g["need"],
		"title": t("ui.dev.badge") if GameData.state.dev_mode else t("name.title.none")})
	_goal.text = t("ui.field.goal").format({"title": _goal_text()})


## 할 일: 퀘스트가 아직 없으면 들판에서 단어 잡기, 알림판 퀘스트를 아직 받지 않았으면 알림판에 가 보기.
func _goal_text() -> String:
	var s := GameData.state
	var book := GameData.quests
	var q := book.next_quest(s, GameFlow.STAGE)
	if q.is_empty():
		return t("ui.quest.goal_none") if book.boss_blockers(s, GameFlow.STAGE).size() > 0 else t("ui.quest.all_done")
	if q["kind"] == "words" and not main.flow.seen(String(q["id"]) + "_got"):
		return t("ui.quest.goal_board")
	return t("ui.quest.%s.title" % q["id"])


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

func _new_enemy() -> FieldMob:
	var near: Array = _f["spawn_near"]
	var p := map.random_field_spot(GameFlow.STAGE, _rng, _hero, float(near[0]), float(near[1]), ENEMY_R)
	if p == Vector2.INF:
		return null
	var m := FieldMob.new()
	m.pos = p
	m.kind = FieldMob.pick_kind(_f["kinds"], _rng)
	m.words = _pick_words(bool(_f["kinds"][m.kind].get("rare", false)))
	return m


## 조우 단어: 그 스테이지 필드 1차, 빈도가 높을수록 자주(01-rpg-base '희귀도'). 다시 잡을 단어가 있으면 섞는다.
## rare(도망가는 몹)면 거꾸로 드문 단어일수록 자주.
func _pick_words(rare := false) -> Array[String]:
	var pool := GameData.repo.first_tier(GameFlow.STAGE, "field")
	var n := GameData.rules.team_size(GameData.state)
	var out: Array[String] = []
	var targets: Array = GameData.state.recapture.values()
	if not targets.is_empty() and _rng.randf() < 0.5:
		out.append(str(targets[_rng.randi_range(0, targets.size() - 1)]))
	var total := 0
	var wt := func(w: WordData) -> int: return maxi(1, 100 / maxi(1, w.freq)) if rare else w.freq
	for w in pool:
		total += wt.call(w)
	var guard := 0
	while out.size() < n and guard < 100:
		guard += 1
		var r := _rng.randi_range(1, total)
		for w in pool:
			r -= wt.call(w)
			if r <= 0:
				if not w.id in out:
					out.append(w.id)
				break
	return out


# ----- 움직임 -----

func _process(delta: float) -> void:
	if _busy or _full or _quests:
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if _stick_on:
		dir = _stick_vec
	var was_town := map.is_town(_hero)
	var before := _hero
	_hero = map.move(_hero, dir * float(_f["hero_speed"]) * delta, HERO_R, _gates)
	var left: int = main.flow.rest_left()
	if left > 0 and was_town and not map.is_town(_hero):  # 병원에서 쉬는 중: 마을 밖으로 못 나간다
		_hero = before
		if _rest_t <= 0.0:
			_rest_t = 2.0
			_show_toast(t("ui.field.rest_block").format({"left": _mmss(left)}))
	_rest_t -= delta
	var card: Control = _rest.get_meta("card")
	card.visible = left > 0
	if left > 0:
		_rest.text = t("ui.field.resting").format({"left": _mmss(left)})
	elif _was_resting:
		_show_toast(t("ui.field.rest_done"))
	_was_resting = left > 0
	for v in _villagers:  # 마을 사람: 마을 안에서만 천천히
		var vv := v.steer(_hero, delta, _f["kinds"], _rng) * 0.5
		var vp: Vector2 = map.move(v.pos, vv * delta, ENEMY_R)
		if map.is_town(vp):
			v.pos = vp
	if was_town and not map.is_town(_hero) and map.stage_at(_hero) == GameFlow.STAGE:
		main.flow.entered_field()
	# 닫힌 스테이지 문에 막히면 알려 준다
	_gate_t -= delta
	if dir.length() > 0.1 and _hero.distance_to(before) < 1.0 and _gate_t <= 0.0:
		var qg := map.touching_quest(_hero, HERO_R, _gates)
		if qg != "":  # 퀘스트 길목(무너진 다리·절벽): 할 수 있으면 장면 뒤 길이 열린다
			_gate_t = 3.0
			_busy = true
			_stick_on = false
			_remember()
			var hint: String = main.flow.quest_gate(qg, _quest_done)
			if hint != "":
				_busy = false
				_show_toast(hint)
			return
		if map.touching_gate(_hero, HERO_R, _gates) > 0:
			_gate_t = 3.0
			_show_toast(t("ui.field.gate_closed"))
	for i in _enemies.size():
		var e := _enemies[i]
		if e.pos.distance_to(_hero) > float(_f["spawn_far"]):  # 멀어진 적은 가까이에 다시
			var ne := _new_enemy()
			if ne:
				_enemies[i] = ne
			continue
		var v := e.steer(_hero, delta, _f["kinds"], _rng)
		var np: Vector2 = map.move(e.pos, v * delta, ENEMY_R)
		if not map.is_town(np) and map.stage_at(np) == GameFlow.STAGE:
			e.pos = np
		if e.pos.distance_to(_hero) < HERO_R + ENEMY_R:
			_busy = true
			_remember()
			main.flow.encounter(e.words)
			return
	_near = {}
	for sp in _spots:
		if (sp["pos"] as Vector2).distance_to(_hero) < TOUCH_R:
			_near = sp
	if _near.is_empty():
		for v in _villagers:
			if v.pos.distance_to(_hero) < TOUCH_R * 0.8:
				_near = {"id": "villager", "key": "ui.field.villager", "line": v.words[0]}
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
		"hospital":
			var left: int = main.flow.rest_left()
			main.notice(t("ui.field.nurse_rest").format({"left": _mmss(left)}) if left > 0 else t("ui.field.nurse"))
		"villager":
			main.notice(t("ui.npc.s01_%s" % _near["line"]))
		"notice":
			_busy = true
			_stick_on = false
			main.flow.notice_board(_quest_done)
		"boss":
			main.flow.boss_gate()


## 알림판 퀘스트가 열렸는데 아직 받지 않았거나, 단어를 다 모아 마칠 수 있을 때.
func _board_calls() -> bool:
	var s := GameData.state
	var q := GameData.quests.get_quest("s01_q_word")
	if q.is_empty() or not GameData.quests.visible(s, q) or GameData.quests.done(s, q["id"]):
		return false
	return not main.flow.seen("s01_q_word_got") or GameData.quests.progress(s, q, [])["ready"]


## 퀘스트를 마치면(장면이 끝나면) 길목을 다시 읽는다.
func _quest_done() -> void:
	_gates = main.flow.open_gates()
	_busy = false
	_update_top()
	_map_tex = null  # 미니맵도 다시(길목 색)
	_mini.texture = map_texture(map, _gates)


static func _mmss(sec: int) -> String:
	return "%d:%02d" % [sec / 60, sec % 60]


## 마을 안 아무 서 있을 수 있는 자리(마을 사람).
func _town_spot() -> Vector2:
	var t: Array = map.region(GameFlow.STAGE)["town"]
	for k in 80:
		var c := Vector2i(int(t[0]) + _rng.randi_range(1, int(t[2]) - 2), int(t[1]) + _rng.randi_range(1, int(t[3]) - 2))
		var p := (Vector2(c) + Vector2(0.5, 0.5)) * map.tile
		if map.is_town(p) and map.fits(p, ENEMY_R):
			return p
	return map.start(GameFlow.STAGE)


func _go_home() -> void:
	_hero = map.start(GameFlow.STAGE)
	_stick_on = false
	_remember()
	_show_toast(t("ui.field.home_done"))


## 퀘스트 목록(오른쪽 위 '퀘스트'). 아무 곳이나 누르면 닫힌다.
func _open_quests() -> void:
	if _quests:
		return
	_stick_on = false
	_quests = Control.new()
	_quests.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_quests.mouse_filter = Control.MOUSE_FILTER_STOP
	_quests.z_index = 20
	add_child(_quests)
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.13, 0.22, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_top = -UiKit.BG_BLEED
	dim.offset_bottom = UiKit.BG_BLEED
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quests.add_child(dim)
	var card := UiKit.card()
	card.custom_minimum_size = Vector2(640, 0)
	card.position = Vector2(40, 220)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quests.add_child(card)
	var v := UiKit.vbox(16)
	card.add_child(v)
	v.add_child(UiKit.label(t("ui.quest.list_title"), 30, UiKit.ACCENT.darkened(0.3)))
	var roots := GameData.rules.owned_roots(GameData.state)
	var shown := GameData.quests.shown(GameData.state, GameFlow.STAGE)
	if shown.is_empty():
		var none := UiKit.label(t("ui.quest.none"), 22, UiKit.INK.lightened(0.2))
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = 600
		v.add_child(none)
	for q in shown:
		var done := GameData.quests.done(GameData.state, q["id"])
		var pr := GameData.quests.progress(GameData.state, q, roots)
		var head := "%s %s  (%s)" % ["✔" if done else "●", t("ui.quest.%s.title" % q["id"]),
			t("ui.quest.state_done") if done else (t("ui.quest.state_ready") if pr["ready"] and q["kind"] != "words" else "%s %d/%d" % [t("ui.quest.state_todo"), pr["have"], pr["need"]])]
		v.add_child(UiKit.label(head, 24, UiKit.LEAF.darkened(0.3) if done else UiKit.INK))
		var d := UiKit.label(t("ui.quest.%s.desc" % q["id"]), 20, UiKit.INK.lightened(0.25))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 600
		v.add_child(d)
	var close := UiKit.button(t("ui.quest.close"), _close_quests, UiKit.PAPER, 24)
	close.custom_minimum_size = Vector2(220, 70)
	_quests.add_child(close)
	UiKit.thumb(close)
	_quests.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_close_quests())


func _close_quests() -> void:
	if _quests:
		_quests.queue_free()
		_quests = null


# ----- 그리기 -----

func _draw() -> void:
	var o := -_cam
	# 화면 위아래 여백(Main)까지 땅색으로
	draw_rect(Rect2(-20, -UiKit.BG_BLEED, size.x + 40, size.y + UiKit.BG_BLEED * 2), TILE_COL["^"])
	_draw_tiles(o)
	var font := ThemeDB.fallback_font
	_draw_buildings(o)
	for v in _villagers:
		_draw_villager(o + v.pos)
	for sp in _spots:
		var p: Vector2 = o + sp["pos"]
		var col: Color = sp["color"]
		if sp["id"] in BUILDING_ROOF:  # 건물이 있는 시설: 문 앞에 이름만
			if sp["id"] == "hospital" or sp["id"] == "forge" or sp["id"] == "board" or sp["id"] == "tree":
				continue
		if sp["id"] == "boss" and main.flow.seen("boss_s01"):
			col = UiKit.LEAF
		var art_id: String = "boss_gate_open" if sp["id"] == "boss" and main.flow.seen("boss_s01") else str(sp["id"])
		if not Art.draw(self, "building", art_id, p, Vector2(160, 160)):
			draw_circle(p, 54, col)
			draw_arc(p, 54, 0, TAU, 40, UiKit.INK, 4)
		draw_string(font, p + Vector2(-80, 86), t(sp["key"]), HORIZONTAL_ALIGNMENT_CENTER, 160, 22, UiKit.INK)
		if sp["id"] == "notice" and _board_calls():  # 알림판에 가야 할 때: 머리 위에 깜빡이는 !
			draw_string(font, p + Vector2(-20, -70), "!", HORIZONTAL_ALIGNMENT_CENTER, 40, 48 + 6 * sin(Time.get_ticks_msec() / 200.0), UiKit.BAD)
	for qg in map.quest_gates:  # 닫힌 퀘스트 길목에 표지판(어디서 무엇을 해야 하는지)
		if _gates.get(qg["id"], false) or not GameData.quests.visible(GameData.state, GameData.quests.by_gate(qg["id"])):
			continue
		var sp: Array = qg["spot"]
		var p := o + Vector2(float(sp[0]), float(sp[1])) + Vector2(0, -40)
		if not Rect2(Vector2(-200, -100), size + Vector2(400, 200)).has_point(p):
			continue
		draw_line(p, p + Vector2(0, 50), Color("7a5a3a"), 6)
		var title := t("ui.quest.%s.title" % qg["id"])
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 24
		draw_rect(Rect2(p - Vector2(tw / 2, 34), Vector2(tw, 34)), Color("fff4dc"))
		draw_rect(Rect2(p - Vector2(tw / 2, 34), Vector2(tw, 34)), Color("7a5a3a"), false, 3)
		draw_string(font, p + Vector2(-tw / 2, -10), title, HORIZONTAL_ALIGNMENT_CENTER, tw, 20, UiKit.INK)
		draw_string(font, p + Vector2(-10, -40), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 30 + 4 * sin(Time.get_ticks_msec() / 200.0), UiKit.BAD)
	for e in _enemies:
		_draw_mob(e, o + e.pos)
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


## 마을 건물: 벽(타일) 위에 지붕, 문, 창, 간판. 말뿌리 나무는 큰 나무로.
func _draw_buildings(o: Vector2) -> void:
	var ts := float(map.tile)
	var font := ThemeDB.fallback_font
	for b in map.region(GameFlow.STAGE).get("buildings", []):
		var rc: Array = b["rect"]
		var r := Rect2(o + Vector2(float(rc[0]), float(rc[1])) * ts, Vector2(float(rc[2]), float(rc[3])) * ts)
		if not r.grow(200).intersects(Rect2(Vector2.ZERO, size)):
			continue
		var id := String(b["id"])
		if id == "tree":
			var c := r.get_center()
			draw_rect(Rect2(c + Vector2(-14, 0), Vector2(28, ts)), Color("7a5a3a"))
			draw_circle(c + Vector2(0, -20), ts * 1.1, Color("4f8f57"))
			draw_circle(c + Vector2(-40, 0), ts * 0.7, Color("5f9f67"))
			draw_circle(c + Vector2(40, 0), ts * 0.7, Color("5f9f67"))
			draw_string(font, c + Vector2(-90, ts * 1.6), t("ui.field.tree"), HORIZONTAL_ALIGNMENT_CENTER, 180, 22, UiKit.INK)
			continue
		var roof: Color = BUILDING_ROOF.get(id, Color("a46a4a") if id.ends_with("1") or id.ends_with("3") else Color("8a6aa4"))
		draw_rect(r, Color("efe3cf"))
		draw_rect(r, UiKit.INK, false, 3)
		var top := Rect2(r.position - Vector2(10, 0), Vector2(r.size.x + 20, r.size.y * 0.45))
		draw_colored_polygon(PackedVector2Array([top.position + Vector2(0, top.size.y), top.position + Vector2(top.size.x / 2, -ts * 0.5),
			top.end]), roof)
		draw_polyline(PackedVector2Array([top.position + Vector2(0, top.size.y), top.position + Vector2(top.size.x / 2, -ts * 0.5),
			top.end]), UiKit.INK, 3)
		var dp: Array = b["door"]
		var door := o + Vector2(float(dp[0]), float(dp[1])) - Vector2(ts * 0.3, ts * 0.9)
		draw_rect(Rect2(door, Vector2(ts * 0.6, ts * 0.8)), Color("8b6640"))
		for k in 2:  # 창
			var wx := r.position.x + (k + 0.5) * r.size.x / 2.0 - ts * 0.25
			if absf(wx + ts * 0.25 - (door.x + ts * 0.3)) > ts * 0.6:
				draw_rect(Rect2(Vector2(wx, r.position.y + r.size.y * 0.55), Vector2(ts * 0.5, ts * 0.4)), Color("bfe3f5"))
		if id == "hospital":
			var c := Vector2(r.get_center().x, r.position.y + r.size.y * 0.2)
			draw_rect(Rect2(c - Vector2(8, 22), Vector2(16, 44)), UiKit.BAD)
			draw_rect(Rect2(c - Vector2(22, 8), Vector2(44, 16)), UiKit.BAD)
		if id == "forge":  # 굴뚝 연기
			var ch0 := r.position + Vector2(r.size.x * 0.8, -ts * 0.2)
			draw_rect(Rect2(ch0, Vector2(18, 30)), Color("6f6257"))
			for k in 3:
				var ph := fmod(Time.get_ticks_msec() / 900.0 + k / 3.0, 1.0)
				draw_circle(ch0 + Vector2(9 + sin(ph * 6.0) * 6, -ph * 70), 8 + ph * 8, Color(0.9, 0.9, 0.9, 0.7 * (1.0 - ph)))
		var key: String = {"forge": "ui.field.forge", "board": "ui.field.order", "hospital": "ui.field.hospital"}.get(id, "")
		if key != "":
			var label := t(key)
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 20
			var lp := Vector2(r.get_center().x - tw / 2, r.end.y - r.size.y * 0.15 - 30)
			draw_rect(Rect2(lp, Vector2(tw, 30)), Color("fff4dc"))
			draw_rect(Rect2(lp, Vector2(tw, 30)), UiKit.INK, false, 2)
			draw_string(font, lp + Vector2(0, 22), label, HORIZONTAL_ALIGNMENT_CENTER, tw, 22, UiKit.INK)


func _draw_villager(p: Vector2) -> void:
	if Art.draw(self, "npc", "villager", p, Vector2(ENEMY_R * 2.6, ENEMY_R * 2.6)):
		return
	draw_circle(p + Vector2(0, 14), 18, Color("e9c46a"))
	draw_circle(p - Vector2(0, 10), 16, Color("ffe3c4"))
	draw_arc(p - Vector2(0, 10), 16, 0, TAU, 24, UiKit.INK, 2)
	draw_circle(p + Vector2(-5, -12), 2, UiKit.INK)
	draw_circle(p + Vector2(5, -12), 2, UiKit.INK)


## 몹 모양: 배회(보라, 동그란 눈), 쫓기(주황, 뿔과 성난 눈썹, 쫓을 때 !), 도망(민트, 긴 귀와 땀방울, 도망칠 때 땀).
func _draw_mob(e: FieldMob, p: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var bob := sin(Time.get_ticks_msec() / 160.0 + p.x * 0.01) * 3.0
	p += Vector2(0, bob)
	if not Art.draw(self, "enemy", "field_" + e.kind, p, Vector2(ENEMY_R * 2.6, ENEMY_R * 2.6)):
		var col: Color = MOB_COL.get(e.kind, MOB_COL["wander"])
		match e.kind:
			"chase":
				for sg in [-1.0, 1.0]:
					draw_colored_polygon(PackedVector2Array([p + Vector2(sg * 10, -24), p + Vector2(sg * 24, -42), p + Vector2(sg * 24, -18)]), col.darkened(0.25))
			"flee":
				for sg in [-1.0, 1.0]:
					draw_set_transform(p + Vector2(sg * 13, -30), sg * 0.25, Vector2(0.45, 1.0))
					draw_circle(Vector2.ZERO, 14, col.darkened(0.15))
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(p, ENEMY_R, col)
		draw_arc(p, ENEMY_R, 0, TAU, 32, UiKit.INK, 3)
		draw_circle(p + Vector2(-9, -4), 3, UiKit.INK)
		draw_circle(p + Vector2(9, -4), 3, UiKit.INK)
		if e.kind == "chase":
			draw_line(p + Vector2(-15, -14), p + Vector2(-4, -9), UiKit.INK, 3)
			draw_line(p + Vector2(15, -14), p + Vector2(4, -9), UiKit.INK, 3)
	if e.alert:
		if e.kind == "chase":
			draw_string(font, p + Vector2(-10, -46), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 34, UiKit.BAD)
		elif e.kind == "flee":
			draw_circle(p + Vector2(ENEMY_R - 2, -ENEMY_R + 4), 6, Color("8cc6e8"))


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
				"q":  # 퀘스트 길목: 무너진 다리(물 위) / 절벽 끝. 열리면 다리·길로 보인다
					var qid := map.closed_quest(Vector2i(x, y), _gates)
					var kind: String = map.quest_gate(String(map.gate_id(Vector2i(x, y)))).get("kind", "")
					if kind == "bridge":
						draw_rect(r, TILE_COL["~"])
						for k2 in 4:
							if qid == "" or (hsh + k2) % 3 != 0:  # 무너지면 널이 듬성듬성
								draw_rect(Rect2(r.position + Vector2(4 + k2 * 15, 4), Vector2(10, ts - 8)), TILE_COL["b"] if qid == "" else Color("7a5a3a"))
					else:
						draw_rect(r, TILE_COL["p"] if qid == "" else TILE_COL["#"])
						if qid != "":
							for k2 in 3:
								draw_line(r.position + Vector2(4, 12 + k2 * 18), r.end - Vector2(4, ts - 18 - k2 * 18), Color("4a3f36"), 3)
						else:  # 내려가는 계단
							for k2 in 4:
								draw_line(r.position + Vector2(6, 10 + k2 * 14), r.position + Vector2(ts - 6, 10 + k2 * 14), Color("b8a27a"), 3)
				"s":
					if hsh % 3 == 0:
						draw_rect(Rect2(r.position + Vector2(6 + hsh % 20, 8 + (hsh / 3) % 30), Vector2(18, 12)), Color("c8c0b0"))
				"F":
					draw_rect(Rect2(r.position + Vector2(0, ts * 0.35), Vector2(ts, 8)), Color("8b6640"))
					draw_rect(Rect2(r.position + Vector2(0, ts * 0.65), Vector2(ts, 8)), Color("8b6640"))
					for k2 in 2:
						draw_rect(Rect2(r.position + Vector2(10 + k2 * 32, ts * 0.2), Vector2(10, ts * 0.65)), Color("7a5a3a"))
				"o":  # 분수·우물: 이웃한 칸끼리 한 연못으로 이어진다
					draw_rect(r, Color("a7a7b4"))
					var inner := r.grow(-8)
					if map.ch(Vector2i(x - 1, y)) == "o":
						inner = inner.grow_side(SIDE_LEFT, 8)
					if map.ch(Vector2i(x + 1, y)) == "o":
						inner = inner.grow_side(SIDE_RIGHT, 8)
					if map.ch(Vector2i(x, y - 1)) == "o":
						inner = inner.grow_side(SIDE_TOP, 8)
					if map.ch(Vector2i(x, y + 1)) == "o":
						inner = inner.grow_side(SIDE_BOTTOM, 8)
					draw_rect(inner, Color("8cc6e8"))
					if hsh % 2 == 0:
						draw_circle(c + Vector2(0, -6 + sin(Time.get_ticks_msec() / 200.0) * 3), 5, Color(1, 1, 1, 0.8))
				"f":
					for k2 in 3:
						draw_line(r.position + Vector2(8 + k2 * 22, 10), r.position + Vector2(8 + k2 * 22, ts - 10), Color("6f9a3a"), 4)
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

static func map_texture(m: WorldMap, gates: Dictionary = {}) -> ImageTexture:
	if _map_tex == null:
		var img := Image.create(m.w, m.h, false, Image.FORMAT_RGB8)
		for y in m.h:
			var row := m.rows[y]
			for x in m.w:
				var k := row[x]
				if k == "q":  # 열린 길목은 길 색, 닫힌 길목은 빨갛게(어디서 막혔는지 보이게)
					k = "p" if m.walkable(Vector2i(x, y), gates) else "="
				img.set_pixel(x, y, TILE_COL.get(k, Color.MAGENTA))
		_map_tex = ImageTexture.create_from_image(img)
	return _map_tex


func _build_minimap() -> void:
	_mini = TextureRect.new()
	_map_tex = null
	_mini.texture = map_texture(map, _gates)
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
			var sp: Array = rg["start"]
			var p := Vector2(float(sp[0]), float(sp[1])) / ts * k
			var label := "%d. %s" % [int(rg["stage"]), t("name.stage.s%02d" % int(rg["stage"]))]
			c.draw_string(font, p + Vector2(-60, -6), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, UiKit.INK)
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
	tex.texture = map_texture(map, _gates)
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
