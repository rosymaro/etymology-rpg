extends GutTest
## 말 공방 미니게임 1~10 규칙(05-minigames).

var bal: Dictionary


func before_all() -> void:
	bal = JsonFile.read("res://data/balance/minigames.json")


## 서로 다른 어원 형태를 가진 단어 n개(앞 어원 + 뒤 어원). extra개는 칠판에 안 쓰이는 함정용 단어.
func _words(n: int) -> Array[WordData]:
	var out: Array[WordData] = []
	var pre := ["ab", "con", "ex", "pre", "sub", "trans", "per", "pro", "ob", "dis", "re", "in", "de", "inter",
		"mis", "un", "post", "anti", "bene", "mal", "circum", "intro", "retro", "super", "contra"]
	var stem := ["duc", "struct", "port", "dict", "ject", "mit", "spect", "tract", "vert", "scrib", "fer", "pel",
		"rupt", "cept", "pend", "pos", "voc", "grad", "sist", "vid", "fact", "form", "pli", "tend", "sequ"]
	for i in n:
		var id: String = pre[i % pre.size()] + stem[i % stem.size()] + "x".repeat(i / 25)
		out.append(WordData.from_dict({"id": id, "meaning": "뜻%d" % i, "tier": 1,
			"etym": [{"root": pre[i % pre.size()] + "-", "form": pre[i % pre.size()]}, {"root": stem[i % stem.size()], "form": stem[i % stem.size()]}]}))
	return out


func _make(id: String, n: int = 24, seed: int = 3) -> FactoryGame:
	var g := FactoryGame.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	g.setup(_words(n), FactoryGame.config(bal, id), 5, rng)
	return g


## 벨트에서 그 형태의 어원을 찾아(없으면 올려서) 어원 조합 쪽으로 옮긴다.
func _grab(g: FactoryGame, form: String) -> int:
	for it in g.belt:
		if it["form"] == form:
			it["t"] = 0.8
			return it["uid"]
	var it := g._put_on_belt(form, 0.8, false)
	return it["uid"]


func _forge(g: FactoryGame, i: int) -> int:
	for f in g.board[i]["forms"]:
		assert_eq(g.put(_grab(g, f)), "in")
	return g.hammer()


func test_config_merges_common_and_game_values() -> void:
	var c := FactoryGame.config(bal, "f08")
	assert_eq(int(c["board"]), 14)
	assert_eq(int(c["absorb"]), 7)
	assert_eq(int(c["max_miss"]), 3, "공통 값")
	assert_eq(int(FactoryGame.config(bal, "f09")["board"]), 20)
	assert_true(bool(FactoryGame.config(bal, "f10")["search_reverse"]))
	assert_false(bool(FactoryGame.config(bal, "f09")["search_reverse"]))


func test_board_lines_show_modern_roots() -> void:
	var g := _make("f01")
	assert_eq(g.board.size(), 10)
	assert_eq(g.max_words, 10, "칠판 단어를 모두 확보하면 성공")
	assert_eq(g.board_line(0), "ab + duc = abduc → 뜻0")


func test_word_forms_come_from_data_or_root() -> void:
	var w := WordData.from_dict({"id": "abduct", "etym": [{"root": "ab-", "form": "ab"}, {"root": "ducere", "form": "duc"}]})
	assert_eq(w.forms(), ["ab", "duc"] as Array[String])
	var w2 := WordData.from_dict({"id": "x", "etym": [{"root": "ex-"}]})
	assert_eq(w2.forms(), ["ex"] as Array[String], "형태가 없으면 어근에서 '-'를 뗀다")


func test_real_data_has_forms_for_stage_words() -> void:
	var repo := WordRepository.load_default()
	var w := repo.get_word("abduct")
	if w:
		assert_eq(w.forms(), ["ab", "duc"] as Array[String])
	var with_forms := 0
	for x in repo.first_tier(1):
		with_forms += 1 if not x.forms().is_empty() else 0
	assert_gt(with_forms, 20, "스테이지 1 단어로 칠판 20개를 채울 수 있다")


# ----- 1: 어원 조합 -----

