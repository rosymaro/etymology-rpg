extends SceneTree
## 전투 시뮬레이터: 게임의 규칙 층(BattleSetup, BattleEngine, 마법 클래스)을 그대로 쓴다(tools/balance/README.md).
## 턴마다 마법을 쓰는 지금 방식(한 전투에 나오는 3개, 하나는 한 번씩)을 세 가지 플레이어로 비교한다.
##   없음: 마법을 안 쓴다  /  아무거나: 쓸 수 있으면 아무 마법이나 반쯤 쓴다  /  생각: 아래 규칙으로 때를 골라 쓴다(마법을 아는 사람)
## godot --headless -s tools/balance/battle_sim.gd -- [판=300] [스테이지=2-10] [tune]
## tune: '생각' 플레이어 승률이 필드 TARGET_FIELD, 보스 TARGET_BOSS 가까이 되도록 적 기준 레벨(enemy.json stage_curve base_level)과
##       보스 level_delta(boss.json)에 더할 값을 찾아 표로 보여 준다. JSON에 적는 것은 사람이 한다.
## 가정(sim-10stage.md와 같다): 스테이지 s에 들어올 때 앞 스테이지 1차 단어를 모두, 그 스테이지 1차의 60%를 가지고, 재료가 모이면 바로 진화한다.
## 파티는 합류한 유닛 중 무작위 4명(_joined). 방어 마법의 조합 뜻 고르기는 80% 맞힌다. 덱은 가진 마법 중 앞 4개.

const QUIZ_OK := 0.8
const TARGET_FIELD := 0.75
const TARGET_BOSS := 0.65

var rng := RandomNumberGenerator.new()
var gd  ## GameData(자동 로드는 -s 스크립트에서 이름으로 못 쓴다)
var _started := false


func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	gd = root.get_node("GameData")
	_main()
	return true


func _main() -> void:
	var args := OS.get_cmdline_user_args()
	var trials := int(args[0]) if args.size() > 0 else 300
	var lo := 2
	var hi := 10
	if args.size() > 1:
		var p := String(args[1]).split("-")
		lo = int(p[0])
		hi = int(p[p.size() - 1])
	rng.seed = 7
	gd.rng.seed = 7
	if args.size() > 2 and args[2] == "each":
		_each(trials, lo, hi)
		quit()
		return
	if args.size() > 2 and args[2] == "tune":
		_tune(trials, lo, hi)
		quit()
		return
	print("스테이지 | 평균Lv | 필드: 없음 / 아무거나 / 생각 | 보스: 없음 / 아무거나 / 생각 | 마법 씀(생각, 판당)")
	for s in range(lo, hi + 1):
		var st := _state(s)
		var lv := 0
		for u in st.joined:
			lv += gd.rules.level(st, u)
		var line := "%d | %.1f |" % [s, float(lv) / st.joined.size()]
		var uses := 0.0
		for boss in [false, true]:
			var rates := []
			for pol in ["none", "random", "smart"]:
				var won := 0
				for t in trials:
					var r := _battle(st, s, boss, pol)
					if r["won"]:
						won += 1
					if pol == "smart" and not boss:
						uses += float(r["used"])
				rates.append("%d%%" % roundi(100.0 * won / trials))
			line += " %s |" % " / ".join(rates)
		line += " %.1f" % (uses / trials)
		print(line)
	quit()


func _state(s: int) -> GameState:
	var st := GameState.new()
	st.stage = s
	st.joined.clear()
	for u in _joined(s):
		st.joined.append(u)
	for k in range(1, s):
		for w in gd.repo.first_tier(k):
			gd.rules.gain_word(st, w.id)
	var cur: Array = gd.repo.first_tier(s)
	for i in int(cur.size() * 0.6):
		gd.rules.gain_word(st, cur[i].id)
	while true:  # 부지런한 플레이어: 재료가 모이면 바로 진화
		var ev: Array = gd.evolution.available(st, 4)
		if ev.is_empty():
			break
		for w in ev:
			gd.rules.gain_word(st, (w as WordData).id)
	for id in st.dex:  # 부위마다 가진 것 중 가장 높은 차수를 입는다(개발자 모드와 같은 규칙)
		var w: WordData = gd.repo.get_word(id)
		if w and w.unit > 0 and w.slot != "":
			var eq: Equipment = st.eq(w.unit)
			var cur_id := eq.get_in(w.slot)
			if cur_id == "" or gd.repo.get_word(cur_id).tier < w.tier:
				eq.put(w.slot, id)
	return st


