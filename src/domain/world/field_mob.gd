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
var phase_t := 0.0
var _dash_dir := Vector2.ZERO


## 필드 사냥 무기에 맞음. 쓰러지면 true. 뿌리먹이(eater)는 체력이 1 아래로 내려가지 않는다(공격을 뚫고 온다).
func take_hit(dmg: int) -> bool:
	flash = 0.15
	hp = maxi(1 if kind == "eater" else 0, hp - dmg)
	return hp <= 0


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
	var k: Dictionary = kinds.get(kind, kinds["wander"])
	if ignore:
		alert = false
		return _wander(delta, k, kinds, rng)
	var d := hero - pos
	var dist := d.length()
	match kind:
		"chase":
			if alert:
				alert = dist < float(k["give_up"])
			else:
				alert = dist < float(k["sight"])
			if alert and dist > 1.0:
				vel = d / dist * float(k["speed"])
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
