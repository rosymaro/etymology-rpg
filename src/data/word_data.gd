class_name WordData
extends RefCounted
## 단어 하나(data/game/words.json의 한 줄). 바꾸지 않는 값 객체다.

var id: String
var meaning: String
var freq: int
var attrs: Array[int] = []
var tier: int  ## 0 = 보스 단어, 1~4 = 차수
var unit: int  ## 입는 유닛 번호(1~12), 보스 단어는 0
var slot: String  ## weapon head chest hands feet
var tree: int
var evolves_to: String
var mats: Array[String] = []
var stage: int  ## 1차·보스 단어의 스테이지. 2~4차는 0(재료로 정해진다)
var obtain: String  ## field town boss (1차·보스만)
var skill_roots: Array[String] = []
var etym: Array = []  ## [{root, meaning, form}] form = 현대 영어 형태(ab, duc)
var example: Dictionary = {}
var ipa: String


static func from_dict(d: Dictionary) -> WordData:
	var w := WordData.new()
	w.id = d["id"]
	w.meaning = d.get("meaning", "")
	w.freq = int(d.get("freq", 5))
	for a in d.get("attrs", []):
		w.attrs.append(int(a))
	w.tier = int(d.get("tier", 1))
	w.unit = int(d.get("unit", 0))
	w.slot = d.get("slot", "")
	w.tree = int(d.get("tree", 0))
	w.evolves_to = d.get("to", "")
	for m in d.get("mats", []):
		w.mats.append(str(m))
	w.stage = int(d.get("stage", 0))
	w.obtain = d.get("obtain", "")
	for r in d.get("skill_roots", []):
		w.skill_roots.append(str(r))
	w.etym = d.get("etym", [])
	w.example = d.get("example", {})
	w.ipa = d.get("ipa", "")
	return w


## 어원의 현대 영어 형태들(미니게임 칠판 'ab + duc = abduct'). 형태가 없으면 어근에서 '-'를 뗀 것.
func forms() -> Array[String]:
	var out: Array[String] = []
	for e in etym:
		var f := str(e.get("form", "")).to_lower()
		if f == "":
			f = str(e.get("root", "")).replace("-", "").to_lower()
		if f != "":
			out.append(f)
	return out


func primary_attr() -> int:
	return attrs[0] if attrs.size() > 0 else 0


## 어원 풀이에 이 접두사(예: "de-")가 있는가. 공격 마법이 덜 듣는 단어를 가린다.
func has_prefix(prefix: String) -> bool:
	for e in etym:
		if str(e.get("root", "")) == prefix:
			return true
	return false
