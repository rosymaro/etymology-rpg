class_name FieldTraits
extends RefCounted
## 필드 특성(사용자 의견, docs/design/07-fun.md '필드 특성'). 노드·화면을 모른다.
## 데리고 다니는 유닛들이 걸친 장비의 속성을 센다: 장비 하나가 그 단어의 속성마다 tier_factor[차수-1]점.
## 속성마다 특성 하나(data/balance/field_traits.json traits). 크기 = at5 × 점수 / 5 (점수는 max_score에서 멈춘다).
## 한 유닛이 같은 속성 장비를 shield.same개 걸치면 주인공 방어막 1개(유닛마다 따로, 최대 데리고 다니는 수).

const PATH := "res://data/balance/field_traits.json"

var cfg: Dictionary
var score := {}  ## 속성 번호(int) -> 점수
var shields := 0  ## 방어막 수
var _by_id := {}  ## 특성 id -> 속성 번호


func _init(c: Dictionary = {}) -> void:
	cfg = c if not c.is_empty() else JsonFile.read(PATH)
	for a in cfg["traits"]:
		_by_id[String(cfg["traits"][a]["id"])] = int(a)


## 장비 목록(유닛마다 단어 목록)으로 센다.
static func from_gear(per_unit: Array, c: Dictionary = {}) -> FieldTraits:
	var ft := FieldTraits.new(c)
	var tf: Array = ft.cfg["tier_factor"]
	var same := int(ft.cfg["shield"]["same"])
	for words in per_unit:
		var cnt := {}
		for w in words:
			var wd: WordData = w
			var f := float(tf[clampi(wd.tier, 1, tf.size()) - 1]) if wd.tier > 0 else float(tf[tf.size() - 1])
			for a in wd.attrs:
				ft.score[int(a)] = float(ft.score.get(int(a), 0.0)) + f
				cnt[int(a)] = int(cnt.get(int(a), 0)) + 1
		for a in cnt:
			if int(cnt[a]) >= same:
				ft.shields += 1
				break
	return ft


## 게임 상태에서: 데리고 다니는 유닛(Loadout.companions)의 장비.
static func from_state(state: GameState, repo: WordRepository, c: Dictionary = {}) -> FieldTraits:
	var per_unit: Array = []
	for u in Loadout.companions(state):
		if state.equipment.has(u):
			per_unit.append((state.equipment[u] as Equipment).words(repo))
	return from_gear(per_unit, c)


## 특성의 크기(at5 × 점수/5). 없는 특성은 0.
func value(id: String) -> float:
	if not _by_id.has(id):
		return 0.0
	var a: int = _by_id[id]
	var s := minf(float(score.get(a, 0.0)), float(cfg["max_score"]))
	return float(cfg["traits"][str(a)]["at5"]) * s / 5.0


func param(id: String, key: String, default: float) -> float:
	if not _by_id.has(id):
		return default
	return float(cfg["traits"][str(_by_id[id])].get(key, default))


## 맞히는 피해: 공격(배율) → 처형(체력이 절반 아래면 +) → 치명(두 배). 소수는 확률로 올림한다(작은 수에서도 조금씩 오르게).
func damage(base: int, mob_ratio: float, rng: RandomNumberGenerator) -> int:
	var d := float(base) * (1.0 + value("attack"))
	if mob_ratio <= param("execute", "below", 0.5):
		d += value("execute")
	var n := roll(d, rng)
	if rng.randf() < value("crit"):
		n *= 2
	return maxi(1, n)


## 소수를 확률로 올림: 2.3 → 70% 2, 30% 3
static func roll(x: float, rng: RandomNumberGenerator) -> int:
	var f := floorf(x)
	return int(f) + (1 if rng.randf() < x - f else 0)


## 스테이지 몹 체력 배율
func mob_hp_mult(stage: int) -> float:
	var arr: Array = cfg["mob_hp_stage"]
	return float(arr[clampi(stage, 1, arr.size()) - 1])


## 보이는 목록: [{attr, id, value}] 점수가 있는 것만, 큰 것부터.
func summary() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in score:
		var id := String(cfg["traits"][str(a)]["id"])
		out.append({"attr": int(a), "id": id, "value": value(id)})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["value"]) / float(cfg["traits"][str(x["attr"])]["at5"]) > float(y["value"]) / float(cfg["traits"][str(y["attr"])]["at5"]))
	return out
