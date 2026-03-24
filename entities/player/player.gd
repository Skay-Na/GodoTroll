extends CharacterBody2D

# ================= 状态枚举 =================
enum PlayerState {SMALL, BIG, FLOWER, SUPERMAN}
var current_state = PlayerState.SMALL

enum ActionState {NORMAL, SLIDING_FLAG, WALKING_TO_CASTLE}
var action_state = ActionState.NORMAL

# ================= 物理参数 =================
@export_group("Movement")
@export var walk_speed: float = 100.0
@export var run_speed: float = 145.0
@export var fly_speed: float = 300.0 # 新增：超人形态的飞行速度
@export var fly_dash_speed: float = 550.0 # 新增：超人按下 Shift 时的冲刺速度
@export var acceleration: float = 500.0
@export var friction: float = 800.0

@export_group("Jumping")
@export var jump_velocity: float = -388.4
@export var run_jump_velocity: float = -420.0
@export var fall_gravity_multiplier: float = 0.8
@export var short_jump_gravity_multiplier: float = 4.0
@export var jump_buffer_time: float = 0.1
@export var coyote_time: float = 0.1

# ================= 状态变量 =================
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_invincible: bool = false
var is_jumping: bool = false
var is_dead: bool = false
var truck_push_time_left: float = 0.0

var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0
@onready var respawn_position = global_position
@export var superman_duration: float = 10.0 # 超人形态持续时间（秒）
var superman_time_left: float = 0.0         # 当前剩余时间
var pre_superman_state: PlayerState = PlayerState.SMALL # 记录变身超人前的状态
@export_group("Effects")
@export var enable_trail: bool = true # 🌟拖影功能总开关

# ================= 节点引用 =================
@onready var weapon_manager = $WeaponManager
@onready var shoot_point = $ShootPoint
@onready var anim_player = $AnimationPlayer
@onready var sprite = $Sprite2D
@onready var trail_effect = $TrailEffect # 🌟获取拖影组件节点

const GAME_OVER_SCREEN_SCENE = preload("uid://bk6vbpe17fbgb")

# ================= 生命周期 =================
func _ready():
	# 🌟【新增修复】确保进入新场景时恢复运行，防止卡死
	get_tree().paused = false
	
	if GameManager.player_state != PlayerState.SMALL:
		current_state = GameManager.player_state as PlayerState
		
	# 🌟【新增修复】先无条件清理场景中多余的 Player（比如编辑器摆放的占位符）
	var players = get_tree().get_nodes_in_group("Player")
	for p in players:
		if p != self and not p.is_queued_for_deletion():
			# 如果是没有目标 ID 也无存档点，才需要继承占位符的位置
			if GameManager.target_teleporter_id == "" and GameManager.checkpoint_position == Vector2.ZERO:
				global_position = p.global_position
				respawn_position = p.global_position
				print("🚩 已同步到关卡预设 Player 位置")
			p.queue_free()
			print("🚩 已清理多余的占位符 Player 防止冲突")
			break
			
	if GameManager.target_teleporter_id != "":
		# 强制同步查找，避免 call_deferred 导致的一帧相机或位置撕裂
		_teleport_to_start_id()
	elif GameManager.checkpoint_position != Vector2.ZERO:
		# 🌟【新增】如果有存档点，优先出生在存档点
		global_position = GameManager.checkpoint_position
		respawn_position = GameManager.checkpoint_position
	
	update_animation()
	add_to_group("Player")

func _physics_process(delta):
	# === 新增：处理超人倒计时 ===
	_handle_superman_timer(delta)
	
	# 1. 处理特殊状态挂起 (卡车脱离倒计时)
	_handle_truck_timer(delta)

	# 2. 处理关卡特殊演出 (旗杆/通关)
	if action_state != ActionState.NORMAL:
		_handle_special_actions(delta)
		return

	# 3. 如果没按键权限 (如变身时停)，直接跳过物理计算
	if not is_processing_input():
		return

	# 4. 核心移动与跳跃逻辑拆分
	_handle_movement(delta)
	_handle_jump(delta)
	
	# 应用位移
	move_and_slide()
	
	# 实时判断并处理拖影状态
	_handle_trail_effect()

	# 5. 碰撞检测与边界保护
	_check_bounds()
	check_head_collision()
	update_animation()

	# 6. 武器发射
	if Input.is_key_pressed(KEY_X):
		var shoot_direction = -1 if sprite.flip_h else 1
		weapon_manager.shoot(shoot_direction, shoot_point.global_position, is_on_floor())

	# 7. 坠崖检测
	if global_position.y > 200:
		die(true)

