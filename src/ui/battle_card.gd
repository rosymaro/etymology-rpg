class_name BattleCard
extends VBoxContainer
## 전투 카드: 카드 바깥(위)에 코인이 돌고, 카드 안에는 이름과 능력치. 코인이 붙는 능력치 앞에 코인 표기("+2C3  9").
## 적 단어 카드는 속성 색 바탕, 이름 앞에 착용 부위 아이콘, 가진 단어인지 글자색(WordCard와 같은 규칙).
## 누르고 있으면 held(true, 누른 자리)를 알린다(화면이 그 자리에 처음 모습 창을 띄운다).

signal held(on: bool, at: Vector2)

const SPIN_SEC := 1.0  ## 코인이 도는 시간(그 뒤 앞뒤가 정해진다)
const ART_H := 176.0  ## 카드 위쪽 그림 자리 높이(사용자 의견: 카드를 세로로 키워 위 절반에 단어 그림)

var coins: CoinRow
var _card: PanelContainer
var _bg: ColorRect
var _title: Label
var art: WordArt  ## 그림 자리: 적은 단어 그림, 아군은 유닛 그림
var _gem: TextureRect  ## 금테 위 가운데 보석
var _icon: SlotIcon
var _atk: Label
var _def: Label
var _hp: Label
var _now := {}  ## 지금 모습 {name, atk, def, hp, note_atk, note_hp}
var _base := {}  ## 처음 모습
var hold_enabled := true  ## 전투 중에도 누르고 있으면 처음 모습 팝업
var combatant: Combatant
var skip := false  ## 빨리 보기: 깜빡임을 바로 끝낸다
var _word_id := ""


