extends Node2D

@export var required_energy: float = 100.0   # 彻底冲破定身符需要的总能量
@export var energy_multiplier: float = 150.0 # 能量转换倍率 (数字越大，解开越轻松)
@export var noise_floor_db: float = -45.0    # 门槛，从-30下调到-45，更灵敏
@export var energy_decay_rate: float = 30.0  # 🌟 新增：没声音时，能量流失的速度

@export_group("Video Settings")
@export var activation_video: VideoStream
@export var chroma_key_color: Color = Color.GREEN
@export var pickup_range: float = 0.15 # 🌟 增大默认容差
@export var fade_range: float = 0.1   # 平滑过渡
@export var spill_suppression: float = 0.5 # 溢色抑制 (去除绿边)

var trapped_player: Node2D = null
var current_energy: float = 0.0

var mic_bus_index: int
var mic_player: AudioStreamPlayer

# UI 元素
var ui_canvas: CanvasLayer
var energy_bar: ProgressBar
var debug_label: Label
var stack_label: Label

var stack_count: int = 1

func _ready():
	set_process(false)
	mic_bus_index = AudioServer.get_bus_index("Record")
	
	if mic_bus_index == -1:
		push_warning("【定身符】未找到名为 'Record' 的音轨，麦克风功能可能失效！")
		
	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "Record" if mic_bus_index != -1 else "Master"
	add_child(mic_player)
	
	# 加入组以便生成器查找
	add_to_group("active_binding_talisman")