## 스테이지마다 합류한 유닛(00-overview 이야기에서 어림): 1 뚝딱·척척, 2 덥석, 3 힐끔·조잘, 4 쌩·빙글, 5 영차, 6 대장,
## 8 꿈쩍·휙 합류·영차 이탈, 9 와장, 10 영차가 돌아온다.
static func _joined(s: int) -> Array[int]:
	var add := {1: [1, 4], 2: [2], 3: [3, 5], 4: [6, 10], 5: [7], 6: [8], 8: [11, 9], 9: [12], 10: [7]}
	var out: Array[int] = []
	for k in range(1, s + 1):
		for u in add.get(k, []):
			if not u in out:
				out.append(u)
		if k == 8:
			out.erase(7)
	return out


var only := ""  ## each: 이 마법 하나만 나온다


func _battle(st: GameState, s: int, boss: bool, pol: String) -> Dictionary:
	var party: Array[int] = gd.setup.pick_party(st)
	var roots := {}
	for u in party:
		var rs: Array[String] = gd.rules.equippable_roots(st, u)
		roots[u] = rs[rng.randi_range(0, rs.size() - 1)] if not rs.is_empty() else ""
	var ctx: BattleContext = gd.setup.make_context(st, party, roots, "")
	for m in gd.bal.magic["magics"]:
		ctx.magic_defs[m["id"]] = m
	ctx.offer = gd.rules.magic_offer(st, roots.values(), rng) if pol != "none" else ([] as Array[String])
	if only != "":
		ctx.offer = [only] as Array[String]
	if boss:
		gd.setup.boss_enemies(ctx, st, s)
	else:
		var pool: Array = gd.repo.first_tier(s, "field")
		var ids: Array[String] = []
		while ids.size() < 4:
			var w: WordData = pool[rng.randi_range(0, pool.size() - 1)]
			if not w.id in ids:
				ids.append(w.id)
		gd.setup.field_enemies(ctx, ids, s)
	var eng := BattleEngine.new(ctx)
	if OS.get_environment("SIM_DEBUG") != "":
		for u in ctx.allies:
			print("A lv%d %d/%d/%d coins%d eq" % [u.level, u.base.atk, u.base.def, u.base.hp, u.coins])
		for u in ctx.enemies:
			print("E lv%d %d/%d/%d coins%d %s" % [u.level, u.base.atk, u.base.def, u.base.hp, u.coins, u.word_id])
	eng.begin()
	var guard := 0
	while not eng.finished and guard < 400:
		guard += 1
		var id := _pick(ctx, eng, pol)
		var ok := true
		if id != "" and String(gd.bal.magic_def(id).get("kind", "")) == "defense":
			ok = rng.randf() < QUIZ_OK
		eng.turn(id, ok)
	return {"won": eng.res.won(), "used": ctx.used.size()}


