class_name GameState
extends RefCounted
## 저장되는 게임 상태. 규칙 계산은 ProgressRules가 하고, 여기는 값만 갖는다.
## 저장 형식이 바뀌면 VERSION을 올리고 SaveStore에 변환을 더한다(architecture.md 11절).

const VERSION := 1
const UNIT_COUNT := 12

var hero_name := ""
var stage := 1  ## 열린 가장 높은 스테이지
var dex: Dictionary = {}  ## 단어 id -> 얻은 순서 번호(1부터). 한 번 얻으면 줄지 않는다(04-meta.md 5절)
var unit_exp: Array[int] = []
var joined: Array[int] = [1]  ## 합류한 유닛 번호
var equipment: Dictionary = {}  ## 유닛 번호(int) -> Equipment
var magics: Array[String] = ["de"]
var chosen_roots: Dictionary = {}  ## 유닛 번호 -> 마지막으로 장착한 어근
var flags: Dictionary = {}  ## 본 장면, 이긴 보스 등
var recapture: Dictionary = {}  ## 진화 단어 id -> 다시 잡아야 하는 1차 단어 id
var place := "town"  ## town | field
var pos := Vector2.ZERO
var titles: Array[String] = []
var exam_fail_date := ""


func _init() -> void:
	unit_exp.resize(UNIT_COUNT)
	unit_exp.fill(0)
	for u in range(1, UNIT_COUNT + 1):
		equipment[u] = Equipment.new()


func dex_count() -> int:
	return dex.size()


func has_word(id: String) -> bool:
	return dex.has(id)


func eq(unit_no: int) -> Equipment:
	return equipment[unit_no]


func to_dict() -> Dictionary:
	var eqs := {}
	for u in equipment:
		eqs[str(u)] = equipment[u].to_dict()
	return {
		"version": VERSION, "hero_name": hero_name, "stage": stage, "dex": dex, "unit_exp": unit_exp,
		"joined": joined, "equipment": eqs, "magics": magics, "chosen_roots": _str_keys(chosen_roots),
		"flags": flags, "recapture": recapture, "place": place, "pos": [pos.x, pos.y],
		"titles": titles, "exam_fail_date": exam_fail_date,
	}


static func from_dict(d: Dictionary) -> GameState:
	var g := GameState.new()
	g.hero_name = d.get("hero_name", "")
	g.stage = int(d.get("stage", 1))
	for k in d.get("dex", {}):
		g.dex[k] = int(d["dex"][k])
	var ue: Array = d.get("unit_exp", [])
	for i in mini(ue.size(), UNIT_COUNT):
		g.unit_exp[i] = int(ue[i])
	g.joined.clear()
	for u in d.get("joined", [1]):
		g.joined.append(int(u))
	var eqs: Dictionary = d.get("equipment", {})
	for k in eqs:
		g.equipment[int(k)] = Equipment.from_dict(eqs[k])
	g.magics.clear()
	for m in d.get("magics", ["de"]):
		g.magics.append(str(m))
	for k in d.get("chosen_roots", {}):
		g.chosen_roots[int(k)] = str(d["chosen_roots"][k])
	g.flags = d.get("flags", {})
	g.recapture = d.get("recapture", {})
	g.place = d.get("place", "town")
	var p: Array = d.get("pos", [0, 0])
	g.pos = Vector2(float(p[0]), float(p[1]))
	for t in d.get("titles", []):
		g.titles.append(str(t))
	g.exam_fail_date = d.get("exam_fail_date", "")
	return g


static func _str_keys(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		o[str(k)] = d[k]
	return o
