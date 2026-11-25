class_name ComboQuiz
extends RefCounted
## 방어 마법 퀴즈: 조합 뜻 고르기(01-rpg-base '방어 마법 퀴즈'). 접두사 + 아군 장착 어근으로 만들어지는 실제 단어의 뜻을 고른다.
## 보기 5개 = 정답 N개(조합 단어 뜻) + 임의 단어 뜻(5 − N). 고른 뜻은 되돌릴 수 없고, 틀리면 그 자리에서 실패.

const OPTIONS := 5

var answers: Array[String] = []  ## 정답 단어 id
var options: Array[Dictionary] = []  ## {word, meaning, right}
var picked: Array[String] = []
var failed := false


## 그 어근과 접두사로 만들어진 실제 단어 중 가장 흔한 것(없으면 "").
static func combo_word(repo: WordRepository, prefix: String, root: String) -> String:
	var best := ""
	var best_f := -1
	for id in repo.all_ids():
		var w := repo.get_word(id)
		if w == null or not root in w.skill_roots:
			continue
		var has_prefix := false
		for e in w.etym:
			if String(e.get("root", "")) == prefix:
				has_prefix = true
				break
		if has_prefix and w.freq > best_f:
			best = id
			best_f = w.freq
	return best


static func possible(repo: WordRepository, prefix: String, roots: Array) -> bool:
	for r in roots:
		if String(r) != "" and combo_word(repo, prefix, String(r)) != "":
			return true
	return false


## roots: 아군 장착 어근들. 조합 단어가 하나도 없으면 null(그 마법은 이번 전투에 못 고른다).
static func make(repo: WordRepository, prefix: String, roots: Array, rng: RandomNumberGenerator) -> ComboQuiz:
	var q := ComboQuiz.new()
	for r in roots:
		if String(r) == "":
			continue
		var w := combo_word(repo, prefix, String(r))
		if w != "" and not w in q.answers:
			q.answers.append(w)
	if q.answers.is_empty():
		return null
	q.answers = q.answers.slice(0, OPTIONS - 1)
	for id in q.answers:
		q.options.append({"word": id, "meaning": repo.get_word(id).meaning, "right": true})
	var all := repo.all_ids()
	var guard := 0
	while q.options.size() < OPTIONS and guard < 500:
		guard += 1
		var id: String = all[rng.randi_range(0, all.size() - 1)]
		var w := repo.get_word(id)
		if w == null or id in q.answers or w.meaning == "" or q.options.any(func(o: Dictionary) -> bool: return o["meaning"] == w.meaning):
			continue
		q.options.append({"word": id, "meaning": w.meaning, "right": false})
	for i in range(q.options.size() - 1, 0, -1):  # 섞기
		var k := rng.randi_range(0, i)
		var tmp: Dictionary = q.options[i]
		q.options[i] = q.options[k]
		q.options[k] = tmp
	return q


## 보기 하나를 고른다. 돌려주는 값: "right" | "wrong" | "done"(정답을 모두 골랐다) | ""(이미 끝남·이미 고름)
func pick(i: int) -> String:
	if failed or all_found() or i < 0 or i >= options.size():
		return ""
	var o: Dictionary = options[i]
	if o["word"] in picked:
		return ""
	picked.append(o["word"])
	if not o["right"]:
		failed = true
		return "wrong"
	return "done" if all_found() else "right"


func all_found() -> bool:
	for a in answers:
		if not a in picked:
			return false
	return true
