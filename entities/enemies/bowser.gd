extends CharacterBody2D

# --- 基础属性 ---
const SPEED = 60.0          # 巡逻速度
const JUMP_VELOCITY = -350.0 # 跳跃力度
const GRAVITY = 900.0       # 重力

# --- AI 状态与边界 ---
var direction = -1 # 初始向左走 (-1是左, 1是右)
var min_x = 0.0
var max_x = 0.0
var patrol_distance = 100.0 # 初始位置左右各巡逻100像素

# --- [新增] 生命值与状态 ---
var health = 10               # 库巴需要打5发火球
var is_dead = false          # 死亡状态标记


# --- 节点引用 ---
@onready var jump_timer = $JumpTimer
@onready var fire_timer = $FireTimer
@onready var fire_position = $FirePosition
@onready var sprite = $Sprite2D

# --- 面向方向（1=右, -1=左）---
var facing_direction = -1

# [新增] 动画播放器引用，请确保你的节点名字是 AnimationPlayer
@onready var anim_player = $AnimationPlayer 

@export var bowser_fire_scene: PackedScene 

func _ready():
	min_x = global_position.x - patrol_distance
	max_x = global_position.x + patrol_distance
	
	jump_timer.timeout.connect(_on_jump_timer_timeout)
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	
	# [新增] 连接动画结束信号，用于攻击完毕后切回走路
	anim_player.animation_finished.connect(_on_animation_finished)
	
	# [新增] 游戏开始时，默认播放走路动画
	anim_player.play("walk")
	
	_reset_jump_timer()
	_reset_fire_timer()
	
	# [新增] 将库巴加入敌人组，方便玩家脚本识别
	add_to_group("Enemy")


func _physics_process(delta):
	if is_dead:
		return

	if not is_on_floor():

		velocity.y += GRAVITY * delta

	velocity.x = direction * SPEED
	
	if global_position.x <= min_x and direction == -1:
		direction = 1  
	elif global_position.x >= max_x and direction == 1:
		direction = -1 

	move_and_slide()
	
	# 每帧更新面向玩家的朝向
	_update_facing()
	
	# [新增] 每一帧检查碰撞，如果碰到玩家就触发逻辑
	_check_player_collision()

# --- 面向玩家 ---

func _update_facing():
	var player = get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	
	# 计算玩家相对于库巴的方向 (正数代表玩家在右边，负数代表在左边)
	var to_player = player.global_position.x - global_position.x
	
	# 记录旧的朝向用于判定是否发生了转向
	var old_facing = facing_direction
	
	if to_player > 0:
		facing_direction = 1
		# 考虑到项目中怪物贴图通常默认朝左，所以向右(facing=1)时需要翻转
		sprite.flip_h = true  
	else:
		facing_direction = -1
		# 向左(facing=-1)时保持默认不翻转（即朝左）
		sprite.flip_h = false 
	
	# 只有在朝向真正改变时才打印日志，避免刷屏
	if old_facing != facing_direction:
		var side = "右" if facing_direction == 1 else "左"
		print("【逻辑】Bowser 检测到玩家在", side, "，更新视觉朝向。")
		# 注意：库巴的移动方向 (direction) 依然受巡逻逻辑控制，不受视觉朝向影响

# --- [新增] 玩家碰撞检查 ---

func _check_player_collision():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if (collider.name == "Player" or collider.is_in_group("Player")) and collider.has_method("take_damage"):
			collider.take_damage()


# --- 动作与计时器逻辑 ---


func _on_jump_timer_timeout():
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
	_reset_jump_timer() 

func _on_fire_timer_timeout():
	shoot_fire()
	_reset_fire_timer() 

func shoot_fire():
	if not bowser_fire_scene: 
		print("警告：未挂载 Bowser Fire Scene！")
		return
		
	# [新增] 发射火球时，播放攻击动画
	anim_player.play("attack")
	
	var fire = bowser_fire_scene.instantiate()
	var random_y_offset = randf_range(-15.0, 15.0)
	# 根据朝向偏移生成位置（X绝对值保持不变，符号跟随朝向）
	var fire_offset_x = abs(fire_position.position.x) * facing_direction
	fire.global_position = global_position + Vector2(fire_offset_x, fire_position.position.y) + Vector2(0, random_y_offset)
	# 将朝向传递给火球
	fire.direction = Vector2(facing_direction, 0)
	
	get_parent().add_child(fire)

# [新增] 动画结束回调函数
func _on_animation_finished(anim_name: String):
	# 如果刚播完的是攻击动画，就切回走路状态
	if anim_name == "attack":
		anim_player.play("walk")

# --- 随机时间生成器 ---
func _reset_jump_timer():
	jump_timer.start(randf_range(1.0, 4.0)) 

func _reset_fire_timer():
	fire_timer.start(randf_range(1.5, 3.5))

# --- [新增] 受击与死亡逻辑 ---

## 响应火球攻击的函数
func take_damage():
	if is_dead: return
	
	health -= 1
	print("库巴被击中！剩余血量：", health)
	
	# 简单的受击闪烁反馈
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", Color(10, 10, 10), 0.1) # 变白
	tween.tween_property($Sprite2D, "modulate", Color(1, 1, 1), 0.1)    # 恢复
	
	if health <= 0:
		die()

## 库巴死亡
func die():
	if is_dead: return
	is_dead = true
	
	print("库巴被打败了！")
	
	# 播放失败/死亡音效
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_stomp(global_position) # 暂时用踩踏音效，如果有BOSS死亡音效可以换

	# 停止计时器
	jump_timer.stop()
	fire_timer.stop()
	
	# 彻底关闭碰撞
	set_collision_layer(0)
	set_collision_mask(0)
	
	# 视觉效果：翻转并飞出屏幕（参考 Goomba 的 die 逻辑）
	if has_node("Sprite2D"):
		$Sprite2D.flip_v = true
		
	var tween = create_tween()
	var start_y = global_position.y
	# 向上弹一下，再掉出屏幕
	tween.tween_property(self, "global_position:y", start_y - 120, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", start_y + 800, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.finished.connect(func(): queue_free())

## 为了防止玩家踩在库巴头上不受伤，实现这个接口
func die_by_stomp(player):
	if is_dead: return
	# 库巴通常不能被踩死，反而会伤害玩家
	if player.has_method("take_damage"):
		player.take_damage()
