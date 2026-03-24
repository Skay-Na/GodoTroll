extends Node

# ============================================================
# 🎵 迪厅地板 v3.0 - 透明柱子版
# 保留原始瓷砖外观，用看不见的碰撞柱按频率独立弹跳
# ============================================================

# --- 检查器参数 ---
@export var band_count: int = 8                   # 频率柱子数量（减小 = 柱子更宽）
@export var punch_multiplier: float = 120.0       # 振幅倍率
@export var max_height: float = 48.0              # 每个柱子最大跳动高度（像素）
@export var rise_speed: float = 18.0              # 上升插值速度
@export var drop_speed: float = 8.0               # 下落复位速度
@export var column_thickness: float = 300.0       # 柱子碰撞体的高度
@export var column_overlap: float = 6.0           # 柱子横向额外重叠宽度（消除缝隙）
@export var min_freq: float = 40.0
@export var max_freq: float = 8000.0
@export var audio_bus_name: String = "Master"

# --- 音乐卡槽 ---
@export var track_1: AudioStream
@export var track_2: AudioStream
@export var track_3: AudioStream

# --- 内部变量 ---
var spectrum: AudioEffectSpectrumAnalyzerInstance
var is_active: bool = false
var original_ground: Node2D = null
var disco_columns: Array = []
var column_offsets: Array = []
var column_base_y: float = 0.0
var original_volume: float = 0.0
var is_muted_by_death: bool = false

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

func _ready():
	audio_player.finished.connect(_on_music_finished)

# ============================
# 开关迪厅模式
# ============================
func toggle_disco_mode():
	if is_active:
		_stop_disco()
		return

	# 收集音乐
	var tracks = []
	if track_1: tracks.append(track_1)
	if track_2: tracks.append(track_2)
	if track_3: tracks.append(track_3)
	if tracks.is_empty():
		print("❌ [迪厅] 请在检查器里放入音乐！")
		return

	# 获取频谱
	var bus_index = AudioServer.get_bus_index(audio_bus_name)
	if bus_index == -1:
		print("❌ [迪厅] 找不到音频总线 '", audio_bus_name, "'")
		return
	spectrum = AudioServer.get_bus_effect_instance(bus_index, 0)
	if not spectrum:
		print("❌ [迪厅] 请在 Audio 面板的 '", audio_bus_name, "' 总线上添加 SpectrumAnalyzer 效果！")
		return

	# 找地形
	original_ground = _find_ground()
	if not original_ground:
		return

	column_base_y = original_ground.global_position.y

	# 禁用原始地形的碰撞（但保持可视），让彩虹柱子接管物理
	original_ground.collision_enabled = false

	# 创建透明柱子
	_create_columns()

	# 播放
	audio_player.stream = tracks.pick_random()
	audio_player.bus = audio_bus_name
	audio_player.play()

	is_active = true
	print("🎵 [迪厅] 启动！", band_count, " 个彩虹频谱柱就绪！")

# ============================
# 创建透明碰撞柱
# ============================
func _create_columns():
	disco_columns.clear()
	column_offsets.clear()

	for i in range(band_count):
		var body = StaticBody2D.new()
		body.name = "DiscoCol_%d" % i

		# 碰撞体
		var col_shape = CollisionShape2D.new()
		col_shape.name = "ColShape"
		var rect = RectangleShape2D.new()
		rect.size = Vector2(32, column_thickness)
		col_shape.shape = rect
		body.add_child(col_shape)

		# 彩虹色视觉块
		var visual = ColorRect.new()
		visual.name = "Visual"
		var hue = float(i) / float(band_count)
		visual.color = Color.from_hsv(hue, 0.85, 0.9, 0.85)
		body.add_child(visual)

		get_tree().current_scene.add_child(body)
		disco_columns.append(body)
		column_offsets.append(0.0)

