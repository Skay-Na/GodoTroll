extends Area2D

@export var move_distance: float = 30.0  # 移动距离
@export var move_time: float = 1.5        # 单程移动时间
@export var move_direction: Vector2 = Vector2.UP # 默认向上移动
@export var pause_time: float = 1.0       # 最高处停顿时间 (秒)
@export var safe_distance: float = 40.0   # 【新增】安全距离：玩家在这个横向距离内，它不会出来

var start_position: Vector2
var is_dead: bool = false
var movement_tween: Tween

func _ready() -> void:
	start_position = global_position
	body_entered.connect(_on_body_entered)
	
	# 设置监测状态
	monitoring = true
	monitorable = true
	
	# 随机延迟 0.2 到 1.0 秒后再开始运动
	var random_delay = randf_range(0, 2)
	
	# 使用 await 等待延迟，然后直接启动运动循环
	await get_tree().create_timer(random_delay).timeout
	_movement_loop()

# 【核心修改】使用异步循环替代 set_loops()
func _movement_loop() -> void:
	while not is_dead:
		# 1. 尝试获取玩家节点 (假设你的玩家节点在 "Player" 分组中)
		var player = get_tree().get_first_node_in_group("Player")
		var player_is_near = false
		
		# 2. 判断玩家是否在管子上方或附近 (主要判断 X 轴的绝对距离)
		if is_instance_valid(player):
			var distance_x = abs(player.global_position.x - start_position.x)
			if distance_x <= safe_distance:
				player_is_near = true
				
		# 3. 如果玩家离得太近（站管子上了），它就不出来，暗中等待 0.5 秒后再重新检测
		if player_is_near:
			await get_tree().create_timer(0.5).timeout
			continue # 跳过下方的移动代码，直接重新开始下一轮 while 循环进行判断
			
		# 4. 玩家不在附近，安全！执行一次完整的【出 -> 停 -> 进 -> 停】
		movement_tween = create_tween()
		var target_pos = start_position + move_direction * move_distance
		
		# 向上移动到目标位置
		movement_tween.tween_property(self, "global_position", target_pos, move_time).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		# 在最高点停顿
		movement_tween.tween_interval(pause_time)
		# 回到原点 (缩回管子)
		movement_tween.tween_property(self, "global_position", start_position, move_time).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		# 在最低点停顿
		movement_tween.tween_interval(pause_time)
		
		# 等待这整套动画播放完毕，然后再进入下一次 while 循环重新检测玩家位置
		await movement_tween.finished

func _on_body_entered(body: Node2D) -> void:
	if is_dead: return
	
	if _is_fireball(body):
		_handle_fireball(body)
	elif body.name == "Player" or body.is_in_group("Player"):
		# 触碰后玩家受到正常伤害
		if body.has_method("take_damage"):
			body.take_damage()

# 辅助方法：判断物体是否为火球
func _is_fireball(body: Node2D) -> bool:
	return body.is_in_group("Fireball") or body.name.to_lower().contains("fireball")

# 辅助方法：处理火球撞击
func _handle_fireball(body: Node2D) -> void:
	if body.has_method("explode"):
		body.explode()
	die()

func die() -> void:
	if is_dead: return
	is_dead = true
	
	# 停止运动
	if movement_tween:
		movement_tween.kill()
	
	# 禁用监测
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# 播放音效
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_stomp(global_position)
	
	# 死亡效果：向下弹出并半透明消失
	var die_tween = create_tween()
	die_tween.set_parallel(true)
	die_tween.tween_property(self, "global_position:y", global_position.y + 40, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	die_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	die_tween.chain().finished.connect(queue_free)

func take_damage() -> void:
	die()
