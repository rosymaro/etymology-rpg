extends GutTest
## 02-rpg-v2 '장비 능력치', '켜지는 속성'


func _repo() -> WordRepository:
	var r := WordRepository.new()
	r.load_dicts([
		{"id": "w", "meaning": "", "attrs": [5, 1], "tier": 4, "unit": 1, "slot": "weapon"},
		{"id": "h", "meaning": "", "attrs": [1, 5], "tier": 2, "unit": 1, "slot": "head"},
		{"id": "c", "meaning": "", "attrs": [5], "tier": 1, "unit": 1, "slot": "chest"},
		{"id": "g", "meaning": "", "attrs": [1], "tier": 3, "unit": 1, "slot": "hands"},
		{"id": "f", "meaning": "", "attrs": [7], "tier": 1, "unit": 1, "slot": "feet"},
	])
	return r


func test_gear_stats_from_gear_json() -> void:
	var e := Equipment.new()
	for s in ["weapon", "head", "chest", "hands", "feet"]:
		e.put(s, s.substr(0, 1) if s != "hands" else "g")
	var st := e.stats(_repo(), JsonFile.read("res://data/balance/gear.json"))
	# 무기 4차 공+6, 머리 2차 방+2, 가슴 1차 체+2, 장갑 3차 공+2 방+2, 신발 1차 체+1
	assert_eq([st.atk, st.def, st.hp], [8, 4, 3])


func test_tie_breaks_by_weapon_primary_attr() -> void:
	var e := Equipment.new()
	for s in ["weapon", "head", "chest", "hands", "feet"]:
		e.put(s, s.substr(0, 1) if s != "hands" else "g")
	# 5: w,h,c = 3점 / 1: w,h,g = 3점 → 동점, 무기의 주속성 5
	var r := AttributeResolver.new().resolve(e, _repo())
	assert_eq(r["attr"], 5)
	assert_eq(r["tier"], 1)


func test_below_three_is_off() -> void:
	var e := Equipment.new()
	e.put("feet", "f")
	assert_eq(AttributeResolver.new().resolve(e, _repo())["tier"], 0)
