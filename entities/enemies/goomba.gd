extends CharacterBody2D

# ==========================================
# 酷霸 (Goomba) 怪物 AI 逻辑
# ==========================================

const WALK_SPEED = 40.0
var current_direction = -1 # 默认向左走 (-1)

# 重力，从项目设置里获取
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var is_dead = false
var initial_position: Vector2

func _ready():
	# 物理処理を初期状態で停止します (初始状态下停止物理处理，防止掉落)
	set_physics_process(false)
	
	# 启动时开始播放走路动画
	if $AnimatedSprite2D.sprite_frames.has_animation("walk"):
		$AnimatedSprite2D.play("walk")
		
	# 绑定头顶弱点 (Hitbox) 用于被马里奥踩死
	if has_node("Hitbox"):
		$Hitbox.body_entered.connect(_on_hitbox_body_entered)
	else:
		push_warning("Goomba 缺少 Hitbox 子节点！无法检测被玩家防空踩踏。")
		
	# 绑定侧面攻击区域 (Hurtbox) 用于伤害马里奥
	if has_node("Hurtbox"):
		$Hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	else:
		print("如果在侧面需要伤害马里奥，请给 Goomba 添加名叫 'Hurtbox' 的 Area2D 并包裹身体两侧！")
		
	# 记录初始出生点，并监听全图重置信号
	initial_position = global_position
	GameManager.reset_level.connect(_on_reset_level)

# 响应玩家死亡复活时的全图重置
func _on_reset_level():
	# 🌟【健壮性修复】如果节点已经不在场景树中（可能正在被销毁），直接跳过，防止 get_tree() 返回 null 崩溃
	if not is_inside_tree():
		return
		
	# 如果已经被踩死了，不再复活
	if is_dead:
		return
		
	# 活着的话，回到原点，恢复初生状态
	# 先暂停物理，防止瞬间传送后的第一帧因重力穿透地板
	set_physics_process(false)
	global_position = initial_position
	velocity = Vector2.ZERO
	current_direction = -1
	if $AnimatedSprite2D.sprite_frames.has_animation("walk"):
		$AnimatedSprite2D.play("walk")
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

	# 2. 持续沿着当前方向行走
	velocity.x = current_direction * WALK_SPEED

	# 3. 移动并处理物理碰撞
	move_and_slide()

	# 4. 如果撞墙了，就反向继续走
	if is_on_wall():
		# get_wall_normal().x 会返回墙面的法线方向（撞右墙是 -1，撞左墙是 1）
		current_direction = sign(get_wall_normal().x)

func _on_hitbox_body_entered(body: Node2D):
	if is_dead:
		return
		
	if body.name == "Player" or body.is_in_group("Player"):
		# 如果马里奥碰到了 Goomba 的 Hitbox 碰撞盒（代表攻击范围），说明被撞伤了
		# 注意：这里不需要再额外判断 y，因为如果满足踩踏条件，上面的 Hurtbox 信号会先处理 (或者我们可以加个逻辑守卫)
		if body.has_method("take_damage"):
			body.take_damage()

func _on_hurtbox_body_entered(body: Node2D):
	if is_dead:
		return
	
	if body.name == "Player" or body.is_in_group("Player"):
		# 通过判断马里奥的脚（Y坐标）是否略高于怪物的中心底部，来确认是否是“从上往下踩”
		if body.global_position.y < global_position.y - 5:
			# 如果马里奥碰到了 Goomba 的 Hurtbox（代表受击弱点），且在头顶
			# 说明是被踩死了
			die_by_stomp(body)

func die_by_stomp(player):
	is_dead = true
	
	# 给玩家一个向上的弹跳反馈
	player.velocity.y = -300
	
	# 播放踩踏音效
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_stomp(global_position)
	
	# 禁用碰撞
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	if has_node("Hitbox"):
		$Hitbox.get_node("CollisionShape2D").set_deferred("disabled", true)
	
	# 播放被踩扁的动画
	if $AnimatedSprite2D.sprite_frames.has_animation("dead"):
		$AnimatedSprite2D.play("dead")
	
	# 半秒后消失
	await get_tree().create_timer(0.5).timeout
	queue_free()

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
	
# 画面に入った時のシグナル受信関数 (进入屏幕时的信号接收函数)
func _on_visible_on_screen_notifier_2d_screen_entered():
	if not is_dead:
		# 物理処理を再開します (恢复物理处理，让怪物开始活动)
		set_physics_process(true)


func _on_visible_on_screen_enabler_2d_screen_entered() -> void:
	pass # Replace with function body.
