extends CharacterBody2D
class_name Fireball

# --- 核心物理参数 ---
var speed: float = 280.0          # 水平飞行速度 (从 300 降至 220)
var bounce_force: float = -150.0  # 碰到地面时的弹跳力度 (从 -250 降至 -180)
var gravity: float = 800.0        # 重力加速度 (从 900 增至 1100)
var direction: int = 1            # 飞行方向：1为右，-1为左

# 【关键状态】：由 WeaponManager 在生成火球时赋值
# true = 马里奥在地面发射（弹跳模式）
# false = 马里奥在空中发射（斜下砸地模式）
var is_bouncing_mode: bool = true 

@onready var notifier = $VisibleOnScreenNotifier2D

func _ready():
	add_to_group("Fireball")
	
	# 1. 离开屏幕时自动销毁，防止内存泄漏（确保你的节点名叫这个）
	if notifier:
		notifier.screen_exited.connect(queue_free)
		
	# 2. 如果是“空中特攻”模式，给它一个初始的向下速度
	if not is_bouncing_mode:
		velocity.y = 100.0 # 数值越大，斜向下的角度越陡

func _physics_process(delta):
	# --- 1. 计算当前帧的速度 ---
	velocity.x = direction * speed
	velocity.y += gravity * delta # 始终受重力影响，轨迹更自然
	
	# --- 2. 移动并获取碰撞信息 ---
	# move_and_collide 返回的是一个 KinematicCollision2D 对象
	var collision = move_and_collide(velocity * delta)
	
	# 如果发生了碰撞
	if collision:
		var collider = collision.get_collider()
		var normal = collision.get_normal()
		
		# 【情景 A】：击中可触发受击动作或摧毁的物体（敌人、特定砖块等）
		if collider.has_method("take_damage"):
			collider.take_damage()
			explode()
			return
		elif collider.has_method("die"):
			collider.die()
			explode()
			return
			
		# 【情景 B】：碰到了地形（TileMap或静态碰撞体）
		if is_bouncing_mode:
			# 弹跳模式：只在碰到地面时反弹
			# normal.y < -0.5 意味着碰撞面的法线是朝上的（即地面）
			if normal.y < -0.5: 
				velocity.y = bounce_force
			else: 
				# 撞到墙壁（法线朝左右）或天花板（法线朝下）
				explode()
		else:
			# 空中下砸模式：碰到任何地形（地面、墙壁）都直接销毁
			explode()

# 销毁与爆炸逻辑
func explode():
	# TODO: 后续我们可以在这里生成一个爆炸火花的动画特效
	queue_free()
