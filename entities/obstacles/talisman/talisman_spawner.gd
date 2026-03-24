extends Node

@export var talisman_scene: PackedScene 

func spawn_talisman():
	if not talisman_scene:
		return
		
	var player = get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player): return
	
	# 🌟 1. 检查是否已经有激活的定身符
	var existing_talisman = get_tree().get_first_node_in_group("active_binding_talisman")
	if is_instance_valid(existing_talisman):
		if existing_talisman.has_method("add_stack"):
			existing_talisman.add_stack()
			return # 已经加了堆叠，直接返回，不再生成新的
	
	# 👇 2. 寻找真正的屏幕视野正中心！
	var screen_center = player.global_position
	var camera = get_viewport().get_camera_2d()
	if camera:
		# 🌟 核心修复：使用 get_screen_center_position() 
		# 它获取的是当前镜头画面绝对中心的坐标，不再受马里奥位置干扰！
		screen_center = camera.get_screen_center_position()
	
	# 3. 召唤符纸
	var talisman = talisman_scene.instantiate()
	get_tree().current_scene.add_child(talisman)
	talisman.add_to_group("spawned_trash")
	
	# 👇 4. 呼叫符纸的强控函数，把真正的屏幕中心位置和玩家传给它！
	if talisman.has_method("activate_talisman"):
		talisman.activate_talisman(player, screen_center)