func test_f01_belt_fills_with_board_roots_and_traps() -> void:
	var g := _make("f01")
	for k in 600:
		g.update(0.1)
	assert_gt(g.belt.size(), 6, "벨트가 찬다")
	assert_lte(g.belt.size(), int(g.cfg["belt_cap"]))
	var traps := 0
	var forms := {}
	for b in g.board:
		for f in b["forms"]:
			forms[f] = true
	for it in g.belt:
		if it["trap"]:
			traps += 1
			assert_false(forms.has(it["form"]), "함정은 칠판 어원이 아니다")
		else:
			assert_true(forms.has(it["form"]))
	assert_gt(traps, 0, "함정 어원도 곳곳에")
	# 어원끼리 겹치지 않는다
	for a in g.belt:
		for b in g.belt:
			if a != b:
				var d := absf(float(a["t"]) - float(b["t"]))
				assert_gt(minf(d, 1.0 - d), float(g.cfg["min_gap"]) * 0.9)


func test_f01_hammer_right_roots_in_any_order_makes_word() -> void:
	var g := _make("f01")
	var forms: Array = g.board[2]["forms"].duplicate()
	forms.reverse()  # 순서는 상관없다
	for f in forms:
		g.put(_grab(g, f))
	assert_eq(g.hammer(), 2)
	assert_eq(g.earned, [g.board[2]["id"]] as Array[String], "만들면 바로 확보")
	assert_eq(g.misses, 0)


func test_f01_wrong_mix_burns_and_three_misses_end() -> void:
	var g := _make("f01")
	for k in 3:
		g.put(_grab(g, g.board[0]["forms"][0]))
		g.put(_grab(g, g.board[1]["forms"][1]))
		assert_eq(g.hammer(), -1)
		assert_true(g.furnace.is_empty(), "넣은 어원은 탄다")
	assert_eq(g.misses, 3)
	assert_true(g.finished, "3번 틀리면 끝")
	assert_false(g.success())


func test_f01_all_board_words_is_success() -> void:
	var g := _make("f01")
	for i in g.board.size():
		_forge(g, i)
	assert_true(g.finished)
	assert_true(g.success())
	assert_eq(g.earned.size(), 10)


func test_f01_only_combine_side_can_be_grabbed_when_anagram_exists() -> void:
	var g := _make("f05")
	var it := g._put_on_belt(g.board[0]["forms"][0], 0.2, false)
	assert_eq(g.section(it), FactoryGame.ANAGRAM)
	assert_eq(g.put(it["uid"]), "none", "에너그램 쪽 어원은 집을 수 없다")
	it["t"] = 0.7
	assert_eq(g.put(it["uid"]), "in")


# ----- 2: 에너그램 -----

func test_f02_anagram_roots_cross_belt_to_earn_word() -> void:
	var g := _make("f02")
	assert_false(g.puzzle.is_empty())
	var first: String = g.puzzle["form"]
	assert_eq(first, g.board[0]["forms"][0], "칠판 순서대로, 함정 없이")
	assert_ne("".join(g.puzzle["letters"]), first, "글자는 섞여 있다")
	var sorted_a: Array = g.puzzle["letters"].duplicate()
	sorted_a.sort()
	var sorted_b: Array = []
	for ch in first:
		sorted_b.append(ch)
	sorted_b.sort()
	assert_eq(sorted_a, sorted_b, "같은 글자들")
	assert_eq(g.submit(first), "ok")
	assert_eq(g.submit(g.puzzle["form"]), "ok")
	for k in 400:
		g.update(0.1)
	assert_true(g.board[0]["id"] in g.earned, "두 어원이 벨트 너머로 사라지면 확보")


func test_f02_wrong_spelling_is_a_miss_only_in_game_two() -> void:
	var g := _make("f02")
	assert_eq(g.submit("zzz"), "wrong")
	assert_eq(g.misses, 1)
	var g5 := _make("f05")
	assert_eq(g5.submit("zzz"), "wrong")
	assert_eq(g5.misses, 0, "5번부터는 틀림이 아니다")


func test_f05_traps_skip_and_trash() -> void:
	var g := _make("f05")
	var saw_trap := false
	for k in 40:
		if g.puzzle.get("trap", false):
			saw_trap = true
		g.skip()
	assert_true(saw_trap, "5번부터 함정 어원도 나온다")
	# 함정을 만들어도 틀림이 아니다
	for k in 40:
		if g.puzzle.get("trap", false):
			break
		g.skip()
	assert_eq(g.submit(g.puzzle["form"]), "ok")
	assert_eq(g.misses, 0)
	g.update(0.05)
	assert_eq(g.belt.size(), 1, "벨트에 올라간다")
	var uid: int = g.belt[0]["uid"]
	assert_true(g.trash(uid), "에너그램 쪽에서 버린다")
	assert_true(g.belt.is_empty())


