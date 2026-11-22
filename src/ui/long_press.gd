class_name LongPress
extends RefCounted
## 길게 누르면 설명을 띄운다(01-rpg-base '전투 준비'). 버튼에 붙여 쓴다.

const HOLD_SEC := 0.5


static func attach(btn: Control, show_help: Callable) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = HOLD_SEC
	btn.add_child(timer)
	timer.timeout.connect(show_help)
	btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			if ev.pressed:
				timer.start()
			else:
				timer.stop())
