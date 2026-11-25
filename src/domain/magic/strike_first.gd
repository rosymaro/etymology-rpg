class_name StrikeFirstMagic
extends BattleMagic
## de-(아래로): 지금 싸우는 적을 내리쳐 피해를 주고, 그 적의 공격을 전투 내내 atk_down 낮춘다.


func cast(ctx: BattleContext, side: int) -> void:
	var target := ctx.cur(ctx.other(side))
	if target == null:
		return
	var dmg := strike_damage(ctx, target)
	var down := num("atk_down", ctx)
	hurt(target, dmg)
	if target.entered:
		target.atk = maxi(0, target.atk - down)
	target.perm_atk -= down
	ctx.add_log({"t": "magic", "id": id, "side": side, "target": ctx.team(ctx.other(side)).find(target), "damage": dmg, "atk_down": down})
