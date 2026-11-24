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
