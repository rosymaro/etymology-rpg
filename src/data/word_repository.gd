class_name WordRepository
extends RefCounted
## 게임 단어 전체. 스테이지·얻는 방법별 목록과 진화 트리를 찾는다.

const DEFAULT_PATH := "res://data/game/words.json"

var _words: Dictionary = {}  ## id -> WordData
var _leaves: Dictionary = {}  ## id -> Array[String] (그 아래 1차 단어들)
var _all_ids: Array[String] = []


static func load_default() -> WordRepository:
	var repo := WordRepository.new()
	repo.load_dicts(JsonFile.read(DEFAULT_PATH)["words"])
	return repo


func load_dicts(rows: Array) -> void:
	_words.clear()
	_leaves.clear()
	_all_ids.clear()
	for d in rows:
		var w := WordData.from_dict(d)
		_words[w.id] = w
		_all_ids.append(w.id)


func has(id: String) -> bool:
	return _words.has(id)


func get_word(id: String) -> WordData:
	return _words.get(id)


func all_ids() -> Array[String]:
	return _all_ids


func size() -> int:
	return _all_ids.size()


## 스테이지 s의 1차 단어. obtain이 비면 필드·마을 모두.
func first_tier(stage: int, obtain: String = "") -> Array[WordData]:
	var out: Array[WordData] = []
	for id in _all_ids:
		var w: WordData = _words[id]
		if w.tier == 1 and w.stage == stage and (obtain == "" or w.obtain == obtain):
			out.append(w)
	return out


func boss_word(stage: int) -> WordData:
	for id in _all_ids:
		var w: WordData = _words[id]
		if w.tier == 0 and w.stage == stage:
			return w
	return null


## 그 단어 아래에 든 1차 단어 모두(1차면 자기 자신).
func leaves(id: String) -> Array[String]:
	if _leaves.has(id):
		return _leaves[id]
	var w: WordData = _words[id]
	var out: Array[String] = []
	if w.mats.is_empty():
		out.append(id)
	else:
		for m in w.mats:
			out.append_array(leaves(m))
	_leaves[id] = out
	return out


## 진화 단어가 '어느 스테이지 단어인가' = 재료 1차의 가장 큰 스테이지.
func evolved_stage(id: String) -> int:
	var s := 0
	for l in leaves(id):
		s = maxi(s, _words[l].stage)
	return s


## 스테이지 s까지의 재료로 만들 수 있는 차수 tier 단어들.
func evolutions_up_to(stage: int, tier: int) -> Array[WordData]:
	var out: Array[WordData] = []
	for id in _all_ids:
		var w: WordData = _words[id]
		if w.tier == tier and evolved_stage(id) <= stage:
			out.append(w)
	return out
