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


func test_step_a_shows_everything_on_stage1() -> void:
	var q := quiz.question("information", 1)
	assert_eq(q.kind, "infer")
	assert_eq(q.step, "A")
	assert_true(q.show_split)
	for p in q.parts:
		if p["piece"] != "":
			assert_true(p["shown"], "A: 조각 뜻을 다 보여 준다")
	assert_string_contains(q.explain("알림"), "in(안에)")


func test_step_b_hides_learned_pieces_but_helps_with_new_ones() -> void:
	var q := quiz.question("receipt", 2)  # re-(배움) + capere(배움)
	assert_eq(q.step, "B")
	assert_true(q.show_split)
	for p in q.parts:
		if p["learned"]:
			assert_false(p["shown"], "B: 배운 조각 뜻은 스스로 떠올린다")
	var w := GameData.repo.get_word("supply")  # sub-는 스테이지 4: 스테이지 2에선 안 배운 조각
	var q2 := quiz.question(w.id, 2)
	for p in q2.parts:
		if p["piece"] != "" and not p["learned"]:
			assert_true(p["shown"], "안 배운 조각은 뜻을 보여 준다")


func test_step_c_does_not_split_and_familiar_pieces_hide_early() -> void:
	var q := quiz.question("effect", 4)
	assert_eq(q.step, "C")
	assert_false(q.show_split, "C: 나누지 않는다(조각을 스스로 찾는다)")
	var fam := {"in-": 3, "forma": 3}
	var q1 := quiz.question("information", 1, fam)
	for p in q1.parts:
		if p["learned"]:
			assert_false(p["shown"], "잘 아는 조각은 A에서도 숨긴다")


func test_words_without_learned_pieces_are_plain_meaning_questions() -> void:
	var w: WordData = GameData.repo.first_tier(1, "field").filter(func(x: WordData) -> bool: return not cur.has_learned(x, 1))[0]
	var q := quiz.question(w.id, 1)
	assert_eq(q.kind, "meaning")
	assert_false(q.show_split)
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
