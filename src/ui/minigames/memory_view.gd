class_name MemoryView
extends MinigameScreen
## 2 덫 놓기(짝 맞추기): 엎어 둔 덫을 두 개씩 연다. 영어 단어와 그 뜻이 짝이면 걸린다.

const PEEK := 1.0  ## 틀린 두 장을 보여 주는 시간(초)

var _grid: GridContainer
var _btns: Array[Button] = []
var _peek_t := 0.0


func build() -> void:
	var g := game as MemoryGame
	_grid = GridContainer.new()
	_grid.columns = 4 if g.cards.size() <= 12 else 5
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.position = Vector2(40, 10)
	body.add_child(_grid)
	for i in g.cards.size():
		var idx := i
		var b := UiKit.button("", func() -> void: _flip(idx), UiKit.LEAF, 22)
		b.custom_minimum_size = Vector2(290, 120)
		b.clip_text = true
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_grid.add_child(b)
		_btns.append(b)


func _flip(i: int) -> void:
	var g := game as MemoryGame
	var r := g.flip(i)
	if r == "miss":
		_peek_t = PEEK
		GameData.vibrate()
	elif r == "match":
		GameData.vibrate(true)
	changed()


func tick(delta: float) -> void:
	var g := game as MemoryGame
	if _peek_t > 0.0:
		_peek_t -= delta
		if _peek_t <= 0.0:
			g.close_mismatch()
			refresh()


func refresh() -> void:
	var g := game as MemoryGame
	for i in g.cards.size():
		var c: Dictionary = g.cards[i]
		var b := _btns[i]
		var face_up: bool = c["open"] or c["done"]
		b.text = g.label(i) if face_up else t("ui.mini.trap.closed")
		var bg := UiKit.LEAF
		if c["done"]:
			bg = UiKit.GOOD.lightened(0.45)
		elif i in g.mismatch:
			bg = UiKit.BAD.lightened(0.35)
		elif face_up:
			bg = UiKit.SKY if c["side"] == "word" else UiKit.APRICOT
		b.add_theme_stylebox_override("normal", UiKit.box(bg, 24))
		b.add_theme_stylebox_override("hover", UiKit.box(bg.lightened(0.1), 24))
		b.add_theme_font_size_override("font_size", 28 if c["side"] == "word" and face_up else 20)
