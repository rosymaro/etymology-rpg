class_name StatBonusSkill
extends Skill
## 이번 격돌 내 능력치 +(ple 체력, spect·act 공격, fort 방어 …).


func on_clash(ctx: BattleContext, me: Combatant, _foe: Combatant) -> void:
	me.atk += int(params.get("atk", 0))
	me.def += int(params.get("def", 0))
	if params.has("hp"):
		ctx.heal(me, int(params["hp"]), true)
