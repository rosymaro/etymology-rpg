class_name FieldMagicUse
extends RefCounted
## 필드 마법 버튼(07-fun 2절). 쉬는 시간(쿨타임)과 몹에게 주는 효과만 계산한다. 노드·화면을 모른다.
## 수치는 data/balance/field.json의 magic. 마을로 가기·퀘스트 길목 같은 흐름은 화면·GameFlow가 한다.

var cfg: Dictionary
var cool := {}  ## 마법 id -> 남은 쉬는 시간
var sneak := 0.0  ## sub-: 남은 몰래 걷기 시간
var light := 0.0  ## pro-: 남은 앞길 비추기 시간(어두운 동굴)


func _init(field_magic_cfg: Dictionary) -> void:
	cfg = field_magic_cfg


func ready(id: String) -> bool:
	return cfg.has(id) and float(cool.get(id, 0.0)) <= 0.0


func implemented(id: String) -> bool:
	return cfg.has(id)


func tick(delta: float) -> void:
	for k in cool:
		cool[k] = maxf(0.0, float(cool[k]) - delta)
	sneak = maxf(0.0, sneak - delta)
	light = maxf(0.0, light - delta)


## 마법을 쓴다. 몹에게 미치는 효과를 주고 쉬는 시간을 건다. 못 쓰면 false.
func use(id: String, hero: Vector2, mobs: Array) -> bool:
	if not ready(id):
		return false
	var c: Dictionary = cfg[id]
	match id:
		"de":  # 둘레 몹을 내리쳐 멈춘다
			for m in mobs:
				if (m as FieldMob).pos.distance_to(hero) <= float(c["r"]):
					(m as FieldMob).stun = float(c["stun"])
		"ob":  # 둘레 몹을 멀리 밀친다(벽은 화면이 WorldMap.move로 막는다: 여기서는 갈 곳만 정한다)
			for m in mobs:
				var fm := m as FieldMob
				var d := fm.pos - hero
				if d.length() <= float(c["r"]):
					fm.set_meta("push", (d.normalized() if d.length() > 1.0 else Vector2.RIGHT) * float(c["push"]))
		"sub":
			sneak = float(c["sec"])
		"pro":
			light = float(c["sec"])
	cool[id] = float(c["cd"])
	return true
