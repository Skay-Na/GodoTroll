extends AnimatableBody2D

enum PlatformType {
	ONE_WAY_SPAWNER, # 单向不断生成的电梯 (原功能)
	PING_PONG        # 往返来回移动的电梯 (新功能)
}

@export_group("Platform Behavior")
@export var platform_type: PlatformType = PlatformType.ONE_WAY_SPAWNER
@export var speed: Vector2 = Vector2(0, -50)

@export_group("One-Way Spawner Settings")
@export var travel_distance: float = 800.0 # 电梯移动多少像素后消失
@export var is_spawner: bool = true
@export var spawn_interval: float = 2.0

@export_group("Ping-Pong Settings")
@export var ping_pong_distance: float = 200.0 # 往返移动的最大单程距离

var spawn_timer: float = 0.0
var distance_traveled: float = 0.0 # 记录当前移动的距离
var start_position: Vector2 = Vector2.ZERO # 记录初始位置，用于往返计算
var moving_forward: bool = true # 往返状态记录：当前是否正向移动

func _ready():
	start_position = global_position
	
	if platform_type == PlatformType.ONE_WAY_SPAWNER:
		if is_spawner:
			# 隐藏生成器，禁用碰撞，它只作为生成锚点
			visible = false
			for child in get_children():
				if child is CollisionShape2D or child is CollisionPolygon2D:
					child.set_deferred("disabled", true)
			
			# 关卡开始时默认先生成一个
			_spawn_platform()

func _physics_process(delta):
	match platform_type:
		PlatformType.ONE_WAY_SPAWNER:
			_process_one_way(delta)
		PlatformType.PING_PONG:
			_process_ping_pong(delta)

func _process_one_way(delta):
	if is_spawner:
		# 生成器定时产生新电梯
		spawn_timer += delta
		if spawn_timer >= spawn_interval:
			spawn_timer = 0.0
			_spawn_platform()
	else:
		# 持续移动 (克隆体)
		var movement = speed * delta
		global_position += movement
		
		# 累加移动距离
		distance_traveled += movement.length()
		
		# 当移动距离超过设定值时自我销毁
		if distance_traveled >= travel_distance:
			queue_free()

func _process_ping_pong(delta):
	var current_speed = speed if moving_forward else -speed
	var movement = current_speed * delta
	global_position += movement
	
	distance_traveled += movement.length()
	
	if distance_traveled >= ping_pong_distance:
		# 到达往复的极点，掉头
		distance_traveled = 0.0
		moving_forward = !moving_forward
		# 对齐位置以保证长期运行不偏移
		if moving_forward:
			global_position = start_position
		else:
			global_position = start_position + speed.normalized() * ping_pong_distance

func _spawn_platform():
	# 复制自身作为一个非生成器的移动平台
	var clone = self.duplicate()
	clone.is_spawner = false
	clone.visible = true
	
	get_parent().add_child.call_deferred(clone)
	clone.global_position = self.global_position
	clone.start_position = clone.global_position
	
	# 恢复克隆体的物理碰撞
	for child in clone.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", false)
