class_name Combatant
extends RefCounted
## 전투에 나선 유닛 하나(아군 유닛 또는 적 단어). 격돌 동안 바뀌는 값을 갖는다.

const ALLY := 0
const ENEMY := 1

var side: int
var unit_no: int  ## 아군: 유닛 번호, 적: 성향을 빌린 유닛 번호(없으면 0)
var word_id: String  ## 적: 단어 id
var prefixes: Array[String] = []  ## 적 단어 어원의 접두사(공격 마법이 덜 듣는지)
var level: int
var coins: int
var coin_value: int
var coin_style: String
var base: Stats  ## 장비·장비 몫·보정까지 더한 고정값
var skill_root: String = ""
var skill: Skill
var boss_ability: BossAbility
var is_boss := false

# 격돌 상태
var flips: Array[bool] = []
var atk: int
var def: int
var hp: int
var heads_chance := 0.5
var perm_atk := 0  ## 전투 내내 붙는 공격 보정(de- 등)
var pre_damage := 0  ## 나올 때 받는 피해(공격 마법)
var hold_hp := 0  ## 순서 마법으로 뒤로 갔다가 다시 나올 때 지닐 체력(0이면 새로 정한다)
var reduce := 0  ## 이번 격돌 받는 피해 감소
var first_strike := false
var double_first := false
var sealed := false
var reflect := 0.0  ## 이번 격돌 받는 피해 중 되돌리는 몫(ob-)
var share := 0.0  ## 이번 격돌 받는 피해 중 기다리는 동료가 나눠 받는 몫(com-)
var share_taken := 1.0  ## 동료가 맡은 몫 중 실제로 받는 비율
var wall := 0  ## 벽(inter-): 남은 wall_rounds 턴 동안 받는 피해 감소
var wall_rounds := 0
var entered := false


func max_hp_now() -> int:
	return base.hp


func heads(m: int = -1) -> int:
	var n := flips.size() if m < 0 else mini(m, flips.size())
	var h := 0
	for i in n:
		if flips[i]:
			h += 1
	return h


func alive() -> bool:
	return hp > 0


## 코인을 던지고 능력치를 정한다(격돌에 처음 나올 때).
func roll(coin_src: CoinSource, formula: StatFormula) -> void:
	flips = coin_src.flip(coins, heads_chance)
	var t := formula.coin_terms(coin_style, coin_value, flips)
	atk = base.atk + t.atk + perm_atk
	def = base.def
	hp = maxi(1, base.hp + t.hp) - pre_damage
	if hold_hp > 0:
		hp = hold_hp
	hold_hp = 0
	pre_damage = 0
	entered = true


## 코인이 바뀌었을 때 공격만 다시 계산한다(체력은 그대로, engine.py와 같다).
func recalc_atk(formula: StatFormula) -> void:
	var t := formula.coin_terms(coin_style, coin_value, flips)
	atk = base.atk + t.atk + perm_atk


func start_clash() -> void:
	reduce = 0
	first_strike = false
	double_first = false
	reflect = 0.0
	share = 0.0
	share_taken = 1.0
	wall = 0
	wall_rounds = 0
