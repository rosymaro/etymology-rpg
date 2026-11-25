extends GutTest
## 말 뽑기(07-fun.md 7절).

var g: Gacha
var rng := RandomNumberGenerator.new()


func before_each() -> void:
	g = Gacha.new(GameData.repo, GameData.rules, JsonFile.read("res://data/balance/gacha.json"))
	rng.seed = 2


func test_costs_coins_and_gives_a_word() -> void:
	var s := GameState.new()
	assert_eq(g.pull(s, 1, rng), [] as Array[Dictionary], "코인이 모자라면 못 뽑는다")
	s.wallet = 150
	var got := g.pull(s, 1, rng)
	assert_eq(got.size(), 1)
	assert_eq(s.wallet, 50)
	assert_true(s.has_word(got[0]["id"]), "뽑은 단어는 도감에")
	assert_eq(GameData.repo.get_word(got[0]["id"]).stage, 1, "열린 스테이지 단어만")


func test_ten_pulls_have_a_rare_word_and_rare_is_rarer() -> void:
	var s := GameState.new()
	s.wallet = 900 * 20
	for k in 20:
		var got := g.pull(s, 10, rng)
		assert_eq(got.size(), 10)
		assert_true(got.any(func(x: Dictionary) -> bool: return x["rare"]), "10번 뽑기는 드문 단어 보장")
	var common := 0
	var rare := 0
	s.wallet = 100 * 400
	for k in 400:
		var w := GameData.repo.get_word(g.pull(s, 1, rng)[0]["id"])
		if w.freq >= 8:
			common += 1
		elif w.freq <= 5:
			rare += 1
	# 스테이지 1: 빈도 8~9 단어 25개, 빈도 5 단어 53개. 단어 하나당 흔한 단어가 더 자주 나온다
	assert_gt(float(common) / 25.0, float(rare) / 53.0, "빈도가 낮을수록 드물다")
