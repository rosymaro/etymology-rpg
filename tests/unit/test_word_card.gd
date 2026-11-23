extends GutTest
## 단어 카드: 속성 색 띠, 착용 부위 아이콘, 가진 단어/처음 단어 글자색.


func _w(attrs: Array, slot: String) -> WordData:
	return WordData.from_dict({"id": "confer", "meaning": "주다", "attrs": attrs, "tier": 1, "slot": slot, "etym": []})


func _mat(c: WordCard) -> ShaderMaterial:
	for ch in c.get_children():
		if ch is ColorRect:
			return (ch as ColorRect).material
	return null


func test_colors_follow_attributes_up_to_three() -> void:
	assert_eq(WordCard.colors(_w([1], "")).size(), 1)
	assert_eq(WordCard.colors(_w([1, 4], "")).size(), 2)
	assert_eq(WordCard.colors(_w([1, 4, 7], "")).size(), 3)
	assert_eq(WordCard.colors(_w([1, 4], ""))[1], MinigameScreen.attr_color(4))
	var c := WordCard.make(_w([2, 5, 9], "head"), "", 22, Callable(), 1)
	add_child_autofree(c)
	assert_eq(_mat(c).get_shader_parameter("n"), 3, "속성 3개면 세 띠")


func test_slot_icon_only_when_wearable() -> void:
	var c := WordCard.make(_w([1], "hands"), "", 22, Callable(), 1)
	add_child_autofree(c)
	assert_eq(c.find_children("*", "SlotIcon", true, false).size(), 1)
	var none := WordCard.make(_w([1], ""), "", 22, Callable(), 1)
	add_child_autofree(none)
	assert_eq(none.find_children("*", "SlotIcon", true, false).size(), 0)


func test_owned_and_fresh_words_have_different_name_color() -> void:
	var a := WordCard.make(_w([1], "feet"), "", 22, Callable(), 1)
	var b := WordCard.make(_w([1], "feet"), "", 22, Callable(), 0)
	add_child_autofree(a)
	add_child_autofree(b)
	assert_ne(a.name_color(), b.name_color())
	assert_eq(a.name_color(), WordCard.OWNED)
	assert_eq(b.name_color(), WordCard.FRESH)


func test_press_calls_back() -> void:
	var hit := [0]
	var c := WordCard.make(_w([1], "weapon"), "", 22, func() -> void: hit[0] += 1, 1)
	add_child_autofree(c)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	c._gui_input(ev)
	assert_eq(hit[0], 1)
