class_name FieldScreen
extends Screen
## 월드맵(X·Y 탑다운): 스테이지 1~10이 한 지도에 있다(data/map/world.json, 04-meta.md 6절). 임시 도형으로 그린다.
## 지역마다 미로처럼 산·바다·호수·절벽·숲·성벽이 길을 가른다. 다음 지역으로 가는 문은 스토리가 열어 줘야 지나간다.
## 조작: 화면 어디든 누르고 끌면 가상 조이스틱, 키보드 방향키도 된다. 가까이 가면 '살펴보기' 버튼이 뜬다.
## 왼쪽 위 미니맵을 누르면 전체 지도가 펼쳐진다.
## 몹은 배회·쫓기·도망 세 가지(FieldMob, data/balance/field.json). 퀘스트 길목(무너진 다리·절벽)은 퀘스트를 마쳐야 지나간다.

const HERO_R := 26.0
const ENEMY_R := 30.0
const TOUCH_R := 110.0
const MINI_SCALE := 0.9  ## 미니맵: 타일 하나당 픽셀(큰 지도)
const CAVE_WALL := Color("3f3934")  ## 동굴 지도의 바위벽
const MINI_H := 144.0  ## 미니맵 높이(동굴 지도도 같은 높이로 크게 그린다)
const TILE_COL := {".": Color("d8eec9"), ",": Color("f3ead8"), "p": Color("d9c59a"), "b": Color("b98c5a"), "=": Color("e9876a"), "q": Color("8c6a4a"),
	"x": Color("f5e7a8"), "s": Color("d9d2c3"), "O": Color("3d3530"), "i": Color("cfe9f5"), "k": Color("8a7d6e"), "c": Color("9a8f86"), "F": Color("c9a874"), "h": Color("b7a48c"), "o": Color("8cc6e8"), "f": Color("b9d77e"),
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
var _fmagic: FieldMagicUse  ## 필드 마법 버튼 2개(07-fun 2절)
var _fbtns: Array[Button] = []
# 필드 사냥(07-fun 1절)
var _run: HuntRun
var _hc: Dictionary  ## data/balance/field_hunt.json
var _uw := UnitWeapons.new()  ## 데리고 다니는 유닛의 무기(07-fun 1절)
var _pals: Array[Dictionary] = []  ## 주인공을 따라다니는 유닛 {unit, pos}
var perf := {}  ## 시간 재기(FPS 표시 옵션): 이름 -> 최근 평균 ms
var _pal_check := 0.0  ## 동행이 바뀌었는지 가끔 본다(유닛 합류·동행 바꾸기가 여러 곳에서 일어난다)
var _trail: Array[Vector2] = []  ## 주인공이 지나온 자리(앞이 최근). 유닛이 이 길을 따라온다
var _facing := Vector2.RIGHT  ## 주인공이 걷는 쪽
var _drops: Array[Dictionary] = []  ## 떨어진 것 {pos, kind: orb|coin|word, v}
var _hunt_lbl: Label
var _lvl_bar: ProgressBar
var _choosing: Control  ## 레벨업 보기 창
var _in_town_now := true
var _spawn_t := 0.0
var _full_t := 0.0
# 돌 밀기 퍼즐(07-fun 3·4절)
var _puz: Array[PushPuzzle] = []
var _push_t := 0.0  ## 마지막으로 돌에 붙어 민 뒤 지난 시간(떨어지면 다시 느리게)
var _push_dur := 0.0  ## 다음 한 칸에 걸리는 시간(이어 밀수록 짧아진다)
var _slides := {}  ## 미끄러지는 돌 "퍼즐id|x,y(도착 칸)" -> {pz, to: Vector2i, a: Vector2, b: Vector2, t, dur, sink}
var _lock: Control  ## 조각 자물쇠 창
var _lock_pick: Array[String] = []
var _lock_fail := 0
const BUILDING_ROOF := {"forge": Color("c0634a"), "board": Color("6f8fd0"), "hospital": Color("f2f2f2"), "tree": Color("4f8f57")}
var _quests: Control
var _quest_btn: Button
var _party_btn: Button
var _home_btn: Button
var _goal_card: Control
var _tut: TutorialOverlay  ## 지금 보이는 튜토리얼(08-tutorial.md)
var _tut_level_btn: Button
var _cave := ""  ## 들어가 있는 동굴 지도 id(07-fun 5절). 비면 큰 지도
var _painter: MapPainter  ## 큰 지도 그리기(풍경·바람·물·산맥, data/map/biomes.json). 동굴이면 null
var _life: MapLife  ## 작은 동물과 날리는 것
var _mv: MapView  ## 지도 그림 조각(한 번 그려 두고 붙인다, 그림 파일이 있으면 그것). 동굴이면 null

static var _map_tex: ImageTexture


func open(args: Dictionary) -> void:
	_rng.randomize()
	_f = GameData.field
	_hc = GameData.hunt_cfg
	_run = GameData.hunt_run()
	_gates = main.flow.open_gates()
	_fmagic = FieldMagicUse.new(_f["magic"])
	var s := GameData.state
	_cave = s.cave
	map = WorldMap.load_cave(_cave) if _cave != "" else null
	if map == null:
		_cave = ""
		map = WorldMap.load_default()
	_hero = s.pos
	if _hero == Vector2.ZERO or not map.fits(_hero, HERO_R, _gates):
		_hero = map.exit_inside(0) if _cave != "" else map.start(GameFlow.STAGE)  # 처음이거나 옛 지도 자리면 마을에서
	_setup_map()
	_in_town_now = map.is_town(_hero)
	if _in_town_now and int(_run.bag()["orbs"]) + int(_run.bag()["coins"]) + (_run.bag()["words"] as Array).size() > 0:
		_in_town_now = false  # 마을에서 시작(병원 등): 주머니를 바로 푼다
		_town_edge.call_deferred()
	_build_hud()
	_build_minimap()
	if args.get("msg", "") != "":
		_show_toast(args["msg"])
	_tutorial.call_deferred("field")
	set_process(true)


## 지금 지도(큰 지도 또는 동굴 지도)에 맞춰 자리·몹·마을 사람·퍼즐을 채운다.
func _setup_map() -> void:
	_enemies.clear()
	_villagers.clear()
	_drops.clear()
	_uw.clear()
	_set_pals()
	_painter = MapPainter.for_map(map) if not map.is_cave else null
	_life = MapLife.new(_painter) if _painter else null
	if _mv:
		_mv.queue_free()
		_mv = null
	if _painter:
		_mv = MapView.new(_painter, UiKit.BG_BLEED)
		add_child(_mv)
		move_child(_mv, 0)
	_puz.clear()
	_spots = []
	if _cave != "":
		for i in int(_f.get("cave_enemies", 5)):
			var ce := _new_enemy()
			if ce:
				_enemies.append(ce)
		for q in map.puzzles:
			if not GameData.puzzles.has(q["id"]):
				GameData.puzzles[q["id"]] = PushPuzzle.from_dict(q)
			_puz.append(GameData.puzzles[q["id"]])
		_sync_blocks()
		return
	_spots = [
		{"id": "forge", "pos": map.spot(1, "forge"), "key": "ui.field.forge", "color": UiKit.APRICOT},
		{"id": "tree", "pos": map.spot(1, "tree"), "key": "ui.field.tree", "color": UiKit.LEAF},
		{"id": "board", "pos": map.spot(1, "board"), "key": "ui.field.order", "color": UiKit.PINK},
		{"id": "hospital", "pos": map.spot(1, "hospital"), "key": "ui.field.hospital", "color": UiKit.BAD},
		{"id": "notice", "pos": map.spot(1, "notice"), "key": "ui.field.notice", "color": UiKit.SKY},
		{"id": "gacha", "pos": map.spot(1, "gacha"), "key": "ui.field.gacha", "color": Color("f6a5c0")},
		{"id": "kid", "pos": map.spot(1, "kid"), "key": "ui.field.kid", "color": Color("ffe3c4")},
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
	for q in map.puzzles:  # 퍼즐 상태는 화면이 바뀌어도 남는다
		if not GameData.puzzles.has(q["id"]):
			GameData.puzzles[q["id"]] = PushPuzzle.from_dict(q)
		_puz.append(GameData.puzzles[q["id"]])
	_sync_blocks()


## 데리고 다니는 유닛(파티 화면에서 고른다)을 주인공 둘레에 둔다.
func _set_pals() -> void:
	_run.set_units(Loadout.companions(GameData.state))
	_pals.clear()
	_trail.clear()
	for u in _run.d["units"]:
		_pals.append({"unit": int(u), "pos": _hero})


func _pal_units() -> Array[int]:
	var out: Array[int] = []
	for pal in _pals:
		out.append(int(pal["unit"]))
	return out


## 동행이 바뀌었을 때: 남은 동행은 자리 그대로, 새로 온 동행은 주인공 자리에서 나온다.
func _sync_pals() -> void:
	_run.set_units(Loadout.companions(GameData.state))
	var old := {}
	for pal in _pals:
		old[int(pal["unit"])] = pal
	_pals.clear()
	for u in _run.d["units"]:
		_pals.append(old.get(int(u), {"unit": int(u), "pos": _hero}))
	if _pals.size() != old.size():
		_trail.clear()


## 유닛은 주인공이 지나온 길을 따라 줄지어 온다(겹치지 않게 간격을 둔다).
func _follow_pals(dir: Vector2, delta: float) -> void:
	if dir.length() > 0.2:
		_facing = dir.normalized()
	if _trail.is_empty() or _trail[0].distance_to(_hero) > 12.0:
		_trail.push_front(_hero)
		if _trail.size() > 60:
			_trail.resize(60)
	for k in _pals.size():
		var gap := (k + 1) * 5
		var to: Vector2 = _trail[mini(gap, _trail.size() - 1)] if not _trail.is_empty() else _hero
		if to.distance_to(_hero) < 40.0 * (k + 1) and _trail.size() <= gap:  # 아직 길이 짧으면 뒤쪽 옆에
			to = _hero - _facing * 46.0 * (k + 1) + _facing.orthogonal() * (18.0 if k % 2 == 0 else -18.0)
		if not map.fits(to, 14.0, _gates):  # 벽 위에는 서지 않는다(벽 너머를 쏘지 않게)
			to = _trail[mini(gap, _trail.size() - 1)] if not _trail.is_empty() else _hero
			if not map.fits(to, 14.0, _gates):
				to = _hero
		var pal := _pals[k]
		pal["pos"] = (pal["pos"] as Vector2).lerp(to, minf(1.0, delta * 8.0))


## 동굴 입구(c)를 밟으면 동굴 지도로, 동굴의 나가는 곳(x)을 밟으면 큰 지도의 그 입구 밖으로.
func _cave_step() -> void:
	var c := map.cell(_hero)
	if _cave == "":
		var mo := map.mouth_at(c)
		if not mo.is_empty():
			_switch_map(String(mo[0]), int(mo[1]))
	else:
		var i := map.exit_at(c)
		if i >= 0:
			_leave_cave(i)


func _leave_cave(i: int) -> void:
	_switch_map("", i)


## 지도를 바꾼다. cave = ""면 큰 지도(직전 동굴의 i번째 입구 밖), 아니면 그 동굴의 i번째 나가는 곳 안쪽.
func _switch_map(cave: String, i: int) -> void:
	var from := _cave
	_cave = cave
	if cave == "":
		map = WorldMap.load_default()
		_hero = map.cave_out(from, i)
	else:
		map = WorldMap.load_cave(cave)
		_hero = map.exit_inside(i)
	_stick_on = false
	_setup_map()
	_map_tex = null
	_mini.texture = map_texture(map, _gates)
	_mini.custom_minimum_size = Vector2(map.w, map.h) * _mini_k()
	_mini.size = _mini.custom_minimum_size
	_remember()
	GameData.save()
	_follow_cam()
	_show_toast(t("ui.cave.enter") if cave != "" else t("ui.cave.leave"))
	queue_redraw()


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
	_quest_btn = UiKit.button(t("ui.menu.quest"), _open_quests, UiKit.APRICOT, 22)
	right.add_child(_quest_btn)
	right.add_child(UiKit.button(t("ui.menu.dex"), func() -> void: _go(main.flow.go_dex), UiKit.LEAF, 22))
	_party_btn = UiKit.button(t("ui.menu.party"), func() -> void: _go(main.flow.go_party), UiKit.SKY, 22)
	right.add_child(_party_btn)
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
	gc.position = Vector2(16, 150 + MINI_H + 10)
	_goal_card = gc
	_rest = UiKit.label("", 22, UiKit.BAD.darkened(0.2))
	var rc := UiKit.card(Color("fff4dc"))
	rc.add_child(_rest)
	add_child(rc)
	rc.position = Vector2(16, 150 + MINI_H + 10 + 48)
	rc.visible = false
	_rest.set_meta("card", rc)
	var hc := UiKit.card(Color("f3ecff"))
	var hv := UiKit.vbox(2)
	hc.add_child(hv)
	_hunt_lbl = UiKit.label("", 18)
	hv.add_child(_hunt_lbl)
	_lvl_bar = ProgressBar.new()
	_lvl_bar.custom_minimum_size = Vector2(220, 10)
	_lvl_bar.show_percentage = false
	hv.add_child(_lvl_bar)
	add_child(hc)
	UiKit.pin(hc, 1, 0, -16, 150)
	_hunt_lbl.set_meta("card", hc)
	_update_hunt_hud()
	var home := UiKit.button(t("ui.field.home"), _go_home, UiKit.PAPER, 24)
	_home_btn = home
	home.custom_minimum_size = Vector2(150, 70)
	add_child(home)
	UiKit.thumb(home, 0.0)  # 엄지 자리 왼쪽
	# 필드 마법 버튼: 엄지 자리 바로 위 오른쪽, 장착한 2개
	var mrow := UiKit.hbox(10)
	add_child(mrow)
	var slots := Loadout.field(GameData.state)
	for i in slots.size():
		var id := slots[i]
		var b := UiKit.button(GameText.field_magic_name(id).split(" ")[0] if id != "" else "", func() -> void: _cast(id), UiKit.SKY.lightened(0.2), 20)
		b.custom_minimum_size = Vector2(150, 64)
		b.visible = id != ""
		b.set_meta("id", id)
		mrow.add_child(b)
		_fbtns.append(b)
	UiKit.pin(mrow, 1, 1, -24, -(UiKit.THUMB_ROW + UiKit.THUMB_H + 20))
	_act_btn = UiKit.button("", _act, UiKit.ACCENT.lightened(0.4), 28)
	_act_btn.custom_minimum_size = Vector2(260, 80)
	_act_btn.visible = false
	add_child(_act_btn)
	UiKit.thumb(_act_btn, 1.0)  # 엄지 자리
	_toast = UiKit.label("", 26)
	_toast.custom_minimum_size = Vector2(640, 0)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tb := UiKit.box(Color(0.25, 0.25, 0.3, 0.72), 16, 0)  # 반투명 회색 바탕 + 밝은 글씨(사용자 의견): 어디서나 보이게
	_toast.add_theme_color_override("font_color", Color.WHITE)
	tb.content_margin_left = 14
	tb.content_margin_right = 14
	tb.content_margin_top = 8
	tb.content_margin_bottom = 8
	_toast.add_theme_stylebox_override("normal", tb)
	_toast.visible = false
	add_child(_toast)
	UiKit.pin(_toast, 0.5, 0, 0, 150 + MINI_H + 70)  # 미니맵·할 일 아래(가리지 않게)
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
	if book.boss_blockers(s, GameFlow.STAGE).is_empty():
		return t("ui.quest.all_done")  # 보스 앞 퀘스트를 다 마쳤다(마을 아이 같은 곁 퀘스트는 목록에 남는다)
	if q.is_empty():
		return t("ui.quest.goal_none")
	if q["kind"] == "words" and not main.flow.seen(String(q["id"]) + "_got"):
		return t("ui.quest.goal_board")
	return t("ui.quest.%s.title" % q["id"])


func _go(f: Callable) -> void:
	_remember()
	f.call()


func _remember() -> void:
	GameData.state.pos = _hero
	GameData.state.cave = _cave
	GameData.state.place = "town" if map.is_town(_hero) else "field"


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = text != ""
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
	var w0 := GameData.repo.get_word(m.words[0]) if not m.words.is_empty() else null
	m.attr = int(w0.attrs[0]) if w0 and not w0.attrs.is_empty() else 0
	m.slot = w0.slot if w0 else ""
	m.max_hp = _run.mob_hp(m.kind)  # 레벨이 올라도 한 방에 죽지 않는다
	m.hp = m.max_hp
	return m


## 조우 단어: 그 스테이지 필드 1차, 빈도가 높을수록 자주(01-rpg-base '희귀도'). 다시 잡을 단어가 있으면 섞는다.
## rare(도망가는 몹)면 거꾸로 드문 단어일수록 자주.
func _pick_words(rare := false) -> Array[String]:
	var pool := GameData.repo.first_tier(GameFlow.STAGE, "field")
	if _rng.randf() < float(GameData.learning["learned_mix"]):  # 유추 연습: 배운 조각이 든 단어를 절반쯤(06-learning.md 5절)
		var lp := pool.filter(func(w: WordData) -> bool: return GameData.curriculum.has_learned(w, GameFlow.STAGE))
		if lp.size() >= GameData.rules.team_size(GameData.state):
			pool.assign(lp)
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
	var t0 := Time.get_ticks_usec()
	_step(delta)
	if _mv:
		var st := GameData.settings  # 옵션에서 지도 효과를 하나씩 끈다(04-meta.md 2절)
		_mv.on_grass = st.map_grass
		_mv.on_sway = st.map_sway
		_mv.on_water = st.map_water
		_mv.update(_cam, size, Time.get_ticks_msec() / 1000.0, _gates)
	_perf("tick", t0)


func _step(delta: float) -> void:
	if _busy or _full or _quests or _choosing or _lock or (_tut and is_instance_valid(_tut)):
		_follow_cam()  # 멈춰 있어도 화면은 주인공을 비춘다(튜토리얼이 가리킬 자리가 맞게)
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if _stick_on:
		dir = _stick_vec
	var was_town := map.is_town(_hero)
	var before := _hero
	_hero = map.move(_hero, dir * float(_f["hero_speed"]) * _run.speed_mult() * delta, HERO_R, _gates)
	_puzzle_step(dir, before, delta)
	_cave_step()
	if _life:
		var st := GameData.settings
		_life.on_critters = st.map_critters
		_life.on_particles = st.map_particles
		_life.update(delta, _hero, _cam, size, Time.get_ticks_msec() / 1000.0)
	_pal_check -= delta
	if _pal_check <= 0.0:
		_pal_check = 0.5
		if _pal_units() != Loadout.companions(GameData.state):
			_sync_pals()
	_follow_pals(dir, delta)
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
	_fmagic.tick(delta)
	for b in _fbtns:
		var id: String = b.get_meta("id")
		if id == "":
			continue
		var cd := float(_fmagic.cool.get(id, 0.0))
		b.text = GameText.field_magic_name(id).split(" ")[0] + ("  %d" % ceili(cd) if cd > 0.0 else "")
		b.modulate = Color(1, 1, 1, 0.5) if cd > 0.0 else Color.WHITE
	for v in _villagers:  # 마을 사람: 마을 안에서만 천천히
		var vv := v.steer(_hero, delta, _f["kinds"], _rng) * 0.5
		var vp: Vector2 = map.move(v.pos, vv * delta, ENEMY_R)
		if map.is_town(vp):
			v.pos = vp
	if was_town and not map.is_town(_hero) and map.stage_at(_hero) == GameFlow.STAGE:
		main.flow.entered_field()
	_town_edge()
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
	_update_hunt_hud()
	if not map.is_town(_hero):
		_hunt(delta)
	for i in _enemies.size():
		var e := _enemies[i]
		if e.pos.distance_to(_hero) > float(_f["spawn_far"]) and e.kind != "eater":  # 멀어진 적은 가까이에 다시
			var ne := _new_enemy()
			if ne:
				_enemies[i] = ne
			continue
		e.ignore = _fmagic.sneak > 0.0
		var kinds: Dictionary = _f["kinds"].duplicate()
		kinds["eater"] = {"speed": _hc["eater"]["speed"]}
		var v := e.steer(_hero, delta, kinds, _rng)
		if e.has_meta("push"):  # ob-: 밀쳐진 몹은 0.3초 동안 날아간다
			v = (e.get_meta("push") as Vector2) / 0.3
			var pt := float(e.get_meta("push_t", 0.3)) - delta
			e.set_meta("push_t", pt)
			if pt <= 0.0:
				e.remove_meta("push")
				e.remove_meta("push_t")
		var np: Vector2 = map.move(e.pos, v * delta, ENEMY_R)
		if e.kind == "eater":  # 뿌리먹이는 벽에 걸려도 미끄러지며 계속 온다(벽을 넘지 않고, 마을에는 못 들어온다)
			var ep := np if np != e.pos else map.move(e.pos, v.rotated(0.8) * delta, ENEMY_R)
			if not map.is_town(ep):
				e.pos = ep
		elif not map.is_town(np) and map.stage_at(np) == GameFlow.STAGE:
			e.pos = np
		if e.pos.distance_to(_hero) < HERO_R + ENEMY_R and _fmagic.sneak <= 0.0 and e.stun <= 0.0 and not map.is_town(_hero):
			_busy = true
			_remember()
			main.flow.encounter(e.words, 0, [], {"hurt": snappedf(e.hurt_ratio(), 0.01), "hard": e.kind == "eater"})
			if e.kind == "eater":
				_enemies.remove_at(i)
			return
	_near = {}
	for sp in _spots:
		if (sp["pos"] as Vector2).distance_to(_hero) < TOUCH_R:
			_near = sp
	if _near.is_empty():
		for pz in _puz:
			for c in pz.chests:
				var cp := (Vector2(c) + Vector2(0.5, 0.5)) * map.tile
				if cp.distance_to(_hero) < TOUCH_R:
					_near = {"id": "chest", "key": "ui.puz.chest", "puz": pz}
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
			_toast.visible = false
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
		"gacha":
			main.flow.go_gacha()
		"kid":
			_busy = true
			_stick_on = false
			main.flow.kid_talk(func() -> void:
				_busy = false
				_update_top())
		"chest":
			_open_chest(_near["puz"])
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


## 필드 마법을 쓴다(07-fun 2절). de-는 절벽 길목 가까이면 내려가기(퀘스트), re-는 마을로.
func _cast(id: String) -> void:
	if _busy or id == "":
		return
	if not _fmagic.implemented(id):
		_show_toast(t("ui.field.magic_soon"))
		return
	if not _fmagic.ready(id):
		return
	if id == "de":
		var qg := map.touching_quest(_hero, HERO_R + 90.0, _gates)
		if qg == "s01_q_magic":
			_fmagic.use(id, _hero, [])
			_busy = true
			_remember()
			var hint: String = main.flow.quest_gate(qg, _quest_done)
			if hint != "":
				_busy = false
				_show_toast(hint)
			return
	if id == "re":
		_fmagic.use(id, _hero, [])
		_go_home()
		return
	if id == "ex":  # 동굴에서 바로 밖으로
		if map.in_cave(_hero):
			_fmagic.use(id, _hero, [])
			_leave_cave(map.nearest_exit(_hero))
		return
	if id == "com":  # 떨어진 것을 모두 끌어온다
		for dr in _drops:
			dr["pos"] = _hero + Vector2.from_angle(_rng.randf() * TAU) * 20.0
	_fmagic.use(id, _hero, _enemies)
	_show_toast(t("ui.field.magic_used").format({"magic": GameText.field_magic_name(id)}))
	queue_redraw()


# ----- 필드 사냥(07-fun 1절) -----

## 마을 경계를 넘을 때: 들어가면 주머니를 풀고(내 것이 된다), 나서면 새 나들이.
func _town_edge() -> void:
	var now := map.is_town(_hero)
	if now == _in_town_now:
		return
	_in_town_now = now
	if now:
		var got := _run.bank(GameData.state, GameData.rules)
		_uw.clear()
		_drops.clear()
		if int(got["orbs"]) + int(got["coins"]) + (got["words"] as Array).size() > 0:
			GameData.save()
			_show_toast(t("ui.hunt.banked").format({"orbs": got["orbs"], "coins": got["coins"], "words": (got["words"] as Array).size(), "wallet": GameData.state.wallet}))
		_enemies = _enemies.filter(func(e: FieldMob) -> bool: return e.kind != "eater")
	else:
		_sync_pals()  # 마을에서 유닛이 새로 들어왔거나 동행을 바꿨으면 보이는 동행도 같이 바꾼다(공격만 바뀌던 버그)
		_run.reset()
		_uw.clear()
		_tutorial("hunt")


func _hunt(delta: float) -> void:
	# 뿌리먹이
	if _run.tick(delta):
		_spawn_eater()
	# 무기: 데리고 다니는 유닛이 저마다 쏜다. 몹은 주인공에게 온다
	var origins := {}
	for pal in _pals:
		origins[_run.weapon_of(int(pal["unit"]))] = pal["pos"]
	_uw.no_fire_near = float(_hc["no_fire_near"])
	for h in _uw.tick(delta, _run.weapons_now(), origins, _hero, _facing, _enemies, map):
		_hit(h["mob"], int(h["dmg"]), h["from"], float(h.get("push", 0.0)), float(h.get("stun", 0.0)))
	# 떨어진 것: 가까우면 빨려 오고, 닿으면 줍는다
	for dr in _drops.duplicate():
		var dd: Vector2 = _hero - (dr["pos"] as Vector2)
		if dd.length() < _run.magnet():
			dr["pos"] = (dr["pos"] as Vector2) + dd.normalized() * minf(dd.length(), 640.0 * delta)
		if dd.length() < HERO_R + 10:
			_drops.erase(dr)
			match String(dr["kind"]):
				"orb":
					if _run.pick_orbs(int(dr["v"])):
						_open_level_up()
						if _run.max_level():
							_show_toast(t("ui.hunt.level_max"))
				"coin":
					if _run.pick_coins(int(dr["v"])):
						_full_t = 20.0
						_show_toast(t("ui.hunt.coins_full").format({"cap": _run.coin_cap()}))
				"word":
					_run.pick_word(String(dr["v"]))
					_show_toast(t("ui.hunt.word").format({"word": dr["v"]}))
	# 레벨이 오르면 몹이 더 많이 나온다
	_spawn_t -= delta
	if _spawn_t <= 0.0 and _enemies.filter(func(e: FieldMob) -> bool: return e.kind != "eater").size() < _run.mob_count(_base_count()):
		_spawn_t = 0.4
		var ne := _new_enemy()
		if ne:
			_enemies.append(ne)
	# 주머니 코인이 가득: 잊지 않게 가끔 다시 알린다
	_full_t -= delta
	if _run.coins_full() and _full_t <= 0.0:
		_full_t = 20.0
		_show_toast(t("ui.hunt.coins_full").format({"cap": _run.coin_cap()}))


## 사냥 칸: 마을 밖이면 사냥 레벨·주머니, 마을 안이면 내 코인(지갑)만. 내 코인은 언제나 보인다.
func _update_hunt_hud() -> void:
	var town := map.is_town(_hero)
	var b := _run.bag()
	if town:
		_hunt_lbl.text = t("ui.hunt.hud_town").format({"wallet": GameData.state.wallet})
	else:
		_hunt_lbl.text = t("ui.hunt.hud").format({"lv": (t("ui.hunt.max") if _run.max_level() else str(_run.level())),
			"wallet": GameData.state.wallet, "orbs": b["orbs"], "coins": b["coins"], "cap": _run.coin_cap(), "words": (b["words"] as Array).size()})
	_lvl_bar.visible = not town
	_lvl_bar.max_value = _run.need()
	_lvl_bar.value = _run.need() if _run.max_level() else int(_run.d["exp"])


func _base_count() -> int:
	return int(_f.get("cave_enemies", 5)) if _cave != "" else int(_f["enemy_count"])


## 맞음: push > 0이면 그만큼, 0이면 기본만큼 뒤로 밀려나고, < 0이면 밀리지 않는다(붙잡힘). stun초 동안 멈춘다.
func _hit(e: FieldMob, dmg: int, from: Vector2, push := 0.0, stun := 0.0) -> void:
	if not _enemies.has(e):
		return
	var dead := e.take_hit(dmg)
	if stun > 0.0 and e.kind != "eater":
		e.stun = maxf(e.stun, stun)
	if e.kind != "eater" and push >= 0.0:  # 맞으면 뒤로 밀려난다(0.3초)
		var away := e.pos - from
		if away.length() < 1.0:
			away = e.pos - _hero
		e.set_meta("push", (away.normalized() if away.length() > 0.5 else Vector2.RIGHT) * (push if push > 0.0 else float(_hc["knockback"])))
		e.set_meta("push_t", 0.3)
	if dead:
		var got := _run.drops(e.kind, e.words, _rng)
		_drops.append({"pos": e.pos, "kind": "orb", "v": got["orbs"]})
		if int(got["coins"]) > 0:
			_drops.append({"pos": e.pos + Vector2(14, 6), "kind": "coin", "v": got["coins"]})
		if got["word"] != "":
			_drops.append({"pos": e.pos + Vector2(-14, 6), "kind": "word", "v": got["word"]})
		var i := _enemies.find(e)
		var ne := _new_enemy()
		if ne:
			_enemies[i] = ne
		else:
			_enemies.remove_at(i)


func _spawn_eater() -> void:
	var m := FieldMob.new()
	m.kind = "eater"
	m.max_hp = int(_hc["mob_hp"]["eater"])
	m.hp = m.max_hp
	var p := map.random_field_spot(GameFlow.STAGE, _rng, _hero, 800, 1100, ENEMY_R)
	if p == Vector2.INF:
		_run.d["eaters"] = maxi(0, int(_run.d["eaters"]) - 1)  # 설 자리가 없으면 다음에 다시
		return
	m.pos = p
	var pool := GameData.repo.first_tier(GameFlow.STAGE, "field").filter(func(w: WordData) -> bool: return GameData.curriculum.has_learned(w, GameFlow.STAGE))
	for k in int(_hc["eater"]["words"]):
		if not pool.is_empty():
			m.words.append((pool[_rng.randi_range(0, pool.size() - 1)] as WordData).id)
	_enemies.append(m)
	_show_toast(t("ui.hunt.eater"))
	GameData.vibrate(true)


## 레벨업: 보기 3개(무기 새로·강화, 이동 속도, 구슬 끌기) 중 하나. 고르는 동안 필드는 멈춘다.
func _open_level_up() -> void:
	var cs := _run.choices(_rng)
	_stick_on = false
	_choosing = Control.new()
	_choosing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choosing.mouse_filter = Control.MOUSE_FILTER_STOP
	_choosing.z_index = 25
	add_child(_choosing)
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.13, 0.22, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_top = -UiKit.BG_BLEED
	dim.offset_bottom = UiKit.BG_BLEED
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choosing.add_child(dim)
	_choosing.set_meta("first", true)
	var v := UiKit.vbox(14)
	v.position = Vector2(60, 360)
	v.custom_minimum_size.x = 600
	_choosing.add_child(v)
	var title := UiKit.label(t("ui.hunt.level_up").format({"lv": _run.level()}), 34, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	for c in cs:
		var ch: Dictionary = c
		var txt := t("ui.hunt.pick_" + String(ch["type"])).format({"w": t("ui.hunt.weapon." + String(ch["id"])) if ch["id"] != "" else ""})
		var b := UiKit.button(txt, func() -> void:
			_run.apply(ch)
			_choosing.queue_free()
			_choosing = null, UiKit.APRICOT.lightened(0.3), 26)
		b.custom_minimum_size = Vector2(600, 96)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(b)
		if _choosing.get_meta("first", false):
			_choosing.set_meta("first", false)
			_tut_level_btn = b
	_tutorial.call_deferred("level_up")


# ----- 돌 밀기 퍼즐 -----

## 돌·상자는 막고, 메운 물·구멍은 지나간다(WorldMap이 이 표를 본다).
func _sync_blocks() -> void:
	map.extra_block.clear()
	map.extra_walk.clear()
	for pz in _puz:
		for c in pz.rocks:
			map.extra_block[c] = true
		for c in pz.chests:
			map.extra_block[c] = true
		for c in pz.filled:
			map.extra_walk[c] = true


## 밀기(돌에 붙어 0.3초), 숨은 쪽지 줍기, 구역을 벗어나면 되돌리기.
func _puzzle_step(dir: Vector2, before: Vector2, delta: float) -> void:
	var hc := map.cell(_hero)
	var pushed := false
	if map.in_cave(_hero):
		_tutorial("cave")
	for pz in _puz:
		if Rect2i(pz.origin, pz.size).has_point(hc) and not pz.rocks.is_empty():
			_tutorial("puzzle", pz)
	_slide_rocks(delta)
	if dir.length() > 0.3:  # 돌에 붙어 밀면 바로 밀린다. 이어 밀면 조금씩 빨라진다(그래도 느리게)
		var d := Vector2i(signi(roundi(dir.x)), 0) if absf(dir.x) >= absf(dir.y) else Vector2i(0, signi(roundi(dir.y)))
		var front := map.cell(_hero + Vector2(d) * (HERO_R + 32))
		for pz in _puz:
			if pz.rocks.has(front) and not _slides.has(_slide_key(pz, front)):
				var rp := (Vector2(front) + Vector2(0.5, 0.5)) * map.tile
				if _hero.distance_to(rp) > HERO_R + map.tile * 0.44 + 10.0 and _hero.distance_to(before) > 0.5:
					continue  # 아직 닿지 않았다
				pushed = true
				var rp_cfg: Dictionary = _f["rock_push"]
				if _push_t > 0.25 or _push_dur <= 0.0:
					_push_dur = float(rp_cfg["first"])
				var heavy: String = pz.rocks[front]
				var had_filled := pz.filled.size()
				if pz.push(front, d, "com" in GameData.state.magics):
					var to := _rock_landing(pz, front, d, had_filled)
					var cells := maxi(1, absi(to.x - front.x) + absi(to.y - front.y))
					var dur := _push_dur + float(rp_cfg["ice_cell"]) * (cells - 1)
					_slides[_slide_key(pz, to)] = {"pz": pz, "to": to, "a": rp, "b": (Vector2(to) + Vector2(0.5, 0.5)) * map.tile,
						"t": 0.0, "dur": dur, "sink": pz.filled.size() > had_filled, "kind": heavy}
					_push_dur = maxf(float(rp_cfg["min"]), _push_dur * float(rp_cfg["faster"]))
					_sync_blocks()
					GameData.vibrate()
				elif heavy == "H" and not "com" in GameData.state.magics:
					_show_toast(t("ui.puz.heavy"))
	if pushed or not _slides.is_empty():
		_push_t = 0.0
	else:
		_push_t += delta
	for it in map.items:  # 동굴의 퀘스트 물건
		if Vector2i(int(it["cell"][0]), int(it["cell"][1])) == hc and not it["id"] in GameData.state.items:
			GameData.state.items.append(it["id"])
			GameData.save()
			_show_toast(t("ui.cave.item"))
	for pz in _puz:
		for sc in pz.secrets:  # 숨은 쪽지: 돌이 비킨 자리를 밟으면 줍는다
			if sc == hc and not pz.rocks.has(sc) and pz.note != "" and not pz.note in GameData.state.notes:
				GameData.state.notes.append(pz.note)
				GameData.save()
				var pc: Dictionary = GameData.curriculum.pieces.get(pz.note, {})
				_show_toast(t("ui.puz.note").format({"piece": String(pc.get("name", pz.note)), "meaning": String(pc.get("meaning", ""))}))
		var r := Rect2i(pz.origin - Vector2i(3, 3), pz.size + Vector2i(6, 6))
		if not r.has_point(hc) and not GameData.state.flags.get("chest_" + pz.id, false) and (pz.rocks.hash() != pz._start_rocks.hash() or not pz.filled.is_empty()):
			pz.reset()  # 구역을 벗어나면 처음으로(막혀서 못 푸는 일이 없게)
			for k in _slides.keys():
				if _slides[k]["pz"] == pz:
					_slides.erase(k)
			_sync_blocks()


func _slide_key(pz: PushPuzzle, c: Vector2i) -> String:
	return "%s|%d,%d" % [pz.id, c.x, c.y]


## 밀린 돌이 멈춘 칸: 물·구멍에 빠졌으면 그 칸, 아니면 돌이 새로 놓인 칸(얼음이면 미끄러진 끝).
func _rock_landing(pz: PushPuzzle, from: Vector2i, d: Vector2i, had_filled: int) -> Vector2i:
	var c := from + d
	if pz.filled.size() > had_filled:
		while not pz.filled.has(c) and pz.contains(c + d):
			c += d
		return c
	while not pz.rocks.has(c) and pz.contains(c + d):
		c += d
	return c


## 미끄러지는 돌: 그리는 자리를 옮기고, 주인공은 그 돌을 뚫고 지나가지 못한다(돌 뒤를 따라간다).
func _slide_rocks(delta: float) -> void:
	for k in _slides.keys():
		var sl: Dictionary = _slides[k]
		sl["t"] = float(sl["t"]) + delta
		if float(sl["t"]) >= float(sl["dur"]):
			_slides.erase(k)
			continue
		var rp := _slide_pos(sl)
		var gap := HERO_R + map.tile * 0.44
		if _hero.distance_to(rp) < gap:
			_hero = rp + (_hero - rp).normalized() * gap


func _slide_pos(sl: Dictionary) -> Vector2:
	var k := clampf(float(sl["t"]) / float(sl["dur"]), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)  # 부드럽게 출발하고 멈춘다
	return (sl["a"] as Vector2).lerp(sl["b"], k)


func _open_chest(pz: PushPuzzle) -> void:
	var s := GameData.state
	if s.flags.get("chest_" + pz.id, false):
		_show_toast(t("ui.puz.opened"))
		return
	if not pz.chest_ready():
		_show_toast(t("ui.puz.plates"))
		return
	if pz.kind == "lock":
		_open_lock(pz)
		return
	s.flags["chest_" + pz.id] = true
	_show_toast(main.flow.give_treasure(pz.reward))


## 조각 자물쇠(07-fun 4절): 답 단어의 뜻이 그림으로 새겨져 있고, 주운 쪽지 조각을 차례로 눌러 그 단어를 만든다.
func _open_lock(pz: PushPuzzle) -> void:
	_stick_on = false
	_lock_pick.clear()
	_lock = Control.new()
	_lock.tree_entered.connect(func() -> void: _tutorial.call_deferred("lock"))
	_lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lock.mouse_filter = Control.MOUSE_FILTER_STOP
	_lock.z_index = 25
	add_child(_lock)
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.13, 0.22, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_top = -UiKit.BG_BLEED
	dim.offset_bottom = UiKit.BG_BLEED
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock.add_child(dim)
	var card := UiKit.card()
	card.custom_minimum_size = Vector2(640, 0)
	card.position = Vector2(40, 300)
	_lock.add_child(card)
	var v := UiKit.vbox(12)
	card.add_child(v)
	v.add_child(UiKit.label(t("ui.puz.lock_title"), 30, UiKit.ACCENT.darkened(0.3)))
	var w := GameData.repo.get_word(pz.answer)
	v.add_child(UiKit.wrap(UiKit.label(t("ui.puz.lock_clue").format({"meaning": w.meaning}), 22), 600))
	var slots := UiKit.label("", 34)
	slots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(slots)
	var want := GameData.curriculum.pieces_of(w)
	var show := func() -> void:
		var bits: Array[String] = []
		for k in want.size():
			bits.append(_piece_form(_lock_pick[k]) if k < _lock_pick.size() else "＿")
		slots.text = " + ".join(bits)
	show.call()
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	v.add_child(row)
	if GameData.state.notes.is_empty():
		v.add_child(UiKit.label(t("ui.puz.lock_none"), 20, UiKit.BAD.darkened(0.2)))
	for n in GameData.state.notes:
		var pid := String(n)
		row.add_child(UiKit.button(_piece_form(pid), func() -> void:
			if _lock_pick.size() >= want.size():
				return
			_lock_pick.append(pid)
			show.call()
			if _lock_pick.size() == want.size():
				if _lock_pick == want:
					GameData.state.flags["chest_" + pz.id] = true
					_close_lock()
					_show_toast(main.flow.give_treasure(pz.reward))
				else:
					_lock_fail += 1
					_lock_pick.clear()
					show.call()
					_show_toast(t("ui.puz.lock_wrong") + (("  " + t("ui.puz.lock_hint").format({"piece": _piece_form(want[0])})) if _lock_fail >= 3 else "")), UiKit.SKY, 26))
	var nav := UiKit.hbox(10)
	v.add_child(nav)
	nav.add_child(UiKit.button(t("ui.puz.lock_reset"), func() -> void:
		_lock_pick.clear()
		show.call(), UiKit.PAPER, 22))
	nav.add_child(UiKit.button(t("ui.puz.lock_close"), _close_lock, UiKit.PAPER, 22))


func _close_lock() -> void:
	if _lock:
		_lock.queue_free()
		_lock = null


func _piece_form(pid: String) -> String:
	var pc: Dictionary = GameData.curriculum.pieces.get(pid, {})
	var fs: Array = pc.get("forms", [])
	return "%s(%s)" % [String(fs[0]) if not fs.is_empty() else pid, String(pc.get("meaning", ""))]


func _draw_puzzles(o: Vector2) -> void:
	var ts := float(map.tile)
	for pz in _puz:
		var r := Rect2(o + Vector2(pz.origin) * ts, Vector2(pz.size) * ts)
		if not r.grow(ts).intersects(Rect2(Vector2.ZERO, size)):
			continue
		for c in pz.plates:  # 발판
			var pr := Rect2(o + Vector2(c) * ts, Vector2(ts, ts)).grow(-8)
			draw_rect(pr, Color("c8c0b0"))
			draw_rect(pr, Color("f5c542") if pz.rocks.has(c) else UiKit.INK, false, 4)
		for c in pz.filled:  # 메운 물·구멍
			draw_rect(Rect2(o + Vector2(c) * ts, Vector2(ts, ts)), Color("a89c8c"))
		for c in pz.secrets:  # 드러난 쪽지
			if not pz.rocks.has(c) and not pz.note in GameData.state.notes:
				var sp := o + (Vector2(c) + Vector2(0.5, 0.5)) * ts
				draw_rect(Rect2(sp - Vector2(12, 9), Vector2(24, 18)), Color("fff4dc"))
				draw_circle(sp + Vector2(14, -14), 4 + 2 * sin(Time.get_ticks_msec() / 150.0), Color("f5c542"))
		for c in pz.chests:  # 보물 상자(자물쇠 상자는 자물쇠 그림)
			var cp := o + (Vector2(c) + Vector2(0.5, 0.5)) * ts
			var opened: bool = GameData.state.flags.get("chest_" + pz.id, false)
			draw_rect(Rect2(cp - Vector2(24, 16), Vector2(48, 34)), Color("a46a3a"))
			draw_rect(Rect2(cp - Vector2(24, 16), Vector2(48, 34)), UiKit.INK, false, 3)
			if opened:
				draw_rect(Rect2(cp - Vector2(24, 28), Vector2(48, 10)), Color("7a4a2a"))
			else:
				draw_rect(Rect2(cp - Vector2(24, 18), Vector2(48, 8)), Color("c58a4a"))
				draw_circle(cp + Vector2(0, -2), 6, Color("f5c542") if pz.chest_ready() else UiKit.GRAY)
				if pz.kind == "lock":
					draw_arc(cp + Vector2(0, -12), 9, PI, TAU, 10, UiKit.INK, 3)
		for k in _slides:  # 물·구멍으로 미끄러져 빠지는 돌(빠질 때까지 보인다)
			var sl: Dictionary = _slides[k]
			if sl["pz"] == pz and sl["sink"]:
				var sp2 := o + _slide_pos(sl)
				var fade := 1.0 - clampf(float(sl["t"]) / float(sl["dur"]), 0.0, 1.0) * 0.6
				draw_circle(sp2, ts * 0.44 * fade, Color("9a948e"))
				draw_arc(sp2, ts * 0.44 * fade, 0, TAU, 24, UiKit.INK, 3)
		for c in pz.rocks:  # 돌(밀리는 중이면 미끄러지는 자리에)
			var sk := _slide_key(pz, c)
			var rp := o + (_slide_pos(_slides[sk]) if _slides.has(sk) else (Vector2(c) + Vector2(0.5, 0.5)) * ts)
			var heavy: bool = pz.rocks[c] == "H"
			draw_circle(rp, ts * 0.44, Color("6f6a66") if heavy else Color("9a948e"))
			draw_arc(rp, ts * 0.44, 0, TAU, 24, UiKit.INK, 3)
			draw_circle(rp + Vector2(-8, -8), 6, Color(1, 1, 1, 0.3))
			if heavy:
				draw_line(rp + Vector2(-18, 4), rp + Vector2(18, 4), UiKit.INK, 3)
				draw_line(rp + Vector2(-14, 12), rp + Vector2(14, 12), UiKit.INK, 3)


# ----- 튜토리얼(08-tutorial.md) -----

## 대사·알림 창이 떠 있으면 다 닫힐 때까지 기다렸다가, 처음이면 그 튜토리얼을 보인다.
func _tutorial(id: String, arg: Variant = null) -> void:
	if _tut and is_instance_valid(_tut):
		return
	if not TutorialBook.should(GameData.state, id, GameData.tutorials_enabled):
		return
	while main._overlay.get_child_count() > 0:
		await get_tree().process_frame
		if not is_instance_valid(self):
			return
	var hero_rect := func() -> Rect2: return Rect2(get_global_transform_with_canvas() * (_hero - _cam) - Vector2(48, 60), Vector2(96, 110))
	var steps: Array[Dictionary] = []
	match id:
		"field":
			steps = [
				{"target": hero_rect, "text": "tut.field.move", "mode": "any"},
				{"target": _mini, "text": "tut.field.minimap", "mode": "any"},
				{"target": _goal_card, "text": "tut.field.goal", "mode": "any"},
				{"target": _home_btn, "text": "tut.field.home", "mode": "any"},
				{"target": _party_btn, "text": "tut.field.party", "mode": "any"},
				{"target": _quest_btn, "text": "tut.field.quest", "mode": "tap"},
			]
			var fb: Array = _fbtns.filter(func(b: Button) -> bool: return b.visible)
			if not fb.is_empty():
				steps.insert(5, {"target": fb[0], "text": "tut.field.magic", "mode": "any"})
		"hunt":
			steps = [
				{"target": hero_rect, "text": "tut.hunt.auto", "mode": "any"},
				{"target": _hunt_lbl.get_meta("card"), "text": "tut.hunt.bag", "mode": "any"},
			]
		"level_up":
			if _tut_level_btn == null:
				return
			steps = [{"target": _tut_level_btn, "text": "tut.hunt.level_up", "mode": "tap"}]
		"puzzle":
			var pz: PushPuzzle = arg
			var rk: Vector2i = pz.rocks.keys()[0]
			var rock_rect := func() -> Rect2: return Rect2(get_global_transform_with_canvas() * (Vector2(rk) * map.tile - _cam), Vector2(map.tile, map.tile))
			steps = [{"target": rock_rect, "text": "tut.puzzle.push", "mode": "any"}, {"target": hero_rect, "text": "tut.puzzle.reset", "mode": "any"}]
		"cave":
			steps = [{"target": hero_rect, "text": "tut.cave", "mode": "any"}]
		"lock":
			if _lock == null:
				return
			steps = [{"target": _lock.get_child(1), "text": "tut.lock", "mode": "any"}]
	if steps.is_empty():
		return
	_stick_on = false
	_tut = TutorialOverlay.run(self, id, steps)


func _follow_cam() -> void:
	_cam = (_hero - size / 2).clamp(Vector2.ZERO, (map.size_px() - size).max(Vector2.ZERO))
	queue_redraw()


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
	if _cave != "":
		_switch_map("", 0)
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
	if not GameData.state.notes.is_empty():  # 가방: 주운 쪽지(조각 사전)
		var ns: Array[String] = []
		for n in GameData.state.notes:
			ns.append(_piece_form(String(n)))
		var nl := UiKit.label(t("ui.quest.notes").format({"list": ", ".join(ns)}), 20, UiKit.ACCENT.darkened(0.3))
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size.x = 600
		v.add_child(nl)
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

func _perf(key: String, t0: int) -> int:
	var now := Time.get_ticks_usec()
	perf[key] = lerpf(float(perf.get(key, 0.0)), (now - t0) / 1000.0, 0.1)
	return now


func _draw() -> void:
	var p0 := Time.get_ticks_usec()
	var o := -_cam
	# 화면 위아래 여백(Main)까지 땅색으로
	var tnow := Time.get_ticks_msec() / 1000.0
	if _mv:  # 지도는 MapView(뒤에 먼저 그려진다)
		p0 = _perf("map", p0)
		_life.draw_critters(self, o, tnow)
	else:
		draw_rect(Rect2(-20, -UiKit.BG_BLEED, size.x + 40, size.y + UiKit.BG_BLEED * 2), CAVE_WALL)
		_draw_tiles(o)
		p0 = _perf("map", p0)
	_draw_region_labels(o)
	var font := ThemeDB.fallback_font
	_draw_buildings(o)
	_draw_puzzles(o)
	for it in map.items:
		if not it["id"] in GameData.state.items:
			var ip := o + (Vector2(float(it["cell"][0]), float(it["cell"][1])) + Vector2(0.5, 0.5)) * map.tile
			draw_rect(Rect2(ip + Vector2(-4, -2), Vector2(8, 22)), Color("8b6640"))
			draw_rect(Rect2(ip + Vector2(-14, -12), Vector2(28, 12)), Color("e9876a"))
			draw_circle(ip + Vector2(16, -16), 4 + 2 * sin(Time.get_ticks_msec() / 150.0), Color("f5c542"))
	for v in _villagers:
		_draw_villager(o + v.pos)
	for sp in _spots:
		var p: Vector2 = o + sp["pos"]
		var col: Color = sp["color"]
		if sp["id"] == "kid":  # 마을 아이(작은 마을 사람)
			draw_circle(p + Vector2(0, 10), 13, Color("9fd8c8"))
			draw_circle(p - Vector2(0, 8), 12, Color("ffe3c4"))
			draw_arc(p - Vector2(0, 8), 12, 0, TAU, 20, UiKit.INK, 2)
			var qk := GameData.quests.get_quest("s01_q_hammer")
			if not qk.is_empty() and GameData.quests.visible(GameData.state, qk) and not GameData.quests.done(GameData.state, qk["id"]):
				draw_string(font, p + Vector2(-10, -30), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 30, UiKit.BAD)
			continue
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
	for dr in _drops:
		var dp: Vector2 = o + dr["pos"]
		match String(dr["kind"]):
			"orb":
				draw_circle(dp, 8 + int(dr["v"]), Color("7cc4f0"))
				draw_circle(dp - Vector2(2, 2), 3, Color.WHITE)
			"coin":
				draw_circle(dp, 9, Color("f5c542"))
				draw_arc(dp, 9, 0, TAU, 16, Color("b8902a"), 2)
			"word":
				draw_rect(Rect2(dp - Vector2(12, 15), Vector2(24, 30)), Color("fff4dc"))
				draw_rect(Rect2(dp - Vector2(12, 15), Vector2(24, 30)), UiKit.ACCENT, false, 3)
	for e in _enemies:
		_draw_mob(e, o + e.pos)
	if not map.is_town(_hero):
		_draw_weapons(o)
	for pal in _pals:  # 동행 유닛과 이름
		var pp: Vector2 = o + pal["pos"]
		PalArt.draw(self, int(pal["unit"]), pp, _facing)
		draw_string(ThemeDB.fallback_font, pp + Vector2(-40, 38), t("name.char." + GameData.UNIT_CHARS[int(pal["unit"]) - 1]), HORIZONTAL_ALIGNMENT_CENTER, 80, 14, UiKit.INK)
	for e in _enemies:  # 화면 밖 뿌리먹이: 가장자리 빨간 화살표
		if e.kind == "eater":
			var sp := o + e.pos
			if not Rect2(Vector2.ZERO, size).has_point(sp):
				var c := size / 2.0
				var dir := (sp - c).normalized()
				var edge := c + dir * minf(size.x * 0.45, size.y * 0.4)
				draw_colored_polygon(PackedVector2Array([edge + dir * 30, edge + dir.rotated(2.5) * 24, edge + dir.rotated(-2.5) * 24]), UiKit.BAD)
	# 주인공과 칭호 리본(04-meta.md 5절). 몰래 걷는 동안은 흐리게
	var h := o + _hero
	if _fmagic and _fmagic.sneak > 0.0:
		draw_circle(h, HERO_R + 14, Color(UiKit.SKY, 0.35))
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
	if map.in_cave(_hero):  # 어두운 동굴: 둘레만 보인다(pro-로 밝힌다)
		var lr: Array = _f["cave_light"]
		var rad := float(lr[1]) if _fmagic.light > 0.0 else float(lr[0])
		var big := 2600.0
		draw_arc(h, rad + big / 2.0, 0, TAU, 96, Color(0.35, 0.35, 0.38, 0.55), big)  # 반투명한 밝은 회색(글씨가 보이게)
		draw_arc(h, rad, 0, TAU, 64, Color(0.35, 0.35, 0.38, 0.25), 30)
		if _fmagic.light <= 0.0 and _toast_t <= 0.0 and not "pro" in GameData.state.magics:
			_show_toast(t("ui.cave.dark"))
	if _life:  # 바람에 날리는 것(꽃잎·눈·불씨 …)은 맨 위
		_life.draw_particles(self, tnow)
	_perf("rest", p0)
	if GameData.settings.show_fps:  # 프레임 확인용(옵션): 초당 그림 수, 지도 그리기·나머지 그리기·계산(ms)
		var line := t("ui.field.fps").format({"fps": Engine.get_frames_per_second(), "draw": "%.1f" % (float(perf.get("map", 0.0)) + float(perf.get("rest", 0.0))), "tick": "%.1f" % perf.get("tick", 0.0)})
		draw_rect(Rect2(6, size.y - 40, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 12, 34), Color(1, 1, 1, 0.75))
		draw_string(font, Vector2(12, size.y - 15), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiKit.INK)
	if _stick_on:
		draw_arc(_stick_base, 90, 0, TAU, 40, Color(UiKit.INK, 0.4), 4)
		draw_circle(_stick_base + _stick_vec * 90, 28, Color(UiKit.INK, 0.3))


## 유닛 무기 그리기: 날아가는 것(shots), 도는 것(orbit), 잠깐 효과(fx).
func _draw_weapons(o: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for sh in _uw.shots:
		var sp: Vector2 = o + sh["pos"]
		var col := PalArt.color(int(sh["unit"]))
		match String(sh["type"]):
			"boomerang":  # 망치
				draw_set_transform(sp, now * 16.0, Vector2.ONE)
				draw_rect(Rect2(-14, -6, 28, 12), Color("8b6640"))
				draw_rect(Rect2(6, -12, 12, 24), Color("6f6257"))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"straight":
				var v: Vector2 = (sh["vel"] as Vector2).normalized()
				if int(sh["unit"]) == 6:  # 쌩: 바람 화살
					draw_line(sp - v * 30, sp, Color(col, 0.6), 6)
					draw_colored_polygon(PackedVector2Array([sp + v * 14, sp + v.orthogonal() * 8, sp - v.orthogonal() * 8]), col.darkened(0.3))
				else:  # 휙: 돌멩이
					draw_circle(sp, 9, Color("9a8f86"))
					draw_arc(sp, 9, 0, TAU, 12, UiKit.INK, 2)
			"lob":  # 영차: 보따리(포물선)
				var k := float(sh["t"]) / float(sh["max"])
				var up := Vector2(0, -sin(k * PI) * 90.0)
				draw_circle(o + sh["to"], float(sh["r"]) * 0.35, Color(0, 0, 0, 0.15))
				draw_circle(sp + up, 14, Color("c9a874"))
				draw_line(sp + up + Vector2(-6, -12), sp + up + Vector2(6, -12), Color("8b6640"), 4)
	for id in _run.d["weapons"]:
		var w := _run.weapon(String(id))
		if w["type"] != "orbit":
			continue
		for k in int(w["count"]):
			var p := o + _uw.orbit_pos(_hero, w, k)
			draw_circle(p, 14, Color("e9a0b8"))
			draw_arc(p, 14, _uw.orbit_a * 3.0, _uw.orbit_a * 3.0 + PI, 10, UiKit.INK, 3)
	for id in _run.d["weapons"]:  # 대장의 깃발 둘레(언제나 흐리게)
		var w2 := _run.weapon(String(id))
		if w2["type"] == "aura":
			draw_circle(o + _pal_pos(int(w2["unit"])), float(w2["range"]), Color(PalArt.color(8), 0.12))
	for f in _uw.fx:
		var k := float(f["t"]) / float(f["max"])
		var col := PalArt.color(int(f["unit"]))
		var a: Vector2 = o + f["a"]
		match String(f["type"]):
			"grab":  # 덥석: 늘어나는 팔
				var b: Vector2 = o + f["b"]
				draw_line(a, a.lerp(b, minf(1.0, k * 2.0)), col.darkened(0.2), 10)
				draw_circle(a.lerp(b, minf(1.0, k * 2.0)), 14, col)
			"beam":  # 힐끔: 눈빛
				draw_line(a, o + f["b"], Color(col, 0.7 * (1.0 - k)), float(f["r"]))
				draw_line(a, o + f["b"], Color(1, 1, 1, 0.8 * (1.0 - k)), 6)
			"snipe":  # 척척: 콕 찍는 별
				var b2: Vector2 = o + f["b"]
				draw_line(a, b2, Color(col, 0.5 * (1.0 - k)), 3)
				draw_circle(b2, 18 * (1.0 - k) + 6, Color(col, 1.0 - k))
			"nova", "bash":  # 조잘: 퍼지는 말 / 꿈쩍: 방패 밀치기
				draw_arc(a, float(f["r"]) * k, 0, TAU, 48, Color(col, 1.0 - k), 8 if f["type"] == "nova" else 14)
			"aura":
				draw_arc(a, float(f["r"]), 0, TAU, 48, Color(col, 0.6 * (1.0 - k)), 5)
			"slam":  # 와장·영차: 쾅
				draw_circle(a, float(f["r"]) * (0.5 + 0.5 * k), Color(col, 0.35 * (1.0 - k)))
				draw_arc(a, float(f["r"]) * (0.5 + 0.5 * k), 0, TAU, 32, Color(col.darkened(0.3), 1.0 - k), 5)


func _pal_pos(unit: int) -> Vector2:
	for pal in _pals:
		if int(pal["unit"]) == unit:
			return pal["pos"]
	return _hero


## 마을 건물: 벽(타일) 위에 지붕, 문, 창, 간판. 말뿌리 나무는 큰 나무로.
## 마을 건물의 움직이거나 글씨인 것만(건물 그림은 지도 배경 MapPainter._building): 이름표, 굴뚝 연기. 동굴은 건물이 없다.
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
			draw_string(font, r.get_center() + Vector2(-90, ts * 1.6), t("ui.field.tree"), HORIZONTAL_ALIGNMENT_CENTER, 180, 22, UiKit.INK)
			continue
		if id == "forge":  # 굴뚝 연기
			var ch0 := r.position + Vector2(r.size.x * 0.8, -ts * 0.2)
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
## 몹 모습은 단어의 성질로 나눈다(사용자 의견): 몸 색 = 주속성(스테이지 1은 모두 파동이라 같은 색),
## 몸 모양 = 착용 부위(무기 별, 머리 동글, 가슴 네모, 장갑 물방울, 신발 세모) + 부위 첫 글자.
## 움직임(배회·쫓기·도망)은 머리 위 표시(! / 땀방울)로만 알린다.
func _draw_attr_body(e: FieldMob, p: Vector2) -> void:
	var col := MinigameScreen.attr_color(e.attr)
	var r := ENEMY_R
	match e.slot:
		"head":  # 동글
			draw_circle(p, r, col)
			draw_arc(p, r, 0, TAU, 32, UiKit.INK, 3)
		"chest":  # 네모
			var rc := Rect2(p - Vector2(r, r * 0.9), Vector2(r * 2, r * 1.8))
			draw_rect(rc, col)
			draw_rect(rc, UiKit.INK, false, 3)
		"hands":  # 물방울(위가 뾰족)
			var pts := PackedVector2Array([p + Vector2(0, -r * 1.4)])
			for k in 13:
				var a := PI * k / 12.0
				pts.append(p + Vector2(cos(a) * r, sin(a) * r))  # 아래 반원
			draw_colored_polygon(pts, col)
			pts.append(pts[0])
			draw_polyline(pts, UiKit.INK, 3)
		"feet":  # 세모
			var tri := PackedVector2Array([p + Vector2(0, -r * 1.2), p + Vector2(r * 1.1, r * 0.9), p + Vector2(-r * 1.1, r * 0.9)])
			draw_colored_polygon(tri, col)
			tri.append(tri[0])
			draw_polyline(tri, UiKit.INK, 3)
		_:  # 무기: 별(뾰족뾰족)
			var st := PackedVector2Array()
			for k in 12:
				var a := k * TAU / 12.0 - PI / 2.0
				st.append(p + Vector2(cos(a), sin(a)) * (r * 1.15 if k % 2 == 0 else r * 0.8))
			draw_colored_polygon(st, col)
			st.append(st[0])
			draw_polyline(st, UiKit.INK, 3)
	draw_circle(p + Vector2(-9, -4), 3.5, UiKit.INK)
	draw_circle(p + Vector2(9, -4), 3.5, UiKit.INK)
	if e.slot != "":  # 부위 첫 글자
		var nm := t("name.slot." + e.slot)
		draw_string(ThemeDB.fallback_font, p + Vector2(-12, 16), nm.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, 24, 16, UiKit.INK)


func _draw_mob(e: FieldMob, p: Vector2) -> void:
	var font := ThemeDB.fallback_font
	if e.kind == "eater":  # 뿌리먹이: 크고 검붉은, 뿌리 같은 촉수
		var t0 := Time.get_ticks_msec() / 300.0
		for k in 6:
			var a := k * TAU / 6.0 + t0
			draw_line(p, p + Vector2.from_angle(a) * (ENEMY_R * 2.2 + sin(t0 * 2 + k) * 8), Color("5a2a3a"), 6)
		draw_circle(p, ENEMY_R * 1.6, Color("7a2a3a"))
		draw_circle(p + Vector2(-12, -6), 6, Color("f5c542"))
		draw_circle(p + Vector2(12, -6), 6, Color("f5c542"))
		return
	var bob := sin(Time.get_ticks_msec() / 160.0 + p.x * 0.01) * 3.0
	p += Vector2(0, bob)
	if e.kind == "rush" and e.phase == "wind":  # 돌진 전에 부르르 떤다
		p.x += sin(Time.get_ticks_msec() / 25.0) * 4.0
	if not Art.draw(self, "enemy", "attr_%02d" % e.attr, p, Vector2(ENEMY_R * 2.6, ENEMY_R * 2.6)):
		_draw_attr_body(e, p)
	if e.flash > 0.0:
		draw_circle(p, ENEMY_R + 4, Color(1, 1, 1, 0.55))
	if e.hp < e.max_hp:  # 깎인 체력
		draw_rect(Rect2(p + Vector2(-24, ENEMY_R + 6), Vector2(48, 6)), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(p + Vector2(-24, ENEMY_R + 6), Vector2(48.0 * e.hp / maxi(1, e.max_hp), 6)), UiKit.BAD)
	if e.stun > 0.0:  # de-로 멈춘 몹: 머리 위 별
		for k in 3:
			var a := Time.get_ticks_msec() / 200.0 + k * TAU / 3.0
			draw_circle(p + Vector2(cos(a) * 22, -ENEMY_R - 10 + sin(a) * 6), 5, Color("f5c542"))
	if e.alert:
		if e.kind == "chase":
			draw_string(font, p + Vector2(-10, -46), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 34, UiKit.BAD)
		elif e.kind == "flee":
			draw_circle(p + Vector2(ENEMY_R - 2, -ENEMY_R + 4), 6, Color("8cc6e8"))
	if e.kind == "rush":  # 돌진: 떨 때 !!, 달릴 때 뒤로 줄
		if e.phase == "wind":
			draw_string(font, p + Vector2(-20, -46), "!!", HORIZONTAL_ALIGNMENT_CENTER, 40, 34, UiKit.BAD)
		elif e.phase == "dash" and e.vel.length() > 1.0:
			var bk := -e.vel.normalized()
			for k in 3:
				var off := bk.orthogonal() * (k - 1) * 12.0
				draw_line(p + bk * (ENEMY_R + 4) + off, p + bk * (ENEMY_R + 34) + off, Color(1, 1, 1, 0.8), 4)


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
			var hsh := (x * 73856093) ^ (y * 19349663)
			if map.is_cave and k == "^":  # 동굴 벽: 울퉁불퉁한 바위
				draw_rect(r, CAVE_WALL)
				draw_circle(r.get_center() + Vector2((hsh % 16) - 8, ((hsh / 5) % 16) - 8), ts * 0.32, CAVE_WALL.lightened(0.12))
				continue
			draw_rect(r, TILE_COL.get(k, Color.MAGENTA))
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
				"c":  # 동굴 입구: 검은 굴
					draw_rect(r, TILE_COL["^"])
					draw_circle(c + Vector2(0, 8), ts * 0.42, Color("1e1a22"))
					draw_rect(Rect2(c + Vector2(-ts * 0.42, 8), Vector2(ts * 0.84, ts * 0.42)), Color("1e1a22"))
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


## 지역 이름(마을 위)과 다른 지역의 보스 자리.
func _draw_region_labels(o: Vector2) -> void:
	var ts := float(map.tile)
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
		var mp: MapPainter = MapPainter.for_map(m) if not m.is_cave else null
		for y in m.h:
			var row := m.rows[y]
			for x in m.w:
				if mp:
					img.set_pixel(x, y, mp.mini_color(x, y, gates))
					continue
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
	_mini.custom_minimum_size = Vector2(map.w, map.h) * _mini_k()
	_mini.size = _mini.custom_minimum_size
	_mini.position = Vector2(16, 150)
	_mini.mouse_filter = Control.MOUSE_FILTER_STOP
	_mini.draw.connect(func() -> void: _draw_marks(_mini, _mini_k(), false))
	_mini.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_open_full())
	add_child(_mini)


## 지도 위 표시: 주인공(깜빡이는 점), 보이는 화면 테두리, 보스 자리, (전체 지도면) 지역 이름.
func _mini_k() -> float:
	return MINI_H / float(map.h)


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