# ============================
# 每帧更新
# ============================
func _process(delta: float) -> void:
	if not is_active or not spectrum: return

	# 获取当前玩家
	var player = get_tree().get_first_node_in_group("Player")
	
	# === 1. 死亡静音 / 复活恢复音量 逻辑 ===
	if player:
		var player_dead = player.get("is_dead") if "is_dead" in player else false
		if player_dead and not is_muted_by_death:
			original_volume = audio_player.volume_db
			audio_player.volume_db = -80.0
			is_muted_by_death = true
			print("🔇 [迪厅] 玩家死亡，音乐已静音。")
		elif not player_dead and is_muted_by_death:
			audio_player.volume_db = original_volume
			is_muted_by_death = false
			print("🔊 [迪厅] 玩家复活，音量已恢复。")
	
	# === 2. 场景重载检测 (柱子消失自动补全) ===
	if disco_columns.is_empty() or not is_instance_valid(disco_columns[0]):
		print("🔄 [迪厅] 检测到场景重载或柱子丢失，正在重新初始化...")
		original_ground = _find_ground()
		if original_ground:
			column_base_y = original_ground.global_position.y
			original_ground.collision_enabled = false
			_create_columns()
	
	if not player: return

	# 获取摄像机视口信息
	var cam_transform = player.get_viewport().get_canvas_transform()
	var viewport_w = player.get_viewport_rect().size.x / cam_transform.get_scale().x
	var screen_left = -cam_transform.origin.x / cam_transform.get_scale().x
	var col_w = viewport_w / float(band_count)

	for i in range(band_count):
		if not is_instance_valid(disco_columns[i]): continue

		# 对应的频率（对称映射：屏幕中心 = 低频/低音，两侧边缘 = 高频/高音）
		# center_dist 范围：0.0（正中心）→ 1.0（最边缘）
		var center_dist = abs(2.0 * float(i) / float(band_count - 1) - 1.0)
		var t_lo = center_dist * 0.8
		var t_hi = min(center_dist * 0.8 + (0.8 / float(band_count)), 1.0)
		var freq_lo = min_freq * pow(max_freq / min_freq, t_lo)
		var freq_hi = min_freq * pow(max_freq / min_freq, t_hi)

		# 计算振幅
		var magnitude = spectrum.get_magnitude_for_frequency_range(freq_lo, freq_hi).length()
		var target_offset = clamp(-magnitude * punch_multiplier, -max_height, 0.0)

		# 平滑插值
		if target_offset < column_offsets[i]:
			column_offsets[i] = lerp(column_offsets[i], target_offset, rise_speed * delta)
		else:
			column_offsets[i] = lerp(column_offsets[i], 0.0, drop_speed * delta)

		var body = disco_columns[i]

		# 柱子横向跟随摄像机
		body.global_position.x = screen_left + i * col_w + col_w / 2.0
		# 柱子纵向随频率弹起
		body.global_position.y = column_base_y + column_thickness / 2.0 + column_offsets[i]

		# 更新碰撞体和视觉块宽度（加上重叠消除缝隙）
		var effective_w = col_w + column_overlap
		var col_shape = body.get_node("ColShape")
		var visual = body.get_node("Visual")
		if col_shape and col_shape.shape:
			col_shape.shape.size = Vector2(effective_w, column_thickness)
		if visual:
			visual.size = Vector2(effective_w, column_thickness)
			visual.position = Vector2(-effective_w / 2.0, -column_thickness / 2.0)

# ============================
# 停止
# ============================
func _on_music_finished():
	print("[迪厅] 音乐结束，自动关停。")
	_stop_disco()

func _stop_disco():
	is_active = false
	audio_player.stop()

	# 销毁所有透明柱子
	for body in disco_columns:
		if is_instance_valid(body):
			body.queue_free()
	disco_columns.clear()
	column_offsets.clear()

	# 恢复原始地形碰撞
	if is_instance_valid(original_ground):
		original_ground.collision_enabled = true
	print("[迪厅] 已停止，地板碰撞已恢复正常。")

# ============================
# 辅助：寻找地形
# ============================
func _find_ground() -> Node2D:
	var node = get_tree().current_scene.find_child("GroundLayer", true, false)
	if node:
		print("🎯 [迪厅] 找到地形：", node.name)
		return node as Node2D
	print("❌ [迪厅] 没有找到名为 GroundLayer 的节点！")
	return null
