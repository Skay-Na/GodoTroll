extends Area2D

# 标记这个存档点是否已经被激活过
var is_activated = false

func _ready():
	# 连接信号，当有物体进入区域时触发
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print("【存档点测试】检测到物体进入：", body.name)
	
	# 已经被激活就忽略
	if is_activated:
		return
		
	# 检查碰到的是不是玩家
	if body.name == "Player": 
		is_activated = true
		
		# 1. 播放激活特效或动画（比如旗子升起）
		# $AnimatedSprite2D.play("active")
		
		# 2. 更新玩家的重生坐标 (持久化存储到 GameManager)
		GameManager.checkpoint_position = global_position
		
		# 也可选更新当前玩家实例的变量（方便立即复活而不用 reload 场景的情况，虽然目前是用 reload）
		if "respawn_position" in body:
			body.respawn_position = global_position
		
		print("✅ 存档点已更新！位置：", global_position)
