extends GutTest
## 어원으로 뜻 유추하기(06-learning.md): 커리큘럼, 조각 나누기, 유추 문제의 사다리.

var cur: Curriculum
var quiz: InferenceQuiz


func before_each() -> void:
	cur = Curriculum.load_default()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	quiz = InferenceQuiz.new(GameData.repo, cur, GameData.learning, rng)


func test_each_stage_teaches_three_to_five_pieces() -> void:
	for st in range(1, 11):
		var n: int = cur.stages[st].size()
		assert_between(n, 3, 5, "스테이지 %d" % st)
	assert_true(cur.learned(1).has("facere"), "스테이지 1은 fac")
	assert_false(cur.learned(1).has("capere"), "capere는 스테이지 2")
	assert_true(cur.learned(2).has("facere"), "앞 스테이지 조각도 배운 것")


func test_split_finds_pieces_in_the_word() -> void:
	var w := GameData.repo.get_word("information")
	var parts := PieceSplit.split(w.id, w.etym)
	var text := ""
	for p in parts:
		text += p["text"]
	assert_eq(text, "information", "이어 붙이면 단어")
	var ids := parts.map(func(p: Dictionary) -> String: return p["piece"]).filter(func(x: String) -> bool: return x != "")
	assert_eq(ids, ["in-", "forma"])
	assert_eq(PieceSplit.piece_at(parts, 0), "in-")
	assert_eq(PieceSplit.piece_at(parts, 3), "forma")


func test_step_a_shows_pieces_and_meanings_before_stage5_boss() -> void:
	var q := quiz.question("information", 1)
	assert_eq(q.kind, "infer")
	assert_eq(q.step, "A")
	assert_true(q.show_split)
	for p in q.parts:
		if p["piece"] != "":
			assert_true(p["shown"], "A: 조각 뜻을 다 보여 준다")
	assert_string_contains(q.explain("알림"), "in(안에)")
	var q2 := quiz.question("receipt", 4, {"boss_s04": true})
	assert_eq(q2.step, "A", "스테이지 5 보스 전까지 A")


func test_step_a_splits_words_without_learned_pieces_too() -> void:
	var q := quiz.question("supply", 2)  # sub-는 스테이지 4 조각: 안 배웠어도 나눠서 뜻을 보인다
	assert_true(q.show_split)
	for p in q.parts:
		if p["piece"] != "":
			assert_true(p["shown"])


func test_step_b_hides_all_meanings_before_stage8_boss() -> void:
	var q := quiz.question("receipt", 6, {"boss_s05": true})
	assert_eq(q.step, "B")
	assert_true(q.show_split, "B: 조각은 나눠 준다")
	for p in q.parts:
		assert_false(p["shown"], "B: 조각 뜻은 ?")
	var q2 := quiz.question("receipt", 8, {"boss_s05": true, "boss_s07": true})
	assert_eq(q2.step, "B", "스테이지 8 보스 전까지 B")


func test_step_c_shows_only_the_word_after_stage8_boss() -> void:
	var q := quiz.question("effect", 9, {"boss_s05": true, "boss_s08": true})
	assert_eq(q.step, "C")
	assert_false(q.show_split, "C: 영어 단어만")


func test_step_bonus_raises_one_step() -> void:
	assert_eq(quiz.question("effect", 1, {}, 1).step, "B")
	assert_eq(quiz.question("effect", 6, {"boss_s05": true}, 1).step, "C")
	assert_eq(quiz.question("effect", 9, {"boss_s05": true, "boss_s08": true}, 1).step, "C")


func test_words_without_learned_pieces_are_plain_meaning_questions() -> void:
	var w: WordData = GameData.repo.first_tier(1, "field").filter(func(x: WordData) -> bool: return not cur.has_learned(x, 1))[0]
	var q := quiz.question(w.id, 1)
	assert_eq(q.kind, "meaning")
	assert_eq(q.options.size(), 4)
	assert_true(q.answer >= 0)


func test_record_counts_right_answers_per_piece() -> void:
	var pieces := {}
	var q := quiz.question("information", 1)
	InferenceQuiz.record(pieces, q, true)
	InferenceQuiz.record(pieces, q, false)
	assert_eq(pieces["forma"], {"seen": 2, "right": 1})
	assert_eq(InferenceQuiz.familiar_of(pieces)["in-"], 1)
	var s := GameState.new()
	s.pieces = pieces
	assert_eq(GameState.from_dict(s.to_dict()).pieces["forma"]["right"], 1, "저장된다")


## 사용자 의견: 철자에 어원 모양이 그대로 없어도 자른다(presentation = pre + sent + ation), 설명은 '변형'으로
func test_presentation_splits_into_pre_sent_ation() -> void:
	var w := GameData.repo.get_word("presentation")
	var parts := PieceSplit.split(w.id, w.etym)
	var texts: Array = parts.map(func(p: Dictionary) -> String: return p["text"])
	assert_eq(texts, ["pre", "sent", "ation"])
	var notes := GameText.etym_notes(parts, w.etym)
	assert_string_contains(notes, "pre ← prae-")
	assert_string_contains(notes, "sent ← esse (futurus)")


func test_every_word_cuts_every_piece_it_still_has() -> void:
	var cut := 0
	for id in GameData.repo.all_ids():
		var w := GameData.repo.get_word(id)
		var parts := PieceSplit.split(w.id, w.etym)
		var joined := ""
		var pieces := 0
		for p in parts:
			joined += String(p["text"])
			if String(p["piece"]) != "":
				pieces += 1
		assert_eq(joined, w.id, "이어 붙이면 단어: " + w.id)
		var want := 0
		for e in w.etym:
			if String(e.get("form", "")) != "" and not bool(e.get("lost", false)):
				want += 1
		if pieces != want:
			fail_test("조각이 빠졌다: %s %d/%d" % [w.id, pieces, want])
			return
		cut += pieces
	assert_gt(cut, 12000)
