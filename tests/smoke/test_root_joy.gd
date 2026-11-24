extends GutTest
## 전투 '결과 보기' 뒤: 새 어근을 익힌 유닛이 유닛별로 차례로 나와 기뻐하고, 그다음 결과 화면.


func after_each() -> void:
	GameData.save_store.erase()
	GameData.use_dev_save(false)


## 서로 다른 계열(유닛)의 어근 두 개, 같은 계열 어근 하나를 찾는다.
func _roots_for(units: Array) -> Dictionary:
	var by := {}
	for r in GameData.bal.skill_roots.keys():
		var u := GameData.bal.root_family(String(r))
		if u in units:
			if not by.has(u):
				by[u] = []
			by[u].append(String(r))
	return by


func test_root_joy_list_groups_by_unit_in_order() -> void:
	GameData.new_game("테스트")
	GameData.state.joined = [1, 4] as Array[int]
	var by := _roots_for([1, 4])
	assert_true(by.has(1) and by.has(4), "두 유닛 모두 어근 계열이 있다")
	var events := [
		{"roots": [by[4][0]]},
		{"roots": [by[1][0]]},
		{"roots": []},
	]
	if by[1].size() > 1:
		events[2]["roots"] = [by[1][1]]
	var list := GameFlow.root_joy_list(events)
	assert_eq(list.size(), 2, "유닛별로 한 화면")
	assert_eq(list[0][0], 1, "유닛 번호 순")
	assert_eq(list[1][0], 4)
	assert_eq(list[1][1], [by[4][0]])
	assert_true(by[1][0] in list[0][1])


func test_units_not_joined_are_skipped() -> void:
	GameData.new_game("테스트")
	GameData.state.joined = [1] as Array[int]
	var by := _roots_for([4])
	var list := GameFlow.root_joy_list([{"roots": [by[4][0]]}])
	assert_eq(list.size(), 0, "아직 함께 다니지 않는 유닛은 나오지 않는다")


func test_joy_screens_then_result() -> void:
	var main: Main = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_physics_frames(2)
	GameData.new_game("테스트")  # 단어가 없는 새 판: 무엇을 얻든 새 어근
	var s := GameData.state
	s.joined = [1, 4] as Array[int]
	# 아직 없는 어근이 든 단어를 유닛 1, 4 계열에서 하나씩 고른다
	var owned := GameData.rules.owned_roots(s)
	var pick: Array[String] = []
	var units_hit := {}
	for id in GameData.repo.all_ids():
		var w := GameData.repo.get_word(id)
		if s.has_word(w.id):
			continue
		for r in w.skill_roots:
			var u := GameData.bal.root_family(r)
			if u in [1, 4] and not units_hit.has(u) and not r in owned:
				units_hit[u] = true
				pick.append(w.id)
				break
		if units_hit.size() == 2:
			break
	assert_eq(units_hit.size(), 2, "두 유닛의 새 어근 단어가 있다")
	main.flow._give_words(pick, "ui.result.won", [], true)
	await wait_physics_frames(2)
	var seen: Array[int] = []
	for k in 4:
		var j := main.current() as RootJoyScreen
		if j == null:
			break
		seen.append(j._fig.unit)
		for b in j.find_children("*", "Button", true, false):
			(b as Button).pressed.emit()
			break
		await wait_physics_frames(2)
	assert_eq(seen.size(), 2, "유닛마다 한 번씩")
	assert_true(seen[0] < seen[1], "유닛 순서대로")
	assert_true(main.current() is ResultScreen, "기뻐한 뒤 결과 화면")