# 由生成器直接调用的强制吸附函数
func activate_talisman(target_player: Node2D, center_pos: Vector2):

	global_position = center_pos
	trapped_player = target_player
	
	print("【定身符】急急如律令！万象天引！")
	
	var count = trapped_player.get_meta("trap_count", 0)
	trapped_player.set_meta("trap_count", count + 1)
	
	trapped_player.set_physics_process(false)
	trapped_player.set_process_input(false)
	if trapped_player.has_method("set_process_unhandled_input"):
		trapped_player.set_process_unhandled_input(false)
		
	if "velocity" in trapped_player:
		trapped_player.velocity = Vector2.ZERO
		
	var tween = create_tween()
	tween.tween_property(trapped_player, "global_position", center_pos, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	_create_energy_ui()
	
	if activation_video and has_node("/root/VideoManager"):
		var video_manager = get_node("/root/VideoManager")
		await video_manager.play_chroma_video(activation_video, {
			"chroma_color": chroma_key_color,
			"pickup_range": pickup_range,
			"fade_range": fade_range,
			"spill_suppression": spill_suppression
		})
		
	mic_player.play()
	set_process(true)

# 🌟 创建竖向道教进度条
func _create_energy_ui():
	ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 100 
	get_tree().current_scene.add_child(ui_canvas)
	
	# 创建一个中心定位器 (改用普通 Control 以允许手动偏移子节点)
	var center_node = Control.new()
	center_node.set_anchors_preset(Control.PRESET_CENTER)
	ui_canvas.add_child(center_node)
	
	energy_bar = ProgressBar.new()
	energy_bar.max_value = required_energy
	
	# 👇 🌟 核心：改成窄窄的样式
	energy_bar.custom_minimum_size = Vector2(15, 300) 
	# 👇 🌟 核心：让进度条从下往上填充！
	energy_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP 
	energy_bar.show_percentage = false # 竖着显示数字不好看，直接关掉百分比
	
	# 🌟 样式设计：道教黄条 + 深色半透明底框
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(1.0, 0.8, 0.1) 
	energy_bar.add_theme_stylebox_override("fill", fill_style)
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(1.0, 0.9, 0.5, 0.3) # 🌟 淡黄色半透明背景
	energy_bar.add_theme_stylebox_override("background", bg_style)
	
	# 把进度条丢进中心定位器
	center_node.add_child(energy_bar)
	
	# 设置锚点为中心，这样 position 0,0 就是屏幕中心
	energy_bar.set_anchors_preset(Control.PRESET_CENTER)
	
	# 👇 🌟 调整进位置看这里！ (180 是横向偏移，0 是纵向偏移)
	var manual_offset_x = 90 
	var manual_offset_y = 0
	
	energy_bar.set_anchor_and_offset(SIDE_LEFT, 0.5, manual_offset_x - 7.5) # 15/2 = 7.5
	energy_bar.set_anchor_and_offset(SIDE_RIGHT, 0.5, manual_offset_x + 7.5)
	energy_bar.set_anchor_and_offset(SIDE_TOP, 0.5, manual_offset_y - 150)
	energy_bar.set_anchor_and_offset(SIDE_BOTTOM, 0.5, manual_offset_y + 150)
	
	# energy_bar.position += energy_bar_offset # 已经通过 offset 逻辑设置了
	energy_bar.value = 0.0
	
	# 🌟 新增：堆叠层数文字 (x1, x2...)
	stack_label = Label.new()
	stack_label.add_theme_color_override("font_outline_color", Color.BLACK)
	stack_label.add_theme_constant_override("outline_size", 8)
	stack_label.add_theme_font_size_override("font_size", 42)
	stack_label.text = "x%d" % stack_count
	
	center_node.add_child(stack_label)
	stack_label.set_anchors_preset(Control.PRESET_CENTER)
	
	# 放在进度条右侧稍微靠上的位置
	stack_label.set_anchor_and_offset(SIDE_LEFT, 0.5, manual_offset_x + 20)
	stack_label.set_anchor_and_offset(SIDE_TOP, 0.5, manual_offset_y - 150)

# 🌟 带有缓冲池的充能逻辑
func _process(delta):
	if not is_instance_valid(trapped_player): return
	if mic_bus_index == -1: return

	var volume_db = AudioServer.get_bus_peak_volume_left_db(mic_bus_index, 0)
	
	# 如果想实时监控音量，这行取消注释 (可能会刷屏)
	# print("【定身符】麦克风音量:", volume_db)
	
	# 充能与消散逻辑
	if volume_db > noise_floor_db:
		var linear_volume = db_to_linear(volume_db)
		var energy_input = linear_volume * energy_multiplier * delta
		current_energy += energy_input
		
		# 声音大时，符纸跟着狂震
		scale = Vector2.ONE * (1.0 + linear_volume * 0.4)
	else:
		# 没声音或换气时，能量缓慢掉落，符纸恢复原状
		current_energy -= energy_decay_rate * delta
		scale = Vector2.ONE 
		
	# 锁死能量范围
	current_energy = clamp(current_energy, 0.0, required_energy)
	
	# 更新 UI 表现
	if is_instance_valid(energy_bar):
		energy_bar.value = current_energy
		
		# (可选) 充能时高亮，掉落时稍微变暗，增强反馈感
		if volume_db > noise_floor_db:
			energy_bar.modulate = Color(1.0, 1.0, 1.0) 
		else:
			energy_bar.modulate = Color(0.7, 0.7, 0.7) 
			
		# 更新调试文字 (已注释)
		#if is_instance_valid(debug_label):
			#debug_label.text = "Mic ID: %d\nVol: %.1f dB\nEnergy: %.1f / %.1f" % [
				#mic_bus_index,
				#volume_db,
				#current_energy,
				#required_energy
			#]
			
		# 冲破封印！
		if current_energy >= required_energy:
			stack_count -= 1
			if stack_count <= 0:
				_release_player()
			else:
				# 还有堆叠，重置当前能量条，更新文字
				current_energy = 0.0
				_update_stack_ui()
				print("【定身符】冲破一层！剩余层数：", stack_count)
				
				# 冲破一层时，重新播放一次惩罚视频
				if activation_video and has_node("/root/VideoManager"):
					set_process(false)
					mic_player.stop()
					var video_manager = get_node("/root/VideoManager")
					await video_manager.play_chroma_video(activation_video, {
						"chroma_color": chroma_key_color,
						"pickup_range": pickup_range,
						"fade_range": fade_range,
						"spill_suppression": spill_suppression
					})
					# 如果在这期间玩家还没死、场景还没切换，继续处理
					if is_instance_valid(self):
						mic_player.play()
						set_process(true)

func add_stack():
	stack_count += 1
	_update_stack_ui()
	print("【定身符】层数累加！当前层数：", stack_count)

func _update_stack_ui():
	if is_instance_valid(stack_label):
		stack_label.text = "x%d" % stack_count

func _release_player():
	print("【定身符】破！封印解除！")
	set_process(false) 
	
	if is_instance_valid(ui_canvas):
		ui_canvas.queue_free()
	
	if is_instance_valid(trapped_player):
		var count = trapped_player.get_meta("trap_count", 0) - 1
		trapped_player.set_meta("trap_count", count)
		
		if count <= 0:
			trapped_player.set_physics_process(true)
			trapped_player.set_process_input(true)
			if trapped_player.has_method("set_process_unhandled_input"):
				trapped_player.set_process_unhandled_input(true)
			var collision = trapped_player.get_node_or_null("CollisionShape2D")
			if collision:
				collision.set_deferred("disabled", false)
			
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	fade_tween.tween_callback(queue_free)
