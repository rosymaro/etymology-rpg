class_name ResultScreen
extends Screen
## 얻은 단어, 경험치, 레벨 업, 새 어근, 자동 장비를 보여 준다.


func open(args: Dictionary) -> void:
	UiKit.fill_bg(self, UiKit.PAPER)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32 if side != "bottom" else int(UiKit.THUMB_ROW + UiKit.THUMB_H / 2.0 + 16))
	add_child(margin)
	var v := UiKit.vbox(12)
	margin.add_child(v)
	v.add_child(UiKit.label(t(args["title"]), 34))
	# 세로 화면: 얻은 단어 → 확인 버튼을 위쪽에 모으고, 전투 기록은 그 아래에 따로 스크롤
	var list := UiKit.vbox(8)
	var top_scroll := UiKit.scroll(list)
	top_scroll.size_flags_vertical = Control.SIZE_FILL
	v.add_child(top_scroll)
	var ups := {}
	var roots: Array[String] = []
	for ev in args["events"]:
		var w := GameData.repo.get_word(ev["word"])
		var line := "%s  %s" % [w.meaning, t("ui.result.new") if ev["new"] else t("ui.result.dup")]
		if ev["equipped"] > 0:
			line += "  " + t("ui.result.equipped").format({"name": UiKit.unit_name(ev["equipped"])})
		list.add_child(WordCard.make(w, line, 22, Callable(), 0 if ev["new"] else 1))
		for u in ev["level_ups"]:
			ups[u[0]] = u[2]
			EventBus.level_up.emit(u[0], u[2])
		for r in ev["roots"]:
			roots.append(r)
	for u in ups:
		if u in GameData.state.joined:
			list.add_child(UiKit.label(t("ui.result.level_up").format({"name": UiKit.unit_name(u), "level": ups[u]}), 24, UiKit.ACCENT.darkened(0.2)))
	for r in roots:
		list.add_child(UiKit.label(t("ui.result.new_root").format({"root": r}), 24, UiKit.ACCENT.darkened(0.2)))
	# 전투 기록: 무엇 때문에 체력이 깎였는지. 턴(또는 새 격돌)마다 가로줄
	var done: Callable = args["done"]
	var ok_btn := UiKit.button(t("ui.common.ok"), func() -> void: done.call(), UiKit.LEAF)
	ok_btn.custom_minimum_size.x = 600
	add_child(ok_btn)
	UiKit.thumb(ok_btn)  # 엄지 자리(글 목록은 그 위에서 스크롤)
	var n_rows := list.get_child_count()
	top_scroll.custom_minimum_size.y = clampf(n_rows * 58.0 + 10.0, 60.0, 560.0)
	var history: Array = args.get("history", [])
	var hist_list := UiKit.vbox(8)
	if not history.is_empty():
		v.add_child(UiKit.scroll(hist_list))
		list = hist_list
		list.add_child(UiKit.label(t("ui.result.history"), 26))
		var box := UiKit.card(Color(1, 1, 1, 0.8))
		var hv := UiKit.vbox(4)
		box.add_child(hv)
		list.add_child(box)
		for e in history:
			if e.get("sep", false):
				var line := HSeparator.new()
				line.add_theme_constant_override("separation", 10)
				hv.add_child(line)
			else:
				hv.add_child(UiKit.wrap(UiKit.label(String(e["text"]), 19, Color(String(e.get("col", "4b3f72"))))))