func test_f05_belt_only_has_anagram_roots() -> void:
	var g := _make("f05")
	for k in 300:
		g.update(0.1)
	assert_true(g.belt.is_empty(), "에너그램에서 올린 어원만 벨트에 있다")


func test_f05_forge_from_anagram_roots() -> void:
	var g := _make("f05")
	var target := g.board[0]
	for f in target["forms"]:
		for k in 60:
			if g.puzzle["form"] == f:
				break
			g.skip()
		assert_eq(g.submit(f), "ok")
		for k in 20:
			g.update(0.1)
	for it in g.belt.duplicate():
		it["t"] = 0.8
		g.put(it["uid"])
	assert_eq(g.hammer(), 0)
	assert_true(target["id"] in g.earned)


# ----- 3: 단어 뜻 -----

func test_f03_stacked_words_go_to_matching_shelf() -> void:
	var g := _make("f03")
	assert_eq(g.stack.size(), 10, "칠판 단어가 쌓여 있다")
	assert_eq(g.slots.size(), 5)
	var k := 0
	var i: int = g.slots[0]
	assert_true(i in g.stack)
	# 틀린 칸
	var wrong := 1 if g.slots[1] != i else 2
	assert_false(g.place(i, wrong))
	assert_eq(g.misses, 1)
	assert_true(g.place(i, k))
	assert_true(g.board[i]["id"] in g.earned)
	assert_ne(g.slots[0], i, "맞힌 칸은 다음 뜻으로 바뀐다")
	assert_true(g.slots[0] >= 0)


func test_f03_all_shelved_is_success() -> void:
	var g := _make("f03")
	for n in 20:
		if g.finished:
			break
		var k := 0
		while k < g.slots.size() and g.slots[k] < 0:
			k += 1
		g.place(g.slots[k], k)
	assert_true(g.success())


func test_f06_forged_word_goes_to_stack_then_shelf() -> void:
	var g := _make("f06")
	var forms: Array = g.board[3]["forms"]
	for f in forms:
		g.put(_grab(g, f))
	assert_eq(g.hammer(), 3)
	assert_true(g.earned.is_empty(), "진열해야 확보")
	assert_true(3 in g.stack)
	assert_true(3 in g.slots, "쌓인 단어의 뜻은 진열대에 있다")
	assert_true(g.place(3, g.slots.find(3)))
	assert_true(g.board[3]["id"] in g.earned)


# ----- 4, 7~10: 흡수와 단어찾기 -----

func test_f04_roots_auto_absorb_then_hot_then_search() -> void:
	var g := _make("f04")
	for k in 3000:
		g.update(0.1)
		if g.hot:
			break
	assert_true(g.hot, "단어 5개 몫을 흡수하면 달아오른다")
	assert_eq(g.absorb_shown(), Vector2i(5, 5))
	assert_true(g.open_search())
	var ids := g.search.ids()
	assert_eq(ids.size(), 5)
	assert_almost_eq(g.search_left, 75.0, 0.01, "단어 하나에 15초")
	# 찾기
	var cells := g.search.cells_of(ids[0])
	var hit := g.search_select(cells[0], cells[-1])
	assert_true(hit >= 0)
	assert_true(g.board[hit]["id"] in g.earned)


func test_f04_search_timeout_returns_roots() -> void:
	var g := _make("f04")
	for k in 3000:
		g.update(0.1)
		if g.hot:
			break
	g.open_search()
	var ids := g.search.ids()
	var cells := g.search.cells_of(ids[0])
	g.search_select(cells[0], cells[-1])
	g.update(80.0)  # 시간이 다 됐다
	assert_null(g.search, "단어찾기가 닫힌다")
	assert_false(g.hot)
	assert_eq(g.earned.size(), 1, "찾은 것만 확보")
	assert_eq(g.todo_count(), 9, "못 찾은 단어는 다시 만들어야 한다")
	assert_eq(g.misses, 0, "시간이 다 돼도 틀림은 아니다")


