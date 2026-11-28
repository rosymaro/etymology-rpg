class_name GameText
extends RefCounted
## 여러 화면이 함께 쓰는 설명 글(스킬, 마법, 단어 카드 팝업). 문장은 locale/*.csv 키로.


static func tr_(key: String) -> String:
	return TranslationServer.translate(key)


## 어근 스킬: "spect: 이번 격돌 공격 +2. 코인 조건: 보통(앞면 절반 이상)"
static func root_desc(root: String) -> String:
	if root == "":
		return ""
	var def := GameData.bal.skill_def(root)
	var cond: String = {"쉬움": "easy", "보통": "normal", "어려움": "hard"}.get(GameData.bal.root_tier(root), "normal")
	return "%s: %s %s" % [root, tr_("sys.root.%s.desc" % root).format(def.get("params", {})),
		tr_("sys.root.cond").format({"cond": tr_("sys.root.cond." + cond)})]


## 전투 마법: 위력 P를 넣은 설명.
static func magic_desc(id: String, power: int) -> String:
	if id == "":
		return tr_("sys.magic.none.desc")
	var def := GameData.bal.magic_def(id)
	var vals := {}
	for k in def.get("params", {}):
		vals[k] = Formula.int_value(def["params"][k], {"P": power})
	var phase := String(def.get("phase", ""))  # 언제 강한지(초반·후반·전체)
	var tag := (" " + tr_("sys.magic.phase." + phase)) if phase != "" else ""
	return tr_("sys.magic.%s.desc" % id).format(vals) + tag


## 필드 마법 이름(data/field_magic.json의 접두사 + 필드 효과 뜻).
static func field_magic_name(id: String) -> String:
	if id == "":
		return ""
	var key := "sys.field_magic.%s" % id
	var s := tr_(key)
	return s if s != key else magic_name(id)


static func magic_name(id: String) -> String:
	return tr_("sys.magic.%s.name" % (id if id != "" else "none"))


static func attrs_text(w: WordData) -> String:
	var names: Array[String] = []
	for a in w.attrs:
		names.append(tr_("name.attr.%02d" % int(a)))
	return ", ".join(names)


static func etym_text(w: WordData) -> String:
	var parts: Array[String] = []
	for e in w.etym:
		parts.append("%s(%s)" % [e.get("root", ""), e.get("meaning", "")])
	return " + ".join(parts) if not parts.is_empty() else "-"


## 받침에 맞춘 조사: josa("뚝딱", "은", "는") → "뚝딱은", josa("빙글", "아", "야") → "빙글아".
static func josa(word: String, with_final: String, without_final: String) -> String:
	if word == "":
		return word
	var c := word.unicode_at(word.length() - 1)
	var has := c >= 0xAC00 and c <= 0xD7A3 and (c - 0xAC00) % 28 != 0
	return word + (with_final if has else without_final)


## 동행을 바꾸었을 때 주인공의 말(사용자 의견: 마을 여관에 머문다는 설정).
## "뚝딱은 마을에서 쉬고 있어. 빙글아, 우리 같이 놀자~"
static func companion_swap(gone: Array, came: Array, levels: Dictionary) -> String:
	var lines: Array[String] = []
	var gn: Array[String] = []
	for u in gone:
		gn.append(tr_("name.char." + GameData.UNIT_CHARS[int(u) - 1]))
	if not gn.is_empty():
		var last := gn.pop_back() as String
		gn.append(josa(last, "은", "는"))
		lines.append(tr_("ui.party.swap_rest").format({"names": ", ".join(gn)}))
	var cn: Array[String] = []
	for u in came:
		cn.append(tr_("name.char." + GameData.UNIT_CHARS[int(u) - 1]))
	if not cn.is_empty():
		var last2 := cn.pop_back() as String
		cn.append(josa(last2, "아", "야"))
		lines.append(tr_("ui.party.swap_join").format({"names": ", ".join(cn)}))
		var lv: Array[String] = []
		for u in came:
			lv.append("%s %d" % [tr_("name.char." + GameData.UNIT_CHARS[int(u) - 1]), int(levels.get(int(u), 0))])
		if not gone.is_empty():
			lines.append(tr_("ui.party.swap_level").format({"list": ", ".join(lv)}))
	return "\n".join(lines)
