extends GutTest
## 전투 화면 연출 규칙: 처음엔 아군·적이 함께 나오고, 턴 수는 적이 바뀌어도 이어서 센다.


func after_each() -> void:
	GameData.save_store.erase()
	GameData.use_dev_save(false)


func _battle() -> BattleScreen:
	var main: Main = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_physics_frames(2)
	main.flow.dev_game()
	await wait_physics_frames(2)
	var ids: Array[String] = []
	for w in GameData.repo.first_tier(1, "field").slice(0, 3):
		ids.append(w.id)
	main.flow.go_battle_prep(ids, false)
	await wait_physics_frames(2)
	(main.current() as BattlePrepScreen)._start()
	await wait_physics_frames(2)
	return main.current() as BattleScreen


func test_turns_count_up_across_enemies() -> void:
	var bs := await _battle()
	var rounds := bs._ctx.log.filter(func(e: Dictionary) -> bool: return e["t"] == "round").size()
	bs.skip_all()
	await wait_seconds(1.0)
	assert_true(bs._ended)
	assert_eq(bs._turn_n, rounds, "턴은 전투 처음부터 이어서 센다")
	var hist := "\n".join(bs.lines)
	assert_string_contains(hist, "%d턴" % rounds, "마지막 턴 번호가 기록에 남는다")


func test_first_ally_and_enemy_enter_together() -> void:
	var bs := await _battle()
	# 나오는 중(코인을 던지기 전): 두 카드 모두 이미 펴져 있고 코인은 아직 '?'
	await wait_physics_frames(6)
	assert_not_null(bs._a_box.combatant, "아군이 나왔다")
	assert_not_null(bs._b_box.combatant, "적도 함께 나왔다")
	assert_true(bs._a_box.coins.pending and bs._b_box.coins.pending, "코인은 나온 다음에 던진다")
	await wait_seconds(BattleScreen.GROW_SEC + 0.2)
	assert_true(bs._a_box.coins.spinning() and bs._b_box.coins.spinning(), "두 카드의 코인이 함께 돈다")


func test_magic_card_lands_by_kind() -> void:
	var a := Rect2(40, 330, 300, 400)
	var b := Rect2(380, 330, 300, 400)
	assert_almost_eq(MagicFx.anchor("attack", a, b).x, b.get_center().x, 0.1, "공격 마법은 적 카드 위")
	assert_almost_eq(MagicFx.anchor("defense", a, b).x, a.get_center().x, 0.1, "방어 마법은 아군 카드 위")
	for k in ["effect", "order"]:
		assert_almost_eq(MagicFx.anchor(k, a, b).x, (a.get_center().x + b.get_center().x) / 2.0, 0.1, "%s 마법은 가운데" % k)
	for m in GameData.bal.magic["magics"]:
		assert_true(JsonFile.read("res://data/magic_fx.json")["fx"].has(m["id"]), "이펙트가 있다: %s" % m["id"])


func test_battle_magic_card_flies_from_magic_button() -> void:
	var bs := await _battle()
	if bs._ctx.magic_id == "":
		pass_test("마법 없이 시작")
		return
	var ev_i := bs._ctx.log.map(func(e: Dictionary) -> String: return e["t"]).find("magic")
	if ev_i < 0:
		pass_test("마법이 걸리지 않음")
		return
	# 마법 기록이 나올 때까지 '다음'을 누른다
	for i in 40:
		if bs.last_magic_card:
			break
		bs._tapped = true
		await wait_seconds(0.4)
	assert_not_null(bs.last_magic_card, "마법 카드가 나왔다")
	await wait_physics_frames(2)
	var rest: Vector2 = bs.last_magic_card.get_meta("rest")
	var kind: String = bs.last_magic_card.get_meta("kind")
	var want := MagicFx.anchor(kind, bs._a_box.get_global_rect(), bs._b_box.get_global_rect())
	assert_almost_eq(rest.x, want.x, 1.0, "종류에 맞는 자리에 놓인다")
