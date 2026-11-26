extends GutTest
## 단어 카드 임시 그림 고르기(src/domain/art/word_picture.gd)

var wp: WordPicture


func before_all() -> void:
	wp = WordPicture.load_default()


func test_meaning_picks_picture() -> void:
	assert_eq(wp.pick("토론장; 포럼", [])["glyph"], "speech")
	assert_eq(wp.pick("개구리", [])["glyph"], "animal")


func test_root_meaning_when_word_meaning_has_none() -> void:
	var etym := [{"root": "ex-", "meaning": "밖으로", "form": "ex"}, {"root": "portare", "meaning": "나르다", "form": "port"}]
	var r := wp.pick("수출하다", etym)
	assert_eq(r["glyph"], "carry", "수출 → 나르기")
	assert_eq(r["mod"], "out", "접두사 ex- → 밖으로 표시")


func test_one_letter_key_needs_word_ending() -> void:
	assert_true(WordPicture.has_key("밀다", "밀"))
	assert_true(WordPicture.has_key("적의 공격", "적"))
	assert_false(WordPicture.has_key("전략적인", "적"), "적인은 적(敵)이 아니다")
	assert_false(WordPicture.has_key("물건", "물"))


func test_unknown_gives_empty() -> void:
	assert_eq(wp.pick("ㅁㄴㅇ", [])["glyph"], "")


func test_most_words_get_a_picture() -> void:
	var ids := GameData.repo.all_ids()
	var got := 0
	for id in ids:
		var w := GameData.repo.get_word(id)
		if wp.pick(w.meaning, w.etym)["glyph"] != "":
			got += 1
	assert_gt(float(got) / ids.size(), 0.6, "6할 넘게 뜻 그림을 받는다")