func test_f07_manual_absorb_rejects_useless_root() -> void:
	var g := _make("f07")
	var it := g._put_on_belt("zzz", 0.8, true)
	assert_eq(g.put(it["uid"]), "miss", "필요 없는 어원을 넣으면 1번 틀림")
	assert_eq(g.misses, 1)
	for i in 5:
		for f in g.board[i]["forms"]:
			assert_eq(g.put(_grab(g, f)), "absorbed")
	assert_true(g.hot)
	assert_eq(g.put(_grab(g, g.board[6]["forms"][0])), "hot", "달아오르면 먼저 단어찾기")
	g.open_search()
	for id in g.search.ids():
		var c := g.search.cells_of(id)
		g.search_select(c[-1], c[0])  # 끝에서 처음으로 끌어도 된다
	assert_null(g.search, "다 찾으면 닫힌다")
	assert_eq(g.stack.size(), 5, "찾은 단어는 진열대 앞에 쌓인다")
	assert_true(g.earned.is_empty())


func test_f07_timeout_puts_roots_back_on_belt_from_anagram_games() -> void:
	var g := _make("f07")
	for i in 5:
		for f in g.board[i]["forms"]:
			g.put(_grab(g, f))
	g.open_search()
	g.update(100.0)
	assert_eq(g.outbox.size(), 10, "못 찾은 단어 어원이 벨트로 돌아온다")


func test_f08_to_f10_board_and_batch_sizes() -> void:
	var g8 := _make("f08", 30)
	assert_eq(g8.board.size(), 14)
	assert_eq(g8.absorb_shown(), Vector2i(0, 7))
	var g9 := _make("f09", 30)
	assert_eq(g9.board.size(), 20)
	assert_eq(g9.absorb_shown(), Vector2i(0, 10))
	var g10 := _make("f10", 30)
	for i in 10:
		for f in g10.board[i]["forms"]:
			g10.put(_grab(g10, f))
	assert_true(g10.hot)
	g10.open_search()
	assert_true(g10.search.reverse, "10번은 거꾸로 방향도")


func test_last_batch_is_smaller_when_few_words_left() -> void:
	var g := _make("f07")
	for i in 5:
		for f in g.board[i]["forms"]:
			g.put(_grab(g, f))
	g.open_search()
	for id in g.search.ids():
		var c := g.search.cells_of(id)
		g.search_select(c[0], c[-1])
	# 남은 5개 중 4개는 진열로 넘기고(상태만), 남은 단어 수보다 크게 기다리지 않는다
	for i in range(5, 9):
		g.board[i]["state"] = FactoryGame.DONE
	assert_eq(g.absorb_shown(), Vector2i(0, 1))
	for f in g.board[9]["forms"]:
		g.put(_grab(g, f))
	assert_true(g.hot, "남은 단어가 1개면 1개로 달아오른다")


# ----- 글자판 -----

func test_letter_grid_forward_only_by_default() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var ids: Array[String] = ["abduct", "construct", "export", "predict", "subject", "transmit", "perspect", "protract", "obvert", "describe"]
	var g := LetterGrid.make(ids, 8, 13, false, rng)
	assert_eq(g.placed.size(), 10, "다 들어간다")
	for p in g.placed:
		assert_true(p["dir"] in LetterGrid.FORWARD, "→ ↓ ↘만")
		var c := g.cells_of(p["id"])
		assert_eq(g.read(c[0], c[-1]), p["id"])
	var r := LetterGrid.make(ids, 8, 13, true, rng)
	var back := 0
	for k in 20:
		r = LetterGrid.make(ids, 8, 13, true, rng)
		for p in r.placed:
			back += 1 if not p["dir"] in LetterGrid.FORWARD else 0
	assert_gt(back, 0, "거꾸로도 숨긴다")


func test_real_stage_words_fill_twenty_board_and_can_be_won() -> void:
	var repo := WordRepository.load_default()
	var pool: Array[WordData] = []
	for w in repo.first_tier(1):
		pool.append(w)
	var g := FactoryGame.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	g.setup(pool, FactoryGame.config(bal, "f09"), 5, rng)
	assert_eq(g.board.size(), 20, "스테이지 1 단어로 칠판 20개")
	assert_false(g.traps.is_empty())
	for i in g.board.size():
		for f in g.board[i]["forms"]:
			assert_true(f.length() > 0)
	# 1번 규칙으로 모두 만들 수 있다(같은 어원 조합 단어가 겹쳐도 하나씩)
	var g1 := FactoryGame.new()
	g1.setup(pool, FactoryGame.config(bal, "f01"), 5, rng)
	for i in g1.board.size():
		if g1.board[i]["state"] != FactoryGame.TODO:
			continue
		for f in g1.board[i]["forms"]:
			g1.put(_grab(g1, f))
		assert_true(g1.hammer() >= 0)
	assert_true(g1.success())
