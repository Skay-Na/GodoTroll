extends Area2D
class_name BearTrap


@export var trigger_sound: AudioStream # 踩到捕兽夹时的音效
@export var required_presses: int = 10 # 🌟 需要按下的空格键总次数（暴露在 Inspector 中）

# 🌟 静态全局变量，用于叠加多个捕兽夹的情况
static var _active_traps: Array = []
static var _total_required: int = 0
static var _current_presses: int = 0
static var _master_trap: BearTrap = null
static var _trapped_player: Node2D = null

var is_triggered: bool = false
var ui_canvas: CanvasLayer
var escape_label: Label

func _ready():
	body_entered.connect(_on_body_entered)
	set_process(false) 
	
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.visible = false

func _on_body_entered(body: Node2D):
	if is_triggered: return 
	if not body.is_in_group("Player"): return

	is_triggered = true
	
	# 单例和重载容错：清理失效的静态变量，防止复活后按键次数叠加
	if _master_trap != null and (not is_instance_valid(_master_trap) or not _master_trap.is_inside_tree()):
		_master_trap = null
		
	if _master_trap == null:
		_trapped_player = null
		_active_traps.clear()
		_total_required = 0
		_current_presses = 0
	
	# 加入全局管理
	_active_traps.append(self)
	_total_required += required_presses
	
	# 🌟 始终将玩家吸附到当前这个夹子的中心
	body.global_position.x = global_position.x
	
	# 播放夹边动作
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("default")
	
	# 如果是第一个踩中的夹子，它将作为“主控”来管理 UI 和逻辑
	if _master_trap == null:
		_master_trap = self
		_trapped_player = body
		_current_presses = 0
		
		# 冻结玩家
		_trapped_player.set_physics_process(false)
		_trapped_player.set_process_input(false)
		if _trapped_player.has_method("set_process_unhandled_input"):
			_trapped_player.set_process_unhandled_input(false)
		if "velocity" in _trapped_player:
			_trapped_player.velocity = Vector2.ZERO
		
		# 创建 UI
		_create_stacking_ui()
		
		# 开启主控的 _process
		set_process(true)
	else:
		# 如果已有主控，由它更新 UI 显示
		_master_trap._update_ui_text()
		
	# 播放提示动画
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.visible = true
		if $AnimatedSprite2D.has_method("play"):
			$AnimatedSprite2D.play()

	# 播放音效
	if trigger_sound:
		var audio_player = AudioStreamPlayer2D.new()
		add_child(audio_player)
		audio_player.stream = trigger_sound
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)

func _create_stacking_ui():
	ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 100 
	get_tree().current_scene.add_child(ui_canvas)
	
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT) 
	ui_canvas.add_child(center_container)
	
	escape_label = Label.new()
	_update_ui_text() # 设置初始文字
	escape_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	escape_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	escape_label.add_theme_font_size_override("font_size", 40)
	escape_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	escape_label.add_theme_constant_override("outline_size", 20)
	escape_label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	center_container.add_child(escape_label)
	
	await get_tree().process_frame
	if is_instance_valid(escape_label):
		escape_label.pivot_offset = escape_label.size / 2

func _update_ui_text():
	if is_instance_valid(escape_label):
		escape_label.text = "x" + str(_total_required - _current_presses)

func _process(_delta):
	# 只有 MasterTrap 执行此逻辑
	if _master_trap != self: 
		set_process(false) # 容错关闭
		return

	if not is_instance_valid(_trapped_player) or _trapped_player.get("is_dead") == true: 
		# 🌟【修改】当玩家消失或死亡时，销毁已触发的夹子节点，保留未触发的，重置按键数
		release_all_traps(true)
		return

	# 🌟【新增】被夹住期间允许翻转方向和开火
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		if "sprite" in _trapped_player and is_instance_valid(_trapped_player.sprite):
			_trapped_player.sprite.flip_h = (direction < 0)
			
	if Input.is_key_pressed(KEY_X):
		if "weapon_manager" in _trapped_player and "shoot_point" in _trapped_player:
			var shoot_direction = -1 if _trapped_player.sprite.flip_h else 1
			_trapped_player.weapon_manager.shoot(shoot_direction, _trapped_player.shoot_point.global_position, true)

	if Input.is_action_just_pressed("ui_accept"):
		_current_presses += 1
		_update_ui_text()
		
		# 跳动动画
		if is_instance_valid(escape_label):
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_BACK)
			tween.set_ease(Tween.EASE_OUT)
			escape_label.scale = Vector2(1.5, 1.5)
			tween.tween_property(escape_label, "scale", Vector2(1.0, 1.0), 0.1)
			escape_label.modulate = Color(2.0, 2.0, 2.0) 
			tween.parallel().tween_property(escape_label, "modulate", Color(1.0, 1.0, 1.0), 0.1)

		if _current_presses >= _total_required:
			release_all_traps(true)

func release_all_traps(should_free_nodes: bool = true):
	# 恢复玩家
	if is_instance_valid(_trapped_player):
		_trapped_player.set_physics_process(true)
		_trapped_player.set_process_input(true)
		if _trapped_player.has_method("set_process_unhandled_input"):
			_trapped_player.set_process_unhandled_input(true)
	
	# 清理 UI (只在主控中存在)
	if is_instance_valid(ui_canvas):
		ui_canvas.queue_free()
	
	# 复制列表防止迭代中被修改
	var traps_to_handle = _active_traps.duplicate()
	
	# 重置静态变量
	_active_traps = []
	_total_required = 0
	_current_presses = 0
	_master_trap = null
	_trapped_player = null
	
	# 🌟【修改】根据参数决定是否销毁夹子
	for trap in traps_to_handle:
		if is_instance_valid(trap):
			if should_free_nodes:
				var spawner_script = load("res://entities/obstacles/bear_trap/bear_trap_spawner.gd")
				if spawner_script and spawner_script.has_method("remove_persistent_trap"):
					var pos_to_erase = trap.get_meta("spawn_pos") if trap.has_meta("spawn_pos") else trap.global_position
					spawner_script.remove_persistent_trap(pos_to_erase)
				trap.queue_free()
			else:
				# 如果不销毁，则重置陷阱状态，让它能再次被触发（或者仅仅是留在原地）
				trap.is_triggered = false
				if trap.has_node("AnimationPlayer"):
					trap.get_node("AnimationPlayer").play("RESET") # 恢复开启状态
				if trap.has_node("AnimatedSprite2D"):
					trap.get_node("AnimatedSprite2D").visible = false
