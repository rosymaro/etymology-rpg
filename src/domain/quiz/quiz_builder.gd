class_name QuizBuilder
extends RefCounted
## 뜻 고르기 4지선다(01-rpg-base '조우: 뜻 맞히기'). 오답 보기도 실제 단어의 뜻이다(없는 단어를 만들지 않는다).

var repo: WordRepository
var rng: RandomNumberGenerator
var choices := 4


func _init(words: WordRepository, random: RandomNumberGenerator = null) -> void:
	repo = words
	rng = random if random else RandomNumberGenerator.new()


func build(word_ids: Array[String]) -> Array[QuizQuestion]:
	var out: Array[QuizQuestion] = []
	for id in word_ids:
		out.append(question(id))
	return out


func question(id: String) -> QuizQuestion:
	var q := QuizQuestion.new()
	q.word_id = id
	var right := repo.get_word(id).meaning
	var opts: Array[String] = [right]
	var ids := repo.all_ids()
	var guard := 0
	while opts.size() < choices and guard < 200:
		guard += 1
		var m := repo.get_word(ids[rng.randi_range(0, ids.size() - 1)]).meaning
		if m != "" and not m in opts:
			opts.append(m)
	# 섞기
	for i in range(opts.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := opts[i]
		opts[i] = opts[j]
		opts[j] = t
	q.options = opts
	q.answer = opts.find(right)
	return q
