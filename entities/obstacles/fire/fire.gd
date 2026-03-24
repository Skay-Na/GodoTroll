extends Area2D

# 落下速度 (火球的下落速度，你可以随便调)
@export var speed: float = 200.0 
# 破坏半径 (核心新增：根据你火球的实际像素大小来调整，比如火球宽32，半径就填16)
@export var destroy_radius: float = 16.0 

var direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	# コリジョンレイヤー設定 (Layer 1 是墙体, Layer 2 是玩家, Layer 5 是地形)
	collision_layer = 0
	collision_mask = 529 # 1 + 16 + 512 = 529 核心修改：移除 Layer 2 (玩家)，让火不再检测玩家
	monitoring = true 
	
	# シグナル接続 (玩家检测逻辑已移除)
	# if not body_entered.is_connected(_on_body_entered):
	# 	body_entered.connect(_on_body_entered)

# 毎フレームの物理処理
func _physics_process(delta: float) -> void:
	# 毎フレーム移動
	global_position += direction * speed * delta

	# 重なっているオブジェクトを取得
	var overlapping_bodies = get_overlapping_bodies()
	
	for body in overlapping_bodies:
		
		# 判断是否是需要直接破坏的生成物
		var current_node = body
		var node_to_destroy = null
		
		# 向上遍历父节点，一直找到最外层的 buid 或 firebar
		while is_instance_valid(current_node) and current_node != get_tree().root:
			var cname = current_node.name.to_lower()
			var path = current_node.scene_file_path.get_file().to_lower() if current_node.scene_file_path else ""
			
			# 如果该节点的名字或者场景文件路径包含建筑标识，把它标记为要销毁
			# 因为 Buid3 里面还有 Firebar，所有往上找能确保连最外层的 Buid3 一起销毁
			if "buid1" in cname or "buid2" in cname or "buid3" in cname or \
			   "buid_1" in path or "buid_2" in path or "buid_3" in path or \
			   "firebar" in cname or "firebar" in path:
				node_to_destroy = current_node
			
			current_node = current_node.get_parent()
				
		if node_to_destroy:
			if is_instance_valid(node_to_destroy) and not node_to_destroy.is_queued_for_deletion():
				node_to_destroy.queue_free()
			continue

		var is_terrain = false
		
		# 地形判定
		if body.has_method("get_collision_layer_value") and (body.get_collision_layer_value(5) or body.get_collision_layer_value(1)):
			# 核心修改：加上了 or body.get_collision_layer_value(1)，现在 Layer 1 也会被当成地形破坏！
			is_terrain = true
		elif body is TileMap or body.get_class() == "TileMapLayer" or "Ground" in body.name or "Layer" in body.name:
			is_terrain = true

		if is_terrain:
			# スポナーを呼ぶ
			var spawner = get_tree().get_first_node_in_group("FireSpawner")
			if spawner and spawner.has_method("register_destroyed_tile"):
				
				# 【核心修改】：去掉了向左和向右的探测，只保留中心和正下方
				var check_points = [
					global_position, # 中心
					global_position + Vector2(0, destroy_radius)   # 仅向下开路，保证一路垂直向下
				]
				
				for point in check_points:
					spawner.register_destroyed_tile(body, point, direction)

# プレイヤーとの衝突判定 (已废弃)
# func _on_body_entered(body: Node2D) -> void:
# 	pass
