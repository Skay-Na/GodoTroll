extends CharacterBody2D

@export var move_speed: float = 700.0 # トラックの速度 (卡车的行驶速度，越快越难躲)
@export var push_force: float = 800.0 # プレイヤーを押し戻す力 (推回玩家的力量)

# 确保卡车不会被玩家的跳跃或子弹挡住 (设置物理层级：卡车在第一层，玩家在第二层，这里假设玩家也是用 default 层，如果分了层，请自行调整层级和掩码)


func _physics_process(_delta: float) -> void:
	# 1. 往左恒速移动
	velocity.x = -move_speed
	
	# 2. 移动并检测碰撞 (move_and_slide 自动处理碰撞)
	move_and_slide()
	
	# 3. 核心：如果撞到了东西，并且是玩家，就狠狠地推！
	# 遍历当前帧的所有碰撞
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
			# 检查撞到的是不是玩家 (假设玩家在 "Player" 组)
		if collider and collider.is_in_group("Player"):
			# 计算推力方向：卡车往左开，所以推力应该主要是往左
			# 如果想更智能一点，可以根据相对位置判断，但由于卡车是恒速向左，直接向左推即可
			var final_push = Vector2(-push_force, -150) # 稍微加大上弹力度，防止脚底摩擦力抵消
			
			if collider.has_method("apply_truck_push"):
				collider.apply_truck_push(final_push)
			elif "velocity" in collider:
				collider.velocity = final_push
				if collider.has_method("move_and_slide"):
					collider.move_and_slide()
