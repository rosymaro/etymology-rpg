class_name PieceSplit
extends RefCounted
## 단어 글자를 어원 조각 자리로 나눈다(06-learning.md 조각 찾기). etym의 form을 앞에서부터 차례로 찾는다.
## form은 실제 철자에 맞춰 두었다(tools/data/fit_forms.py, 사용자 의견: presentation = pre + sent + ation).
## at이 있으면 그 자리, 없으면 앞에서부터 찾는다. lost(철자에 모양이 남지 않은 조각)는 자르지 않는다(lost()로 따로).
## 돌려주는 값: [{text, piece(조각 id, 조각이 아닌 글자는 ""), meaning, at, root, base}] 글자 순서대로. 이어 붙이면 단어가 된다.


static func split(word: String, etym: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var low := word.to_lower()
	var pos := 0
	for e in etym:
		var f := String(e.get("form", "")).to_lower()
		if f == "":
			continue
		var at := int(e["at"]) if e.has("at") and low.substr(int(e["at"]), f.length()) == f and int(e["at"]) >= pos else low.find(f, pos)
		if at < 0:
			continue
		if at > pos:
			out.append({"text": word.substr(pos, at - pos), "piece": "", "meaning": "", "at": pos, "root": "", "base": ""})
		out.append({"text": word.substr(at, f.length()), "piece": Curriculum.piece_id(e), "meaning": String(e.get("meaning", "")), "at": at,
			"root": String(e.get("root", "")), "base": String(e.get("base", ""))})
		pos = at + f.length()
	if pos < word.length():
		out.append({"text": word.substr(pos), "piece": "", "meaning": "", "at": pos, "root": "", "base": ""})
	return out


## 철자에 모양이 남지 않은 조각들(예: funnel의 in-). [{root, meaning}]
static func lost(etym: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in etym:
		if bool(e.get("lost", false)):
			out.append({"root": String(e.get("root", "")), "meaning": String(e.get("meaning", ""))})
	return out


## 조각 글자가 어근 이름과 다른가(그러면 '변형'으로 설명한다). "prae-" vs "pre" → true, "spect" vs "spectare" → true.
static func is_variant(p: Dictionary) -> bool:
	var r := String(p.get("root", "")).split(" ")[0].replace("-", "").to_lower()
	return String(p.get("piece", "")) != "" and r != "" and String(p["text"]).to_lower() != r


## 글자 자리 i가 든 조각 id(조각이 아니면 "").
static func piece_at(parts: Array[Dictionary], i: int) -> String:
	for p in parts:
		if i >= int(p["at"]) and i < int(p["at"]) + String(p["text"]).length():
			return String(p["piece"])
	return ""
