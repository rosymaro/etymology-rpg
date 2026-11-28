class_name FieldMob
extends RefCounted
## 필드 몹의 움직임(04-meta.md 7절). 노드·화면을 모른다. 수치는 data/balance/field.json의 kinds.
## wander: 이리저리 배회. chase: 주인공이 sight 안에 오면 쫓아온다(give_up보다 멀어지면 그만). flee: 가까이 오면 반대로 도망간다.
## rush: 가까이 오면 잠깐 멈춰 떨다가(windup, 화면에 !!) 그때 주인공 자리로 아주 빠르게 돌진하고(dash), 잠깐 쉰다(rest).

var kind := "wander"
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var words: Array[String] = []
var alert := false  ## 쫓는 중·도망가는 중
var stun := 0.0  ## 남은 멈춤 시간(필드 마법 de- 등)
var ignore := false  ## 주인공을 못 알아챔(필드 마법 sub- 몰래 걷기)
var attr := 0  ## 몸 색을 정하는 속성(첫 단어의 주속성, 1~20)
var slot := ""  ## 몸 모양을 정하는 착용 부위(첫 단어: weapon head chest hands feet)
var hp := 1  ## 필드 사냥 체력(07-fun 1절)
var max_hp := 1
var flash := 0.0  ## 맞고 깜빡이는 남은 시간
var phase := ""  ## rush: "" | wind(떨기) | dash(돌진) | rest(쉬기)
## 속성 행동(data/balance/mob_attrs.json, 사용자 의견): 움직임 kind 위에 덧붙는 성질
var quirk := ""  ## regen ghost sleeper pack shield rope split blink caller heavy burrow
var shield := 0  ## 남은 방어막(맞아도 한 번 막는다)
var fake := false  ## 나뉜 가짜(닿아도 전투가 없다)
var split_left := 0  ## 남은 나뉨 수
var hidden := false  ## 땅속에 숨음(burrow): 안 보이고 맞지 않는다
var rage := 0.0  ## 동료가 불러서(caller)·무리가 모여서(pack) 달려드는 남은 시간
var rage_speed := 0.0
var want_tp := false  ## 순간이동·튀어나올 자리를 화면에 부탁(blink, burrow)
var want_rope := false  ## 밧줄을 쏠 때(rope)
var facing_hero := Vector2.ZERO  ## 주인공이 보는 쪽(stalk)
var moves := {}  ## mob_attrs.json moves
var traits := {}  ## mob_attrs.json traits
var _tr_t := 0.0  ## 성질 타이머
var _dive_t := 0.0
var phase_t := 0.0
var wave_scale := 1.0  ## 파동: 사냥 레벨에 따라 물결 거리·속도 배율(set_level)
var _dash_dir := Vector2.ZERO


## 필드 사냥 무기에 맞음. 쓰러지면 true. 뿌리먹이(eater)는 체력이 1 아래로 내려가지 않는다(공격을 뚫고 온다).
func take_hit(dmg: int) -> bool:
	flash = 0.15
	if shield > 0:  # 방어막(권위): 한 번은 막는다
		shield -= 1
		return false
	hp = maxi(1 if kind == "eater" else 0, hp - dmg)
	if quirk == "sleeper" and kind == "still":  # 자연: 가만히 있다가 맞으면 달려든다
		kind = "chase"
		alert = true
		rage = 999.0
		rage_speed = float(traits.get("sleeper", {}).get("speed", 520))
	return hp <= 0


## 속성 행동을 붙인다(mob_attrs.json attrs[속성]). mixed면 예전 네 가지(kinds 무게)에서 고른다.
func apply_attr(cfg: Dictionary, kinds: Dictionary, rng: RandomNumberGenerator) -> void:
	var a: Dictionary = cfg.get("attrs", {}).get(str(attr), {})
	moves = cfg.get("moves", {})
	traits = cfg.get("traits", {})
	var mv := String(a.get("move", "mixed"))
	kind = pick_kind(kinds, rng) if mv == "mixed" else mv
	quirk = String(a.get("quirk", ""))
	if quirk == "shield":
		shield = int(traits.get("shield", {}).get("count", 1))
	if quirk == "split":
		split_left = int(traits.get("split", {}).get("times", 1))
	_tr_t = rng.randf_range(0.5, 2.0)


