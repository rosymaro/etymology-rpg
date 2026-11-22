class_name NoticeOverlay
extends Control
## 가운데 알림 카드.


func show_text(text: String, done: Callable) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.2, 0.18, 0.3, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var card := UiKit.card()
	card.custom_minimum_size = Vector2(640, 0)
	c.add_child(card)
	var v := UiKit.vbox(18)
	card.add_child(v)
	var l := UiKit.wrap(UiKit.label(text, 28), 600)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.add_child(UiKit.button(TranslationServer.translate("ui.common.ok"), func() -> void:
		queue_free()
		if done.is_valid():
			done.call()))
