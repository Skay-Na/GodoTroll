extends Area2D

func _ready():
	# 1. 刚生成时，关闭碰撞，防止还没完全冒出来就被玩家吃掉
	$CollisionShape2D.set_deferred("disabled", true)
	# === 终极修复：用代码强行绑定吃花的信号，防止 UI 里忘连 ===
	if not self.body_entered.is_connected(_on_body_entered):
		self.body_entered.connect(_on_body_entered)
	
	# 3. 确保动画正在播放（假设你的动画名叫 "default"）
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default")

func pop_out():
	
	# === 关键修复：让花先隐身等待砖块谈跳结束 ===
	visible = false
	await get_tree().create_timer(0.2).timeout
	visible = true
	
	# 4. 使用 Tween 制作平滑上升动画
	var tween = create_tween()
	# 向上移动 16 个像素，耗时 0.8 秒（因为原点在中心）
	tween.tween_property(self, "position:y", position.y - 16, 0.8)
	
	# 5. 升起结束后，恢复层级并开启碰撞，允许玩家吃
	tween.finished.connect(func():
		$CollisionShape2D.set_deferred("disabled", false)
	)

# --- 接收玩家碰撞信号的函数 ---
func _on_body_entered(body):
	# print("【感应测试】某位大仙进入了花花的感应圈！它的名字叫：", body.name)
	
	# 判断碰到它的是不是玩家
	if body.name == "Player" or body.has_method("change_state"):
		# print("【系统】玩家吃到了火焰花！")
		
		# 播放获得道具音效
		if has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_powerup()
			
		# 触发玩家变成花花状态
		body.change_state(body.PlayerState.FLOWER)
		
		# 吃完后销毁花花
		queue_free()
