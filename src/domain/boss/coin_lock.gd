class_name CoinLockAbility
extends BossAbility
## destroyer '결함': 격돌마다 상대 코인 count개를 뒷면으로 고정한다(01-rpg-base '보스 능력 1차').


func on_clash(ctx: BattleContext, _boss: Combatant, foe: Combatant) -> void:
	var n := mini(int(params.get("count", 1)), foe.flips.size())
	var changed := false
	for i in n:
		if foe.flips[i]:
			foe.flips[i] = false
			changed = true
	if changed:
		foe.recalc_atk(ctx.formula)
	ctx.add_log({"t": "boss_ability", "id": "CoinLock", "count": n})