## 사냥 레벨에 맞춘다(파동: 레벨이 오를수록 더 멀리·빠르게 밀려온다).
func set_level(lv: int) -> void:
	var k: Dictionary = moves.get("wave", {})
	wave_scale = minf(float(k.get("max_scale", 1.0)), 1.0 + lv * float(k.get("per_level", 0.0)))


## 나뉜다(창조): 체력을 반으로 하고 똑같은 모습의 짝을 돌려준다. 하나만 진짜(fake = false).
func split_off(rng: RandomNumberGenerator) -> FieldMob:
	split_left -= 1
	hp = maxi(1, int(ceil(hp / 2.0)))
	var m := FieldMob.new()
	m.kind = kind
	m.pos = pos + Vector2.from_angle(rng.randf() * TAU) * 40.0
	m.words = words
	m.attr = attr
	m.slot = slot
	m.quirk = quirk
	m.moves = moves
	m.wave_scale = wave_scale
	m.traits = traits
	m.max_hp = max_hp
	m.hp = hp
	if rng.randf() < 0.5:  # 어느 쪽이 진짜인지 모르게
		m.fake = true
	else:
		fake = true
	return m


## 성질의 시간 흐름: 다시 차는 체력(regen), 순간이동(blink), 숨기·튀어나오기(burrow), 밧줄(rope). 화면은 want_*를 보고 한다.
func tick_trait(delta: float, hero: Vector2) -> void:
	rage = maxf(0.0, rage - delta)
	_tr_t -= delta
	if _tr_t > 0.0:
		return
	var tc: Dictionary = traits.get(quirk, {})
	match quirk:
		"regen":
			_tr_t = float(tc.get("every", 3.0))
			hp = mini(max_hp, hp + 1)
		"blink":
			_tr_t = float(tc.get("every", 3.2))
			if alert:
				want_tp = true
		"burrow":
			hidden = not hidden
			_tr_t = float(tc.get("hide" if hidden else "show", 2.4))
			if not hidden and pos.distance_to(hero) < 900.0:
				want_tp = true  # 주인공 가까이 튀어나온다
		"rope":
			_tr_t = float(tc.get("cd", 4.5))
			if pos.distance_to(hero) < float(tc.get("range", 460)):
				want_rope = true
		_:
			_tr_t = 999.0


func hurt_ratio() -> float:
	return 1.0 - float(hp) / float(maxi(1, max_hp))
var _t := 0.0


