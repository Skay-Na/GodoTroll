extends Area2D

func _ready():
	# 确保金币一生成就开始播放旋转动画
	$AnimatedSprite2D.play("spin")
	
	# 连接玩家吃金币的信号（兼容根节点或子节点 Area2D）
	if has_node("Area2D"):
		$Area2D.body_entered.connect(_on_body_entered)
	else:
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	# 如果是玩家碰到了散落在地图上的金币，就把它吃掉
	if body.name == "Player":
		if has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_coin(global_position)
		GameManager.add_coin()
		queue_free()

# 这个函数专门留给玩家顶砖块时调用
func pop_out():
	# 如果你加了 CollisionShape2D，生成时禁用碰撞，防止意外被吃掉两次（地图金币没有这问题）
	if has_node("Area2D/CollisionShape2D"):
		$"Area2D/CollisionShape2D".set_deferred("disabled", true)
	elif has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	# 取消掉碰撞检测，顶出来只能看纯动画，阻止在此期间被意外拾取
	if has_node("Area2D") and $Area2D.body_entered.is_connected(_on_body_entered):
		$Area2D.body_entered.disconnect(_on_body_entered)
	elif body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)
	
	# 使用 Tween 制作平滑的弹跳动画
	var tween = create_tween()
	var start_pos = position
	
	# 阶段1：快速向上弹起 (向上偏移 40 像素)
	tween.tween_property(self, "position:y", start_pos.y - 40, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 阶段2：稍微回落一点点 (回落 25 像素)，同时透明度渐变消失
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2).set_delay(0.2) 
	tween.tween_property(self, "position:y", start_pos.y - 25, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 阶段3：动画结束，自动销毁金币
	tween.finished.connect(func():
		print("金币（弹跳）动画结束，加分！")
		if has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_coin(global_position)
		GameManager.add_coin()
		queue_free()
	)
