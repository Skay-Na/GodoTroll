extends Node

## 为玩家增加生命值
func add_player_life() -> void:
	print("【系统】触发 F3 快捷键：增加 1 点生命值")
	
	# 播放 1-up 音效
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_1up()
	
	# 调用全局 GameManager 增加生命
	GameManager.add_life()
