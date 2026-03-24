extends CharacterBody2D

const SPEED = 90.0
var direction = 1 # 1 表示向右走，-1 表示向左走
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_spawning = true # 标记蘑菇是否正在从砖块里钻出来

# --- 检查器面板接口 ---
# 现在统一在 SoundManager (Autoload) 中配置音效

func _ready():
	# 刚生成时，为了表现“从砖块后钻出来”的效果：
	$CollisionShape2D.disabled = true # 临时禁用物理身体的碰撞，防止卡在墙里
	
	if has_node("PlayerDetector"):
		if not $PlayerDetector.body_entered.is_connected(_on_player_detector_body_entered):
			$PlayerDetector.body_entered.connect(_on_player_detector_body_entered)

func pop_out():
	is_spawning = true
	
	visible = false
	await get_tree().create_timer(0.2).timeout
	visible = true
	
	# 3. 使用 Tween 制作平滑上升的动画
	var tween = create_tween()
	# 向上移动 16 个像素（因为现在它直接诞生在砖块中心处）
	tween.tween_property(self, "position:y", position.y - 16, 0.8)
	tween.finished.connect(_on_spawn_finished)

# 钻出砖块动画结束后的处理
func _on_spawn_finished():
	is_spawning = false
	$CollisionShape2D.disabled = false # 开启物理碰撞，让它可以掉在地上跑

func _physics_process(delta):
	# 如果还在升起阶段，不执行掉落和奔跑逻辑
	if is_spawning:
		return

	# 添加重力
	if not is_on_floor():
		velocity.y += gravity * delta

	# 设置水平移动速度
	velocity.x = direction * SPEED

	move_and_slide()

	# 核心逻辑：如果撞到了墙壁（比如水管或者墙砖），反转方向
	if is_on_wall():
		direction *= -1

# --- 接收 PlayerDetector 信号的函数 ---
func _on_player_detector_body_entered(body):
	# 判断碰到它的是不是玩家
	if body.name == "Player" or body.has_method("change_state"):
		print("【系统】玩家吃到了加命蘑菇 (1-UP)！")
		
		# 使用全局 SoundManager 播放音效
		if Engine.has_singleton("SoundManager") or has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_1up()
		
		# 触发加命逻辑
		GameManager.add_life()
			
		# 吃完后销毁蘑菇
		queue_free()