func _init() -> void:
	add_theme_constant_override("separation", 6)
	coins = CoinRow.new()
	coins.custom_minimum_size = Vector2(326, 44)
	add_child(coins)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_card.custom_minimum_size = Vector2(326, 200 + ART_H)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	_bg = WordCard.make_bg([UiKit.PAPER] as Array[Color])
	_card.add_child(_bg)
	var frame := BattleSkin.card_box()  # 금테 양피지(사용자 레퍼런스). 속성 색은 그림 자리 바탕이 보여 준다
	if frame:
		_card.add_theme_stylebox_override("panel", frame)
		_bg.visible = false
		var g := TextureRect.new()
		g.texture = BattleSkin.tex("gem.png")
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.custom_minimum_size = Vector2(40, 40)
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_gem = g
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 16 if side in ["left", "right"] else 10)
	_card.add_child(pad)
	var v := UiKit.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(v)
	art = WordArt.new()
	art.custom_minimum_size = Vector2(0, ART_H - 6)
	v.add_child(art)
	var head := UiKit.hbox(8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	_icon = SlotIcon.new()
	_icon.custom_minimum_size = Vector2(28, 28)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.visible = false
	head.add_child(_icon)
	_title = UiKit.label("", 24)
	head.add_child(_title)
	_atk = UiKit.label("", 24)
	_def = UiKit.label("", 24)
	_hp = UiKit.label("", 24)
	for l in [_atk, _def, _hp]:
		v.add_child(l)
	_card.gui_input.connect(_on_card_input)
	if _gem:  # 보석은 틀 위 가운데에 걸친다(컨테이너 배치를 피해 빈 Control 안에)
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_card.add_child(holder)
		holder.add_child(_gem)
		_gem.anchor_left = 0.5
		_gem.anchor_right = 0.5
		_gem.offset_left = -20
		_gem.offset_right = 20
		_gem.offset_top = -22
		_gem.offset_bottom = 18


## c: 전투원, 지금 값 a/d/h.
func show_now(c: Combatant, name_text: String, a: int, d: int, h: int, formula: StatFormula, spin := false) -> void:
	var note := formula.coin_notation(c.coin_style, c.coin_value, c.coins)
	combatant = c
	_now = {"name": name_text, "atk": a, "def": d, "hp": h, "note_atk": note["atk"], "note_hp": note["hp"]}
	_base = {"name": name_text, "atk": c.base.atk, "def": c.base.def, "hp": c.base.hp, "note_atk": note["atk"], "note_hp": note["hp"]}
	_set_look(c)
	coins.set_flips(c.flips, spin)
	_render()


## 적 단어면 속성 색·부위 아이콘·보유 글자색. 아군이면 종이 바탕.
func _set_look(c: Combatant) -> void:
	var w: WordData = GameData.repo.get_word(c.word_id) if c.side == Combatant.ENEMY and GameData.repo else null
	_word_id = c.word_id if w else ""
	var mat := _bg.material as ShaderMaterial
	var cs: Array[Color] = [UiKit.LEAF.lightened(0.5)]
	if w:
		cs = WordCard.colors(w)
	mat.set_shader_parameter("n", cs.size())
	for i in 3:
		mat.set_shader_parameter("c%d" % i, cs[mini(i, cs.size() - 1)])
	if w:
		art.set_word(w)
	else:
		art.set_unit(c.unit_no)
	_icon.visible = w != null and w.slot != ""
	if _icon.visible:
		_icon.slot = w.slot
		_icon.queue_redraw()
	_title.add_theme_color_override("font_color", (WordCard.OWNED if WordCard.is_owned(w) else WordCard.FRESH) if w else UiKit.INK)


## 능력치만 바꾼다(표기와 코인은 그대로).
func set_values(a: int, d: int, h: int) -> void:
	if _now.is_empty():
		return
	_now["atk"] = a
	_now["def"] = d
	_now["hp"] = h
	_render()


func value(key: String) -> int:
	return int(_now.get(key, 0))


## 능력치 key("atk"|"def"|"hp")가 from → to로 바뀌는 것을 깜빡여 보여 준 뒤 새 값으로 둔다.
func flash(key: String, from: int, to: int, col: Color, dur: float = 1.0, fast := false) -> void:
	if _now.is_empty():
		return
	var l: Label = {"atk": _atk, "def": _def, "hp": _hp}[key]
	_now[key] = to
	if fast or skip or from == to:
		_render()
		return
	var name_key: String = {"atk": "ui.battle.atk", "def": "ui.battle.def", "hp": "ui.battle.hp"}[key]
	var note: String = _now.get("note_" + key, "")
	l.text = (_line(name_key, note, from) + "  →  %d" % to)
	l.add_theme_color_override("font_color", col)
	var t := 0.0
	while t < dur and not skip:  # 깜빡임(빨리 보기를 누르면 바로 멈춘다)
		l.modulate.a = 0.35 if int(t / (dur / 6.0)) % 2 == 0 else 1.0
		await get_tree().process_frame
		t += get_process_delta_time()
	l.modulate.a = 1.0
	l.add_theme_color_override("font_color", UiKit.INK)
	_render()


func set_hp(h: int) -> void:
	if _now.is_empty():
		return
	_now["hp"] = h
	_render()


func _render() -> void:
	if _now.is_empty():
		return
	_title.text = _now["name"]
	_atk.text = _line("ui.battle.atk", _now["note_atk"], _now["atk"])
	_def.text = _line("ui.battle.def", "", _now["def"])
	_hp.text = _line("ui.battle.hp", _now["note_hp"], _now["hp"])


static func _line(key: String, note: String, value: int) -> String:
	var name := TranslationServer.translate(key)
	return "%s  %s  %d" % [name, note, value] if note != "" else "%s  %d" % [name, value]


## 처음 모습(코인 더하기 전, 체력 닳기 전)의 글. 화면이 팝업에 쓴다.
func base_lines() -> Array[String]:
	if _base.is_empty():
		return []
	return [_base["name"] + "  " + TranslationServer.translate("ui.battle.base"),
		_line("ui.battle.atk", _base["note_atk"], _base["atk"]), _line("ui.battle.def", "", _base["def"]),
		_line("ui.battle.hp", _base["note_hp"], _base["hp"])]


## 카드 한가운데(화면 좌표): 맞을 때 숫자·뜻이 튀어나오는 자리
func card_center() -> Vector2:
	return _card.get_global_rect().get_center()


func _on_card_input(ev: InputEvent) -> void:
	if not hold_enabled or not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	held.emit(ev.pressed, _card.get_global_transform_with_canvas() * ev.position)


## 지금 보이는 글(테스트용)
func text_lines() -> Array[String]:
	return [_title.text, _atk.text, _def.text, _hp.text]
