extends GutTest
## 유닛마다 다른 필드 무기(UnitWeapons, 07-fun 1절): 12가지가 모두 맞히고, 벽 너머는 못 맞힌다.

var cfg: Dictionary


func before_each() -> void:
	cfg = JsonFile.read("res://data/balance/field_hunt.json")


func _open_map(rows: Array) -> WorldMap:
	return WorldMap.from_dict({"w": String(rows[0]).length(), "h": rows.size(), "tile": 64, "rows": rows, "walk": "."})


func _mob(p: Vector2) -> FieldMob:
	var m := FieldMob.new()
	m.kind = "wander"
	m.max_hp = 99
	m.hp = 99
	m.pos = p
	return m


## 3초 동안 쏘아 맞음을 모은다.
func _run_weapon(id: String, map: WorldMap, mobs: Array, origin: Vector2) -> Array[Dictionary]:
	var run := HuntRun.new({}, cfg)
	run.set_units([int(cfg["weapons"][id]["unit"])])
	var uw := UnitWeapons.new()
	var all: Array[Dictionary] = []
	for k in 180:
		all.append_array(uw.tick(1.0 / 60.0, run.weapons_now(), {id: origin}, origin, Vector2.RIGHT, mobs, map))
	return all


func test_every_unit_weapon_hits() -> void:
	var rows := []
	for y in 20:
		rows.append(".".repeat(30))
	var map := _open_map(rows)
	var o := Vector2(10, 10) * 64.0
	for id in cfg["weapons"]:
		var w: Dictionary = cfg["weapons"][id]
		var near := 115.0 if w["type"] in ["bash", "aura"] else 140.0  # 주인공 바로 옆(no_fire_near)은 쏘지 않는다
		var mob := _mob(o + Vector2(near if w["type"] != "orbit" else 110.0, 0))
		var hits := _run_weapon(String(id), map, [mob], o)
		assert_gt(hits.size(), 0, "%s(%s)가 맞힌다" % [id, w["type"]])


func test_weapons_do_not_go_through_walls() -> void:
	var rows := []
	for y in 20:
		rows.append(".".repeat(12) + "^" + ".".repeat(17))
	var map := _open_map(rows)
	var o := Vector2(10.5, 10.5) * 64.0
	for id in cfg["weapons"]:
		var w: Dictionary = cfg["weapons"][id]
		if w["type"] == "orbit" or w["type"] == "aura" or w["type"] == "bash":
			continue  # 닿는 거리가 벽까지 가지 않는다
		var mob := _mob(Vector2(14.5, 10.5) * 64.0)  # 벽(x=12) 너머
		var hits := _run_weapon(String(id), map, [mob], o)
		assert_eq(hits.size(), 0, "%s(%s)는 벽 너머를 못 맞힌다" % [id, w["type"]])


func test_grab_holds_and_bash_pushes_hard() -> void:
	var rows := []
	for y in 20:
		rows.append(".".repeat(30))
	var map := _open_map(rows)
	var o := Vector2(10, 10) * 64.0
	var g := _run_weapon("u02", map, [_mob(o + Vector2(140, 0))], o)
	assert_gt(float(g[0]["stun"]), 0.0, "덥석: 붙잡아 멈춘다")
	assert_lt(float(g[0]["push"]), 0.0, "붙잡힌 몹은 밀리지 않는다")
	var b := _run_weapon("u11", map, [_mob(o + Vector2(115, 0))], o)
	assert_gt(float(b[0]["push"]), float(cfg["knockback"]), "꿈쩍: 세게 밀친다")


func test_companions_up_to_three_and_at_least_one() -> void:
	var s := GameState.new()
	s.joined = [1, 2, 3, 4, 5] as Array[int]
	assert_eq(Loadout.max_companions(), 3, "동행은 3명까지(field_hunt.json field_party)")
	assert_eq(Loadout.companions(s), [1, 2, 3] as Array[int], "처음엔 합류한 순서로")
	assert_false(Loadout.toggle_companion(s, 4), "가득 차면 더 못 넣는다")
	assert_true(Loadout.toggle_companion(s, 2))
	assert_true(Loadout.toggle_companion(s, 4))
	assert_eq(Loadout.companions(s), [1, 3, 4] as Array[int])
	Loadout.toggle_companion(s, 1)
	Loadout.toggle_companion(s, 3)
	assert_false(Loadout.toggle_companion(s, 4), "한 명은 남는다")
	assert_eq(Loadout.companions(GameState.from_dict(s.to_dict())), [4] as Array[int], "저장된다")
