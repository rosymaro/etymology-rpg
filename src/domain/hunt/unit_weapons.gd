class_name UnitWeapons
extends RefCounted
## 필드에 데리고 다니는 유닛의 무기(07-fun.md 1절). 노드·화면을 모른다. 화면은 tick()이 돌려준 맞음을 적용하고,
## shots·fx·orbit_a를 보고 그린다. 무기 종류(type)마다 쏘는 법이 다르다(바뀌기 쉬운 부분은 이 안에 모은다).
## 맞음(hit) = {mob: FieldMob, dmg, from: Vector2(밀려나는 기준), push: 밀려나는 거리(0이면 기본), stun: 멈추는 초}
##
## type: boomerang(갔다 돌아옴) · grab(붙잡아 멈춤) · beam(곧은 빛, 꿰뚫음) · snipe(가장 약한 몹) · nova(원으로 퍼짐)
##       arrow(걷는 쪽으로 꿰뚫고 날아감) · lob(던져서 떨어진 둘레) · aura(둘레를 계속) · fan(부채꼴) · orbit(빙글빙글)
##       bash(가까운 몹을 세게 밀침) · slam(가까운 몹 둘레 크게 내리침)

var timers := {}  ## 무기 id -> 다음 쏘기까지
var shots: Array[Dictionary] = []  ## {id, type, pos, vel | to, back, home(유닛 번호), left(남은 거리), dmg, hit:{}, t}
var fx: Array[Dictionary] = []  ## 그리기용 잠깐 효과 {type, a, b, r, t, max, unit}
var orbit_a := 0.0
var _orbit_hit := {}  ## 몹 -> 다음에 맞을 수 있는 시각
var _now := 0.0
var no_fire_near := 90.0


func clear() -> void:
	timers.clear()
	shots.clear()
	fx.clear()
	_orbit_hit.clear()


## 한 프레임. weapons: {무기 id: 지금 수치(HuntRun.weapon)}, origins: {무기 id: 그 유닛 자리}, hero: 주인공 자리,
## facing: 걷는 쪽(단위 벡터), enemies: 몹, map: 벽 판정(clear_line·walkable)
func tick(delta: float, weapons: Dictionary, origins: Dictionary, hero: Vector2, facing: Vector2, enemies: Array, map: WorldMap) -> Array[Dictionary]:
	_now += delta
	var hits: Array[Dictionary] = []
	for id in weapons:
		var w: Dictionary = weapons[id]
		var o: Vector2 = origins.get(id, hero)
		if w["type"] == "orbit":  # 팽이는 주인공 둘레를 바짝 돈다: 다가온 몹을 쳐서 바깥으로 밀어낸다
			orbit_a += float(w["speed"]) * delta
			for k in int(w["count"]):
				var p := orbit_pos(hero, w, k)
				for e in enemies:
					if (e as FieldMob).pos.distance_to(p) < 48.0 and _now >= float(_orbit_hit.get(e, 0.0)) and map.shot_line(hero, e.pos):
						_orbit_hit[e] = _now + float(w["hit_gap"])
						hits.append({"mob": e, "dmg": int(w["dmg"]), "from": hero})
			continue
		timers[id] = float(timers.get(id, 0.5)) - delta
		if timers[id] > 0.0:
			continue
		timers[id] = float(w["cd"])
		if not _fire(String(id), w, o, hero, facing, enemies, map, hits):
			timers[id] = 0.2  # 쏠 몹이 없으면 곧 다시 본다
	_move_shots(delta, enemies, map, origins, hits)
	for f in fx.duplicate():
		f["t"] = float(f["t"]) + delta
		if f["t"] >= float(f["max"]):
			fx.erase(f)
	return hits


func orbit_pos(o: Vector2, w: Dictionary, k: int) -> Vector2:
	return o + Vector2.from_angle(orbit_a + k * TAU / maxi(1, int(w["count"]))) * float(w["range"])


## 그 자리에서 보이는(벽 없이) 범위 안 몹, 가까운 순. 주인공에게 붙기 직전 몹은 뺀다(퀴즈로 잡고 싶을 때).
func targets(o: Vector2, hero: Vector2, range_px: float, enemies: Array, map: WorldMap) -> Array[FieldMob]:
	var out: Array[FieldMob] = []
	for e in enemies:
		var m := e as FieldMob
		if m.pos.distance_to(o) <= range_px and m.pos.distance_to(hero) > no_fire_near and map.shot_line(o, m.pos):
			out.append(m)
	out.sort_custom(func(a: FieldMob, b: FieldMob) -> bool: return a.pos.distance_to(o) < b.pos.distance_to(o))
	return out


