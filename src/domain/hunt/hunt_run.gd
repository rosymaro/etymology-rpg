class_name HuntRun
extends RefCounted
## 필드 사냥 한 번의 나들이(07-fun.md 1절). 노드·화면을 모른다. 상태는 GameState.hunt(사전)에 두어 저장·화면 전환에도 남는다.
## hunt = {level, exp, units: [데리고 다니는 유닛], weapons: {무기 id: 단계(0부터)}, speed, magnet, sec, eaters, bag: {orbs, coins, words: []}}
## 무기는 데리고 다니는 유닛마다 하나(u01 망치, u05 외침, u10 팽이 …, field_hunt.json weapons).
## 사냥으로 얻은 것은 주머니(bag)에 담기고, 마을에 들어가야(bank) 코인·단어가 내 것이 된다(사용자 의견).
## 사냥 레벨과 구슬은 마을에 가도 그대로다. 퀴즈를 틀려 전투로 들어가면 사냥 레벨과 구슬을 빼앗긴다(lose_orbs).
## 전투에서 지면 주머니의 코인·단어도 모두 잃는다(lose).

var d: Dictionary
var cfg: Dictionary
var traits: FieldTraits  ## 필드 특성(장비 속성). 없으면 특성 없이
var stage := 1  ## 몹 체력 배율을 고르는 스테이지
var rng_bonus := RandomNumberGenerator.new()  ## 특성의 소수 몫을 확률로 올릴 때


func _init(hunt: Dictionary, hunt_cfg: Dictionary) -> void:
	d = hunt
	cfg = hunt_cfg
	if d.is_empty():
		reset()


## 사냥 레벨·강화를 0에서(퀴즈를 틀려 전투로 들어갈 때). 주머니는 그대로.
func reset() -> void:
	var bag: Dictionary = d.get("bag", {"orbs": 0, "coins": 0, "words": []})
	var units: Array = d.get("units", [1])
	d.clear()
	d.merge({"level": 0, "exp": 0, "units": [], "weapons": {}, "speed": 0.0, "magnet": 0.0, "sec": 0.0, "eaters": 0, "bag": bag})
	set_units(units)


## 그 유닛의 무기 id(없으면 "").
func weapon_of(unit: int) -> String:
	for id in cfg["weapons"]:
		if int(cfg["weapons"][id].get("unit", 0)) == unit:
			return String(id)
	return ""


## 동행을 바꾼다(마을 여관에서만, 사용자 의견): 빠진 동행의 무기 단계를 새 동행이 이어받는다.
## 빠진 동행들의 평균(소수점 아래 버림)을 새로 들어온 동행 하나하나에 준다. 그대로 남은 동행은 그대로.
## 빠진 동행 없이 늘기만 하면 새 동행은 0단계. 돌려주는 값: 새 동행 -> 받은 단계.
func swap_units(units: Array) -> Dictionary:
	var old: Array = d.get("units", [])
	var gone: Array = old.filter(func(u: Variant) -> bool: return not int(u) in units.map(func(x: Variant) -> int: return int(x)))
	var came: Array = units.filter(func(u: Variant) -> bool: return not int(u) in old.map(func(x: Variant) -> int: return int(x)))
	var sum := 0
	for u in gone:
		sum += int(d["weapons"].get(weapon_of(int(u)), 0))
	var lv := sum / gone.size() if not gone.is_empty() else 0
	set_units(units)
	var got := {}
	for u in came:
		var id := weapon_of(int(u))
		if id != "":
			d["weapons"][id] = mini(lv, (cfg["weapons"][id]["dmg"] as Array).size() - 1)
			got[int(u)] = int(d["weapons"][id])
	return got


## 데리고 다니는 유닛을 정한다: 그 유닛들의 무기만 남긴다(이미 있던 무기의 강화는 그대로, 새 무기는 0단계).
func set_units(units: Array) -> void:
	var keep := {}
	for u in units:
		var id := weapon_of(int(u))
		if id != "":
			keep[id] = int(d["weapons"].get(id, 0))
	d["units"] = units.map(func(u: Variant) -> int: return int(u))
	d["weapons"] = keep


func level() -> int:
	return int(d["level"])


func need() -> int:
	return Formula.int_value(cfg["level_exp"], {"L": level()})


func bag() -> Dictionary:
	return d["bag"]


func max_level() -> bool:
	return level() >= int(cfg["max_level"])


func coin_cap() -> int:
	return int(round(int(cfg["coin_cap"]) * (1.0 + tv("coin_cap"))))


## 특성 크기(없으면 0)
func tv(id: String) -> float:
	return traits.value(id) if traits else 0.0


