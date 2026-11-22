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
	var roots_before := owned_roots(state)
	if is_new:
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
		for r in owned_roots(state):
			if not r in roots_before:
				new_roots.append(r)
	# 다시 잡아야 했던 단어면 진화 재도전이 열린다
	for evo in state.recapture.keys():
		if state.recapture[evo] == id:
			state.recapture.erase(evo)
	return {"word": id, "new": is_new, "exp": gains, "level_ups": ups, "equipped": equipped, "roots": new_roots}


## 가진 스킬 어근(그 어근이 든 단어를 하나라도 얻었으면). 01-rpg-base '어근 해금'.
func owned_roots(state: GameState) -> Array[String]:
	var out: Array[String] = []
	for id in state.dex:
		var w := repo.get_word(id)
		if w == null:
			continue
		for r in w.skill_roots:
			if not r in out:
				out.append(r)
	return out


## 그 유닛이 장착할 수 있는 어근: 가진 어근 중 그 유닛 계열이고, 게임에 동작이 있는 것.
func equippable_roots(state: GameState, unit_no: int) -> Array[String]:
	var out: Array[String] = []
	for r in owned_roots(state):
		if bal.root_family(r) == unit_no and EffectRegistry.skill_implemented(bal.skill_def(r)):
			out.append(r)
	out.sort()
	return out


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
