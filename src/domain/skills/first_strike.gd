class_name FirstStrikeSkill
extends Skill
## mot: 이번 격돌에서 먼저 공격한다. 먼저 쓰러뜨리면 같이 쓰러지지 않는다.


func on_clash(_ctx: BattleContext, me: Combatant, _foe: Combatant) -> void:
	me.first_strike = true
