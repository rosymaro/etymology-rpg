class_name DialogueOverlay
extends Control
## 대화 장면(data/scenes/s01.json의 lines). 누르면 다음 줄. 문장은 locale/story.csv 키로 꺼낸다.

var _lines: Array = []
var _i := 0
var _done: Callable
var _name: Label
var _text: Label
var _title: Label
var _face: TextureRect


func play(scene_id: String, done: Callable) -> void:
	_done = done
	var stage_file := "res://data/scenes/%s.json" % scene_id.split("_")[0]
	var data: Dictionary = JsonFile.read(stage_file)
	for s in data["scenes"]:
		if s["id"] == scene_id:
			_lines = s["lines"]
			_build(s)
			break
	_show()


func _build(scene: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.18, 0.3, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_title = UiKit.label(TranslationServer.translate(scene.get("title", "")), 24)
	_title.position = Vector2(32, 24)
	add_child(_title)
	var box := UiKit.card()
	box.anchor_left = 0.04
	box.anchor_right = 0.96
	box.anchor_top = 0.66
	box.anchor_bottom = 0.96
	add_child(box)
	var row := UiKit.hbox(14)
	box.add_child(row)
	_face = TextureRect.new()
	_face.custom_minimum_size = Vector2(150, 150)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.visible = false
	row.add_child(_face)
	var v := UiKit.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	_name = UiKit.label("", 24, UiKit.ACCENT.darkened(0.2))
	v.add_child(_name)
	_text = UiKit.wrap(UiKit.label("", 28))
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	var hint := UiKit.label(TranslationServer.translate("ui.dialogue.tap"), 18, UiKit.GRAY.darkened(0.3))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)


func _show() -> void:
	if _i >= _lines.size():
		queue_free()
		if _done.is_valid():
			_done.call()
		return
	var ln: Dictionary = _lines[_i]
	var sp: String = ln.get("speaker", "narr")
	_name.text = "" if sp == "narr" else GameData.say("name.char." + sp)
	var face := Art.tex("face", sp + "_" + str(ln.get("face", "normal")))
	if face == null:
		face = Art.tex("face", sp + "_normal")
	_face.texture = face
	_face.visible = face != null
	_text.text = GameData.say(ln["text"])


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_i += 1
		_show()
		accept_event()
