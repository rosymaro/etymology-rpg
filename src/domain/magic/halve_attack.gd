class_name HalveAttackMagic
extends BattleMagic
## dis-(따로): 지금 싸우는 적의 무기를 떼어 놓는다: 그 적의 지금 공격이 cut_pct% 준다(올림, 다시 나오면 되돌아온다).


func cast(ctx: BattleContext, side: int) -> void:
	var target := ctx.cur(ctx.other(side))
	if target == null or not target.entered:
		return
	var before := target.atk
	target.atk -= int(ceil(target.atk * float(params.get("cut_pct", 25)) / 100.0))
	ctx.add_log({"t": "magic", "id": id, "side": side, "target": ctx.team(ctx.other(side)).find(target), "atk_down": before - target.atk})