func coins_full() -> bool:
	return int(bag()["coins"]) >= coin_cap()


## 지금 들고 있는 무기 가운데 한 방이 가장 센 값.
func best_dmg() -> int:
	var best := 0
	for id in d["weapons"]:
		best = maxi(best, int(weapon(String(id))["dmg"]))
	return best


## 몹 체력: 레벨이 오르면 조금씩 단단해지고, 언제나 가장 센 무기 한 방보다 1 많다(한 방에 죽지 않는다).
func mob_hp(kind: String) -> int:
	var base := int(cfg["mob_hp"].get(kind, 2)) + int(floor(level() * float(cfg["mob_hp_per_level"])))
	var mult: Array = cfg.get("mob_hp_party", [1.0])  # 동행 수에 따라(혼자면 약하게, 셋이면 세게)
	var n := clampi((d["units"] as Array).size(), 1, mult.size())
	base = maxi(1, roundi(base * float(mult[n - 1])))
	if traits:  # 후반 스테이지는 장비가 좋아지는 만큼 단단하게(퀴즈에 들어갈 확률을 비슷하게)
		base = maxi(1, roundi(base * traits.mob_hp_mult(stage)))
	return maxi(base, best_dmg() + 1)


## 필드에 있을 몹 수: 레벨이 오를수록 많아진다.
func mob_count(base: int) -> int:
	return mini(base + level() * int(cfg["spawn_per_level"]), int(cfg["spawn_max"]))


## 몹을 쓰러뜨렸다: 떨어지는 것 {orbs, coins, word}. 주머니에 담는 것은 줍기(pick_*)에서.
## fresh: words 가운데 처음 보는 단어(특성 fresh_word가 그쪽을 고른다).
func drops(kind: String, words: Array, rng: RandomNumberGenerator, fresh: Array = []) -> Dictionary:
	var out := {"orbs": int(cfg["orb"].get(kind, 1)), "coins": 0, "word": ""}
	if rng.randf() < tv("extra_orb"):
		out["orbs"] = int(out["orbs"]) + 1
	if rng.randf() < float(cfg["coin"]["chance"]) and not coins_full():
		var c := rng.randi_range(int(cfg["coin"]["min"]), int(cfg["coin"]["max"]))
		out["coins"] = FieldTraits.roll(c * (1.0 + tv("coin_gain")), rng)
	if not words.is_empty() and rng.randf() < float(cfg["word_chance"]) * (1.0 + tv("word_drop")):
		var pool: Array = fresh if not fresh.is_empty() and rng.randf() < tv("fresh_word") else words
		out["word"] = String(pool[rng.randi_range(0, pool.size() - 1)])
	return out


## 구슬을 주웠다. 레벨이 오르면 true(화면이 보기 3개를 띄운다).
func pick_orbs(n: int) -> bool:
	bag()["orbs"] = int(bag()["orbs"]) + n
	if level() >= int(cfg["max_level"]):
		return false
	var gain := n * (1.0 + tv("orb_exp")) + float(d.get("exp_frac", 0.0))  # 구슬 하나당 경험치(소수 몫은 남겨 둔다)
	d["exp_frac"] = gain - floorf(gain)
	d["exp"] = int(d["exp"]) + int(floorf(gain))
	if int(d["exp"]) >= need():
		d["exp"] = int(d["exp"]) - need()
		d["level"] = level() + 1
		return true
	return false


## 코인을 주웠다(주머니 상한까지만). 이번에 가득 찼으면 true(화면이 마을로 가라고 알린다).
func pick_coins(n: int) -> bool:
	var was := coins_full()
	bag()["coins"] = mini(int(bag()["coins"]) + n, coin_cap())
	return not was and coins_full()


func pick_word(id: String) -> void:
	if id != "":
		(bag()["words"] as Array).append(id)


