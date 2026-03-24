extends Node2D

# 暴露到面板上，方便在不同关卡配置不同火把的旋转速度和方向（正数为顺时针，负数为逆时针）
@export var rotation_speed: float = 2.0 

@onready var pivot: Node2D = $Pivot

func _ready() -> void:
	# 初始化随机角度，最少30度一档
	var random_multiplier = randi() % 12
	var random_degrees = random_multiplier * 40.0
	pivot.rotation_degrees = random_degrees
	
	# 遍历寻找所有的火球节点 (Area2D) 并连接信号
	for area in pivot.get_children():
		if area is Area2D:
			area.body_entered.connect(_on_body_entered)
			area.area_entered.connect(_on_area_entered)
	
	print("【火把初始化】火把已生成！位置：", global_position)

func _physics_process(delta: float) -> void:
	# 让轴心按设定的速度持续旋转
	pivot.rotation += rotation_speed * delta

func _on_body_entered(body: Node2D) -> void:
	print("【火把调试】检测到有 Body 进入了火把范围！进入的物体叫: ", body.name)
	
	if body.has_method("take_damage"): 
		print("【火把调试】-> 确认该物体有 take_damage 方法！开始扣血...")
		body.take_damage()

func _on_area_entered(area: Area2D) -> void:
	print("【火把调试】检测到有 Area 进入了火把范围！进入的物体叫: ", area.name)
	
	# 某些情况下，马里奥的受击判定可能写在了他的子节点 Area2D (Hurtbox) 上
	# 我们获取这个 Area2D 的拥有者 (owner) 或者是父节点（也就是马里奥本体）来调用扣血
	var target = area.owner if area.owner else area.get_parent()
	
	if target:
		if target.has_method("take_damage"):
			print("【火把调试】-> 确认该 Area 的所属节点(", target.name, ")有 take_damage 方法！开始扣血...")
			target.take_damage()
		elif target.name == "Player":
			print("【火把调试】-> 警告: 撞到了Player的Area，但Player身上没有take_damage方法？")
	else:
		print("【火把调试】-> 找不到该 Area 的有效父节点或属主。")
