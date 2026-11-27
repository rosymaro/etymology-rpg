class_name FieldMagicUse
extends RefCounted
## 필드 마법 버튼(07-fun 2절). 쉬는 시간(쿨타임)과 몹에게 주는 효과만 계산한다. 노드·화면을 모른다.
## 수치는 data/balance/field.json의 magic. 마을로 가기·퀘스트 길목 같은 흐름은 화면·GameFlow가 한다.

var cfg: Dictionary
var cool := {}  ## 마법 id -> 남은 쉬는 시간
var sneak := 0.0  ## sub-: 남은 몰래 걷기 시간
var light := 0.0  ## pro-: 남은 앞길 비추기 시간(어두운 동굴)
var under := false  ## de-: 땅속에 숨음(시간 제한 없음, 움직이면 풀린다. 사용자 의견)


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
		"de":  # 땅속으로 들어간다: 공격도 못 하고 받지도 않으며, 어떤 몹도 알아채지 못한다
			under = true
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


## de-: 움직이면 땅 위로 나온다.
func surface() -> void:
	under = false


## 몹이 주인공을 알아채는가. 땅속(de-)이면 아무도, 몰래 걷기(sub-)면 see_attrs 속성과 뿌리먹이만.
func sees(m: FieldMob) -> bool:
	if under:
		return false
	if sneak > 0.0 and m.kind != "eater":
		for a in cfg.get("sub", {}).get("see_attrs", []):  # json 숫자는 float
			if int(a) == m.attr:
				return true
		return false
	return true


## 일행이 공격할 수 있는가(땅속이면 못 한다).
func can_attack() -> bool:
	return not under
