extends Area2D

# --- 检查器暴露变量 ---
@export_group("Attack Settings")
@export var move_speed: float = 500.0
@export var spawn_from_left: bool = false 

@export_group("Kick Effect")
@export var kick_distance: float = 300.0 
@export var kick_duration: float = 0.3  
@export var kick_height: float = 100.0   
@export var spin_turns: float = 4.0     

# 👇 老板要求的震刀机制参数！
@export_group("Parry Settings")
@export var parry_range: float = 25.0 # 判定区间：距离玩家多近时按 A 键才有效（像素）
@export var parry_sound: AudioStream # 震刀成功时播放的音效

# --- 内部变量 ---
var is_kicked: bool = false
var is_parried: bool = false # 是否被成功震刀弹飞
var move_direction: Vector2 = Vector2.LEFT 
var target_player: Node2D = null # 提前锁定玩家，用来算距离

func _ready():
	body_entered.connect(_on_body_entered)
	if has_node("ScreenExit"):
		$ScreenExit.screen_exited.connect(queue_free)
		
	var canvas = get_tree().root.get_canvas_transform()
	var top_left = -canvas.origin / canvas.get_scale()
	var screen_rect = get_viewport().get_visible_rect()
	var current_screen_size = screen_rect.size / canvas.get_scale()
	
	if spawn_from_left:
		global_position.x = top_left.x - 200 
		if has_node("Sprite2D"):
			$Sprite2D.flip_h = true 
	else:
		global_position.x = top_left.x + current_screen_size.x + 200 
		
	global_position.y = randf_range(top_left.y + 50, top_left.y + current_screen_size.y - 50)

	target_player = get_tree().get_first_node_in_group("Player")
	if is_instance_valid(target_player):
		move_direction = (target_player.global_position - global_position).normalized()

func _process(delta: float):
	# 如果已经踢中玩家了，就不动了
	if is_kicked: return
	
	if not is_parried and is_instance_valid(target_player):
		move_direction = (target_player.global_position - global_position).normalized()
		
	position += move_direction * move_speed * delta
	
	# 如果被震刀弹飞了，让它一边转一边飞走
	if is_parried:
		rotation_degrees += 25.0

# 👇 🌟 核心魔法 1：全局输入检测，随时抓取 A 键 🌟 👇
func _input(event: InputEvent):
	# 如果已经结算了（挨踢了或被弹飞了），就不再响应按键
	if is_kicked or is_parried or not is_instance_valid(target_player): 
		return
	
	# 检测是否刚按下键盘 A 键 (防长按)
	if event is InputEventKey and event.keycode == KEY_C and event.pressed and not event.echo:
		var dist = global_position.distance_to(target_player.global_position)
		
		# 判断距离
		if dist <= parry_range:
			# 距离完美 -> 震刀成功！
			_success_parry()
		else:
			# 距离太远（按早了）
			print("【震刀】距离太远，按早了！")

# 👇 🌟 震刀成功执行逻辑 🌟 👇
func _success_parry():
	is_parried = true
	print("【震刀】叮！完美弹反！急先锋被弹飞了！")
	
	# 播放震刀成功音效
	if parry_sound and has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play(parry_sound, global_position)
	
	# 往反方向弹飞，速度翻倍！
	move_direction = -move_direction
	move_speed *= 2.0
	
	# 禁用它的碰撞体，防止它飞回去的路上又撞到玩家
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	# 飞出屏幕或 2 秒后销毁
	get_tree().create_timer(2.0).timeout.connect(queue_free)

# 👇 🌟 挨踢逻辑 (没按，或者按晚了) 🌟 👇
func _on_body_entered(body: Node2D):
	# 如果已经被弹飞了，即使穿过玩家也不触发挨踢
	if is_kicked or is_parried or not body.is_in_group("Player"):
		return
		
	is_kicked = true 
	
	print("【急先锋】你没弹反成功！接受制裁吧！")
	
	_apply_wacky_knockback(body)
	get_tree().create_timer(1.5).timeout.connect(queue_free)


