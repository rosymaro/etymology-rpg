class_name PieceSplit
extends RefCounted
## 단어 글자를 어원 조각 자리로 나눈다(06-learning.md 조각 찾기). etym의 form을 앞에서부터 차례로 찾는다.
## 돌려주는 값: [{text, piece(조각 id, 조각이 아닌 글자는 ""), meaning, at}] 글자 순서대로. 이어 붙이면 단어가 된다.


static func split(word: String, etym: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var low := word.to_lower()
	var pos := 0
	for e in etym:
		var f := String(e.get("form", "")).to_lower()
		if f == "":
			continue
		var at := low.find(f, pos)
		if at < 0:
			continue
		if at > pos:
			out.append({"text": word.substr(pos, at - pos), "piece": "", "meaning": "", "at": pos})
		out.append({"text": word.substr(at, f.length()), "piece": Curriculum.piece_id(e), "meaning": String(e.get("meaning", "")), "at": at})
		pos = at + f.length()
	if pos < word.length():
		out.append({"text": word.substr(pos), "piece": "", "meaning": "", "at": pos})
	return out


## 글자 자리 i가 든 조각 id(조각이 아니면 "").
static func piece_at(parts: Array[Dictionary], i: int) -> String:
	for p in parts:
		if i >= int(p["at"]) and i < int(p["at"]) + String(p["text"]).length():
			return String(p["piece"])
	return ""
