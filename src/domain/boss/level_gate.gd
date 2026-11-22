class_name LevelGateAbility
extends BossAbility
## devil '말뿌리 장막': 공격하는 유닛 레벨이 gate보다 낮으면 모자란 레벨마다 피해 per_level씩 준다(sim-10stage.md 6절).


func modify_incoming(_ctx: BattleContext, _boss: Combatant, attacker: Combatant, dmg: int) -> int:
	var gate := int(params.get("level", 60))
	if attacker.level >= gate:
		return dmg
	return maxi(0, dmg - (gate - attacker.level) * int(params.get("per_level", 0)))
