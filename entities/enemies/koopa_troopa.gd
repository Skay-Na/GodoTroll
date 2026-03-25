extends CharacterBody2D

# ==========================================
# 慢慢龟 (Koopa Troopa) 怪物 AI 逻辑
# ==========================================

enum State {
	WALK,
	SHELL_IDLE,
	SHELL_SLIDE
}

var current_state = State.WALK

const WALK_SPEED = 40.0
const SLIDE_SPEED = 200.0

var current_direction = -1 # 默认向左走 (-1)

# 重力，从项目设置里获取
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var is_dead = false
var initial_position: Vector2

func _ready():
	# 物理処理を初期状態で停止します (初始状态下停止物理处理，防止乱飞)
	set_physics_process(false)
	
	# 记录初始出生点，并监听全图重置信号
	initial_position = global_position
	GameManager.reset_level.connect(_on_reset_level)
	
	_play_anim("walk")


# 响应玩家死亡复活时的全图重置
func _on_reset_level():
	# 🌟【健壮性修复】如果节点已经不在场景树中，直接跳过
	if not is_inside_tree():
		return
		
	# 如果已经被踩死了，不再复活
	if is_dead:
		return
		
	# 先暂停物理，防止瞬间传送后的第一帧因重力穿透地板
	set_physics_process(false)
	
	# 回到原位并立刻恢复为走路起始状态
	global_position = initial_position
	velocity = Vector2.ZERO
	current_direction = -1
	current_state = State.WALK
	_play_anim("walk")
	
	# 恢复碰撞层，与场景文件保持一致
	# collision_layer = 8  (Layer 4: 敌人层)
	# collision_mask  = 26 (Layer 2 + Layer 4 + Layer 5: 玩家 + 敌人 + 地形)
	set_collision_layer(8)
	set_collision_mask(26)
	
	# 等一帧再恢复物理，让引擎在新坐标稳定
	await get_tree().process_frame
	if not is_dead:
		# 画面内にあるか確認します (检查重置后是否在屏幕内，如果在屏幕内才恢复物理)
		if $VisibleOnScreenNotifier2D.is_on_screen():
			set_physics_process(true)

func _physics_process(delta):
	if is_dead:
		return
		
	# 1. 应用重力
	if not is_on_floor():
		velocity.y += gravity * delta

	# 2. 根据状态改变 X 轴速度
	match current_state:
		State.WALK:
			velocity.x = current_direction * WALK_SPEED
			# 走路时根据方向翻转贴图 (-1 向左不翻转，1 向右翻转)
			$AnimatedSprite2D.flip_h = (current_direction > 0)
		State.SHELL_IDLE:
			# 【关键点】：如果正在被踢（0.1s安全期内），逻辑上虽然是IDLE，但物理上要立刻滑起来！
			if is_kicking:
				velocity.x = current_direction * SLIDE_SPEED
			else:
				# 否则常规摩擦力停车
				velocity.x = move_toward(velocity.x, 0, WALK_SPEED * delta * 15)
		State.SHELL_SLIDE:
			# 无敌风火轮状态，全速前进
			velocity.x = current_direction * SLIDE_SPEED

	# 3. 移动并处理物理碰撞
	move_and_slide()
	
	# --------- 基于法线的玩家交互检测 ---------
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# 仅在被主动撞击时处理碰撞反弹或交互
		if collider and (collider.name == "Player" or collider.is_in_group("Player")):
			var normal = collision.get_normal()
			
			if current_state == State.SHELL_SLIDE:
				# 【核心修复】：滑行状态下无视法线，碰到即受伤
				if collider.has_method("take_damage"):
					collider.take_damage()
			else:
				# 非滑行状态（走路或静止）：保留法线判定
				# normal.y 大于 0.5 表示 Player 在正上方且向下压
				if normal.y > 0.5:
					die_by_stomp(collider)
				elif abs(normal.x) > 0.5: # 侧边物理接触
					if current_state == State.WALK:
						if collider.has_method("take_damage"):
							collider.take_damage()
					elif current_state == State.SHELL_IDLE:
						# 防止在 0.1s 延迟期间重复调用
						if not is_kicking:
							kick_shell(collider)
	# ------------------------------------------------

	# 4. 如果撞墙了，或者碰到了其他障碍物（包括其他怪物），就反向继续走
	if is_on_wall():
		if current_state == State.WALK or current_state == State.SHELL_SLIDE:
			var should_bounce = false
			
			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)
				var collider = collision.get_collider()
				
				# 忽略马里奥（碰到马里奥由专门的 Hitbox 处理）
				if collider and collider.name == "Player":
					continue
					
				# 撞到地图瓦片（墙面、水管等），必然反弹
				if collider is TileMapLayer:
					should_bounce = true
					break
				
				if collider:
					if current_state == State.WALK:
						# 【普通走路模式】：碰到不管是静止水管还是其他怪物（包含乌龟、板栗仔），统统回头
						should_bounce = true
						break
					elif current_state == State.SHELL_SLIDE:
						# 【风火轮滑行模式】：碰到水管墙壁这类没有死穴的物体才回头，碰到怪物（有die_by_stomp接口的）则不回头直接创飞
						if not collider.has_method("die_by_stomp"):
							should_bounce = true
							break
			
			if should_bounce:
				# 获取碰撞点法线，根据反作用力方向进行转向
				var wall_normal_x = get_wall_normal().x
				if abs(wall_normal_x) > 0.1:
					current_direction = sign(wall_normal_x)
				else:
					current_direction = -current_direction
			
	# 5. 滑行状态下的“绝对破盾”物理判定：只相信刚体的真实碰撞！
	if current_state == State.SHELL_SLIDE:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			
			if collider and collider != self and collider.has_method("die_by_stomp"):
				if "is_dead" in collider and not collider.is_dead:
					print("【刚猛龟壳】在物理引擎碰撞层创飞了怪物：", collider.name)
					
					# 【核心杀招】：趁物理引擎还没反应过来算出反作用力，
					# 直接拔掉对方在这辈子的最后一丝碰撞体积（所有层级强清空为0）！
					# 这样一来，下一帧的时候，哪怕是 Godot 的底层引擎也会以为撞到的是一团空气，直接无视并平滑穿透过去。
					collider.set_collision_layer(0)
					collider.set_collision_mask(0)
					
					collider.die_by_stomp(self)

