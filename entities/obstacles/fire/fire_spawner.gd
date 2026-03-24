extends Node
# 1. 加载我们刚才做的天火场景 (请确保你的路径是正确的)
@export var fire_scene: PackedScene = preload("uid://bhj6s7h4eqpg8")
@export var restore_time: float = 10.0 # 在编辑器里调整的恢复时间


# 2. 记事本：用来记录被破坏的砖块信息，方便10秒后恢复
var restoring_tiles: Array[Dictionary] = []

func _process(delta: float) -> void:
	# 每帧检查记事本，倒计时到了就修地形
	for i in range(restoring_tiles.size() - 1, -1, -1):
		var data = restoring_tiles[i]
		data.time_left -= delta
		
		if data.time_left <= 0:
			# 时间到！把地形变回来
			if is_instance_valid(data.tilemap):
				if data.tilemap is TileMap:
					data.tilemap.set_cell(0, data.coords, data.source_id, data.atlas_coords)
				elif data.tilemap.is_class("TileMapLayer"):
					data.tilemap.set_cell(data.coords, data.source_id, data.atlas_coords)
			# 从记事本中划掉
			restoring_tiles.remove_at(i)

# ==========================================
# 专属技能 1：长官呼叫时，从天上随机降下火焰
# ==========================================
func spawn_fire():
	
	var player = get_tree().get_first_node_in_group("Player")
	if not player: return

	var canvas = get_tree().root.get_canvas_transform()
	var screen_rect = player.get_viewport_rect()
	var top_left = -canvas.origin / canvas.get_scale()
	var screen_size = screen_rect.size / canvas.get_scale()

	# 坐标：只在屏幕顶部的随机 X 轴位置生成
	var random_x = randf_range(top_left.x, top_left.x + screen_size.x)
	var spawn_pos = Vector2(random_x, top_left.y - 50)

	# 方向：永远笔直向下
	
	# 生成并展示！
	var fire = fire_scene.instantiate()
	get_tree().root.add_child(fire)
	fire.global_position = spawn_pos

func _ready():
	# 记得把火球发射器加入群组，这样火球掉地上才能找到人报账
	add_to_group("FireSpawner")

# ==========================================
# 专属技能 2：瓦片报账员。当火球撞击 TileMap 时调用
# ==========================================
func register_destroyed_tile(tilemap: Node, impact_pos: Vector2, direction: Vector2):
	# 1. 算出撞击的是哪一块瓦片
	# 增加偏移量到 12.0，确保探测点深入到瓦片内部
	var test_pos = impact_pos + direction * 12.0
	var local_pos = tilemap.to_local(test_pos)
	var coords = Vector2i()
	
	if tilemap.has_method("local_to_map"):
		coords = tilemap.local_to_map(local_pos)
	
	# 2. 获取原本的信息（用于 10 秒后恢复）
	var source_id = -1
	var atlas_coords = Vector2i(-1, -1)
	
	if tilemap is TileMap:
		source_id = tilemap.get_cell_source_id(0, coords)
		atlas_coords = tilemap.get_cell_atlas_coords(0, coords)
	elif tilemap.has_method("get_cell_source_id"):
		# 针对 TileMapLayer 的通用调用
		source_id = tilemap.get_cell_source_id(coords)
		atlas_coords = tilemap.get_cell_atlas_coords(coords)
		
	# 调试：打印关键信息
	print("[拆迁办] 目标:", tilemap.name, " 坐标:", coords, " SourceID:", source_id)
		
	# 3. 如果这块地是可以被破坏的（不是空的）
	if source_id != -1:
		# 记录数据
		restoring_tiles.append({
			"tilemap": tilemap,
			"coords": coords,
			"source_id": source_id,
			"atlas_coords": atlas_coords,
			"time_left": restore_time
		})
		
		# 彻底移除
		if tilemap is TileMap:
			tilemap.set_cell(0, coords, -1)
		elif tilemap.has_method("set_cell"):
			tilemap.set_cell(coords, -1)
		print("[拆迁办] 成功拆除瓦片")
	else:
		print("[拆迁办] 撞到了空气或不可破坏的对象")