# ================= 核心逻辑拆分 =================
func _handle_superman_timer(delta):
	if current_state == PlayerState.SUPERMAN and superman_time_left > 0:
		superman_time_left -= delta
		# === 新增：最后2秒闪烁警告 ===
		if superman_time_left <= 2.0 and superman_time_left > 0:
			# 利用 fmod (浮点数取余) 配合剩余时间，制造一闪一闪的效果
			# 乘以 10.0 控制闪烁频率，数值越大闪得越快
			if fmod(superman_time_left * 10.0, 1.0) > 0.5:
				sprite.modulate.a = 0.3 # 变透明
			else:
				sprite.modulate.a = 1.0 # 恢复不透明
		else:
			sprite.modulate.a = 1.0 # 2秒前保持完全不透明
		# =============================
		if superman_time_left <= 0:
			# 时间到，强制恢复为变身前的状态
			change_state(pre_superman_state, true)
			
func _handle_truck_timer(delta):
	if truck_push_time_left > 0:
		truck_push_time_left -= delta
		if truck_push_time_left <= 0:
			if current_state != PlayerState.SUPERMAN:
				set_collision_mask_value(1, true)
				print("【玩家】卡车已开走，重新开启墙壁(Mask 1)碰撞！")

func _handle_special_actions(delta):
	match action_state:
		ActionState.SLIDING_FLAG:
			velocity = Vector2(0, 120)
			move_and_slide()
			if is_on_floor():
				action_state = ActionState.NORMAL
				set_process_input(true)
		ActionState.WALKING_TO_CASTLE:
			velocity.y += gravity * delta
			velocity.x = 100
			move_and_slide()
	update_animation()

func _handle_movement(delta):
	## === 超人飞行逻辑 ===
	if current_state == PlayerState.SUPERMAN:
		# 判断是否按下了 Shift 键 (兼容原有的 run 动作绑定)
		var is_dashing = Input.is_action_pressed("run") or Input.is_key_pressed(KEY_SHIFT)
		var current_fly_speed = fly_dash_speed if is_dashing else fly_speed
		
		# 获取二维方向输入（支持八向飞行）
		var fly_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		# 使用当前决定的飞行速度来计算移动
		velocity = velocity.move_toward(fly_dir * current_fly_speed, acceleration * delta * 2.0)
		
		# 控制朝向翻转
		if fly_dir.x != 0:
			sprite.flip_h = (fly_dir.x < 0)
		return 
	# ==========================
	var current_speed = run_speed if (Input.is_action_pressed("run") or Input.is_key_pressed(KEY_X)) else walk_speed
	var direction = Input.get_axis("ui_left", "ui_right")
	var is_breaking = Input.is_action_pressed("ui_down") and is_on_floor()

	if direction:
		if not is_breaking:
			velocity.x = move_toward(velocity.x, direction * current_speed, acceleration * delta)
		
		# 当人物向指定方向移动、在空中、或者下蹲时，允许翻转精灵图
		if sign(velocity.x) == direction or not is_on_floor() or is_breaking:
			sprite.flip_h = (direction < 0)

	if not direction or is_breaking:
		var current_friction = friction * 3.0 if is_breaking else friction
		velocity.x = move_toward(velocity.x, 0, current_friction * delta)

func _handle_jump(delta):
	# 新增：超人形态没有重力也不需要跳跃
	if current_state == PlayerState.SUPERMAN:
		return
	# 计时器维护
	if jump_buffer_timer > 0: jump_buffer_timer -= delta
	if coyote_timer > 0: coyote_timer -= delta
		
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = jump_buffer_time
		
	if is_on_floor():
		coyote_timer = coyote_time
		is_jumping = false
		
	# 执行跳跃
	if jump_buffer_timer > 0 and coyote_timer > 0:
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		is_jumping = true
		velocity.y = run_jump_velocity if abs(velocity.x) >= run_speed * 0.9 else jump_velocity
		_play_sound("jump", current_state != PlayerState.SMALL)

	# 重力处理 (小跳与下落增强)
	if not is_on_floor():
		var current_gravity = gravity
		if velocity.y < 0 and not Input.is_action_pressed("ui_accept"):
			current_gravity *= short_jump_gravity_multiplier
		elif velocity.y > 0:
			current_gravity *= fall_gravity_multiplier
		velocity.y += current_gravity * delta