## 레벨업 보기 3개: 데리고 다니는 유닛의 무기 강화(up), 이동 속도(speed), 구슬 끌기(magnet).
func choices(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for w in d["weapons"]:
		if int(d["weapons"][w]) < (cfg["weapons"][w]["dmg"] as Array).size() - 1:
			pool.append({"type": "up", "id": String(w)})
	pool.append({"type": "speed", "id": ""})
	pool.append({"type": "magnet", "id": ""})
	var out: Array[Dictionary] = []
	while out.size() < 3 and not pool.is_empty():
		out.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return out


func apply(c: Dictionary) -> void:
	match String(c["type"]):
		"up":
			d["weapons"][c["id"]] = int(d["weapons"][c["id"]]) + 1
		"speed":
			d["speed"] = float(d["speed"]) + float(cfg["speed_up"])
		"magnet":
			d["magnet"] = float(d["magnet"]) + float(cfg["magnet_up"])


## 무기의 지금 수치 {unit, type, cd, dmg, count, range, …}: 배열 값은 지금 강화 단계의 값.
func weapon(id: String) -> Dictionary:
	var w: Dictionary = cfg["weapons"][id]
	var lv := mini(int(d["weapons"].get(id, 0)), (w["dmg"] as Array).size() - 1)
	var out := {}
	for k in w:
		var v: Variant = w[k]
		out[k] = v[lv] if v is Array else v
	if traits:  # 필드 특성: 사정거리, 재사용 시간, 멈추게 하는 시간
		out["range"] = float(out["range"]) * (1.0 + tv("range"))
		out["cd"] = float(out["cd"]) * (1.0 - tv("cooldown"))
		if out.has("stun"):
			out["stun"] = float(out["stun"]) * (1.0 + tv("stun"))
	return out


## 지금 무기 모두 {무기 id: 수치}.
func weapons_now() -> Dictionary:
	var out := {}
	for id in d["weapons"]:
		out[id] = weapon(String(id))
	return out


func magnet() -> float:
	return (float(cfg["magnet"]) + float(d["magnet"])) * (1.0 + tv("magnet"))


func speed_mult() -> float:
	return 1.0 + float(d["speed"]) + tv("move")


## 시간이 흐른다. 뿌리먹이가 나올 때가 되면 true(최대 레벨이거나 after_sec, 그 뒤 again_sec마다).
func tick(delta: float) -> bool:
	d["sec"] = float(d["sec"]) + delta
	var e: Dictionary = cfg["eater"]
	var n := int(d["eaters"])
	var due := (float(e["after_sec"]) + n * float(e["again_sec"])) * (1.0 + tv("eater_late"))
	if level() >= int(cfg["max_level"]) and n == 0:
		due = 0.0
	if float(d["sec"]) >= due:
		d["eaters"] = n + 1
		return true
	return false


## 마을에 들어갔다: 코인 → 지갑, 단어 → 도감(주머니에서 비운다). 사냥 레벨과 구슬은 그대로 둔다(사용자 의견).
## 구슬은 지난번 마을 뒤로 새로 모은 만큼만 유닛 경험치가 되고, 무료 뽑기도 새로 오른 레벨만큼만 준다(두 번 받지 않게).
## 돌려주는 값 {orbs: 이번에 경험치가 된 구슬, coins, words: [단어 id], free_pulls}
func bank(state: GameState, rules: ProgressRules) -> Dictionary:
	var b := bag()
	var out := {"orbs": maxi(0, int(b["orbs"]) - int(d.get("orbs_banked", 0))), "coins": int(b["coins"]), "words": (b["words"] as Array).duplicate()}
	# 사용자 의견: 사냥 레벨 5마다 무료 뽑기 1번(코인이 들지 않는다)
	out["free_pulls"] = maxi(0, free_pulls_for(level()) - int(d.get("pulls_given", 0)))
	d["pulls_given"] = int(d.get("pulls_given", 0)) + int(out["free_pulls"])
	state.free_pulls += int(out["free_pulls"])
	var exp := int(out["orbs"]) * int(cfg["bank"]["exp_per_orb"])
	if exp > 0:
		for u in state.joined:
			state.unit_exp[u - 1] += exp
	d["orbs_banked"] = int(b["orbs"])
	state.wallet += int(b["coins"])
	for w in b["words"]:
		rules.gain_word(state, String(w))
	b["coins"] = 0
	b["words"] = []
	return out


## 사냥 레벨 L에서 마을에 들어오면 받는 무료 뽑기 수(field_hunt.json free_pull_every 레벨마다 1번).
func free_pulls_for(lv: int) -> int:
	return lv / maxi(1, int(cfg.get("free_pull_every", 5)))


## 퀴즈를 틀려 전투로 들어간다(사용자 의견): 사냥 레벨과 구슬을 빼앗긴다. 코인과 단어는 그대로.
func lose_orbs() -> void:
	bag()["orbs"] = 0
	reset()


## 전투에서 졌다(사용자 의견): 주머니의 코인·단어도 모두 잃는다(lose_ratio 1.0, 필드 특성 keep_bag만큼은 남는다).
func lose() -> void:
	var keep := 1.0 - float(cfg["bank"]["lose_ratio"]) * (1.0 - tv("keep_bag"))
	var b := bag()
	b["orbs"] = 0
	b["coins"] = int(floor(int(b["coins"]) * keep))
	var ws: Array = b["words"]
	b["words"] = ws.slice(0, int(floor(ws.size() * keep)))
	reset()
