class_name DoubleFirstRoundSkill
extends Skill
## curr: 첫 라운드에 두 번 공격한다(피해 2배).


func on_clash(_ctx: BattleContext, me: Combatant, _foe: Combatant) -> void:
	me.double_first = true