func _pick(ctx: BattleContext, eng: BattleEngine, pol: String) -> String:
	var free: Array[String] = []
	for id in ctx.offer:
		if not id in ctx.used:
			free.append(id)
	if free.is_empty() or pol == "none":
		return ""
	if pol == "random":
		return free[rng.randi_range(0, free.size() - 1)] if rng.randf() < 0.5 else ""
	var a := ctx.cur(Combatant.ALLY)
	var b := ctx.cur(Combatant.ENEMY)
	if a == null or b == null:
		return ""
	var hit_me := maxi(1, b.atk - a.def - a.reduce)
	var hit_it := maxi(1, a.atk - b.def - b.reduce)
	var rounds_me := ceili(float(a.hp) / hit_me)  # 내가 버티는 턴
	var rounds_it := ceili(float(b.hp) / hit_it)  # 적을 쓰러뜨리는 턴
	for id in free:
		var kind := String(gd.bal.magic_def(id).get("kind", ""))
		match id:
			"pro":  # 뒤에 숨은 보스(또는 가장 센 적)를 끌어낸다
				var w := ctx.waiting(Combatant.ENEMY)
				if not w.is_empty() and (w[w.size() - 1].is_boss or w[w.size() - 1].base.hp > b.hp * 2):
					return id
			"ex":  # 질 싸움에서 빼내 체력을 올린다
				if rounds_me < rounds_it and not ctx.waiting(Combatant.ALLY).is_empty():
					return id
			"in":
				if a.heads() < a.flips.size():
					return id
			"dis":
				if b.atk >= 4 and rounds_me <= rounds_it:
					return id
			_:
				if kind == "attack" and rounds_it > 1:
					return id
				if kind == "defense" and rounds_me <= rounds_it + 1:
					return id
	return ""


func _rate(st: GameState, s: int, boss: bool, pol: String, trials: int) -> float:
	var won := 0
	for t in trials:
		if _battle(st, s, boss, pol)["won"]:
			won += 1
	return float(won) / trials


func _tune(trials: int, lo: int, hi: int) -> void:
	print("스테이지 | 적 기준 Lv(전→후) | 필드 없음/생각 | 보스 level_delta(전→후) | 보스 없음/생각")
	for s in range(lo, hi + 1):
		var st := _state(s)
		var curve: Dictionary = gd.bal.stage_curve(s)
		var base0 := int(curve["base_level"])
		var d := _search(func(v: int) -> float:
			curve["base_level"] = base0 + v
			return _rate(st, s, false, "smart", trials), TARGET_FIELD)
		curve["base_level"] = base0 + d
		var fn := _rate(st, s, false, "none", trials)
		var fs := _rate(st, s, false, "smart", trials)
		var bdef: Dictionary = {}
		for b in gd.bal.boss["bosses"]:
			if int(b["stage"]) == s:
				bdef = b
		var b0 := int(bdef.get("level_delta", 0))
		var bd := _search(func(v: int) -> float:
			bdef["level_delta"] = b0 + v
			return _rate(st, s, true, "smart", trials), TARGET_BOSS)
		bdef["level_delta"] = b0 + bd
		var bn := _rate(st, s, true, "none", trials)
		var bs := _rate(st, s, true, "smart", trials)
		print("%d | %d → %d | %d%% / %d%% | %d → %d | %d%% / %d%%" % [s, base0, base0 + d, roundi(fn * 100), roundi(fs * 100), b0, b0 + bd, roundi(bn * 100), roundi(bs * 100)])


## 마법 하나씩만 쓸 때 필드 승률(생각)이 마법 없을 때보다 얼마나 오르나. 방어 마법은 조합 단어가 있다고 본다.
func _each(trials: int, lo: int, hi: int) -> void:
	for s in range(lo, hi + 1):
		var st := _state(s)
		st.stage = 10
		var base := _rate(st, s, false, "none", trials)
		var line := "%d 없음 %d%% |" % [s, roundi(base * 100)]
		for m in gd.bal.magic["magics"]:
			only = String(m["id"])
			line += " %s %+d" % [only, roundi((_rate(st, s, false, "smart", trials) - base) * 100)]
		only = ""
		print(line)


## 승률이 목표 ±3%에 들 때까지 한 레벨씩 올리고 내린다(세게 하면 승률이 내려간다). 더할 값을 돌려준다.
func _search(rate_at: Callable, target: float) -> int:
	var v := 0
	for k in 20:
		var r: float = rate_at.call(v)
		if r > target + 0.03:
			v += 1
		elif r < target - 0.03:
			v -= 1
		else:
			break
	return v
