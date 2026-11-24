class_name FieldMob
extends RefCounted
## 필드 몹의 움직임(04-meta.md 7절). 노드·화면을 모른다. 수치는 data/balance/field.json의 kinds.
## wander: 이리저리 배회. chase: 주인공이 sight 안에 오면 쫓아온다(give_up보다 멀어지면 그만). flee: 가까이 오면 반대로 도망간다.

var kind := "wander"
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var words: Array[String] = []
var alert := false  ## 쫓는 중·도망가는 중
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
	var k: Dictionary = kinds.get(kind, kinds["wander"])
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
	_t -= delta
	if _t <= 0.0:
		var turn: Array = kinds["wander"]["turn"]
		_t = rng.randf_range(float(turn[0]), float(turn[1]))
		var sp = k.get("wander_speed", null)
		var hi := float(sp) if sp != null else float(kinds["wander"]["speed"][1])
		vel = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, hi)
	return vel
