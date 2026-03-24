extends Area2D

@export var move_speed: float = 400.0 # 火圈向左飞行的速度

func _ready():
	# 1. 绑定碰触玩家的信号 (烧死马里奥)
	body_entered.connect(_on_body_entered)
	
	# 2. 绑定飞出屏幕的信号 (自动销毁，防止内存泄漏)
	var notifier = $ScreenExit
	if notifier:
		notifier.screen_exited.connect(queue_free)

func _process(delta: float):
	# 每帧向左平移
	position.x -= move_speed * delta

func _on_body_entered(body: Node2D):
	# 只要碰到的是玩家，就直接执行死刑！
	if body.is_in_group("Player"):
		print("【火圈】马里奥钻圈失败，变成烤蘑菇了！")
		
		# 假设你的玩家脚本里有一个处理死亡/重置的方法，比如叫 die() 或 take_damage()
		# 你需要根据你自己的 player.gd 里的实际死亡函数名来替换下面的 "die"
		if body.has_method("die"):
			body.die()
		else:
			# 如果你还没写死亡方法，就简单粗暴地重置当前关卡
			get_tree().reload_current_scene()
