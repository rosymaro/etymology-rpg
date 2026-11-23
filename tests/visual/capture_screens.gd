extends Node
## 화면을 차례로 띄워 PNG로 저장한다(그림이 그려지는 빌드에서만). Main이 --capture=<폴더> 인자를 보면 이 노드를 붙인다.
## 사용: godot --path . --resolution 1280x720 -- --capture=/절대/경로

var out_dir := "user://shots"
var main: Main
var root: Window


func start(m: Main, dir: String) -> void:
	main = m
	out_dir = dir
	root = get_tree().root
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " ", Time.get_ticks_msec())


func _run() -> void:
	var gd: Node = root.get_node("GameData")
	gd.save_prefix = "user://shots_"
	gd.use_dev_save(false)
	gd.save_store.erase()
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
		await get_tree().process_frame
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
	for c in main._overlay.get_children():
		c.queue_free()
	main.flow.go_minigames()
	await _shot("17_minigame_hub")
	var n := 18
	for g in MinigameRegistry.games():
		main.flow.play_minigame(g["id"], "free")
		await _shot("%d_mini_%s" % [n, g["id"]])
		if g["id"] == "search":
			await get_tree().create_timer(23.0).timeout
			await _shot("%d_mini_search_faded" % n)
			var sv := main.current() as SearchView
			sv._etym_on = true
			sv.refresh()
			await _shot("%d_mini_search_etym" % n)
			(main.current() as MinigameScreen)._quit()
			await get_tree().create_timer(0.5).timeout
			await _shot("%d_mini_search_review" % n)
		if g["id"] == "trap":
			var tv := main.current() as TrapView
			var tg := tv.game as TrapGame
			await get_tree().create_timer(1.5).timeout
			await _shot("%d_mini_trap_watch" % n)
			tg.place_trap(tg.tray.find(0), tg.pos(0, 0.0))
			tg.place_trap(0, Vector2(0.3, 0.4))
			tv.changed()
			await get_tree().create_timer(1.0).timeout
			await _shot("%d_mini_trap_place" % n)
			tg.hide()
			tv.changed()
			await get_tree().create_timer(0.8).timeout
			await _shot("%d_mini_trap_hunt" % n)
		if g["id"] == "pattern":
			var pv := main.current() as PatternView
			var pg := pv.game as RootLinkGame
			for k in 2:
				for ro in pg.roots:
					if ro["owner"] == pg.targets[k]:
						ro["state"] = "down"
						pg.place(pg.roots.find(ro), k)
			for ro in pg.roots:
				if ro["state"] == "roam":
					ro["state"] = "down"
					ro["down_t"] = 99.0
					break
			pg.shoot(Vector2(0.3, 0.2))
			for i in pg.roots.size():
				if pg.roots[i]["state"] == "down":
					pv._drag = i
					pv._hover = 2
					pv._drag_pos = pv._card_rect(2).get_center() + Vector2(40, 10)
			await get_tree().create_timer(0.3).timeout
			await _shot("%d_mini_pattern_play" % n)
			pv._quit()
			await get_tree().create_timer(0.5).timeout
			await _shot("%d_mini_pattern_review" % n)
		if g["id"] == "guard":
			var gg := (main.current() as MinigameScreen).game as GuardGame
			gg.spawn_climber()
			await get_tree().create_timer(3.0).timeout
			gg.events.append({"kind": "gate", "ok": false, "w": 0, "true": false, "blocked": false, "shown": gg.words[1].meaning, "x": 0.5})
			await _shot("%d_mini_guard_later" % n)
		if g["id"] == "fishing":
			var fg := (main.current() as MinigameScreen).game as FishingGame
			fg.cast(fg.fish[0]["pos"] + Vector2(0.05, 0.02))
			await get_tree().create_timer(1.2).timeout
			await _shot("%d_mini_fishing_bite" % n)
			fg._start_fight(fg.fish[0]["w"])
			await get_tree().create_timer(1.2).timeout
			await _shot("%d_mini_fishing_fight" % n)
		if g["id"] == "order":
			var og := (main.current() as MinigameScreen).game as OrderGame
			var ow: int = og.shelf[0]
			for it in og.items:
				if it["w"] == ow and it["piece"] == 0:
					it["d"] = 0.3
					og.pick(it["uid"])
					og.action = {"kind": "furnace"}
					og.act()
					break
			og.go_pick(og.items[0]["uid"])
			await get_tree().create_timer(1.5).timeout
			await _shot("%d_mini_order_later" % n)
		if g["id"] == "copy":
			await get_tree().create_timer(9.0).timeout
			await _shot("%d_mini_copy_later" % n)
		n += 1
	main.flow.go_title()
	await _shot("30_title_modes")
	await _card_gallery(gd)
	gd.save_store.erase()
	get_tree().quit()


## 단어 카드 견본: 속성 1·2·3개, 부위 다섯 가지, 가진 단어/처음 단어.
func _card_gallery(gd: Node) -> void:
	var layer := ColorRect.new()
	layer.color = UiKit.PAPER
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_child(layer)
	var v := UiKit.vbox(10)
	v.position = Vector2(30, 30)
	layer.add_child(v)
	var picked := {1: [], 2: [], 3: []}
	for id in gd.repo.all_ids():
		var w: WordData = gd.repo.get_word(id)
		var n := mini(3, w.attrs.size())
		if n > 0 and picked[n].size() < 5 and w.slot != "":
			picked[n].append(w)
	for n in [1, 2, 3]:
		var row := UiKit.hbox(10)
		v.add_child(row)
		for i in picked[n].size():
			row.add_child(WordCard.make(picked[n][i], "", 22, Callable(), 1 if i % 2 == 0 else 0))
	await _shot("31_word_cards")
	layer.queue_free()