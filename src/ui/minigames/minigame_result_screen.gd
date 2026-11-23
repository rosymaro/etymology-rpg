class_name MinigameResultScreen
extends Screen
## 미니게임 메뉴에서 한 판이 끝났을 때(보상 없음): 점수와 이 판의 단어 뜻.


func open(args: Dictionary) -> void:
	UiKit.fill_bg(self, UiKit.SKY)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var card := UiKit.card()
	card.custom_minimum_size = Vector2(760, 0)
	c.add_child(card)
	var v := UiKit.vbox(12)
	card.add_child(v)
	var id: String = args["id"]
	var earned: Array[String] = args["earned"]
	v.add_child(UiKit.label(t("name.minigame." + id), 34))
	v.add_child(UiKit.label(t("ui.mini.free_result").format({"n": earned.size()}), 26))
	for w in earned:
		var wd := GameData.repo.get_word(w)
		v.add_child(WordCard.make(wd, wd.meaning, 22))
	var h := UiKit.hbox()
	h.add_child(UiKit.button(t("ui.mini.again"), func() -> void: main.flow.play_minigame(id, "free"), UiKit.LEAF))
	h.add_child(UiKit.button(t("ui.mini.list"), func() -> void: main.flow.go_minigames(), UiKit.PAPER))
	v.add_child(h)
