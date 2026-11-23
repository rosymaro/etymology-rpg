extends GutTest
## 전투 카드의 코인 표기("+2C3")가 코인 항 계산과 같은 규칙인지.

var f: StatFormula


func before_all() -> void:
	f = GameData.setup.factory.formula if GameData.setup else null


func test_notation_matches_terms() -> void:
	if f == null:
		pass_test("공식 없음")
		return
	var flips: Array[bool] = [false, true, true]
	assert_eq(f.coin_notation("atk", 2, 3)["atk"], "+2C3", "공격 5에 +2C3")
	assert_eq(f.coin_terms("atk", 2, flips).atk, 4, "코인 011이면 +4 → 5는 9가 된다")
	assert_eq(f.coin_notation("hp", 2, 3)["hp"], "+4C3")
	assert_eq(f.coin_terms("hp", 2, flips).hp, 8)
	assert_eq(f.coin_notation("stable", 3, 4)["atk"], "+3C1")
	assert_eq(f.coin_notation("swing", 1, 2), {"atk": "+2C2", "hp": "-1C1"})


func test_battle_card_shows_now_and_base_on_hold() -> void:
	if f == null:
		pass_test("공식 없음")
		return
	var c := Combatant.new()
	c.coin_style = "atk"
	c.coin_value = 2
	c.coins = 3
	c.base = Stats.new(5, 2, 12)
	c.flips = [false, true, true] as Array[bool]
	var card := BattleCard.new()
	add_child_autofree(card)
	card.show_now(c, "confer", 9, 2, 7, f)
	assert_string_contains(card.text_lines()[1], "+2C3  9", "지금: 코인 011이 더해진 9")
	assert_string_contains(card.text_lines()[3], "7", "지금 체력")
	card.hold_enabled = true
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	card._on_card_input(ev)
	assert_string_contains(card.text_lines()[1], "+2C3  5", "누르고 있으면 처음 공격 5")
	assert_string_contains(card.text_lines()[3], "12", "처음 체력")
	ev.pressed = false
	card._on_card_input(ev)
	assert_string_contains(card.text_lines()[1], "+2C3  9", "떼면 다시 지금 모습")
	assert_eq(card.coins.flips, c.flips, "코인은 카드 바깥 줄에")
