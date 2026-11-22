extends SceneTree
## 화면을 차례로 띄워 PNG로 저장한다(그림이 그려지는 빌드에서만).
## 사용: godot --path . --resolution 1280x720 -s res://tests/visual/capture_screens.gd -- <출력 폴더>

var out_dir := "user://shots"
var main: Main


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 6:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)


func _run() -> void:
	var gd: Node = root.get_node("GameData")
	gd.save_prefix = "user://shots_"
	gd.use_dev_save(false)
	gd.save_store.erase()
	main = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await _shot("01_title")
	main.flow.new_game()
	await _shot("02_name")
	gd.new_game("하늘")
	main.play_scene("s01_intro", func() -> void: pass)
	await _shot("03_dialogue")
	for c in main._overlay.get_children():
		c.queue_free()
	var s: GameState = gd.state
	s.joined = [1, 4] as Array[int]
	var field: Array[WordData] = gd.repo.first_tier(1, "field")
	for i in 40:
		gd.rules.gain_word(s, field[i].id)
	s.pos = Vector2(950, 760)
	main.flow.go_field()
	await _shot("04_field_gate")
	s.pos = Vector2(330, 470)
	main.flow.go_field()
	await _shot("05_town_forge")
	var ids: Array[String] = [field[50].id, field[51].id]
	main.flow.encounter(ids)
	await _shot("06_quiz")
	main.flow.go_battle_prep(ids, false)
	await _shot("07_prep_magic")
	(main.current() as BattlePrepScreen)._step_roots()
	await _shot("08_prep_roots")
	(main.current() as BattlePrepScreen)._start()
	for i in 60:
		await process_frame
	await _shot("09_battle")
	var r: Array = []
	for i in 3:
		r.append(gd.rules.gain_word(s, field[60 + i].id))
	main.show_screen(ResultScreen.new(), {"events": r, "title": "ui.result.won", "done": func() -> void: pass})
	await _shot("10_result")
	var evo: WordData = gd.repo.evolutions_up_to(1, 2)[0]
	for m in evo.mats:
		gd.rules.gain_word(s, m)
	main.show_screen(EvolveScreen.new())
	await _shot("11_evolve")
	main.flow.go_dex()
	await _shot("12_dex")
	(main.current() as DexScreen)._show(gd.repo.get_word(field[0].id))
	await _shot("13_dex_detail")
	main.flow.go_party()
	await _shot("14_party")
	main.flow.go_options(main.flow.go_field)
	await _shot("15_options")
	main.notice(TranslationServer.translate("ui.boss.gate").format({"need": 77, "have": 40}))
	await _shot("16_notice")
	main.flow.go_minigames()
	await _shot("17_minigame_hub")
	var n := 18
	for g in MinigameRegistry.games():
		main.flow.play_minigame(g["id"], "free")
		await _shot("%d_mini_%s" % [n, g["id"]])
		n += 1
	main.flow.go_title()
	await _shot("30_title_modes")
	gd.save_store.erase()
	quit()
