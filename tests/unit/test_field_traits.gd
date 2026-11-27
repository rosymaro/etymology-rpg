extends GutTest
## 필드 특성(src/domain/hunt/field_traits.gd): 속성 점수, 5개 기준 크기, 4차 장비, 방어막


func _w(attrs: Array, tier: int = 1) -> WordData:
	var w := WordData.new()
	w.id = "w%d" % randi()
	w.tier = tier
	for a in attrs:
		w.attrs.append(int(a))
	return w


func test_five_items_give_full_value() -> void:
	var gear := []
	for i in 5:
		gear.append(_w([6]))  # 원소 = 공격
	var ft := FieldTraits.from_gear([gear])
	assert_almost_eq(ft.value("attack"), float(ft.cfg["traits"]["6"]["at5"]), 0.001)


func test_each_item_adds_a_fifth() -> void:
	var ft := FieldTraits.from_gear([[_w([9])]])  # 공간 = 사정거리
	assert_almost_eq(ft.value("range"), float(ft.cfg["traits"]["9"]["at5"]) / 5.0, 0.001)
	assert_eq(ft.value("attack"), 0.0)


func test_tier4_is_stronger() -> void:
	var t1 := FieldTraits.from_gear([[_w([11], 1)]])
	var t4 := FieldTraits.from_gear([[_w([11], 4)]])
	assert_gt(t4.value("move"), t1.value("move") * 1.5)


func test_word_with_two_attrs_counts_for_both() -> void:
	var ft := FieldTraits.from_gear([[_w([4, 15])]])
	assert_gt(ft.value("knockback"), 0.0)
	assert_gt(ft.value("coin_gain"), 0.0)


func test_shield_per_unit_with_five_same() -> void:
	var a := []
	var b := []
	var c := []
	for i in 5:
		a.append(_w([1]))
		b.append(_w([2]))
		c.append(_w([3] if i < 4 else [5]))  # 4개만 같다
	var ft := FieldTraits.from_gear([a, b, c])
	assert_eq(ft.shields, 2, "다섯 개가 같은 속성인 유닛만 방어막")


func test_score_caps() -> void:
	var gear := []
	for i in 30:
		gear.append(_w([6], 4))
	var ft := FieldTraits.from_gear([gear])
	assert_almost_eq(ft.value("attack"), float(ft.cfg["traits"]["6"]["at5"]) * float(ft.cfg["max_score"]) / 5.0, 0.001)


func test_damage_rises_on_average() -> void:
	var gear := []
	for i in 5:
		gear.append(_w([6]))
	var ft := FieldTraits.from_gear([gear])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var tot := 0
	for i in 2000:
		tot += ft.damage(2, 1.0, rng)
	assert_almost_eq(tot / 2000.0, 2.0 * (1.0 + ft.value("attack")), 0.1)


func test_mob_hp_rises_by_stage() -> void:
	var ft := FieldTraits.new()
	assert_eq(ft.mob_hp_mult(1), 1.0)
	assert_gt(ft.mob_hp_mult(10), ft.mob_hp_mult(5))
