class_name GameState
extends RefCounted
## 저장되는 게임 상태. 규칙 계산은 ProgressRules가 하고, 여기는 값만 갖는다.
## 저장 형식이 바뀌면 VERSION을 올리고 SaveStore에 변환을 더한다(architecture.md 11절).

const VERSION := 1
const UNIT_COUNT := 12

var hero_name := ""
var hero_look := "m"  ## 주인공 모습: m(남) / f(여). 이름 짓는 화면에서 고른다
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
var cave := ""  ## 들어가 있는 동굴 지도 id(07-fun 5절). 비면 큰 지도
var titles: Array[String] = []
var exam_fail_date := ""
var wallet := 0  ## 코인(07-fun 8절)
var free_pulls := 0  ## 무료 뽑기(사냥 레벨 5마다 1번, 마을에 들어올 때 받는다)
var items: Array = []  ## 주운 퀘스트 물건(07-fun 5절)
var notes: Array = []  ## 주운 조각 쪽지(조각 id, 07-fun 4절). 가방에 남아 조각 사전이 된다
var hunt: Dictionary = {}  ## 필드 사냥 한 번의 나들이(HuntRun, 주머니 포함)
var loadout: Dictionary = {}  ## 장착(07-fun.md 2절): {"field": [필드 마법 2], "deck": [전투 마법 4]}
var pieces: Dictionary = {}  ## 어원 조각 id -> {seen, right}: 유추 문제에서 본·맞힌 수(06-learning.md)
var rest_until := 0  ## 병원에서 쉬기가 끝나는 시각(유닉스 초). 그때까지 마을 밖으로 못 나간다(04-meta 9절)
var dev_mode := false  ## 개발자 모드(모든 단어를 갖고 평가용으로 시작). 저장 파일도 따로
var free_roam := false  ## 개발자 모드(자유 탐험): 보스 말고는 단어 전투에 안 들어가고, 지도의 벽·길목에 안 막힌다
var roots_cache: Dictionary = {}  ## 가진 스킬 어근(저장하지 않음, ProgressRules가 채운다)


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
		"version": VERSION, "hero_name": hero_name, "hero_look": hero_look, "stage": stage, "dex": dex, "unit_exp": unit_exp,
		"joined": joined, "equipment": eqs, "magics": magics, "chosen_roots": _str_keys(chosen_roots),
		"flags": flags, "recapture": recapture, "place": place, "pos": [pos.x, pos.y], "cave": cave,
		"titles": titles, "exam_fail_date": exam_fail_date, "dev_mode": dev_mode, "free_roam": free_roam,
		"rest_until": rest_until, "pieces": pieces, "loadout": loadout,
		"wallet": wallet, "free_pulls": free_pulls, "hunt": hunt, "notes": notes, "items": items,
	}


static func from_dict(d: Dictionary) -> GameState:
	var g := GameState.new()
	g.hero_name = d.get("hero_name", "")
	g.hero_look = String(d.get("hero_look", "m"))
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
	g.cave = String(d.get("cave", ""))
	g.rest_until = int(d.get("rest_until", 0))
	g.pieces = d.get("pieces", {})
	g.loadout = d.get("loadout", {})
	g.wallet = int(d.get("wallet", 0))
	g.free_pulls = int(d.get("free_pulls", 0))
	g.notes = d.get("notes", [])
	g.items = d.get("items", [])
	g.hunt = d.get("hunt", {})
	var p: Array = d.get("pos", [0, 0])
	g.pos = Vector2(float(p[0]), float(p[1]))
	for t in d.get("titles", []):
		g.titles.append(str(t))
	g.exam_fail_date = d.get("exam_fail_date", "")
	g.dev_mode = d.get("dev_mode", false)
	g.free_roam = d.get("free_roam", false)
	return g


static func _str_keys(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		o[str(k)] = d[k]
	return o
