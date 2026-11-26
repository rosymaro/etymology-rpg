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
var _stage: SceneStage  ## 무대(staged로 열었을 때만): 컷마다 배경과 인물


## staged: 화면을 덮는 무대를 깔고 conti대로 배경·인물을 보여 준다(새 게임 첫 장면).
func play(scene_id: String, done: Callable, staged: bool = false) -> void:
	_done = done
	var stage_file := "res://data/scenes/%s.json" % scene_id.split("_")[0]
	var data: Dictionary = JsonFile.read(stage_file)
	for s in data["scenes"]:
		if s["id"] == scene_id:
			_lines = s["lines"]
			if staged:
				_stage = SceneStage.new()
				add_child(_stage)
				_stage.setup(s)
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
	dim.offset_top = -UiKit.BG_BLEED  # 화면 위아래 여백까지
	dim.offset_bottom = UiKit.BG_BLEED
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
	if _stage:
		_stage.show_line(_i)
	var ln: Dictionary = _lines[_i]
	var sp: String = ln.get("speaker", "narr")
	_name.text = "" if sp == "narr" else GameData.say("name.char." + sp)
	var fid := sp
	if sp == "hero" and GameData.state:  # 주인공 얼굴은 고른 모습(남·여)
		fid = "hero_" + GameData.state.hero_look
	var face := Art.tex("face", fid + "_" + str(ln.get("face", "normal")))
	if face == null:
		face = Art.tex("face", fid + "_normal")
	_face.texture = face
	_face.visible = face != null
	_text.text = GameData.say(ln["text"])


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_i += 1
		_show()
		accept_event()
