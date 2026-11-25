class_name ShareDamageMagic
extends BattleMagic
## com-(함께): 이번 격돌 동안 지금 싸우는 아군이 받는 피해의 share_pct%를 기다리는 동료가 나눠 맡는다.
## 함께 막으니 동료는 맡은 몫의 taken_pct%만 받는다(전체 피해가 준다).


func cast(ctx: BattleContext, side: int) -> void:
	var me := ctx.cur(side)
	if me == null:
		return
	me.share = float(params.get("share_pct", 40)) / 100.0
	me.share_taken = float(params.get("taken_pct", 100)) / 100.0
	ctx.add_log({"t": "magic", "id": id, "side": side, "who": ctx.team(side).find(me)})
