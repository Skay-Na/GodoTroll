extends Node2D

var _bgm_player: AudioStreamPlayer = null
var current_speed: float = 0.1 

var base_scale: Vector2 = Vector2(1, 1)

@export var custom_position_offset: Vector2 = Vector2(0, 0)
@export var bgm_stream: AudioStream

@export_group("Mash Physics (连打物理学)")
@export var min_speed: float = 0.1
@export var max_speed: float = 2.5
@export var mash_boost: float = 0.35
@export var decay_rate: float = 0.6

@export_group("Media Tuning (音画微调)")
@export var anim_min_speed: float = 0.1  
@export var anim_max_speed: float = 6.0  
@export var audio_min_pitch: float = 0.4 
@export var audio_max_pitch: float = 1.3 

var player_ref: Node2D = null
var is_active: bool = false
var expected_action: String = "ui_right"

# 记录当前还要听多少遍歌曲！
var loops_remaining: int = 1

# 👇 🌟 新增：用来显示 x2, x3 的 UI 组件
var ui_canvas: CanvasLayer
var loop_label: Label

func _ready():
	visible = false

func start_riding(player: Node2D, screen_center: Vector2):
	# ==========================================
	# 核心叠加惩罚逻辑：查重与次数增加
	# ==========================================
	var existing_horses = get_tree().get_nodes_in_group("ActiveHorse")
	for h in existing_horses:
		if h != self and h.is_active:
			h.loops_remaining += 1 # 给正在骑的那匹马增加一次播放次数！
			h.update_loop_ui()     # 👇 🌟 呼叫老马更新屏幕上的 xN 数字！
			print("【摇摇马】惨遭叠加！当前还需要播放 ", h.loops_remaining, " 遍！")
			queue_free() # 把多生成的自己销毁掉，防止两匹马重叠
			return
			
	# 如果是第一次骑马，把自己加入活跃名单
	add_to_group("ActiveHorse")
	loops_remaining = 1

	base_scale = scale 
	player_ref = player
	
	var count = player_ref.get_meta("trap_count", 0)
	player_ref.set_meta("trap_count", count + 1)
	
	player_ref.set_physics_process(false)
	player_ref.set_meta("riding_horse", true) 
	player_ref.set_process_input(false) 
	if player_ref.has_method("set_process_unhandled_input"):
		player_ref.set_process_unhandled_input(false)
	
	for child in player_ref.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			child.visible = false
	
	var collision = player_ref.get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", true)
	
	# ==========================================
	# 👇 🌟 新增：凭空捏造一个极具压迫感的 xN 文本 👇
	# ==========================================
	ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 120 # 确保在最顶层
	get_tree().current_scene.add_child(ui_canvas)
	
	loop_label = Label.new()
	loop_label.set_anchors_preset(Control.PRESET_CENTER) # 居中
	
	# 让文字巨大、血红、带白色粗边框！
	loop_label.add_theme_font_size_override("font_size", 40) 
	loop_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) 
	loop_label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 1.0)) 
	loop_label.add_theme_constant_override("outline_size", 20)
	
	loop_label.position.y -= -80 # 稍微往上抬一点，不要正好挡住马里奥的脸
	loop_label.text = "" # 1遍的时候不显示，留空
	ui_canvas.add_child(loop_label)
	# ==========================================
	
	global_position = screen_center + custom_position_offset
	visible = true
	is_active = true
	current_speed = min_speed 
	
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("rock") 
		$AnimationPlayer.speed_scale = anim_min_speed
	
	if bgm_stream:
		_bgm_player = AudioStreamPlayer.new()
		add_child(_bgm_player)
		_bgm_player.stream = bgm_stream
		_bgm_player.bus = "Music"
		_bgm_player.pitch_scale = audio_min_pitch 
		_bgm_player.play()
		
		_bgm_player.finished.connect(_on_bgm_finished)
	else:
		_start_failsafe_timer()
	
	print("【摇摇马】召唤成功！当前需要听 1 遍。")

# 👇 🌟 新增：专门用来更新屏幕中心数字的函数
func update_loop_ui():
	if is_instance_valid(loop_label):
		if loops_remaining > 1:
			loop_label.text = "x" + str(loops_remaining) # 比如显示 "x2", "x3"
			
			# (可选) 每次数字变大时，让文字有一个轻微的弹跳动画增强打击感
			var tween = create_tween()
			loop_label.scale = Vector2(1.5, 1.5)
			tween.tween_property(loop_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BOUNCE)
		else:
			loop_label.text = "" # 如果只剩 1 遍了，就隐藏数字

func _on_bgm_finished():
	loops_remaining -= 1 # 播完一遍，扣除一次
	update_loop_ui()     # 👇 🌟 播完一遍，更新 UI（比如从 x3 降到 x2）
	
	if loops_remaining > 0:
		print("【摇摇马】还没完呢！还要再听 ", loops_remaining, " 遍！")
		if _bgm_player:
			_bgm_player.play() 
		else:
			_start_failsafe_timer()
	else:
		_finish_riding() 

func _start_failsafe_timer():
	await get_tree().create_timer(5.0).timeout
	_on_bgm_finished()

func _process(delta: float):
	if not is_active: return

	if current_speed > min_speed:
		current_speed -= decay_rate * delta
		current_speed = max(current_speed, min_speed) 

	if _bgm_player:
		_bgm_player.pitch_scale = remap(current_speed, min_speed, max_speed, audio_min_pitch, audio_max_pitch)
		
	if has_node("AnimationPlayer"):
		$AnimationPlayer.speed_scale = remap(current_speed, min_speed, max_speed, anim_min_speed, anim_max_speed)
	
	if is_instance_valid(player_ref):
		var player_current_size = abs(player_ref.scale.x)
		scale = base_scale * player_current_size
		
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.global_rotation = 0

func _input(event):
	if not is_active: return
	
	if event.is_action_pressed(expected_action):
		expected_action = "ui_left" if expected_action == "ui_right" else "ui_right"
		
		current_speed += mash_boost
		current_speed = min(current_speed, max_speed) 

func _finish_riding():
	is_active = false
	
	# 👇 🌟 结束时，把捏造出来的数字画布销毁掉，打扫战场
	if is_instance_valid(ui_canvas):
		ui_canvas.queue_free()
		
	if is_instance_valid(player_ref):
		player_ref.remove_meta("riding_horse") 
		
		# 只有摇摇马才影响隐身，定身符不影响隐身，所以必定恢复可见
		for child in player_ref.get_children():
			if child is Sprite2D or child is AnimatedSprite2D:
				child.visible = true
				
		var count = player_ref.get_meta("trap_count", 0) - 1
		player_ref.set_meta("trap_count", count)
		
		if count <= 0:
			player_ref.set_physics_process(true)
			player_ref.set_process_input(true)
			if player_ref.has_method("set_process_unhandled_input"):
				player_ref.set_process_unhandled_input(true)
				
			var collision = player_ref.get_node_or_null("CollisionShape2D")
			if collision:
				collision.set_deferred("disabled", false)

	
	if has_node("AnimationPlayer"):
		$AnimationPlayer.stop()
		
	print("【摇摇马】一曲肝肠断！音乐彻底结束，玩家恢复自由！")
	queue_free()
