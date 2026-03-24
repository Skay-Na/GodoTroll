extends Node

@export var item_scene: PackedScene # 暴露在外的卡槽：你要生成的场景拖到这里
@export var safe_distance: float = 200.0 # 安全距离：生成的物品必须离玩家至少这么远（像素）

func spawn_random_item():
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not item_scene: return
	
	# 1. 获取当前屏幕（摄像机）的视野边界
	var canvas = get_tree().root.get_canvas_transform()
	var top_left = -canvas.origin / canvas.get_scale()
	var view_size = get_viewport().get_visible_rect().size / canvas.get_scale()
	var bottom_right = top_left + view_size
	
	var spawn_pos = Vector2.ZERO
	var is_valid_pos = false
	var max_attempts = 20 # 安全锁：最多找20次，防止死循环导致游戏卡死
	var attempts = 0
	
	# 2. 疯狂丢飞镖：在屏幕范围内随机找点，直到避开玩家为止
	while not is_valid_pos and attempts < max_attempts:
		# 往屏幕内侧收 50 像素，防止物品一半生在屏幕外
		spawn_pos.x = randf_range(top_left.x + 20, bottom_right.x - 20)
		spawn_pos.y = randf_range(top_left.y + 20, bottom_right.y - 20)
		
		# 检查这个点离马里奥有多远
		if spawn_pos.distance_to(player.global_position) > safe_distance:
			is_valid_pos = true # 距离安全，确定位置！
			
		attempts += 1
		
	# 3. 把物品拉出来放到这个位置上
	var item = item_scene.instantiate()
	get_tree().current_scene.add_child(item)
	item.global_position = spawn_pos
	
	# 🌟 核心：必须加上这行，给它贴上“临时垃圾”的标签！司令部才能认出它！
	item.add_to_group("spawned_trash")
	
	print("【随机生成】成功！避开了马里奥，坐标：", spawn_pos)
