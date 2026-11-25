class_name Curriculum
extends RefCounted
## 스테이지마다 배우는 어원 조각(06-learning.md 3절, data/learning/curriculum.json). 노드·화면을 모른다.
## 조각 id = 단어 etym의 root 이름(facere, de- …). in-이 "아닌" 뜻이면 in_neg-.

const NEG := ["아닌", "않", "없", "반대", "부정"]

var pieces: Dictionary = {}  ## id -> {stage, kind, meaning, forms, name}
var stages: Dictionary = {}  ## stage -> [id]


static func load_default() -> Curriculum:
	return from_dict(JsonFile.read("res://data/learning/curriculum.json"))


static func from_dict(d: Dictionary) -> Curriculum:
	var c := Curriculum.new()
	c.pieces = d.get("pieces", {})
	for s in d.get("stages", []):
		c.stages[int(s["stage"])] = s["pieces"]
	return c


static func piece_id(e: Dictionary) -> String:
	var r := String(e.get("root", ""))
	if r == "in-":
		var m := String(e.get("meaning", ""))
		for k in NEG:
			if k in m:
				return "in_neg-"
	return r


## 그 스테이지까지 배운 조각(id -> true).
func learned(stage: int) -> Dictionary:
	var out := {}
	for st in stages:
		if int(st) <= stage:
			for p in stages[st]:
				out[p] = true
	return out


func is_known(id: String) -> bool:
	return pieces.has(id)


## 단어 속 조각 id들(etym 순서).
func pieces_of(w: WordData) -> Array[String]:
	var out: Array[String] = []
	for e in w.etym:
		out.append(piece_id(e))
	return out


## 배운 조각이 하나라도 든 단어인가.
func has_learned(w: WordData, stage: int) -> bool:
	var l := learned(stage)
	for p in pieces_of(w):
		if l.has(p):
			return true
	return false
