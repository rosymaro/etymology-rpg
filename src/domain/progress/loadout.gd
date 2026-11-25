class_name Loadout
extends RefCounted
## 장착(07-fun.md 2절): 필드 마법 2칸, 전투 마법 덱 4칸, 유닛마다 어근 1개. 노드·화면을 모른다.
## 저장은 GameState.loadout {"field": [...], "deck": [...]}와 GameState.chosen_roots(유닛 번호 -> 어근).
## 바꾸는 것은 마을에서만 한다(화면이 can_change로 막는다).

const FIELD_SLOTS := 2
const DECK_SLOTS := 4
static var _max := -1


## 필드에 데리고 다니는 유닛 수(07-fun 1절, data/balance/field_hunt.json field_party).
static func max_companions() -> int:
	if _max < 0:
		_max = int(JsonFile.read("res://data/balance/field_hunt.json").get("field_party", 3))
	return _max


## 칸 목록을 가진 것만 남기고 칸 수에 맞춘다(빈칸 ""). 처음이면 가진 것 앞에서부터 채운다.
static func _fit(saved: Variant, owned: Array, n: int) -> Array[String]:
	var out: Array[String] = []
	if saved is Array:
		for id in saved:
			var s := String(id)
			out.append(s if s in owned and not s in out else "")
	else:
		for id in owned:
			if out.size() < n:
				out.append(String(id))
	while out.size() < n:
		out.append("")
	return out.slice(0, n)


static func field(state: GameState) -> Array[String]:
	return _fit(state.loadout.get("field"), state.magics, FIELD_SLOTS)


static func deck(state: GameState, rules: ProgressRules) -> Array[String]:
	return _fit(state.loadout.get("deck"), rules.battle_magics(state), DECK_SLOTS)


## 필드에 데리고 다니는 유닛(합류한 유닛 중, 최대 max_companions()). 처음이면 합류한 순서로 앞에서부터.
static func companions(state: GameState) -> Array[int]:
	var out: Array[int] = []
	var saved: Variant = state.loadout.get("units")
	var src: Array = saved if saved is Array else state.joined
	for u in src:
		if int(u) in state.joined and not int(u) in out and out.size() < max_companions():
			out.append(int(u))
	if out.is_empty() and not state.joined.is_empty():
		out.append(state.joined[0])
	return out


## 데리고 다니기를 켜고 끈다. 끄면 하나는 남아야 하고, 켜면 max_companions()를 넘지 못한다. 바뀌면 true.
static func toggle_companion(state: GameState, unit: int) -> bool:
	if not unit in state.joined:
		return false
	var c := companions(state)
	if unit in c:
		if c.size() <= 1:
			return false
		c.erase(unit)
	else:
		if c.size() >= max_companions():
			return false
		c.append(unit)
	state.loadout["units"] = c
	return true


## 칸 i에 id를 넣는다(""이면 비운다). 다른 칸에 이미 있으면 서로 바꾼다. 가진 것이 아니면 false.
static func _put(slots: Array[String], owned: Array, i: int, id: String) -> bool:
	if i < 0 or i >= slots.size() or (id != "" and not id in owned):
		return false
	var j := slots.find(id) if id != "" else -1
	if j >= 0 and j != i:
		slots[j] = slots[i]
	slots[i] = id
	return true


static func set_field(state: GameState, i: int, id: String) -> bool:
	var f := field(state)
	if not _put(f, state.magics, i, id):
		return false
	state.loadout["field"] = f
	return true


static func set_deck(state: GameState, rules: ProgressRules, i: int, id: String) -> bool:
	var d := deck(state, rules)
	if not _put(d, rules.battle_magics(state), i, id):
		return false
	state.loadout["deck"] = d
	return true


## 유닛이 장착한 어근(쓸 수 없게 됐으면 쓸 수 있는 첫 어근, 없으면 "").
static func unit_root(state: GameState, rules: ProgressRules, unit: int) -> String:
	var cand := rules.equippable_roots(state, unit)
	var cur := String(state.chosen_roots.get(unit, ""))
	if cur in cand:
		return cur
	return cand[0] if not cand.is_empty() else ""


static func set_unit_root(state: GameState, rules: ProgressRules, unit: int, root: String) -> bool:
	if root != "" and not root in rules.equippable_roots(state, unit):
		return false
	state.chosen_roots[unit] = root
	return true


static func roots(state: GameState, rules: ProgressRules, party: Array[int]) -> Dictionary:
	var out := {}
	for u in party:
		out[u] = unit_root(state, rules, u)
	return out
