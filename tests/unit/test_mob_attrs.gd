extends GutTest
## 속성마다 몹 행동(data/balance/mob_attrs.json)과 잡은 횟수에 따른 단어 무게(WordWeight)

var cfg: Dictionary
var kinds: Dictionary
var rng := RandomNumberGenerator.new()


func before_all() -> void:
	cfg = JsonFile.read("res://data/balance/mob_attrs.json")
	kinds = JsonFile.read("res://data/balance/field.json")["kinds"]
	rng.seed = 7


func _mob(attr: int) -> FieldMob:
	var m := FieldMob.new()
	m.attr = attr
	m.max_hp = 6
	m.hp = 6
	m.apply_attr(cfg, kinds, rng)
	return m


func test_every_attr_has_behavior_and_shape() -> void:
	for a in range(1, 21):
		var c: Dictionary = cfg["attrs"][str(a)]
		assert_true(c.has("move") and c.has("shape"), "속성 %d" % a)


func test_wave_keeps_old_four_kinds() -> void:
	var seen := {}
	for i in 80:
		seen[_mob(4).kind] = true
	for k in ["wander", "chase", "flee", "rush"]:
		assert_true(seen.has(k), "파동은 예전 네 가지가 섞인다: " + k)


func test_authority_shield_blocks_one_hit() -> void:
	var m := _mob(13)
	assert_eq(m.shield, 1)
	m.take_hit(3)
	assert_eq(m.hp, 6, "첫 방은 방어막이 막는다")
	m.take_hit(3)
	assert_eq(m.hp, 3)


func test_nature_sleeps_until_hit() -> void:
	var m := _mob(5)
	assert_eq(m.kind, "still")
	assert_eq(m.steer(Vector2(200, 0), 0.016, kinds, rng), Vector2.ZERO, "가만히")
	m.take_hit(1)
	assert_gt(m.steer(Vector2(200, 0), 0.016, kinds, rng).x, 0.0, "맞으면 달려든다")


func test_creation_splits_once_with_one_fake() -> void:
	var m := _mob(8)
	m.take_hit(1)
	var twin := m.split_off(rng)
	assert_ne(m.fake, twin.fake, "하나만 진짜")
	assert_eq(m.split_left, 0, "한 번만")
	assert_eq(twin.words, m.words)


func test_wisdom_stalks_only_when_not_looked_at() -> void:
	var m := _mob(3)
	m.facing_hero = Vector2.RIGHT  # 주인공(200,0)이 오른쪽을 본다 → 등 뒤의 몹(0,0)은 다가온다
	assert_gt(m.steer(Vector2(200, 0), 0.016, kinds, rng).x, 0.0)
	m.facing_hero = Vector2.LEFT  # 몹 쪽을 보면 멈춘다
	assert_eq(m.steer(Vector2(200, 0), 0.016, kinds, rng), Vector2.ZERO)


func test_order_marches_on_axis() -> void:
	var m := _mob(20)
	var v := m.steer(Vector2(300, 100), 0.016, kinds, rng)
	assert_true(v.y == 0.0 and v.x > 0.0, "가로·세로로만")


func test_caught_words_appear_less_but_never_vanish() -> void:
	var c := {"cap": 10, "floor": 0.15}
	assert_eq(WordWeight.weight(10.0, 0, c), 10.0)
	assert_lt(WordWeight.weight(10.0, 5, c), 10.0)
	assert_almost_eq(WordWeight.weight(10.0, 10, c), 1.5, 0.001)
	assert_almost_eq(WordWeight.weight(10.0, 40, c), 1.5, 0.001, "10번 넘으면 고정")


func test_catch_count_saved() -> void:
	var s := GameState.new()
	GameData.rules.gain_word(s, "information")
	GameData.rules.gain_word(s, "information")
	assert_eq(int(s.caught["information"]), 2)
	assert_eq(int(GameState.from_dict(s.to_dict()).caught["information"]), 2)
