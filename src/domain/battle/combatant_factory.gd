class_name CombatantFactory
extends RefCounted
## 아군 유닛·적 단어·보스로 전투원을 만든다. 적은 층을 쌓아 정한다(03-tuning.md 4절):
## 스테이지 곡선(기준 레벨, 코인, 장비 몫) → 빈도 보정 → 성향(계열 어근, 없으면 주속성) → 스킬.

const GRADE := {"low": "L", "mid": "M", "high": "H"}
const STYLE := {"attack": "atk", "volatile": "swing"}

var repo: WordRepository
var bal: Balance
var rules: ProgressRules
var formula: StatFormula
var coin_source: CoinSource


func _init(words: WordRepository, balance: Balance, progress: ProgressRules, coins: CoinSource) -> void:
	repo = words
	bal = balance
	rules = progress
	formula = StatFormula.new(balance.unit)
	coin_source = coins


func ally(state: GameState, unit_no: int, root: String) -> Combatant:
	var c := Combatant.new()
	c.side = Combatant.ALLY
	c.unit_no = unit_no
	c.level = rules.level(state, unit_no)
	var tend := formula.role(unit_no)
	c.coin_style = tend["coin_style"]
	c.coins = formula.coins(c.level)
	c.coin_value = formula.coin_value(c.level)
	c.base = formula.base(tend, c.level).plus(state.eq(unit_no).stats(repo, bal.gear))
	if root != "":
		c.skill_root = root
		c.skill = EffectRegistry.make_skill(root, bal.skill_def(root), bal.root_tier(root))
	return c


## 필드 적: 기준 레벨 + 빈도 보정(5 − 빈도, min~max).
func enemy_level(w: WordData, stage: int) -> int:
	var fb: Dictionary = bal.enemy["frequency_level_bonus"]
	var bonus := clampi(Formula.int_value(fb["formula"], {"frequency": w.freq}), int(fb["min"]), int(fb["max"]))
	return clampi(int(bal.stage_curve(stage)["base_level"]) + bonus, 1, 60)


func enemy(w: WordData, stage: int, level: int = -1, coins: int = -1) -> Combatant:
	var c := Combatant.new()
	c.side = Combatant.ENEMY
	c.word_id = w.id
	for e in w.etym:
		var r := str(e.get("root", ""))
		if r.ends_with("-"):
			c.prefixes.append(r)
	c.level = enemy_level(w, stage) if level < 0 else level
	var curve := bal.stage_curve(stage)
	var tend := _tendency(w)
	c.unit_no = tend["unit_no"]
	c.coin_style = tend["coin_style"]
	c.coins = int(curve["coins"]) if coins < 0 else coins
	c.coin_value = formula.coin_value(c.level)
	var gb: Array = curve.get("gear_bonus", [0, 0, 0])
	c.base = formula.base(tend, c.level).plus(Stats.new(int(gb[0]), int(gb[1]), int(gb[2])))
	var usable: Array[String] = []
	for r in w.skill_roots:
		if EffectRegistry.skill_implemented(bal.skill_def(r)):
			usable.append(r)
	if not usable.is_empty():
		var r := usable[coin_source.pick(usable.size())]
		c.skill_root = r
		c.skill = EffectRegistry.make_skill(r, bal.skill_def(r), bal.root_tier(r))
	return c


## 보스: 보스전 때 12유닛 평균 레벨 + level_delta(boss.json), 코인은 보스 정의.
func boss(state: GameState, stage: int) -> Combatant:
	var w := repo.boss_word(stage)
	var def := bal.boss_def(stage)
	var lv := clampi(int(round(rules.avg_level(state))) + int(def.get("level_delta", 0)), 1, 60)
	var c := enemy(w, stage, lv, int(def.get("coins", 1)))
	c.is_boss = true
	c.skill = null
	c.skill_root = ""
	c.boss_ability = EffectRegistry.make_boss(def.get("ability", {}))
	return c


## 보스 졸개: 그 스테이지 재료로 만드는 2차 단어, 필드 기준 레벨 + minion_level_bonus.
func minion(stage: int) -> Combatant:
	var pool := repo.evolutions_up_to(stage, 2)
	var w: WordData = pool[coin_source.pick(pool.size())]
	var lv := int(bal.stage_curve(stage)["base_level"]) + int(bal.boss.get("minion_level_bonus", 2))
	return enemy(w, stage, clampi(lv, 1, 60))


func _tendency(w: WordData) -> Dictionary:
	var row: Dictionary = {}
	var unit_no := 0
	for r in w.skill_roots:
		var fam := bal.root_family(r)
		if fam > 0:
			row = bal.tendency["root_family"][str(fam)]
			unit_no = fam
			break
	if row.is_empty():
		var pa: Dictionary = bal.tendency["primary_attribute"]
		row = pa.get(str(w.primary_attr()), pa["_default"])
	return {"atk": GRADE[row["atk"]], "def": GRADE[row["def"]], "hp": GRADE[row["hp"]],
		"coin_style": STYLE.get(row["coin_style"], row["coin_style"]), "unit_no": unit_no}
