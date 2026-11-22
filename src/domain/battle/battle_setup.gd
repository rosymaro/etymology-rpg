class_name BattleSetup
extends RefCounted
## 전투 하나를 차린다: 아군 파티(합류한 유닛 중 무작위), 적, 마법 위력, 맥락.

var repo: WordRepository
var bal: Balance
var rules: ProgressRules
var factory: CombatantFactory
var coin_source: CoinSource


func _init(words: WordRepository, balance: Balance, progress: ProgressRules, coins: CoinSource) -> void:
	repo = words
	bal = balance
	rules = progress
	coin_source = coins
	factory = CombatantFactory.new(words, balance, progress, coins)


## 출전할 아군 유닛 번호(무작위 순서). 01-rpg-base: 12종 중 4개가 랜덤으로 뽑힌다.
func pick_party(state: GameState) -> Array[int]:
	var pool: Array[int] = state.joined.duplicate()
	var out: Array[int] = []
	var n := rules.team_size(state)
	while out.size() < n and not pool.is_empty():
		out.append(pool.pop_at(coin_source.pick(pool.size())))
	return out


## roots: 유닛 번호 -> 장착 어근(""이면 없음). magic_id: ""이면 마법 없음.
func make_context(state: GameState, party: Array[int], roots: Dictionary, magic_id: String) -> BattleContext:
	var ctx := BattleContext.new()
	ctx.formula = factory.formula
	ctx.coin_source = coin_source
	var lv_sum := 0
	for u in party:
		var a := factory.ally(state, u, roots.get(u, ""))
		ctx.allies.append(a)
		lv_sum += a.level
	ctx.power = bal.magic_power(lv_sum / maxi(1, party.size()))
	if magic_id != "":
		ctx.magic_id = magic_id
		ctx.magic = EffectRegistry.make_magic(bal.magic_def(magic_id))
	ctx.in_dex = func(id: String) -> bool: return state.has_word(id)
	return ctx


func field_enemies(ctx: BattleContext, word_ids: Array[String], stage: int) -> void:
	for id in word_ids:
		ctx.enemies.append(factory.enemy(repo.get_word(id), stage))


## 보스전: 졸개(파티 수 − 1명) 다음에 보스가 마지막으로 나온다.
func boss_enemies(ctx: BattleContext, state: GameState, stage: int) -> Array[String]:
	ctx.is_boss_battle = true
	var ids: Array[String] = []
	for k in maxi(0, ctx.allies.size() - 1):
		var m := factory.minion(stage)
		ctx.enemies.append(m)
		ids.append(m.word_id)
	var b := factory.boss(state, stage)
	ctx.enemies.append(b)
	ids.append(b.word_id)
	return ids
