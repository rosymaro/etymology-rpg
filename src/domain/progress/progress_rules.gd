class_name ProgressRules
extends RefCounted
## 단어 얻기, 경험치, 레벨, 장비 자동 입기, 어근 얻기(01-rpg-base '단어 수집과 성장', 02-rpg-v2 '기존 체계와 연결').
## 수치는 data/balance/progress.json.

var repo: WordRepository
var bal: Balance
var p: Dictionary


func _init(words: WordRepository, balance: Balance) -> void:
	repo = words
	bal = balance
	p = balance.progress


func level_of(exp: int) -> int:
	var per: int = int(p["exp_per_level_squared"])
	return clampi(int(sqrt(float(exp) / per) + 1e-9), 1, int(p["max_level"]))


func level(state: GameState, unit_no: int) -> int:
	return level_of(state.unit_exp[unit_no - 1])


## 12유닛 평균 레벨(보스 레벨을 정할 때, sim-10stage.md 1절).
func avg_level(state: GameState) -> float:
	var s := 0
	for u in range(1, GameState.UNIT_COUNT + 1):
		s += level(state, u)
	return float(s) / GameState.UNIT_COUNT


## 단어의 경험치 바탕값. 1차·보스 = 스테이지 × 10, 진화 단어 = 재료 최대 스테이지 × 4 × 차수.
func base_exp(w: WordData) -> int:
	if w.tier >= 2:
		return repo.evolved_stage(w.id) * int(p["evolve_exp_per_stage_tier"]) * w.tier
	return w.stage * int(p["capture_exp_per_stage"])


## 단어를 얻는다. 돌려주는 사건: {word, new, exp: [12], level_ups: [[unit, from, to]], equipped: unit|0, roots: [새 어근]}
func gain_word(state: GameState, id: String) -> Dictionary:
	var w := repo.get_word(id)
	var is_new := not state.has_word(id)
	state.caught[id] = int(state.caught.get(id, 0)) + 1
	var roots_before := owned_roots(state)
	if is_new:
		for r in w.skill_roots:
			state.roots_cache[r] = true
		state.dex[id] = state.dex.size() + 1
	var base := base_exp(w)
	if not is_new:
		base = int(base * float(p["duplicate_ratio"]))
	var gains: Array[int] = []
	var ups: Array = []
	for u in range(1, GameState.UNIT_COUNT + 1):
		var g := base * (int(p["wearer_multiplier"]) if w.unit == u else 1)
		var before := level(state, u)
		state.unit_exp[u - 1] += g
		gains.append(g)
		var after := level(state, u)
		if after > before:
			ups.append([u, before, after])
	var equipped := 0
	if is_new and w.unit > 0 and state.eq(w.unit).auto_put(w):
		equipped = w.unit
	var new_roots: Array[String] = []
	if is_new:
		for r in w.skill_roots:
			if not r in roots_before and not r in new_roots:
				new_roots.append(r)
	# 다시 잡아야 했던 단어면 진화 재도전이 열린다
	for evo in state.recapture.keys():
		if state.recapture[evo] == id:
			state.recapture.erase(evo)
	return {"word": id, "new": is_new, "exp": gains, "level_ups": ups, "equipped": equipped, "roots": new_roots}


## 가진 스킬 어근(그 어근이 든 단어를 하나라도 얻었으면). 01-rpg-base '어근 해금'.
func owned_roots(state: GameState) -> Array[String]:
	if state.roots_cache.is_empty() and not state.dex.is_empty():
		for id in state.dex:
			var w := repo.get_word(id)
			if w:
				for r in w.skill_roots:
					state.roots_cache[r] = true
	var out: Array[String] = []
	for r in state.roots_cache:
		out.append(r)
	return out


## 개발자 모드: 모든 단어·유닛·마법을 주고, 장비는 부위마다 가장 높은 차수를 입힌다.
## gain_word를 1만 번 부르면 느려서, 같은 규칙(경험치·입는 유닛 2배)을 한 번에 계산한다.
func grant_all(state: GameState, magics: Array[String]) -> void:
	var mult := int(p["wearer_multiplier"])
	var total := 0
	var bonus: Array[int] = []
	bonus.resize(GameState.UNIT_COUNT)
	bonus.fill(0)
	for id in repo.all_ids():
		var w := repo.get_word(id)
		if not state.has_word(id):
			state.dex[id] = state.dex.size() + 1
		var e := base_exp(w)
		total += e
		if w.unit > 0:
			bonus[w.unit - 1] += e * (mult - 1)
		for r in w.skill_roots:
			state.roots_cache[r] = true
		if w.unit > 0 and w.slot != "":
			var eq := state.eq(w.unit)
			var cur := eq.get_in(w.slot)
			if cur == "" or repo.get_word(cur).tier < w.tier:
				eq.put(w.slot, id)
	for u in GameState.UNIT_COUNT:
		state.unit_exp[u] = total + bonus[u]
	state.joined.clear()
	for u in range(1, GameState.UNIT_COUNT + 1):
		state.joined.append(u)
	for m in magics:
		if not m in state.magics:
			state.magics.append(m)


## 그 유닛이 장착할 수 있는 어근: 가진 어근 중 그 유닛 계열이고, 게임에 동작이 있는 것.
func equippable_roots(state: GameState, unit_no: int) -> Array[String]:
	var out: Array[String] = []
	for r in owned_roots(state):
		if bal.root_family(r) == unit_no and EffectRegistry.skill_implemented(bal.skill_def(r)):
			out.append(r)
	out.sort()
	return out


## 가진 전투 마법(동작이 만들어진 것만): 그 스테이지가 열렸으면 얻는다(battle_magic.json unlock.stage). 개발자 모드는 모두.
func battle_magics(state: GameState) -> Array[String]:
	var out: Array[String] = []
	for m in bal.magic["magics"]:
		if not EffectRegistry.magic_implemented(m):
			continue
		if state.dev_mode or state.stage >= int(m.get("unlock", {}).get("stage", 99)):
			out.append(String(m["id"]))
	return out


## 이번 전투에 나올 마법: 덱(장착한 4개, 07-fun 2절) 중 무작위 offer_count개. 방어 마법은 장착 어근과 조합 단어가 있어야 나온다.
func magic_offer(state: GameState, roots: Array, rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = []
	for id in Loadout.deck(state, self):
		if id == "":
			continue
		var d := bal.magic_def(id)
		if String(d.get("kind", "")) == "defense" and not ComboQuiz.possible(repo, String(d.get("prefix", "")), roots):
			continue
		pool.append(id)
	var out: Array[String] = []
	var n := int(bal.magic.get("offer_count", 3))
	while out.size() < n and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


## 전투에서 지면 병원에서 쉰다: now부터 sec초 동안 마을 밖으로 못 나간다(04-meta 9절).
func start_rest(state: GameState, now: int, sec: int) -> void:
	state.rest_until = now + sec


## 쉬는 시간이 몇 초 남았나(0이면 다 쉬었다).
func rest_left(state: GameState, now: int) -> int:
	return maxi(0, state.rest_until - now)


func team_size(state: GameState) -> int:
	return mini(int(p["team_max"]), state.joined.size())


## 보스 길 막기: 그 스테이지 1차 단어를 boss_gate_ratio보다 많이 가졌는가.
func boss_gate(state: GameState, stage: int) -> Dictionary:
	var all := repo.first_tier(stage)
	var have := 0
	for w in all:
		if state.has_word(w.id):
			have += 1
	var need := int(floor(all.size() * float(p["boss_gate_ratio"]))) + 1
	return {"have": have, "need": need, "open": have >= need}
