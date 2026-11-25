class_name BattleEngine
extends RefCounted
## 서바이벌 전투(01-rpg-base '전투: 4 대 4 서바이벌'). tools/balance/engine.py와 같은 순서로 계산한다.
## 1) 마법 발동 2) 출전 순서대로 격돌: 새로 나온 쪽만 코인을 던진다 → 보스 능력 → 스킬 → 라운드 반복
## 라운드: 두 쪽이 동시에 (공격 − 상대 방어 − 감소)만큼, 최소 1 피해. 먼저 공격하는 쪽은 상대를 먼저 친다.

const MAX_ROUNDS := 200

var ctx: BattleContext


func _init(context: BattleContext) -> void:
	ctx = context


var res: BattleResult
var finished := false
var turns := 0  ## 지나간 턴(라운드) 수. 턴마다 마법을 고를 수 있다(01-rpg-base '마법 쓰기')
var _a: Combatant
var _b: Combatant
var _rnd := 0


## 한 번에 끝까지(마법 없이 턴을 넘긴다). 시뮬레이션·테스트용. 시작 마법(ctx.magic)은 begin에서 건다.
func run() -> BattleResult:
	begin()
	while not finished:
		turn("")
	return res


## 전투를 연다: 시작 마법 → 첫 두 유닛 등장 → 격돌 준비(보스 능력·스킬). 다음 턴 앞에서 멈춘다.
func begin() -> void:
	res = BattleResult.new()
	res.enemy_count = ctx.enemies.size()
	res.log = ctx.log
	if ctx.magic:
		ctx.cast_magic(Combatant.ALLY)
	_resolve()


## 한 턴: (고른 마법을 먼저 건다) → 두 유닛이 서로 공격 → 쓰러지면 다음 유닛이 나오고 격돌 준비. 다음 턴 앞에서 멈춘다.
## magic_id가 있으면 그 마법을 건다(ok = false면 퀴즈 실패로 효과 없음). 마법으로 쓰러지거나 순서가 바뀌면 이 턴은 공격 없이 끝난다.
func turn(magic_id: String = "", ok := true) -> void:
	if finished:
		return
	if magic_id != "":
		var pair := [_a, _b]
		_traced(_a, _b, func() -> void: ctx.use_magic(magic_id, ok))
		if _a.hp <= 0 or _b.hp <= 0 or ctx.cur(Combatant.ALLY) != pair[0] or ctx.cur(Combatant.ENEMY) != pair[1]:
			_resolve()
			return
	turns += 1
	_round(_a, _b)
	_resolve()


## 쓰러진 쪽을 내보내고, 빈 자리에 다음 유닛을 들인다. 한쪽이 다 쓰러지면 끝.
func _resolve() -> void:
	if _b != null and _b.hp <= 0:
		var jb := ctx.enemies.find(_b)
		res.killed.append(jb)
		ctx.add_log({"t": "down", "side": Combatant.ENEMY, "idx": jb})
		_b = null
	if _a != null and _a.hp <= 0:
		ctx.add_log({"t": "down", "side": Combatant.ALLY, "idx": ctx.allies.find(_a)})
		_a = null
	if _a != null and ctx.cur(Combatant.ALLY) != _a:  # 순서 마법으로 뒤로 간 유닛
		_a = null
	if _b != null and ctx.cur(Combatant.ENEMY) != _b:
		_b = null
	if ctx.cur(Combatant.ALLY) == null or ctx.cur(Combatant.ENEMY) == null or _rnd >= MAX_ROUNDS:
		if not finished:
			finished = true
			ctx.add_log({"t": "end", "kills": res.killed.size(), "total": res.enemy_count})
		return
	var fresh := false
	if _a == null:
		_a = ctx.cur(Combatant.ALLY)
		_enter(_a, ctx.allies.find(_a))
		fresh = true
	if _b == null:
		_b = ctx.cur(Combatant.ENEMY)
		_enter(_b, ctx.enemies.find(_b))
		fresh = true
	if fresh:
		_rnd = 0
		_clash(_a, _b, ctx.allies.find(_a), ctx.enemies.find(_b))
		if _a.hp <= 0 or _b.hp <= 0:  # 보스 능력·스킬로 바로 쓰러짐
			_resolve()


