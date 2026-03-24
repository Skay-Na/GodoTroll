extends Node

@export var trap_scene: PackedScene # 右侧检查器拖入 BearTrap.tscn

@export var offset_min: float = -80.0 # 后方极限距离
@export var offset_max: float = 80.0  # 前方极限距离

# 🌟【新增】持久化存储静态变量
static var _persistent_traps: Array = [] # 存储字典：{"pos": Vector2, "rot": float}
static var _last_scene_path: String = ""
var _last_scene_ref: Node = null

func _process(_delta):
	var current_scene = get_tree().current_scene
	if current_scene and current_scene != _last_scene_ref:
		_last_scene_ref = current_scene
		
		# 场景换了，有两种可能：1. 切到新关卡 2. 死亡重载旧关卡
		var current_path = current_scene.scene_file_path
		if current_path != _last_scene_path:
			_persistent_traps.clear()
			_last_scene_path = current_path
			print("【捕兽夹持久化】检测到新关卡 (", current_path, ")，已清空存档。")
		else:
			print("【捕兽夹持久化】正在从存档恢复 ", _persistent_traps.size(), " 个夹子...")
			# 用 deferred 调用，确保重载后的碰撞体等都初始化好
			for data in _persistent_traps:
				call_deferred("_create_trap_instance", data.pos, data.rot, false)

func spawn_bear_trap():
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not trap_scene: return
	
	var viewport = player.get_viewport()
	var visible_rect = viewport.get_visible_rect()
	
	# 🌟【需求】屏幕右边出现的概率调大一点
	# 使用 sqrt(randf()) 使随机值更倾向于 1.0 (右侧)
	var x_percent = sqrt(randf())
	
	# 在屏幕可视范围内随机取一个屏幕坐标
	var random_screen_pos = Vector2(
		x_percent * visible_rect.size.x,
		randf_range(0.0, visible_rect.size.y)
	)
	
	# 屏幕坐标 -> 世界坐标
	var spawn_pos = viewport.get_canvas_transform().affine_inverse() * random_screen_pos
	
	# 🌟【需求】捕兽夹出现时的角度要随机
	var random_rot = randf_range(0, TAU)
	
	# 调用统一的生成逻辑并记录到持久化列表
	_create_trap_instance(spawn_pos, random_rot, true)
	
	print("【捕兽夹】在屏幕随机位置生成！右侧权重生效。世界坐标：(%.1f, %.1f)" % [spawn_pos.x, spawn_pos.y])

# 🌟【新增】统一的生成逻辑
func _create_trap_instance(pos: Vector2, rot: float, should_save: bool):
	if not trap_scene: return
	
	var trap = trap_scene.instantiate()
	trap.global_position = pos
	trap.rotation = rot
	trap.set_meta("spawn_pos", pos)
	get_tree().current_scene.add_child(trap)
	
	if should_save:
		_persistent_traps.append({"pos": pos, "rot": rot})

# 🌟【新增】静态方法供外部删除已触发的夹子
static func remove_persistent_trap(pos: Vector2):
	for i in range(_persistent_traps.size() - 1, -1, -1):
		if _persistent_traps[i].pos.distance_to(pos) < 1.0: # 容错匹配
			_persistent_traps.remove_at(i)
			print("【捕兽夹持久化】已成功移除坐标为 ", pos, " 的捕兽夹记录。")
			break
