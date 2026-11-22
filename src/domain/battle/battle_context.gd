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


func team(side: int) -> Array[Combatant]:
	return allies if side == Combatant.ALLY else enemies


func other(side: int) -> int:
	return Combatant.ENEMY if side == Combatant.ALLY else Combatant.ALLY


func add_log(ev: Dictionary) -> void:
	log.append(ev)


func cast_magic(side: int) -> void:
	if magic and side == Combatant.ALLY:
		magic.cast(self, side)


## 지금 체력을 바꾼다. 스킬 회복은 leg가 막을 수 있다.
func heal(u: Combatant, amount: int, from_skill: bool) -> void:
	if from_skill and no_skill_heal:
		return
	u.hp += amount
