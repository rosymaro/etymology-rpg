class_name WordPicture
extends RefCounted
## 단어 카드 그림 자리의 임시 그림 고르기(규칙 층: 노드·화면을 모른다).
## 사용자 의견: 그림은 나중에 직접 채운다. 그때까지 1만 단어를 대략적인 뜻의 도형으로.
## 규칙(data/art/word_pictures.json, tools/art/word_pictures.py가 만든다):
##   그림: 단어 뜻(앞 뜻부터) → 어원 뜻(접두사 아닌 것) 순서로, 낱말이 들어 있는 첫 그림
##   표시: 접두사(어원 이름이 '-'로 끝남)의 뜻으로 고른 작은 표시(밖으로, 다시, 아닌 …)
##   한 글자 낱말은 띄어 쓴 낱말이 그 글자로 시작하고 그 글자뿐이거나 바로 뒤가 끝말일 때만(적 → 적이는 되고 적인은 안 된다)

const PATH := "res://data/art/word_pictures.json"
const ENDINGS := "다기는고음은게어아히하며지을를이가의에도"

var glyphs: Array = []  ## [{id, keys, shapes}]
var mods: Array = []
var _by_id := {}


static func load_default() -> WordPicture:
	var p := WordPicture.new()
	p.setup(JsonFile.read(PATH))
	return p


func setup(d: Dictionary) -> void:
	glyphs = d.get("glyphs", [])
	mods = d.get("mods", [])
	for g in glyphs + mods:
		_by_id[g["id"]] = g


## {glyph: 그림 id 또는 "", mod: 표시 id 또는 ""}
func pick(meaning: String, etym: Array) -> Dictionary:
	var segs: Array[String] = []
	for s in meaning.replace(",", ";").split(";"):
		if s.strip_edges() != "":
			segs.append(s.strip_edges())
	var pref: Array[String] = []
	for e in etym:
		if String(e.get("root", "")).strip_edges().ends_with("-"):
			pref.append(String(e.get("meaning", "")))
		else:
			segs.append(String(e.get("meaning", "")))
	return {"glyph": _first(glyphs, segs), "mod": _first(mods, pref)}


func shapes(id: String) -> Array:
	return _by_id.get(id, {}).get("shapes", [])


static func _first(list: Array, segs: Array) -> String:
	for s in segs:
		for g in list:
			for k in g["keys"]:
				if has_key(String(s), String(k)):
					return g["id"]
	return ""


static func has_key(seg: String, k: String) -> bool:
	if k.length() >= 2:
		return seg.contains(k)
	for tok in seg.replace("(", " ").replace(")", " ").replace("~", " ").replace(".", " ").split(" ", false):
		if tok.begins_with(k) and (tok.length() == 1 or ENDINGS.contains(tok[1])):
			return true
	return false
