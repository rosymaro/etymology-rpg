class_name StrikeUndoMagic
extends BattleMagic
## un-(되돌림): 지금 싸우는 적에게 피해를 주고, 그 적의 코인 앞면 undo_pct%(올림)를 뒷면으로 되돌린다(코인으로 오른 공격이 줄어든다).


func cast(ctx: BattleContext, side: int) -> void:
	var target := ctx.cur(ctx.other(side))
	if target == null:
		return
	var dmg := strike_damage(ctx, target)
	hurt(target, dmg)
	if target.entered:
		var n := int(ceil(target.heads() * float(params.get("undo_pct", 100)) / 100.0))
		for k in target.flips.size():
			if n > 0 and target.flips[k]:
				target.flips[k] = false
				n -= 1
		target.recalc_atk(ctx.formula)
	ctx.add_log({"t": "magic", "id": id, "side": side, "target": ctx.team(ctx.other(side)).find(target), "damage": dmg})