# 🌟【新增】拖影实时控制逻辑
func _handle_trail_effect():
	if not trail_effect: return
	
	# 如果总开关关闭，直接停止拖影并返回
	if not enable_trail:
		trail_effect.stop_trail()
		return
		
	var should_trail = false
	
	if current_state == PlayerState.SUPERMAN:
		# 超人形态：如果飞行速度超过基础飞行速度的 80% (说明正在高速移动或冲刺)，则开启拖影
		if velocity.length() > fly_speed * 0.8:
			should_trail = true
	else:
		# 普通形态：只要水平速度大于走路速度加一点点缓冲，就说明正在奔跑，开启拖影
		if abs(velocity.x) > walk_speed + 10:
			should_trail = true
			
	# 根据判定结果实时开启或关闭
	if should_trail:
		trail_effect.start_trail()
	else:
		trail_effect.stop_trail()


func _check_bounds():
	var start_line_x = 20.0
	if global_position.x < start_line_x:
		global_position.x = start_line_x
		if truck_push_time_left > 0:
			if current_state != PlayerState.SUPERMAN:
				set_collision_mask_value(1, true)
			truck_push_time_left = 0.0

# ================= 碰撞与战斗逻辑 =================

func check_head_collision():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()
		var collider = collision.get_collider()
		if not collider: continue
		
		## === 超人形态专属判定 ===
		if current_state == PlayerState.SUPERMAN:
			# 【修改】不再撞碎砖块，改为直接穿过（无视地形）
			# 地形碰撞已在 change_state 中通过 collision_mask 禁用
			
			# 2. 撞死怪物
			if collider.has_method("die_by_stomp"):
				collider.die_by_stomp(self)
			elif collider.is_in_group("Enemy") and collider.has_method("die"):
				collider.die()
				
			continue 
		# ========================

		# 1. 原本的踩怪 (从上方)
		if normal.y < -0.5:
			if collider.has_method("die_by_stomp"):
				collider.die_by_stomp(self)
				velocity.y = -300
				
		# 2. 原本的顶砖块 (从下方)
		elif normal.y > 0.5:
			velocity.y = 0 
			var is_big = (current_state != PlayerState.SMALL)
			if collider.has_method("hit_by_mario"):
				collider.hit_by_mario(is_big)
			elif collider is TileMapLayer and collider.has_method("hit_tile_by_mario"):
				velocity.y = 70
				var hit_pos = collision.get_position() - normal * 2.0
				var map_pos = collider.local_to_map(collider.to_local(hit_pos))
				collider.hit_tile_by_mario(map_pos, is_big)
				
		# 3. 侧面碰撞 (受伤或踢龟壳)
		elif abs(normal.x) > 0.5:
			if collider.get("is_dead") == false:
				if collider.has_method("kick_shell") and collider.get("current_state") == 1:
					collider.kick_shell(self)
				elif collider.has_method("die_by_stomp") or collider.is_in_group("Enemy"):
					take_damage()
					
		# 4. 滑行龟壳特判
		if collider.has_method("kick_shell") and collider.get("current_state") == 2:
			take_damage()

# ================= 状态切换与动画 =================

func update_animation():
	if is_dead: return
	var prefix = ["small_", "big_", "flower_", "superman_"][current_state]
	# === 超人飞行状态动画 ===
	if current_state == PlayerState.SUPERMAN:
		# 获取玩家的输入方向
		var fly_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		if fly_dir == Vector2.ZERO and velocity.length() < 10.0:
			# 没有输入且速度几乎为0时，播放悬浮待机
			play_anim(prefix + "idle" if anim_player.has_animation(prefix + "idle") else "small_idle")
		else:
			# 有输入或正在移动时，播放飞行
			# 如果你有急转动画，也可以在这里加判断：fly_dir.x 和 velocity.x 符号相反时播放 skid
			play_anim(prefix + "fly" if anim_player.has_animation(prefix + "fly") else "big_jump")
		return
	# ==============================
	# 1. 特殊状态优先
	if action_state == ActionState.SLIDING_FLAG:
		play_anim(prefix + "climb" if anim_player.has_animation(prefix + "climb") else prefix + "idle")
		return
	elif action_state == ActionState.WALKING_TO_CASTLE:
		play_anim(prefix + "walk")
		return

	# 2. 空中状态
	if not is_on_floor():
		play_anim(prefix + "jump")
		return

	# 3. 地面状态
	var is_breaking = Input.is_action_pressed("ui_down")
	var input_dir = Input.get_axis("ui_left", "ui_right")
	
	if velocity.x == 0:
		play_anim(prefix + "duck" if is_breaking and current_state != PlayerState.SMALL else prefix + "idle")
	else:
		# 正在滑动/急停 (包括下蹲滑动，或反方向拉摇杆)
		if is_breaking or (input_dir != 0 and sign(velocity.x) != sign(input_dir)):
			if is_breaking and current_state != PlayerState.SMALL:
				play_anim(prefix + "duck")
			else:
				play_anim(prefix + "skid")
		else:
			play_anim(prefix + "run" if (Input.is_action_pressed("run") or Input.is_key_pressed(KEY_X)) else prefix + "walk")

