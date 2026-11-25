class_name BattleContext
extends RefCounted
## 스킬·마법·보스 능력이 받는 유일한 맥락(architecture.md 4절). 새 효과가 정보를 더 원하면 여기에 필드를 더한다.

var allies: Array[Combatant] = []
var enemies: Array[Combatant] = []
var formula: StatFormula
var coin_source: CoinSource
var power: int  ## 마법 위력 P
var magic_id: String = ""
var magic: BattleMagic
var is_boss_battle := false
var log: Array[Dictionary] = []
var no_skill_heal := false
var reroll_next := {Combatant.ALLY: 0, Combatant.ENEMY: 0}
## 단어가 도감에 있는가(not 스킬). Callable(word_id: String) -> bool
var in_dex: Callable = func(_id: String) -> bool: return false
## 출전 순서(순서 마법이 바꾼다). 값은 allies/enemies의 번호. 기록의 idx는 언제나 allies/enemies 번호다.
var order := {}
## 이번 전투에 나온 마법(3개, 턴마다 하나씩 고른다)과 이미 쓴 마법
var offer: Array[String] = []
var used: Array[String] = []
var magic_defs: Dictionary = {}  ## id -> battle_magic.json 항목(use_magic이 만든다)


func team(side: int) -> Array[Combatant]:
	return allies if side == Combatant.ALLY else enemies


func other(side: int) -> int:
	return Combatant.ENEMY if side == Combatant.ALLY else Combatant.ALLY


func add_log(ev: Dictionary) -> void:
	log.append(ev)


func _order(side: int) -> Array:
	if not order.has(side):
		order[side] = range(team(side).size())
	return order[side]


## 지금 싸우는(또는 다음에 나올) 유닛: 순서대로 아직 쓰러지지 않은 첫 유닛. 없으면 null.
func cur(side: int) -> Combatant:
	for k in _order(side):
		var u: Combatant = team(side)[k]
		if not u.entered or u.hp > 0:
			return u
	return null


## 지금 유닛 뒤에서 기다리는(아직 쓰러지지 않은) 유닛들.
func waiting(side: int) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var c := cur(side)
	for k in _order(side):
		var u: Combatant = team(side)[k]
		if u != c and (not u.entered or u.hp > 0):
			out.append(u)
	return out


## u를 순서 맨 뒤로 보낸다(순서 마법).
func send_back(u: Combatant) -> void:
	var o := _order(u.side)
	var k := team(u.side).find(u)
	o.erase(k)
	o.append(k)


## 턴에 고른 마법을 건다(아군). ok = false면 마법만 쓰이고 효과는 없다(방어 마법 퀴즈 실패).
func use_magic(id: String, ok := true) -> void:
	used.append(id)
	if not ok:
		add_log({"t": "magic", "id": id, "side": Combatant.ALLY, "failed": true})
		return
	var m := EffectRegistry.make_magic(magic_defs.get(id, {}))
	if m:
		m.cast(self, Combatant.ALLY)


func cast_magic(side: int) -> void:
	if magic and side == Combatant.ALLY:
		magic.cast(self, side)


## 지금 체력을 바꾼다. 스킬 회복은 leg가 막을 수 있다.
func heal(u: Combatant, amount: int, from_skill: bool) -> void:
	if from_skill and no_skill_heal:
		return
	u.hp += amount
