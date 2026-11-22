class_name Equipment
extends RefCounted
## 유닛 하나의 장비 5칸(무기·머리·가슴·장갑·신발). 칸마다 단어 id 하나.
## 새로 얻은 장비는 빈칸에만 자동으로 입힌다(01-rpg-base '유닛 12종'), 더 높은 차수로 바꾸기는 사람이 한다.

const SLOTS: Array[String] = ["weapon", "head", "chest", "hands", "feet"]

var slots: Dictionary = {}  ## slot -> word id


func put(slot: String, word_id: String) -> void:
	slots[slot] = word_id


func get_in(slot: String) -> String:
	return slots.get(slot, "")


func auto_put(w: WordData) -> bool:
	if w.slot == "" or slots.has(w.slot):
		return false
	slots[w.slot] = w.id
	return true


func words(repo: WordRepository) -> Array[WordData]:
	var out: Array[WordData] = []
	for s in SLOTS:
		if slots.has(s) and repo.has(slots[s]):
			out.append(repo.get_word(slots[s]))
	return out


## 장비 능력치(data/balance/gear.json slots 식, v = 차수 값, t = 차수).
func stats(repo: WordRepository, gear: Dictionary) -> Stats:
	var st := {"atk": 0, "def": 0, "hp": 0}
	for s in SLOTS:
		if not slots.has(s) or not repo.has(slots[s]):
			continue
		var w := repo.get_word(slots[s])
		var t := w.tier
		var v: int = int(gear["tier_value"].get(str(t), 0))
		var table: Dictionary = gear["slots"].get(_slot_ko(s), {})
		for k in table:
			st[k] += Formula.int_value(table[k], {"v": v, "t": t})
	return Stats.new(st["atk"], st["def"], st["hp"])


func to_dict() -> Dictionary:
	return slots.duplicate()


static func from_dict(d: Dictionary) -> Equipment:
	var e := Equipment.new()
	for k in d:
		e.slots[k] = str(d[k])
	return e


static func _slot_ko(s: String) -> String:
	return {"weapon": "무기", "head": "머리", "chest": "가슴", "hands": "장갑", "feet": "신발"}[s]
