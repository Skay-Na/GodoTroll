extends Node

@export var fire_ring_scene: PackedScene # 右侧检查器拖入 FireRing.tscn

func spawn_fire_ring():
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not fire_ring_scene: return
	
	# 1. 计算屏幕右侧边缘坐标
	var canvas = get_tree().root.get_canvas_transform()
	var top_left = -canvas.origin / canvas.get_scale()
	var screen_rect = get_viewport().get_visible_rect()
	var current_screen_size = screen_rect.size / canvas.get_scale()
	
	var spawn_x = top_left.x + current_screen_size.x + 100
	
	# 2. 计算随机高度：为了保证玩家能“跳”过去，火圈要生成在玩家头顶偏上的位置
	var player_y = player.global_position.y
	# 高度浮动范围：玩家头顶上方 150 像素 到 50 像素之间
	var spawn_y = randf_range(player_y - 150, player_y - 5) 
	
	# 3. 实例化火圈
	var ring = fire_ring_scene.instantiate()
	
	# 先设置天涯海角的坐标，防瞬移 Bug！
	ring.global_position = Vector2(spawn_x, spawn_y)
	
	# 加入场景开始向左飞！
	get_tree().current_scene.add_child(ring)
	print("【火圈】已发射！高度：", spawn_y)
