extends Node

@export var item_scene: PackedScene     # 生成的物品 (比如剑、刺、火把)

func execute_ultimate_attack():
	if not item_scene:
		print("【大招释放失败】请在右侧检查器中放入 item_scene！")
		return
		
	var viewport = get_viewport()
	var visible_rect = viewport.get_visible_rect()
	var canvas_transform_inv = viewport.get_canvas_transform().affine_inverse()
	
	# 获取屏幕四个角的世界坐标
	var top_left = canvas_transform_inv * visible_rect.position
	var bottom_right = canvas_transform_inv * (visible_rect.position + visible_rect.size)
	
	print("【万象天引】全屏生成 200 个随机物品！")
	
	for i in range(500):
		var item = item_scene.instantiate()
		get_tree().current_scene.add_child(item)
		
		# 在当前可见屏幕范围内随机生成世界坐标
		var random_pos = Vector2(
			randf_range(top_left.x, bottom_right.x),
			randf_range(top_left.y, bottom_right.y)
		)
		
		item.global_position = random_pos
		
		# 随机旋转一下，增加一点乱如麻的感觉（可选）
		# item.rotation = randf_range(0, PI * 2)
		
		# 同时也贴上垃圾标签，方便清理
		item.add_to_group("spawned_trash")