func play_anim(anim_name: String):
	if anim_player.has_animation(anim_name) and anim_player.current_animation != anim_name:
		anim_player.play(anim_name)

func change_state(new_state: PlayerState, is_forced: bool = false):
	if current_state == new_state: return
	# === 新增：超人状态拦截强化物 ===
	# 如果当前是超人，且不是强制切换（is_forced = false），则拒绝变身
	if current_state == PlayerState.SUPERMAN and not is_forced:
		return
	# ==============================
	# === 新增：超人形态切换碰撞层屏蔽 (Layer 1 & Layer 5) ===
	if current_state == PlayerState.SUPERMAN:
		# 退出超人时恢复地形和地面碰撞
		set_collision_mask_value(1, true)
		set_collision_mask_value(5, true)
		
	current_state = new_state
	
	if current_state == PlayerState.SUPERMAN:
		# 进入超人时禁用地形 (Layer 1) 和地面 (Layer 5) 碰撞实现穿墙
		set_collision_mask_value(1, false)
		set_collision_mask_value(5, false)
	# ==============================
	
	# === 新增：同步给 GameManager，方便其他脚本判断 ===
	if GameManager.get("player_state") != null:
		GameManager.player_state = new_state
	# ============================================
	anim_player.stop()
	update_animation()
	play_transform_animation()

func play_transform_animation():
	get_tree().paused = true
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(false)
	velocity.x = 0
	velocity.y = 0
	
	if current_state == PlayerState.SUPERMAN:
		var rise_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		rise_tween.tween_property(self, "global_position:y", global_position.y - 40.0, 0.64).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for i in range(4):
		tween.tween_property(sprite, "modulate:a", 0.0, 0.08)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.08)
		
	tween.finished.connect(func():
		sprite.modulate.a = 1.0
		set_process_input(true)
		self.process_mode = Node.PROCESS_MODE_INHERIT
		get_tree().paused = false
	)

# ================= 伤害与死亡 =================

func start_invincibility(duration: float = 1.5):
	if is_invincible: return
	is_invincible = true
	
	var old_layer = collision_layer
	var old_mask = collision_mask
	
	# 暂时禁用与部分物体的碰撞 (如敌人)
	set_collision_mask_value(4, false)
	
	var inv_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var flash_count = int(duration / 0.16)
	for i in range(flash_count):
		inv_tween.tween_property(sprite, "modulate:a", 0.0, 0.08)
		inv_tween.tween_property(sprite, "modulate:a", 1.0, 0.08)
		
	inv_tween.finished.connect(func():
		is_invincible = false
		collision_layer = old_layer
		collision_mask = old_mask
		sprite.modulate.a = 1.0
	)

func take_damage():
	# 新增 SUPERMAN 免疫伤害
	if is_invincible or current_state == PlayerState.SUPERMAN: return
	
	if current_state == PlayerState.SMALL:
		die()
	else:
		change_state(PlayerState.SMALL)
		_play_sound("damage")
		# 触发无敌帧
		start_invincibility(2.0)

