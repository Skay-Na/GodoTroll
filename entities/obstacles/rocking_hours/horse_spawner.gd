extends Node

@export var horse_scene: PackedScene # 在检查器里把你的摇摇马场景拖进来！
@export var required_presses: int = 20 # 需要狂按多少次
@export var spawn_offset: Vector2 = Vector2.ZERO # 在检查器里调整生成位置偏移
@export var ray_length: float = 2000.0 # 射线探测长度
@export var floor_layer: int = 5 # 地板所在的物理层

func spawn_rocking_horse():
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not horse_scene: return
	
	# 计算当前屏幕的正中心坐标 (基于摄像机视口)
	var canvas = get_tree().root.get_canvas_transform()
	var screen_rect = player.get_viewport_rect()
	var viewport_size = screen_rect.size / canvas.get_scale()
	var screen_center = -canvas.origin / canvas.get_scale() + (viewport_size / 2.0)
	
	# 射线发射起始点：屏幕横向中心，纵向设在视口顶部
	var ray_start = Vector2(screen_center.x, screen_center.y - viewport_size.y / 2.0)
	var ray_end = ray_start + Vector2(0, ray_length)
	
	var spawn_pos = screen_center # 默认回退到屏幕中心
	
	# 发射射线探测地板层 (Layer 5)
	var space_state = player.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.collision_mask = 1 << (floor_layer - 1) # 层级转换位掩码
	
	var result = space_state.intersect_ray(query)
	if result:
		spawn_pos = result.position
		print("【摇摇马】射线击中地板: ", spawn_pos)
	else:
		print("【摇摇马】未检测到地板，回退到中心位置")
	
	# 应用偏移量
	spawn_pos += spawn_offset
	
	# 实例化摇摇马
	var horse = horse_scene.instantiate()
	
	# 设置点击次数
	if "required_presses" in horse:
		horse.required_presses = required_presses
		
	get_tree().current_scene.add_child(horse)
	
	# 启动摇摇马并传递玩家和生成点坐标
	if horse.has_method("start_riding"):
		horse.start_riding(player, spawn_pos)
