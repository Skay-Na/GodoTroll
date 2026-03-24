extends Area2D

const SPEED = 120.0 
var direction = Vector2.LEFT 

# 破坏半径：用于检测地形瓦片
@export var destroy_radius: float = 12.0 

func _ready():
	# 设置掩码探测物理层 1 (墙体), 5 (地形), 10 (其他)
	# 529 = 1 + 16 + 512
	collision_mask = 529
	monitoring = true
	
	# 连接出屏幕的信号
	if $VisibleOnScreenNotifier2D:
		$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)
		
	# 播放默认动画
	if $AnimationPlayer.has_animation("default"):
		$AnimationPlayer.play("default")
	
	# 根据运动方向翻转贴图
	$Sprite2D.scale.x = -1.0 if direction.x < 0 else 1.0

func _physics_process(delta):
	position += direction * SPEED * delta
	
	# --- 核心：地形破坏逻辑 ---
	var overlapping_bodies = get_overlapping_bodies()
	for body in overlapping_bodies:
		
		# 判断是否是独立场景物体 (如水管、砖块、建筑等)
		var cname = body.name.to_lower()
		var scene_path = ""
		if "scene_file_path" in body and body.scene_file_path:
			scene_path = body.scene_file_path.get_file().to_lower()
		
		var is_destructible_obj = "pipe" in cname or "brick" in cname or "buid" in cname \
			or "firebar" in cname or "tube" in cname \
			or "pipe" in scene_path or "brick" in scene_path or "buid" in scene_path
		
		if is_destructible_obj:
			# 此处直接释放独立节点
			body.queue_free()
			continue

		# 判断是否是 TileMap 地形
		var is_terrain = false
		if body.has_method("get_collision_layer_value"):
			if body.get_collision_layer_value(1) or body.get_collision_layer_value(5):
				is_terrain = true
		elif body is TileMap or body.get_class() == "TileMapLayer":
			is_terrain = true
		elif "Ground" in body.name or "Layer" in body.name:
			is_terrain = true
			
		if is_terrain:
			var spawner = get_tree().get_first_node_in_group("FireSpawner")
			if spawner and spawner.has_method("register_destroyed_tile"):
				# 水平移动的火球，需要增加上下方向的探测点来破坏高达几个格子的障碍物（比如水管）
				var check_points = [
					global_position,
					global_position + Vector2(0, 16),
					global_position + Vector2(0, -16)
				]
				for point in check_points:
					spawner.register_destroyed_tile(body, point, direction)

func _on_screen_exited():
	queue_free()
