extends GutTest
## 다른 앱을 보다 돌아와 앱이 다시 켜져도 하던 곳에서 이어 한다.


func before_each() -> void:
	GameData.resume_enabled = true
	GameData.resume_path = "user://test_resume.cfg"
	GameData.save_prefix = "user://test_resume_"


func after_each() -> void:
	GameData.set_resume("")
	GameData.resume_enabled = false
	GameData.resume_path = "user://resume.cfg"
	GameData.use_dev_save(false)
	GameData.save_store.erase()
	GameData.save_prefix = "user://"
	GameData.use_dev_save(false)


func _boot() -> Main:
	var main: Main = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_physics_frames(2)
	return main


func test_story_resumes_into_field_after_restart() -> void:
	var m := await _boot()
	assert_true(m.current() is TitleScreen, "처음에는 타이틀")
	m.flow.dev_game()
	await wait_physics_frames(2)
	assert_true(m.current() is FieldScreen)
	# 앱이 멈췄다가(다른 앱) 안드로이드가 닫고 다시 켠 것처럼
	m._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	m.queue_free()
	await wait_physics_frames(2)
	var m2 := await _boot()
	assert_true(m2.current() is FieldScreen, "다시 켜면 필드에서 이어 한다")
	assert_true(GameData.state.dev_mode, "개발자 모드 저장으로 이어 한다")


func test_back_to_title_clears_resume() -> void:
	var m := await _boot()
	m.flow.go_minigames()
	await wait_physics_frames(2)
	assert_eq(GameData.resume_mode(), "mini")
	m.flow.go_title()
	assert_eq(GameData.resume_mode(), "", "타이틀로 돌아가면 이어 하기를 지운다")
