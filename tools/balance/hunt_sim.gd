extends SceneTree
## 필드 사냥 시뮬레이터(07-fun 1절). 게임의 규칙 층(HuntRun, UnitWeapons, FieldMob, WorldMap)을 그대로 쓴다.
## 목표: 동행이 다가오는 몹의 80%쯤을 막고, 20%쯤은 뚫려 주인공에게 붙는다(사용자 의견: 영어를 배워야 하니 자주 뚫린다).
## godot --headless -s tools/balance/hunt_sim.gd -- [초=300] [판=6] [single: 유닛 하나씩]
## 주인공은 들판을 이리저리 걷다가 가까운 몹은 피하고(벽에 막히면 방향을 바꾼다), 떨어진 구슬은 바로 줍는다고 본다(레벨업은 무기 강화를 먼저).

const HERO_R := 26.0
const ENEMY_R := 30.0
const DT := 1.0 / 30.0

var map: WorldMap
var f: Dictionary
var hc: Dictionary


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var secs := float(args[0]) if args.size() > 0 else 300.0
	var trials := int(args[1]) if args.size() > 1 else 6
	map = WorldMap.load_default()
	f = JsonFile.read("res://data/balance/field.json")
	hc = JsonFile.read("res://data/balance/field_hunt.json")
	print("동행 | 판 | 막음 | 뚫림 | 뚫린 비율 | 분당 조우 | 끝 레벨")
	var parties: Array = [[1], [1, 5], [1, 5, 10], [1, 4, 11], [6, 9, 12], [2, 3, 7], [8, 10, 11], [3, 6, 12], [2, 5, 8]]
	if args.size() > 2 and args[2] == "solo":
		parties = [[1]]
	if args.size() > 2 and args[2] == "single":
		parties = []
		for u in range(1, 13):
			parties.append([u])
	for party in parties:
		var kills := 0
		var breach := 0
		var lv := 0
		for t in trials:
			var r := _run(party, secs, 100 + t)
			kills += int(r["kills"])
			breach += int(r["breach"])
			lv += int(r["level"])
		var total := maxi(1, kills + breach)
		print("%s | %d | %d | %d | %d%% | %.1f | %.1f" % [str(party), trials, kills, breach, roundi(100.0 * breach / total),
			breach / (secs / 60.0) / trials, float(lv) / trials])
	quit()


func _run(party: Array, secs: float, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var run := HuntRun.new({}, hc)
	run.set_units(party)
	run.reset()
	var uw := UnitWeapons.new()
	uw.no_fire_near = float(hc["no_fire_near"])
	var hero := _start(rng)
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var turn_t := 0.0
	var mobs: Array = []
	var kills := 0
	var breach := 0
	var t := 0.0
	var spawn_t := 0.0
	var trail: Array[Vector2] = []
	while t < secs:
		t += DT
		# 주인공 걷기
		turn_t -= DT
		if turn_t <= 0.0:
			turn_t = rng.randf_range(1.5, 3.5)
			dir = Vector2.from_angle(rng.randf() * TAU)
		var flee_v := Vector2.ZERO  # 사람처럼 가까운 몹은 피한다(쫓기·돌진 몹이 260px 안이면 반대쪽으로)
		for e in mobs:
			var dd: Vector2 = hero - (e as FieldMob).pos
			if dd.length() < 260.0 and (e as FieldMob).kind != "flee":
				flee_v += dd.normalized() * (260.0 - dd.length())
		var go := dir if flee_v.length() < 1.0 else (flee_v.normalized() * 0.8 + dir * 0.2).normalized()
		var nh := map.move(hero, go * float(f["hero_speed"]) * run.speed_mult() * DT, HERO_R)
		if nh.distance_to(hero) < 1.0 or map.is_town(nh) or map.stage_at(nh) != 1:
			dir = Vector2.from_angle(rng.randf() * TAU)
		else:
			hero = nh
		trail.push_front(hero)
		if trail.size() > 60:
			trail.resize(60)
		# 몹 채우기(화면과 같이 레벨이 오를수록 많이)
		spawn_t -= DT
		if spawn_t <= 0.0 and mobs.size() < run.mob_count(int(f["enemy_count"])):
			spawn_t = 0.4
			var m := _mob(run, rng, hero)
			if m:
				mobs.append(m)
		# 무기
		var origins := {}
		for k in party.size():
			origins[run.weapon_of(int(party[k]))] = trail[mini((k + 1) * 5, trail.size() - 1)]
		for h in uw.tick(DT, run.weapons_now(), origins, hero, dir, mobs, map):
			var e: FieldMob = h["mob"]
			if not mobs.has(e):
				continue
			if float(h.get("stun", 0.0)) > 0.0:
				e.stun = maxf(e.stun, float(h["stun"]))
			var push := float(h.get("push", 0.0))
			if push >= 0.0:
				var away := (e.pos - (h["from"] as Vector2))
				if away.length() < 1.0:
					away = e.pos - hero
				e.set_meta("push", away.normalized() * (push if push > 0.0 else float(hc["knockback"])))
				e.set_meta("push_t", 0.3)
			if e.take_hit(int(h["dmg"])):
				mobs.erase(e)
				kills += 1
				var got := run.drops(e.kind, [], rng)
				if run.pick_orbs(int(got["orbs"])):
					var cs := run.choices(rng)
					var pick: Dictionary = cs[0]
					for c in cs:
						if c["type"] == "up":
							pick = c
					run.apply(pick)
		# 몹 움직이기·붙기
		for e in mobs.duplicate():
			var m := e as FieldMob
			if m.pos.distance_to(hero) > float(f["spawn_far"]):
				mobs.erase(m)
				continue
			var v := m.steer(hero, DT, f["kinds"], rng)
			if m.has_meta("push"):
				v = (m.get_meta("push") as Vector2) / 0.3
				var pt := float(m.get_meta("push_t", 0.3)) - DT
				m.set_meta("push_t", pt)
				if pt <= 0.0:
					m.remove_meta("push")
					m.remove_meta("push_t")
			var np := map.move(m.pos, v * DT, ENEMY_R)
			if not map.is_town(np) and map.stage_at(np) == 1:
				m.pos = np
			if m.pos.distance_to(hero) < HERO_R + ENEMY_R and m.stun <= 0.0:
				breach += 1  # 붙었다: 유추 퀴즈로(시뮬레이션에서는 그 몹을 지운다)
				mobs.erase(m)
		run.tick(DT)
	return {"kills": kills, "breach": breach, "level": run.level()}


func _start(rng: RandomNumberGenerator) -> Vector2:
	for k in 200:
		var p := map.random_field_spot(1, rng, map.start(1), 900, 2400, HERO_R)
		if p != Vector2.INF:
			return p
	return map.start(1)


func _mob(run: HuntRun, rng: RandomNumberGenerator, hero: Vector2) -> FieldMob:
	var near: Array = f["spawn_near"]
	var p := map.random_field_spot(1, rng, hero, float(near[0]), float(near[1]), ENEMY_R)
	if p == Vector2.INF:
		return null
	var m := FieldMob.new()
	m.pos = p
	m.kind = FieldMob.pick_kind(f["kinds"], rng)
	m.max_hp = run.mob_hp(m.kind)
	m.hp = m.max_hp
	return m