# 核心：使用 Tween 实现鬼畜旋转击退效果 (保留了你的防出界逻辑，未改动)
func _apply_wacky_knockback(player: Node2D):
	if not player: return
	
	# 👇 标记玩家正在被踢，防止 player_scaler 误判为死亡并重置体型
	player.set_meta("being_kicked", true)
	
	var is_in_bear_trap = false
	var active_bear_traps = []
	if BearTrap._trapped_player == player:
		is_in_bear_trap = true
		active_bear_traps = BearTrap._active_traps.duplicate()
		
	var active_talisman = null
	for t in get_tree().get_nodes_in_group("active_binding_talisman"):
		if t.trapped_player == player:
			active_talisman = t
			break

	var dir_multiplier = 1.0 if spawn_from_left else -1.0
	var padding = 40.0 
	var canvas = player.get_canvas_transform()
	var top_left = -canvas.origin / canvas.get_scale()
	var screen_size = player.get_viewport().get_visible_rect().size / canvas.get_scale()
	
	var landing_y_offset = 0.0
	if player.has_method("is_on_floor") and player.is_on_floor():
		landing_y_offset = -5.0 

	var raw_target_x = player.global_position.x + (kick_distance * dir_multiplier)
	var min_x = top_left.x + padding
	var max_x = top_left.x + screen_size.x - padding
	var final_target_x = clamp(raw_target_x, min_x, max_x)

	var tween = create_tween().set_parallel(true)
	
	player.set_physics_process(false)
	player.set_process_input(false)
	
	var x_offset = final_target_x - player.global_position.x
	
	tween.tween_property(player, "global_position:x", final_target_x, kick_duration)\
		.set_trans(Tween.TRANS_QUART)\
		.set_ease(Tween.EASE_OUT)
		
	if is_in_bear_trap:
		for trap in active_bear_traps:
			if is_instance_valid(trap):
				tween.parallel().tween_property(trap, "global_position:x", x_offset, kick_duration)\
					.set_trans(Tween.TRANS_QUART)\
					.set_ease(Tween.EASE_OUT).as_relative()
		
	var jump_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var original_player_y = player.global_position.y
	var raw_peak_y = original_player_y - kick_height
	var min_allowed_y = top_left.y + padding
	var final_peak_y = clamp(raw_peak_y, min_allowed_y, original_player_y)
	
	var peak_y_offset = final_peak_y - original_player_y
	var fall_y_offset = (original_player_y + landing_y_offset) - final_peak_y
	
	jump_tween.tween_property(player, "global_position:y", final_peak_y, kick_duration * 0.5)
	if is_in_bear_trap:
		for trap in active_bear_traps:
			if is_instance_valid(trap):
				jump_tween.parallel().tween_property(trap, "global_position:y", peak_y_offset, kick_duration * 0.5).as_relative()
				
	jump_tween.chain().tween_property(player, "global_position:y", original_player_y + landing_y_offset, kick_duration * 0.5).set_ease(Tween.EASE_IN)
	if is_in_bear_trap:
		for trap in active_bear_traps:
			if is_instance_valid(trap):
				jump_tween.parallel().tween_property(trap, "global_position:y", fall_y_offset, kick_duration * 0.5).set_ease(Tween.EASE_IN).as_relative()
	
	var total_rotation = spin_turns * 360.0 * dir_multiplier
	tween.tween_property(player, "rotation_degrees", total_rotation, kick_duration)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_IN_OUT)
	
	var finish_tween = create_tween()
	finish_tween.tween_interval(kick_duration) 
	finish_tween.tween_callback(func():
		if is_instance_valid(player):
			player.rotation_degrees = 0.0 
			
			# 👇 移除被踢标记，恢复 player_scaler 的正常死亡检测
			if player.has_meta("being_kicked"):
				player.remove_meta("being_kicked")
			
			if active_talisman != null and is_instance_valid(active_talisman) and active_talisman.trapped_player == player:
				# 定身符状态：落地后再次被吸到定身符上
				var suck_tween = create_tween()
				suck_tween.tween_property(player, "global_position", active_talisman.global_position, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			elif is_in_bear_trap:
				# 捕兽夹状态：落地后还是被控状态，不需要恢复自由
				pass
			else:
				# 正常情况：恢复自由
				player.set_physics_process(true)
				player.set_process_input(true)
				if player.has_method("set_process_unhandled_input"):
					player.set_process_unhandled_input(true)
	)
