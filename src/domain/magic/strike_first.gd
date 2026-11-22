class_name StrikeFirstMagic
extends BattleMagic
## de-: 적 1번(전투 중이면 지금 상대)을 내리쳐 피해를 주고 공격을 전투 내내 낮춘다.
## 그 접두사가 든 단어는 피해를 절반만 받는다(01-rpg-base '공격 마법 4개').


func cast(ctx: BattleContext, side: int) -> void:
	var foes := ctx.team(ctx.other(side))
	var target: Combatant = null
	for f in foes:
		if f.hp > 0 or not f.entered:
			target = f
			break
	if target == null:
		return
	var dmg := num("damage", ctx)
	if prefix in target.prefixes:
		dmg = dmg / 2
	var down := num("atk_down", ctx)
	if target.entered:
		target.hp -= dmg
		target.atk = maxi(0, target.atk - down)
	else:
		target.pre_damage += dmg
	target.perm_atk -= down
	ctx.add_log({"t": "magic", "id": id, "side": side, "target": foes.find(target), "damage": dmg})
