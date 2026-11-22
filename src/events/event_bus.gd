extends Node
## 화면끼리 직접 부르지 않고 시그널로 알린다(architecture.md 7절).

signal word_captured(word_id: String)
signal level_up(unit_no: int, level: int)
signal evolution_failed(target_word_id: String)
signal boss_defeated(stage: int)
signal settings_changed
