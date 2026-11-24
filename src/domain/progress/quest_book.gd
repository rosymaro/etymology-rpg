class_name QuestBook
extends RefCounted
## 스테이지 퀘스트(04-meta.md 8절, data/quests.json). 노드·화면을 모른다.
## 마친 퀘스트는 state.flags[퀘스트 id] = true. 받은 퀘스트(words)는 state.flags[id + "_got"] = true.

var quests: Array = []


static func load_default() -> QuestBook:
	return from_dict(JsonFile.read("res://data/quests.json"))


static func from_dict(d: Dictionary) -> QuestBook:
	var b := QuestBook.new()
	b.quests = d.get("quests", [])
	return b


func of_stage(stage: int) -> Array:
	return quests.filter(func(q: Dictionary) -> bool: return int(q["stage"]) == stage)


func get_quest(id: String) -> Dictionary:
	for q in quests:
		if q["id"] == id:
			return q
	return {}


## 길목(gate) id로 퀘스트 찾기.
func by_gate(gate: String) -> Dictionary:
	for q in quests:
		if String(q.get("gate", "")) == gate:
			return q
	return {}


func done(state: GameState, id: String) -> bool:
	return bool(state.flags.get(id, false))


## 얼마나 했나: {have, need, ready}. roots = 가진 스킬 어근.
func progress(state: GameState, q: Dictionary, roots: Array) -> Dictionary:
	match String(q["kind"]):
		"words":
			var have := 0
			for w in q["words"]:
				if state.has_word(String(w)):
					have += 1
			return {"have": have, "need": q["words"].size(), "ready": have >= q["words"].size()}
		"root":
			var ok: bool = String(q["root"]) in roots
			return {"have": int(ok), "need": 1, "ready": ok}
		"magic":
			var ok: bool = String(q["magic"]) in state.magics
			return {"have": int(ok), "need": 1, "ready": ok}
	return {"have": 0, "need": 1, "ready": false}


## 마칠 수 있으면 마치고 true.
func finish(state: GameState, id: String, roots: Array) -> bool:
	var q := get_quest(id)
	if q.is_empty() or done(state, id) or not progress(state, q, roots)["ready"]:
		return false
	state.flags[id] = true
	return true


## 마친 퀘스트의 길목: {gate id: true}. WorldMap.walkable의 open_gates에 더한다.
func open_gates(state: GameState) -> Dictionary:
	var out := {}
	for q in quests:
		if q.has("gate") and done(state, q["id"]):
			out[q["gate"]] = true
	return out


## 보스 전에 마쳐야 하는데 아직 못 마친 퀘스트.
func boss_blockers(state: GameState, stage: int) -> Array:
	return of_stage(stage).filter(func(q: Dictionary) -> bool: return bool(q.get("boss", false)) and not done(state, q["id"]))


## 다음에 할 일(퀘스트 목록 순서대로 첫 미완료). 없으면 {}.
func next_quest(state: GameState, stage: int) -> Dictionary:
	for q in of_stage(stage):
		if not done(state, q["id"]):
			return q
	return {}
