class_name WordCard
extends PanelContainer
## 단어 카드: 어디서 보든 같은 모양으로 단어의 속성·착용 부위·보유 여부를 알린다.
## - 바탕: 속성 색. 2개면 가운데 대각선 경계, 3개면 대각선 세 띠(경계는 그라데이션).
## - 단어 앞 아이콘: 착용 부위(무기·머리·가슴·장갑·신발). 부위가 없는 단어는 아이콘 없음.
## - 글자색: 이미 가진 단어는 남보라, 처음 보는 단어는 주황.

const SHADER := preload("res://src/ui/word_card.gdshader")
const OWNED := UiKit.INK
const FRESH := Color("c4561a")

var word: WordData
var owned := true
var _bg: ColorRect
var _on_press: Callable


## extra: 단어 뒤에 붙는 글(뜻, 차수 등). owned_override: -1 = 저장 상태로 판단, 0 = 처음, 1 = 가짐.
static func make(w: WordData, extra: String = "", size: int = 22, on_press: Callable = Callable(), owned_override: int = -1) -> WordCard:
	var c := WordCard.new()
	c.setup(w, extra, size, on_press, owned_override)
	return c


static func is_owned(w: WordData) -> bool:
	return GameData.state != null and GameData.state.has_word(w.id)


## 속성 색(최대 3개). MinigameScreen.attr_color와 같은 표를 쓴다.
static func colors(w: WordData) -> Array[Color]:
	var out: Array[Color] = []
	for a in w.attrs:
		if out.size() < 3:
			out.append(MinigameScreen.attr_color(int(a)))
	if out.is_empty():
		out.append(UiKit.GRAY)
	return out


func setup(w: WordData, extra: String, size: int, on_press: Callable, owned_override: int) -> void:
	word = w
	owned = is_owned(w) if owned_override < 0 else owned_override == 1
	_on_press = on_press
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())  # 바탕 ColorRect가 카드 전체를 덮도록 여백 없음
	_bg = ColorRect.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var cs := colors(w)
	mat.set_shader_parameter("n", cs.size())
	for i in 3:
		mat.set_shader_parameter("c%d" % i, cs[mini(i, cs.size() - 1)])
	mat.set_shader_parameter("border_color", UiKit.INK)
	_bg.material = mat
	add_child(_bg)
	_bg.resized.connect(_sync)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, {"left": 12, "right": 16, "top": 6, "bottom": 6}[side])
	add_child(pad)
	var row := UiKit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(row)
	if w.slot != "":
		var icon := SlotIcon.new()
		icon.slot = w.slot
		icon.custom_minimum_size = Vector2(size + 6, size + 6)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.tooltip_text = TranslationServer.translate("name.slot." + w.slot)
		row.add_child(icon)
	var name_l := UiKit.label(w.id, size, OWNED if owned else FRESH)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_l)
	if extra != "":
		var ex := UiKit.label(extra, maxi(14, size - 4), UiKit.INK.lightened(0.15))
		ex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ex.clip_text = true
		ex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(ex)
	mouse_filter = Control.MOUSE_FILTER_STOP if on_press.is_valid() else Control.MOUSE_FILTER_PASS
	custom_minimum_size.y = size + 22


func _sync() -> void:
	(_bg.material as ShaderMaterial).set_shader_parameter("size", _bg.size)
	(_bg.material as ShaderMaterial).set_shader_parameter("radius", minf(18.0, _bg.size.y / 2.0))


func _gui_input(ev: InputEvent) -> void:
	if _on_press.is_valid() and ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		_on_press.call()
		accept_event()


func name_color() -> Color:
	return OWNED if owned else FRESH
