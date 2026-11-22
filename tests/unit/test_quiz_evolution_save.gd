extends GutTest


func test_quiz_has_four_distinct_real_meanings_with_answer() -> void:
	var repo := TestHelpers.repo()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var q := QuizBuilder.new(repo, rng).question("fa")
	assert_eq(q.options.size(), 4)
	assert_eq(q.options[q.answer], "가")
	var uniq := {}
	for o in q.options:
		uniq[o] = true
	assert_eq(uniq.size(), 4)


func test_evolution_needs_all_materials_and_quizzes_leaves_plus_result() -> void:
	var repo := TestHelpers.repo()
	var rule := EvolutionRule.new(repo)
	var s := GameState.new()
	s.dex["fa"] = 1
	assert_false(rule.can_evolve(s, "ev2"))
	s.dex["fb"] = 2
	assert_true(rule.can_evolve(s, "ev2"))
	assert_eq(rule.quiz_words("ev2"), ["fa", "fb", "ev2"] as Array[String])


func test_failed_evolution_blocks_until_recapture() -> void:
	var repo := TestHelpers.repo()
	var rule := EvolutionRule.new(repo)
	var s := GameState.new()
	s.dex = {"fa": 1, "fb": 2}
	var wrong: Array[String] = ["ev2", "fb"]
	s.recapture["ev2"] = rule.recapture_target("ev2", wrong)
	assert_eq(s.recapture["ev2"], "fb")
	assert_false(rule.can_evolve(s, "ev2"))
	var bal := Balance.new()
	bal.progress = JsonFile.read("res://data/balance/progress.json")
	ProgressRules.new(repo, bal).gain_word(s, "fb")
	assert_true(rule.can_evolve(s, "ev2"), "다시 잡으면 재도전")


func test_save_round_trip() -> void:
	var s := GameState.new()
	s.hero_name = "가나"
	s.dex = {"fa": 1}
	s.unit_exp[3] = 77
	s.eq(1).put("weapon", "fa")
	s.chosen_roots[1] = "ple"
	s.pos = Vector2(3, 4)
	var store := SaveStore.new("user://test_save.json")
	assert_true(store.save(s))
	var t := store.load_state()
	assert_eq(t.hero_name, "가나")
	assert_eq(t.dex["fa"], 1)
	assert_eq(t.unit_exp[3], 77)
	assert_eq(t.eq(1).get_in("weapon"), "fa")
	assert_eq(t.chosen_roots[1], "ple")
	assert_eq(t.pos, Vector2(3, 4))
	store.erase()
