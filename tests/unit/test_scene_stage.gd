extends GutTest
## 첫 장면 무대: 대사 줄마다 맞는 컷(conti의 say = 그 컷의 대사 줄 수), 주인공 모습 저장.


func test_shot_for_line_follows_say_counts() -> void:
	var shots := [{"say": 1}, {"say": 3}, {"say": 7}]
	var starts := [0, 1, 4]
	assert_eq(SceneStage.shot_for(starts, shots, 0), 0, "첫 줄(낭독)은 말뿌리 나무")
	assert_eq(SceneStage.shot_for(starts, shots, 3), 1)
	assert_eq(SceneStage.shot_for(starts, shots, 4), 2, "다섯째 줄부터 대장간")
	assert_eq(SceneStage.shot_for(starts, shots, 20), 2, "줄이 더 많으면 마지막 컷")


func test_shot_with_no_lines_is_skipped() -> void:
	var shots := [{"say": 0}, {"say": 2}, {"say": 4}]
	var starts := [0, 0, 2]
	assert_eq(SceneStage.shot_for(starts, shots, 0), 1)
	assert_eq(SceneStage.shot_for(starts, shots, 2), 2)


func test_hero_look_is_saved() -> void:
	var g := GameState.new()
	g.hero_look = "f"
	assert_eq(GameState.from_dict(g.to_dict()).hero_look, "f")
	assert_eq(GameState.from_dict({}).hero_look, "m", "예전 저장은 남자 견습생")
