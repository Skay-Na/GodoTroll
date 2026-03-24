extends Control

func _ready():
	# 确保进入主菜单时，鼠标光标是可见的
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# 当点击“开始游戏”时触发
func _on_start_button_pressed():
	# 替换为你实际的第一关场景的文件路径
	get_tree().change_scene_to_file("res://level/1-1.tscn")

# 当点击“选择关卡”时触发
func _on_level_select_button_pressed():
	# 替换为你的选关界面场景的文件路径
	get_tree().change_scene_to_file("res://level/2-1.tscn")

# 当点击“设置”时触发
func _on_settings_button_pressed():
	# 替换为你的设置界面场景的文件路径，或者在这里弹出一个设置面板
	get_tree().change_scene_to_file("res://Scenes/Settings.tscn")

# 当点击“退出游戏”时触发
func _on_quit_button_pressed():
	# 退出整个游戏程序
	get_tree().quit()
