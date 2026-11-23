class_name BattleCard
extends VBoxContainer
## 전투 카드: 카드 바깥(위)에 코인이 돌고, 카드 안에는 이름과 능력치. 코인이 붙는 능력치 앞에 코인 표기("+2C3  9").
## 누르고 있으면(전투가 끝난 뒤) 코인이 더해지기 전, 체력이 닳기 전의 처음 모습을 보여 준다.

signal held(on: bool)

const SPIN_SEC := 0.7

var coins: CoinRow
var _card: PanelContainer
var _title: Label
var _atk: Label
var _def: Label
var _hp: Label
var _now := {}  ## 지금 모습 {name, atk, def, hp, note_atk, note_hp}
var _base := {}  ## 처음 모습
var hold_enabled := false
var _showing_base := false


func _init() -> void:
	add_theme_constant_override("separation", 6)
	coins = CoinRow.new()
	coins.custom_minimum_size = Vector2(380, 44)
	add_child(coins)
	_card = UiKit.card(UiKit.PAPER)
	_card.custom_minimum_size = Vector2(380, 210)
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	var v := UiKit.vbox(6)
	_card.add_child(v)
	_title = UiKit.label("", 24)
	v.add_child(_title)
	_atk = UiKit.label("", 26)
	_def = UiKit.label("", 26)
	_hp = UiKit.label("", 26)
	for l in [_atk, _def, _hp]:
		v.add_child(l)
	_card.gui_input.connect(_on_card_input)


## c: 전투원, flips: 이번 코인, 지금 값 a/d/h.
func show_now(c: Combatant, name_text: String, a: int, d: int, h: int, formula: StatFormula, spin := false) -> void:
	var note := formula.coin_notation(c.coin_style, c.coin_value, c.coins)
	_now = {"name": name_text, "atk": a, "def": d, "hp": h, "note_atk": note["atk"], "note_hp": note["hp"]}
	_base = {"name": name_text, "atk": c.base.atk, "def": c.base.def, "hp": c.base.hp, "note_atk": note["atk"], "note_hp": note["hp"]}
	coins.set_flips(c.flips, spin)
	_render()


func set_hp(h: int) -> void:
	if _now.is_empty():
		return
	_now["hp"] = h
	_render()


func show_base(on: bool) -> void:
	_showing_base = on and not _base.is_empty()
	coins.dim = _showing_base
	_render()


func _render() -> void:
	var d: Dictionary = _base if _showing_base else _now
	if d.is_empty():
		return
	_title.text = d["name"] + ("  " + TranslationServer.translate("ui.battle.base") if _showing_base else "")
	_atk.text = _line("ui.battle.atk", d["note_atk"], d["atk"])
	_def.text = _line("ui.battle.def", "", d["def"])
	_hp.text = _line("ui.battle.hp", d["note_hp"], d["hp"])
	_card.add_theme_stylebox_override("panel", UiKit.box(UiKit.SKY.lightened(0.4) if _showing_base else UiKit.PAPER))


static func _line(key: String, note: String, value: int) -> String:
	var name := TranslationServer.translate(key)
	return "%s  %s  %d" % [name, note, value] if note != "" else "%s  %d" % [name, value]


func _on_card_input(ev: InputEvent) -> void:
	if not hold_enabled or not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	show_base(ev.pressed)
	held.emit(ev.pressed)


## 지금 보이는 글(테스트용)
func text_lines() -> Array[String]:
	return [_title.text, _atk.text, _def.text, _hp.text]
