extends GutTest
## 실제 데이터 파일이 읽히고 스테이지 1을 할 수 있는지.


func test_real_data_loads_and_stage1_is_playable() -> void:
	var repo := WordRepository.load_default()
	var bal := Balance.load_default()
	assert_eq(repo.size(), 10000)
	assert_eq(repo.first_tier(1).size(), 153)
	assert_not_null(repo.boss_word(1))
	assert_gt(repo.evolutions_up_to(1, 2).size(), 0, "스테이지 1 재료로 만드는 2차 단어가 있다")
	assert_true(EffectRegistry.magic_implemented(bal.magic_def("de")))
	assert_not_null(EffectRegistry.make_boss(bal.boss_def(1)["ability"]))


func test_real_boss_battle_runs() -> void:
	var repo := WordRepository.load_default()
	var bal := Balance.load_default()
	var rules := ProgressRules.new(repo, bal)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var setup := BattleSetup.new(repo, bal, rules, CoinSource.new(rng))
	var s := GameState.new()
	s.joined = [1, 4] as Array[int]
	var party := setup.pick_party(s)
	var ctx := setup.make_context(s, party, {}, "de")
	setup.boss_enemies(ctx, s, 1)
	var r := BattleEngine.new(ctx).run()
	assert_eq(r.enemy_count, 2)
	assert_gt(ctx.log.size(), 3)