func _fire(id: String, w: Dictionary, o: Vector2, hero: Vector2, facing: Vector2, enemies: Array, map: WorldMap, hits: Array[Dictionary]) -> bool:
	var unit := int(w.get("unit", 0))
	var dmg := int(w["dmg"])
	var rng_px := float(w["range"])
	var ts := targets(o, hero, rng_px, enemies, map)
	match String(w["type"]):
		"arrow":  # 정해진 8방향 가운데 가장 가까운 몹 쪽으로 곧게 꿰뚫는다(조준하지 않아서 비스듬한 몹은 빗나간다)
			if ts.is_empty():
				return false
			var ang := snappedf((ts[0].pos - o).angle(), PI / 4.0)
			var n := int(w["count"])
			for k in n:
				var a := (k - (n - 1) / 2.0) * 0.16
				shots.append({"id": id, "type": "straight", "pos": o, "vel": Vector2.from_angle(ang + a) * float(w["speed"]), "left": rng_px, "dmg": dmg, "hit": {}, "unit": unit, "pierce": true})
			return true
	if ts.is_empty():
		return false
	match String(w["type"]):
		"boomerang":
			for k in mini(int(w["count"]), ts.size()):
				shots.append({"id": id, "type": "boomerang", "pos": o, "to": ts[k].pos, "back": false, "home": id, "dmg": dmg, "hit": {}, "unit": unit, "speed": float(w["speed"])})
		"grab":
			for k in mini(int(w["count"]), ts.size()):
				hits.append({"mob": ts[k], "dmg": dmg, "from": o, "push": -1.0, "stun": float(w["stun"])})
				fx.append({"type": "grab", "a": o, "b": ts[k].pos, "t": 0.0, "max": 0.35, "unit": unit})
		"beam":
			var dir := (ts[0].pos - o).normalized()
			var end := o + dir * rng_px
			for e in enemies:
				var m := e as FieldMob
				var along := (m.pos - o).dot(dir)
				if along > 0.0 and along <= rng_px and absf((m.pos - o).cross(dir)) <= float(w["width"]) and map.shot_line(o, m.pos):
					hits.append({"mob": m, "dmg": dmg, "from": o})
			fx.append({"type": "beam", "a": o, "b": end, "r": float(w["width"]), "t": 0.0, "max": 0.3, "unit": unit})
		"snipe":  # 가장 약한(체력이 적은) 몹부터
			ts.sort_custom(func(a: FieldMob, b: FieldMob) -> bool: return a.hp < b.hp)
			for k in mini(int(w["count"]), ts.size()):
				hits.append({"mob": ts[k], "dmg": dmg, "from": o})
				fx.append({"type": "snipe", "a": o, "b": ts[k].pos, "t": 0.0, "max": 0.3, "unit": unit})
		"nova", "aura", "bash":  # 밀어내는 쪽은 주인공에게서 멀어지는 쪽(동행 뒤에서 밀면 주인공 쪽으로 밀리지 않게)
			for e in ts:
				hits.append({"mob": e, "dmg": dmg, "from": hero, "push": float(w.get("push", 0.0))})
			fx.append({"type": w["type"], "a": o, "r": rng_px, "t": 0.0, "max": 0.35, "unit": unit})
		"fan":
			var base := (ts[0].pos - o).normalized()
			var n := int(w["count"])
			for k in n:
				var a := (k - (n - 1) / 2.0) * float(w["spread"]) / maxf(1.0, n - 1.0)
				shots.append({"id": id, "type": "straight", "pos": o, "vel": base.rotated(a) * float(w["speed"]), "left": rng_px, "dmg": dmg, "hit": {}, "unit": unit, "pierce": false})
		"lob":
			var lead: Vector2 = ts[0].pos + ts[0].vel * float(w["flight"]) * 0.8  # 몹이 갈 자리를 어림해 던진다
			shots.append({"id": id, "type": "lob", "a": o, "pos": o, "to": lead, "t": 0.0, "max": float(w["flight"]), "dmg": dmg, "r": float(w["radius"]), "unit": unit, "hit": {}})
		"slam":
			var c := ts[0].pos
			for e in enemies:
				if (e as FieldMob).pos.distance_to(c) <= float(w["radius"]) and map.shot_line(o, e.pos):
					hits.append({"mob": e, "dmg": dmg, "from": c})
			fx.append({"type": "slam", "a": c, "r": float(w["radius"]), "t": 0.0, "max": 0.4, "unit": unit})
	return true


func _move_shots(delta: float, enemies: Array, map: WorldMap, origins: Dictionary, hits: Array[Dictionary]) -> void:
	for sh in shots.duplicate():
		match String(sh["type"]):
			"boomerang":  # 목표까지 갔다가 그 유닛에게 돌아온다
				var home: Vector2 = origins.get(sh["home"], sh["pos"])
				var to: Vector2 = home if sh["back"] else sh["to"]
				var d: Vector2 = to - (sh["pos"] as Vector2)
				var step := float(sh["speed"]) * delta
				if d.length() <= step:
					if sh["back"]:
						shots.erase(sh)
						continue
					sh["back"] = true
				else:
					sh["pos"] = (sh["pos"] as Vector2) + d.normalized() * step
			"straight":
				sh["pos"] = (sh["pos"] as Vector2) + (sh["vel"] as Vector2) * delta
				sh["left"] = float(sh["left"]) - (sh["vel"] as Vector2).length() * delta
				if float(sh["left"]) <= 0.0:
					shots.erase(sh)
					continue
			"lob":  # 포물선으로 날아가 떨어진 둘레를 친다
				sh["t"] = float(sh["t"]) + delta
				var k := minf(1.0, float(sh["t"]) / float(sh["max"]))
				sh["pos"] = (sh["a"] as Vector2).lerp(sh["to"], k)
				if k >= 1.0:
					for e in enemies:
						if (e as FieldMob).pos.distance_to(sh["to"]) <= float(sh["r"]):
							hits.append({"mob": e, "dmg": int(sh["dmg"]), "from": sh["to"]})
					fx.append({"type": "slam", "a": sh["to"], "r": float(sh["r"]), "t": 0.0, "max": 0.35, "unit": sh["unit"]})
					shots.erase(sh)
				continue
		if not map.shot_passes(map.cell(sh["pos"])):  # 벽을 뚫지 못한다: 부딪히면 떨어진다(마을 성벽 위로는 넘어간다)
			shots.erase(sh)
			continue
		for e in enemies:
			if not (sh["hit"] as Dictionary).has(e) and (e as FieldMob).pos.distance_to(sh["pos"]) < 44.0:
				sh["hit"][e] = true
				hits.append({"mob": e, "dmg": int(sh["dmg"]), "from": sh["pos"]})
				if sh["type"] == "straight" and not sh.get("pierce", false):
					shots.erase(sh)
					break