func die(is_falling_into_pit: bool = false):
	if is_dead: return
	is_dead = true
	
	# === 新增：死亡瞬间强制恢复为 SMALL 状态并恢复碰撞 ===
	if current_state == PlayerState.SUPERMAN:
		set_collision_mask_value(1, true)
		set_collision_mask_value(5, true)
	current_state = PlayerState.SMALL
	superman_time_left = 0.0 # 清除超人倒计时
	# 同步更新 GameManager 中的全局状态，防止关卡重置后读档错误
	if GameManager.get("player_state") != null:
		GameManager.player_state = PlayerState.SMALL
	# ============================================

	_play_sound("death")
	
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true) 
	
	var delay_tween = create_tween()
	if is_falling_into_pit:
		delay_tween.tween_interval(1.0)
	else:
		# 此时 current_state 已经是 SMALL，prefix 必定为 "small_"
		var prefix = ["small_", "big_", "flower_", "superman_"][current_state]
		var death_anim = prefix + "death"
		if anim_player.has_animation(death_anim):
			anim_player.play(death_anim)
		elif anim_player.has_animation("dead"):
			anim_player.play("dead")
		var start_pos = global_position
		delay_tween.tween_property(self , "global_position:y", start_pos.y - 100, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		delay_tween.tween_property(self, "global_position:y", start_pos.y + 600, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	delay_tween.finished.connect(_show_game_over_screen)
	
	if GameManager.has_method("save_pending_traps"):
		GameManager.save_pending_traps()
		
	# 呼叫 GameManager 里的清场函数
	GameManager.clear_all_trash()

func _show_game_over_screen():
	var go_screen = GAME_OVER_SCREEN_SCENE.instantiate()
	get_tree().current_scene.add_child(go_screen)
	get_tree().paused = true
	go_screen.confirmed.connect(_respawn)

func _respawn():
	get_tree().paused = false
	GameManager.lose_life()
	global_position = respawn_position
	velocity = Vector2.ZERO
	scale = Vector2.ONE
	set_physics_process(true)
	$CollisionShape2D.set_deferred("disabled", false)
	
	# === 确保复活时双端状态都是 SMALL ===
	current_state = PlayerState.SMALL
	if GameManager.get("player_state") != null:
		GameManager.player_state = PlayerState.SMALL
	superman_time_left = 0.0
	# ====================================
	
	is_invincible = false
	is_dead = false
	sprite.modulate.a = 1.0
	update_animation()
	GameManager.reset_level.emit()

# ================= 杂项功能 =================

func apply_truck_push(push_velocity: Vector2):
	if not is_processing_input(): return
	velocity = push_velocity
	set_collision_mask_value(1, false)
	truck_push_time_left = 0.2
	
	var tween = create_tween()
	sprite.modulate = Color(2, 0.5, 0.5) 
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func start_flag_slide(pole_x):
	action_state = ActionState.SLIDING_FLAG
	global_position.x = pole_x
	velocity = Vector2.ZERO
	set_process_input(false)
	_play_sound("flagpole")

func _teleport_to_start_id():
	var tid = GameManager.target_teleporter_id
	GameManager.target_teleporter_id = "" # 处理后立即清空防重复
	
	# 先尝试常规查询（如果传送门的 _ready 已经执行完毕）
	for t in get_tree().get_nodes_in_group("teleporters"):
		if t.get("teleporter_id") == tid:
			global_position = t.global_position
			respawn_position = t.global_position
			print("✅ 常规查询成功传送，位置：", global_position)
			return
			
	# 若没找到，说明传送门的 _ready 还没执行，组不存在，手动遍历全树查找
	var found = _search_teleporter_in_node(get_tree().current_scene, tid)
	if found:
		global_position = found.global_position
		respawn_position = found.global_position
		print("✅ 深度遍历查询成功传送，位置：", global_position)
	else:
		print("❌ 错误：在当前场景深度搜索都没找到 ID 为 ", tid, " 的传送门！")

func _search_teleporter_in_node(node: Node, tid: String) -> Node:
	if not node: return null
	# 只检查具有 teleporter_id 且不为空的节点
	if "teleporter_id" in node and node.get("teleporter_id") == tid:
		return node
	for child in node.get_children():
		var found = _search_teleporter_in_node(child, tid)
		if found: return found
	return null

func _input(event):
	# 测试用：循环切换状态
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		change_state((current_state + 1) % 3 as PlayerState) 
	# 新增：N键激活/取消超人形态
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		if current_state == PlayerState.SUPERMAN:
			# 手动提前取消，强制恢复原来的状态
			superman_time_left = 0.0
			change_state(pre_superman_state, true)
		else:
			# 激活超人形态
			pre_superman_state = current_state # 记住变身前的状态
			superman_time_left = superman_duration # 重置倒计时
			change_state(PlayerState.SUPERMAN, true) # 强制变身

# 辅助播放音效
func _play_sound(sound_name: String, arg = null):
	if has_node("/root/SoundManager"):
		var sm = get_node("/root/SoundManager")
		match sound_name:
			"jump": sm.play_jump(arg)
			"damage": sm.play_damage()
			"death": sm.play_death()
			"flagpole": sm.play_flagpole()
