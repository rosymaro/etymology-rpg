class_name BattlePrepScreen
extends Screen
## 전투 준비(01-rpg-base): 출전 유닛과 적, 이번 전투의 마법(덱 4개 중 무작위 3개, 턴마다 하나씩 쓴다)을 보고 전투 시작.
## 유닛 어근은 유닛 창에서 미리 장착한 것을 쓴다(07-fun 2절, 어근 고르기 단계는 없앴다). 덱이 비었으면 마법은 보여 주지 않는다.
## 적 카드는 원래 자리(오른쪽 위)에 그대로 두고, 고르는 판은 오른쪽 아래 절반에 오른쪽 정렬로 놓는다(아군은 왼쪽에 보인다).
## 마법·어근은 누르면 고르고, 고른 것의 설명이 바로 아래에 나온다.

var _words: Array[String] = []
var _boss := false
var _party: Array[int] = []
var _magic := ""  ## 설명을 보여 줄 마법(마지막으로 누른 것)
var _offer: Array[String] = []
var _allies_box: Control
var _enemies_box: Control
var _roots: Dictionary = {}
var _panel: PanelContainer
var _body: VBoxContainer
var _help: Label
var _nav: HBoxContainer
var _root_shown := ""  ## 어근 고르기에서 설명을 보여 줄 어근(마지막으로 누른 것)


func open(args: Dictionary) -> void:
	_words = args["words"]
	_boss = args["boss"]
	_party = GameData.setup.pick_party(GameData.state)
	var s := GameData.state
	_roots = Loadout.roots(s, GameData.rules, _party)
	_offer = GameData.rules.magic_offer(s, _roots.values(), GameData.rng)
	_magic = _offer[0] if not _offer.is_empty() else ""
	UiKit.fill_bg(self, Color("e9e2f3"))
	_build_field_view()
	_panel = UiKit.card()
	# 세로 화면: 아군 아래에 가로로 꽉, 높이는 내용만큼(빈 칸 없이). 내용은 오른쪽 정렬
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.offset_left = 16
	_panel.offset_right = -16
	_panel.offset_top = 420
	_panel.offset_bottom = 420
	add_child(_panel)
	_body = UiKit.vbox(10)
	_panel.add_child(_body)
	_step_magic()


func _build_field_view() -> void:
	# 아군(왼쪽 아래, 판에 가려진다)
	var allies := UiKit.hbox(10)
	_allies_box = allies
	allies.position = Vector2(24, 300)
	add_child(allies)
	for u in _party:
		var c := UiKit.card(UiKit.LEAF)
		c.add_child(UiKit.label("%s\nLv %d" % [UiKit.unit_name(u), GameData.rules.level(GameData.state, u)], 20))
		allies.add_child(c)
	# 적(오른쪽 위, 출전 순서대로)
	var enemies := UiKit.hbox(10)
	_enemies_box = enemies
	add_child(enemies)
	UiKit.pin(enemies, 1, 0, -24, 24)
	var labels: Array[String] = []
	if _boss:
		for k in maxi(0, _party.size() - 1):
			labels.append(t("ui.prep.minion"))
		labels.append(GameData.repo.boss_word(GameFlow.cur()).id)
	else:
		for id in _words:
			var lv := GameData.setup.factory.enemy_level(GameData.repo.get_word(id), GameFlow.cur())
			labels.append("%s\nLv %d" % [id, lv])
	for i in labels.size():
		var c := UiKit.card(UiKit.PINK if not (_boss and i == labels.size() - 1) else UiKit.ACCENT.lightened(0.5))
		c.add_child(UiKit.label("%d. %s" % [i + 1, labels[i]], 20))
		enemies.add_child(c)
	var title := UiKit.label(t("ui.prep.boss") if _boss else t("ui.prep.title"), 30)
	title.position = Vector2(24, 24)
	add_child(title)


func _clear() -> void:
	for c in _body.get_children():
		c.queue_free()


func _step_magic() -> void:
	_clear()
	if not _offer.is_empty():
		_body.add_child(_right(UiKit.wrap(UiKit.label(t("ui.battle.magic_offer"), 22))))
		var row := _flow()
		_body.add_child(row)
		for m in _offer:
			var id := m
			var key := "sys.magic.%s.name" % m
			var b := UiKit.button(t(key), func() -> void:
				_magic = id
				_step_magic(), UiKit.ACCENT.lightened(0.45) if _magic == m else UiKit.PAPER, 24)
			row.add_child(b)
		_help = _right(UiKit.wrap(UiKit.label(_magic_desc(_magic), 22, UiKit.INK.lightened(0.2))))
		_body.add_child(_help)
	# 장착한 어근(유닛 창에서 바꾼다)
	var names: Array[String] = []
	for u in _party:
		names.append("%s: %s" % [UiKit.unit_name(u), _roots[u] if _roots[u] != "" else "-"])
	_body.add_child(_right(UiKit.wrap(UiKit.label(t("ui.prep.roots").format({"list": ", ".join(names)}), 20, UiKit.INK.lightened(0.25)))))
	var nav := _nav_row()
	var start := UiKit.button(t("ui.battle.start"), _start, UiKit.ACCENT.lightened(0.3))
	nav.add_child(start)
	_tutorial.call_deferred(start)


## 처음 전투 준비(08-tutorial.md): 적 → 출전 유닛 → (마법) → 장착 어근 → 전투 시작.
func _tutorial(start: Button) -> void:
	await get_tree().process_frame
	var steps: Array[Dictionary] = [
		{"target": _enemies_box, "text": "tut.prep.enemy", "mode": "any"},
		{"target": _allies_box, "text": "tut.prep.ally", "mode": "any"},
		{"target": _panel, "text": "tut.prep.panel" if not _offer.is_empty() else "tut.prep.roots", "mode": "any"},
		{"target": start, "text": "tut.prep.start", "mode": "tap"},
	]
	TutorialOverlay.run(self, "battle_prep", steps)


func _magic_desc(id: String) -> String:
	return GameText.magic_desc(id, GameData.bal.magic_power(_avg_level()))


func _avg_level() -> int:
	var s := 0
	for u in _party:
		s += GameData.rules.level(GameData.state, u)
	return s / maxi(1, _party.size())


func _root_desc(root: String) -> String:
	return GameText.root_desc(root)


## 오른쪽 정렬 글
func _right(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


## 넘치면 다음 줄로 넘어가는 오른쪽 정렬 줄
func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.alignment = FlowContainer.ALIGNMENT_END
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 6)
	return f


## 이전·다음·전투 시작 버튼 줄: 엄지 자리(UiKit.THUMB_ROW) 오른쪽
func _nav_row() -> HBoxContainer:
	if _nav:
		_nav.queue_free()
	_nav = UiKit.hbox(12)
	add_child(_nav)
	UiKit.thumb(_nav, 1.0)
	return _nav


func _start() -> void:
	main.flow.start_battle(_party, _roots, _offer, _words, _boss)