# ================== 状态切换逻辑 ==================

func become_shell_idle(player):
	current_state = State.SHELL_IDLE
	_play_anim("shell")
	
	# 踩乌龟本身也可以跳起来
	if player and "velocity" in player:
		player.velocity.y = -300

var is_kicking = false
func kick_shell(player):
	is_kicking = true
	# 立即切换动画，保证视觉响应
	_play_anim("shell")
	
	# 播放踢飞音效 (立即播放)
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_kick(global_position)
	
	# 根据马里奥所在的相对位置，决定龟壳的发射方向
	if player.global_position.x < global_position.x:
		current_direction = 1  # 马里奥在左边，往右踢
	else:
		current_direction = -1 # 马里奥在右边，往左踢
		
	# 【核心修复】：等待 0.1 秒后再正式切换到核心危险状态 SHELL_SLIDE
	# 这 0.1s 内，壳在物理上已经由于上面的 is_kicking 飞出去了，但状态还没变，马里奥是安全的
	await get_tree().create_timer(0.1).timeout
	
	current_state = State.SHELL_SLIDE
	is_kicking = false

# ================== 其他杂项 ==================

func _play_anim(anim_name: String):
	if $AnimatedSprite2D.sprite_frames.has_animation(anim_name):
		$AnimatedSprite2D.play(anim_name)

var last_stomp_frame = -1

# 对外暴露的接口：用来处理踩踏事件
func die_by_stomp(attacker = null):
	# 帧守卫：防止马里奥脚本和怪物脚本在同一物理帧内重复触发，导致连跳状态（直接从走变死）
	var current_frame = Engine.get_physics_frames()
	if is_dead or last_stomp_frame == current_frame: 
		return
	last_stomp_frame = current_frame
	
	if current_state == State.WALK or current_state == State.SHELL_SLIDE:
		# 第一次踩，或者在滑行状态下踩，变成静止龟壳
		become_shell_idle(attacker)
	elif current_state == State.SHELL_IDLE:
		# 在龟壳状态下再被踩，就彻底死亡
		is_dead = true
		
		# 禁用物理和所有碰撞盒
		set_physics_process(false)
		$CollisionShape2D.set_deferred("disabled", true)
		
		_play_anim("dead")
		
		# 给马里奥提供弹跳反馈（如果是马里奥触发的）
		if attacker and "velocity" in attacker:
			attacker.velocity.y = -300
			
		# 飞出屏幕外的视觉特效
		var tween = create_tween()
		var start_y = global_position.y
		tween.tween_property(self, "global_position:y", start_y - 100, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "global_position:y", start_y + 600, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
		tween.finished.connect(func(): queue_free())

# 专供火球或非踩踏类杀穿调用的接口
func die():
	if is_dead: return
	is_dead = true
	
	# 播放踢飞/死亡音效
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_kick(global_position)
	
	# 彻底关闭碰撞
	set_collision_layer(0)
	set_collision_mask(0)
	set_physics_process(false)
	
	# 视觉效果：翻转并飞出屏幕
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.flip_v = true
		
	var tween = create_tween()
	var start_y = global_position.y
	# 向上弹一下，再掉出屏幕
	tween.tween_property(self, "global_position:y", start_y - 80, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", start_y + 600, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.finished.connect(func(): queue_free())

# 画面に入った時のシグナル受信関数 (进入屏幕时的信号接收函数)
func _on_visible_on_screen_notifier_2d_screen_entered():
	if not is_dead:
		# 物理処理を再開します (恢复物理处理，让怪物开始活动)
		set_physics_process(true)
