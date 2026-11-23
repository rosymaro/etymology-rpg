extends GutTest
## 7 물레방아(해자 지키기, 물레방아 디펜스): 물길 나누기, 사정거리, 100마리 보상, 난이도.

var cfg: Dictionary


func before_all() -> void:
	cfg = JsonFile.read("res://data/balance/minigames.json")["wheel"]


func _make(sd: int = 3) -> MoatGame:
	var g := MoatGame.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var ws: Array[WordData] = []
	for i in 8:
		ws.append(WordData.from_dict({"id": "w%d" % i, "meaning": "뜻%d" % i, "attrs": [1], "tier": 1, "etym": []}))
	g.setup(ws, cfg, 5, rng)
	return g


## 가장 성에 가까운 적 쪽 물길만 연다(잘하는 플레이어).
func _smart(g: MoatGame) -> void:
	var best := -1.0
	var lane := 1
	for e in g.enemies:
		if e["pos"].y > best:
			best = e["pos"].y
			var d := 9.0
			for i in 3:
				if absf(MoatGame.WHEEL_X[i] - e["pos"].x) < d:
					d = absf(MoatGame.WHEEL_X[i] - e["pos"].x)
					lane = i
	for i in 3:
		g.gates[i] = i == lane


func test_water_is_shared_between_open_gates() -> void:
	var g := _make()
	g.gates = [true, false, false] as Array[bool]
	var one := g.fire_rate(0)
	g.gates = [true, true, true] as Array[bool]
	assert_almost_eq(g.fire_rate(0), one / 3.0, 0.001, "셋을 열면 하나일 때의 1/3씩")
	g.toggle(1)
	assert_false(g.gates[1])
	assert_eq(g.fire_rate(1), 0.0, "닫힌 물레방아는 쏘지 않는다")


func test_wheel_only_shoots_in_range() -> void:
	var g := _make()
	g.gates = [true, false, false] as Array[bool]
	g._spawn = 999.0
	g.spawn_enemy(0.9)  # 왼쪽 물레방아 사정거리 밖
	g.enemies[0]["pos"].y = MoatGame.WHEEL_Y - 0.05
	g.enemies[0]["speed"] = 0.0
	g.update(1.0)
	assert_eq(g.arrows.size(), 0, "사정거리 밖은 쏘지 않는다")
	g.spawn_enemy(0.2)
	g.enemies[1]["pos"].y = MoatGame.WHEEL_Y - 0.15
	g.enemies[1]["speed"] = 0.0
	for _s in 60:
		g.update(0.05)
	assert_eq(g.kills, 1, "사정거리 안의 적을 잡는다")


func test_good_gate_play_reaches_goal_and_gets_all_words() -> void:
	var g := _make()
	var t := 0.0
	while not g.finished:
		if fmod(t, 0.5) < 0.02:
			_smart(g)
		g.update(0.02)
		t += 0.02
	assert_gte(g.kills, int(cfg["goal"]), "물길을 잘 바꾸면 100마리를 잡는다")
	assert_eq(g.score(), 5, "다 잡으면 단어를 모두")


func test_one_gate_only_falls_short_and_gets_half() -> void:
	var g := _make()
	while not g.finished:
		g.gates = [false, true, false] as Array[bool]
		g.update(0.05)
	assert_lt(g.kills, int(cfg["goal"]), "물길 하나만 열어 두면 다 못 잡는다")
	assert_eq(g.score(), 2, "못 잡으면 절반")


func test_enemies_get_faster_and_tougher_over_time() -> void:
	var g := _make()
	g.spawn_enemy(0.5)
	var early: float = g.enemies[-1]["speed"]
	g.elapsed = float(cfg["duration"]) * 0.95
	var tough := 0
	var fast := 0.0
	for k in 20:
		g.spawn_enemy(0.5)
		tough += int(g.enemies[-1]["max"] >= 2)
		fast += g.enemies[-1]["speed"] / 20.0
	assert_gt(fast, early, "뒤로 갈수록 빠르다")
	assert_gt(tough, 0, "뒤로 갈수록 튼튼한 적이 섞인다")