static func pick_kind(kinds: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in kinds:
		total += int(kinds[k]["weight"])
	var r := rng.randi_range(1, maxi(1, total))
	for k in kinds:
		r -= int(kinds[k]["weight"])
		if r <= 0:
			return k
	return "wander"


## 이번 프레임에 가고 싶은 속도(벽은 WorldMap.move가 막는다).
func steer(hero: Vector2, delta: float, kinds: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	if stun > 0.0:
		stun -= delta
		vel = Vector2.ZERO
		return vel
	flash = maxf(0.0, flash - delta)
	if kind == "eater" and ignore:  # 주인공을 알아채지 못하면(마을 안, 벽 너머) 멈춰 기다린다
		alert = false
		vel = Vector2.ZERO
		return vel
	if kind == "eater":  # 뿌리먹이: 곧장 주인공에게(밀리지 않고, 몰래 걷기도 안 통한다)
		var dd := hero - pos
		alert = true
		vel = dd.normalized() * float(kinds.get("eater", {}).get("speed", 420)) if dd.length() > 1.0 else Vector2.ZERO
		return vel
	var k: Dictionary = kinds.get(kind, moves.get(kind, kinds["wander"]))
	if ignore:
		alert = false
		return Vector2.ZERO if kind == "still" else _wander(delta, kinds.get("wander"), kinds, rng)
	var d := hero - pos
	var dist := d.length()
	if rage > 0.0 and dist > 1.0:  # 동료가 부름·무리가 모임·잠에서 깸: 곧장 달려든다
		alert = true
		vel = d / dist * rage_speed
		return vel
	var sp_mult := float(traits.get("ghost", {}).get("speed_mult", 1.0)) if quirk == "ghost" else 1.0
	match kind:
		"still":
			vel = Vector2.ZERO
			alert = false
			return vel
		"stalk":  # 주인공이 등을 보일 때만 다가온다(보면 멈춘다)
			alert = dist < float(k["sight"])
			var looked := facing_hero != Vector2.ZERO and facing_hero.dot(-d / maxf(1.0, dist)) > 0.3
			vel = d / dist * float(k["speed"]) if alert and not looked and dist > 1.0 else Vector2.ZERO
			return vel
		"bounce":  # 벽에 튕기며 곧게(화면이 막히면 vel을 뒤집는다)
			if vel.length() < 1.0:
				vel = Vector2.from_angle(rng.randf() * TAU) * float(k["speed"])
			return vel
		"burst":  # 갔다 섰다(시간)
			_dive_t -= delta
			if _dive_t <= -float(k["off"]):
				_dive_t = float(k["on"])
			alert = dist < float(k["sight"])
			if _dive_t > 0.0 and alert and dist > 1.0:
				vel = d / dist * float(k["speed"])
			else:
				vel = Vector2.ZERO
			return vel
		"zigzag":  # 바람: 좌우로 흔들리며 쫓는다
			alert = dist < float(k["give_up" if alert else "sight"])
			if alert and dist > 1.0:
				_dive_t += delta
				var dir := d / dist
				vel = (dir + dir.orthogonal() * sin(_dive_t * float(k["freq"])) * float(k["amp"])).normalized() * float(k["speed"])
				return vel
		"orbit":  # 둘레를 돌다가 덮친다
			alert = dist < float(k["sight"])
			if alert and dist > 1.0:
				_dive_t -= delta
				if _dive_t < -float(k["dive_sec"]):
					_dive_t = float(k["dive_every"])
				if _dive_t < 0.0:
					vel = d / dist * float(k["dive_speed"])
				elif dist > float(k["radius"]) + 30.0:
					vel = d / dist * float(k["speed"])
				else:
					vel = (d / dist).orthogonal() * float(k["speed"]) + d / dist * (dist - float(k["radius"])) * 0.5
				return vel
		"wave":  # 파동: 물결처럼 밀려왔다 물러난다(조금씩 다가온다)
			alert = dist < float(k["give_up" if alert else "sight"])
			if alert and dist > 1.0:
				phase_t += delta
				var s := sin(phase_t * TAU / float(k["period"]))
				vel = d / dist * float(k["speed"]) * wave_scale * (float(k["bias"]) + s)
				return vel
		"march":  # 질서: 가로·세로로만
			alert = dist < float(k["give_up" if alert else "sight"])
			if alert and dist > 1.0:
				vel = (Vector2(signf(d.x), 0) if absf(d.x) > absf(d.y) else Vector2(0, signf(d.y))) * float(k["speed"])
				return vel
		"chase":
			if alert:
				alert = dist < float(k["give_up"])
			else:
				alert = dist < float(k["sight"])
			if alert and dist > 1.0:
				vel = d / dist * float(k["speed"]) * sp_mult
				return vel
		"flee":
			alert = dist < float(k["sight"])
			if alert and dist > 1.0:
				vel = -d / dist * float(k["speed"])
				return vel
		"rush":
			return _rush(delta, d, dist, k, kinds, rng)
	return _wander(delta, k, kinds, rng)


func _rush(delta: float, d: Vector2, dist: float, k: Dictionary, kinds: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	phase_t -= delta
	match phase:
		"wind":  # 멈춰 떨며 겨눈다
			vel = Vector2.ZERO
			if phase_t <= 0.0:
				phase = "dash"
				phase_t = float(k["dash"])
				_dash_dir = d.normalized() if dist > 1.0 else Vector2.RIGHT
				vel = _dash_dir * float(k["speed"])
			return vel
		"dash":  # 겨눈 쪽으로 곧장(도중에 방향을 바꾸지 않는다: 옆으로 비키면 피한다)
			vel = _dash_dir * float(k["speed"])
			if phase_t <= 0.0:
				phase = "rest"
				phase_t = float(k["rest"])
			return vel
		"rest":
			if phase_t <= 0.0:
				phase = ""
			return _wander(delta, k, kinds, rng)
	alert = dist < float(k["sight"])
	if alert:
		phase = "wind"
		phase_t = float(k["windup"])
		vel = Vector2.ZERO
		return vel
	return _wander(delta, k, kinds, rng)


func _wander(delta: float, k: Dictionary, kinds: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	_t -= delta
	if _t <= 0.0:
		var turn: Array = kinds["wander"]["turn"]
		_t = rng.randf_range(float(turn[0]), float(turn[1]))
		var sp = k.get("wander_speed", null)
		var hi := float(sp) if sp != null else float(kinds["wander"]["speed"][1])
		vel = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, hi)
	return vel
