extends CharacterBody2D

# ==========================================
# 飞天慢慢龟 (Koopa Paratroopa) 怪物 AI 逻辑
# ==========================================

@export_group("Flight Settings")
@export var speed: float = 50.0 # 飞行速度
@export var ping_pong_distance: float = 150.0 # 上下往返的最大单程距离

var start_position: Vector2 = Vector2.ZERO
var distance_traveled: float = 0.0 # 记录当前移动的距离
var moving_up: bool = true # 当前是否往上飞

var is_dead = false
const KOOPA_TROOPA_SCENE = preload("uid://dd6pftgxf5x58") # 假设普通乌龟的场景路径，根据你的实际情况可能需要调整，比如 res://animation/koopa_troopa.tscn

func _ready():
	start_position = global_position
	
	# 如果有飞行贴图动画，默认播放飞行
	if has_node("AnimatedSprite2D") and $AnimatedSprite2D.sprite_frames.has_animation("walk"):
		$AnimatedSprite2D.play("walk") # 如果你有专门的 fly 动画可以改成 fly
	
	# 监听全图重置信号
	GameManager.reset_level.connect(_on_reset_level)

# 玩家死亡时，飞天龟回到初始位置
func _on_reset_level():
	# 🌟【健壮性修复】防止 orphaned nodes 触发回调导致 get_tree() 崩溃
	if not is_inside_tree():
		return
		
	if is_dead:
		return
	# 重置飞行逻辑状态
	distance_traveled = 0.0
	moving_up = true
	velocity = Vector2.ZERO
	# 先暂停物理，防止瞬间位置更改后在下一帧因重力穿透地板
	set_physics_process(false)
	global_position = start_position
	# 等一帧再恢复物理，让引擎在新坐标稳定
	await get_tree().process_frame
	if not is_dead:
		set_physics_process(true)

func _physics_process(delta):
	if is_dead:
		return
		
	# 1. 飞天乌龟不受重力影响，自主上下飞行
	var current_velocity_y = -speed if moving_up else speed
	var movement_y = current_velocity_y * delta
	
	# 这里为了能做基于物理的碰撞检测，我们使用 velocity 控制 CharacterBody2D
	velocity = Vector2(0, current_velocity_y)
	move_and_slide()
	
	# 记录它实际移动了多少（不含被挡住的情况，或者用固定计算也行）
	distance_traveled += abs(movement_y)
	
	# 如果在一个方向上到达了折返点，掉头
	if distance_traveled >= ping_pong_distance:
		distance_traveled = 0.0
		moving_up = !moving_up
		# 可选：如果需要严格对齐防止误差偏移，可以强行设置位置
		# if moving_up: global_position.y = start_position.y + ping_pong_distance 等等
		
	# 2. 只有唯一的碰撞盒，我们需要遍历刚才 move_and_slide 发生的实际碰撞
	# 看看是不是碰到了马里奥
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# 遇到其他慢慢龟或物体可以反弹
		if collider and collider.name != "Player" and not collider is TileMapLayer:
			pass # 如果你想让它飞上飞下撞到天花板反弹，可以把这段加上
		
		if collider and collider.name == "Player":
			var normal = collision.get_normal()
			
			# 判断：法线 Y 大于 0.5，代表马里奥踩在了乌龟的头上（乌龟受到向下的压力，法线朝上对于碰撞面来说）
			if normal.y > 0.5:
				# 这个踩踏逻辑其实 Player 里的 check_head_collision 也会检测并主动调用乌龟的 die_by_stomp
				# 如果玩家那边调用了，这里就会因为 is_dead = true 不再处理。可以不用抢着写。
				pass
			else:
				# 如果马里奥是从侧面或者下面撞上来的，并且马里奥不是无敌状态：
				if not "is_invincible" in collider or not collider.is_invincible:
					if collider.has_method("take_damage"):
						collider.take_damage()

# ================== 状态切换逻辑 ==================

# 暴露给玩家脚本调用的接口：被踩到时触发
func die_by_stomp(attacker = null):
	print("【飞天龟调试】被踩方法 die_by_stomp 被调用！is_dead 当前状态: ", is_dead)
	if is_dead: return
	is_dead = true
	print("【飞天龟调试】is_dead 设置为 true，准备播放死亡动画...")
	
	# 取消本身的物理碰撞，防止再次造成伤害或被踩
	$CollisionShape2D.set_deferred("disabled", true)
	
	# 播放死亡缩入壳中的动画 (基于用户的截图名称)
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("dead")
	
	# 给玩家一个向上的弹跳反馈
	if attacker and "velocity" in attacker:
		print("【飞天龟调试】给予玩家向上弹跳力！")
		attacker.velocity.y = -300
	
	# ==============================
	# 死亡缩壳并掉落的动画表现
	# ==============================
	# 1. 改变图层，避免挡住玩家
	z_index = z_index - 1
	
	# 2. 用 Tween 做一个被踩扁并且掉出屏幕的效果
	var tween = create_tween()
	var start_y = global_position.y
	
	# 稍微往下压一点点模仿被踩扁，然后快速掉出屏幕之外 (增加 500 的 y 坐标)
	tween.tween_property(self, "global_position:y", start_y + 10, 0.1)
	tween.tween_property(self, "global_position:y", start_y + 500, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 3. 动画播完完全掉出去后，执行真正的销毁
	tween.finished.connect(func():
		queue_free()
	)

# 专供火球或非踩踏类杀穿调用的接口
func die():
	if is_dead: return
	is_dead = true
	
	# 播放踢飞/死亡音效
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_stomp(global_position)
	
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
	
	# 如果普通的慢慢龟也有个 direction，可能你想让它继承当前朝向
	# normal_koopa.current_direction = self.current_direction 
	# 不过飞天乌龟通常是原地下坠，所以默认朝向就行。
