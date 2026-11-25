class_name ComboQuizOverlay
extends Control
## 방어 마법 퀴즈 창(01-rpg-base '방어 마법 퀴즈: 조합 뜻 고르기'). 규칙은 ComboQuiz.
## 뜻을 고르면 그 아래에 영어 단어가 뜬다(조합 단어 초록, 임의 단어 빨강). 정답을 다 고르면 성공, 빨강이 뜨면 바로 실패.

signal finished(ok: bool)

var quiz: ComboQuiz
var _buttons: Array[Button] = []
var _words: Array[Label] = []
var _status: Label
var _over := false


func open(q: ComboQuiz, magic_id: String) -> void:
	quiz = q
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 30
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.13, 0.22, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.offset_top = -UiKit.BG_BLEED
	dim.offset_bottom = UiKit.BG_BLEED
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var card := UiKit.card()
	card.custom_minimum_size = Vector2(640, 0)
	card.position = Vector2(40, 260)
	add_child(card)
	var v := UiKit.vbox(10)
	card.add_child(v)
	var title := UiKit.label(tr("ui.combo.title").format({"magic": GameText.magic_name(magic_id)}), 28, UiKit.ACCENT.darkened(0.3))
	v.add_child(title)
	var how := UiKit.label(tr("ui.combo.how").format({"n": q.answers.size()}), 20, UiKit.INK.lightened(0.2))
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 600
	v.add_child(how)
	for i in q.options.size():
		var k := i
		var b := UiKit.button(String(q.options[i]["meaning"]), func() -> void: _pick(k), UiKit.PAPER, 22)
		b.custom_minimum_size = Vector2(600, 60)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(b)
		_buttons.append(b)
		var w := UiKit.label("", 20)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(w)
		_words.append(w)
	_status = UiKit.label("", 24)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_status)


func _pick(i: int) -> void:
	if _over:
		return
	var r := quiz.pick(i)
	if r == "":
		return
	var o: Dictionary = quiz.options[i]
	_words[i].text = String(o["word"])
	_words[i].add_theme_color_override("font_color", UiKit.LEAF.darkened(0.35) if o["right"] else UiKit.BAD)
	_buttons[i].disabled = true
	if r == "wrong" or r == "done":
		_over = true
		var ok := r == "done"
		_status.text = tr("ui.combo.ok") if ok else tr("ui.combo.fail")
		_status.add_theme_color_override("font_color", UiKit.LEAF.darkened(0.35) if ok else UiKit.BAD)
		await get_tree().create_timer(0.9).timeout
		finished.emit(ok)
		queue_free()