func _enter(u: Combatant, idx: int) -> void:
	var magic_hit := u.pre_damage  # 전투 시작 마법으로 미리 받은 피해(roll이 지운다)
	u.roll(ctx.coin_source, ctx.formula)
	var r: int = ctx.reroll_next[u.side]
	if r > 0:
		ctx.reroll_next[u.side] = 0
		for k in u.flips.size():
			if r > 0 and not u.flips[k]:
				u.flips[k] = ctx.coin_source.flip(1, u.heads_chance)[0]
				r -= 1
		u.recalc_atk(ctx.formula)
	# 화면이 '코인 전 → 코인 후'를 보여 줄 수 있게 코인 항과 코인 전 값을 함께 남긴다
	var t := ctx.formula.coin_terms(u.coin_style, u.coin_value, u.flips)
	ctx.add_log({"t": "enter", "side": u.side, "idx": idx, "flips": u.flips.duplicate(),
		"atk": u.atk, "def": u.def, "hp": u.hp, "pre_atk": u.atk - t.atk, "pre_hp": u.hp - t.hp + magic_hit,
		"gain_atk": t.atk, "gain_hp": t.hp, "magic_hit": magic_hit})


## 두 전투원의 지금 값(기록에 '전 → 후'로 남긴다)
static func _snap(a: Combatant, b: Combatant) -> Dictionary:
	return {"a": [a.atk, a.def, a.hp], "b": [b.atk, b.def, b.hp], "a_flips": a.flips.duplicate(), "b_flips": b.flips.duplicate()}


## f()를 부르고, 그 사이에 새로 생긴 기록에 전·후 값을 붙인다.
func _traced(a: Combatant, b: Combatant, f: Callable) -> void:
	var before := _snap(a, b)
	var n := ctx.log.size()
	f.call()
	var after := _snap(a, b)
	for k in range(n, ctx.log.size()):
		ctx.log[k]["before"] = before
		ctx.log[k]["after"] = after


func _clash(a: Combatant, b: Combatant, i: int, j: int) -> void:
	a.start_clash()
	b.start_clash()
	for pair in [[b, a], [a, b]]:
		var boss: Combatant = pair[0]
		if boss.boss_ability and ctx.is_boss_battle:
			_traced(a, b, func() -> void:
				boss.boss_ability.on_clash(ctx, boss, pair[1]))
	for pair in [[a, b], [b, a]]:
		var u: Combatant = pair[0]
		if u.skill and not u.sealed and u.heads() >= ctx.formula.skill_min_heads(u.skill.tier, u.coins):
			_traced(a, b, func() -> void:
				u.skill.on_clash(ctx, u, pair[1])
				ctx.add_log({"t": "skill", "side": u.side, "root": u.skill.root}))
	ctx.add_log({"t": "clash", "a": i, "b": j, "a_atk": a.atk, "a_def": a.def, "a_hp": a.hp,
		"b_atk": b.atk, "b_def": b.def, "b_hp": b.hp})


## 한 라운드: 두 쪽이 동시에(먼저 공격이 있으면 먼저) 친다.
func _round(a: Combatant, b: Combatant) -> void:
	_rnd += 1
	var rnd := _rnd
	var da := _damage(a, b, rnd)
	var db := _damage(b, a, rnd)
	var first := Combatant.ALLY if a.first_strike and not b.first_strike else (Combatant.ENEMY if b.first_strike and not a.first_strike else -1)
	if first == Combatant.ALLY:
		_hit(b, a, da)
		if b.hp > 0:
			_hit(a, b, db)
		else:
			db = 0
	elif first == Combatant.ENEMY:
		_hit(a, b, db)
		if a.hp > 0:
			_hit(b, a, da)
		else:
			da = 0
	else:
		_hit(a, b, db)
		_hit(b, a, da)
	for u in [a, b]:
		if u.wall_rounds > 0:
			u.wall_rounds -= 1
	ctx.add_log({"t": "round", "n": rnd, "to_b": da, "to_a": db, "a_hp": maxi(a.hp, 0), "b_hp": maxi(b.hp, 0), "first": first})


## y가 x에게서 dmg를 받는다: 동료가 나눠 받고(com-), 받은 만큼의 일부를 되돌린다(ob-).
func _hit(y: Combatant, x: Combatant, dmg: int) -> void:
	var took := ctx.split_damage(y, dmg)
	y.hp -= took
	if y.reflect > 0.0 and took > 0:
		x.hp -= int(ceil(took * y.reflect))


func _damage(x: Combatant, y: Combatant, rnd: int) -> int:
	var d := maxi(1, x.atk - y.def - y.reduce - (y.wall if y.wall_rounds > 0 else 0))
	if x.double_first and rnd == 1:
		d *= 2
	if y.boss_ability and ctx.is_boss_battle:
		d = y.boss_ability.modify_incoming(ctx, y, x, d)
	return d

