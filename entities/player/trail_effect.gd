extends Node2D

@export var target_sprite: Sprite2D # 我们要在右侧检查器里把 Player 的 Sprite2D 拖给它
@export var ghost_lifetime: float = 0.4 # 残影存活时间
@export var ghost_interval: float = 0.05 # 生成残影的间隔频率
@export var trail_color: Color = Color(0.955, 0.983, 1.0, 0.776) # 残影颜色（默认半透明白色）

var timer: Timer

func _ready():
	# 动态创建一个计时器，专门用来控制残影生成的频率
	timer = Timer.new()
	timer.wait_time = ghost_interval
	timer.timeout.connect(_spawn_ghost)
	add_child(timer)

# 提供给外部（比如 Player 脚本）调用的开启方法
func start_trail():
	if timer.is_stopped():
		timer.start()

# 提供给外部调用的关闭方法
func stop_trail():
	timer.stop()

# 核心：生成残影的逻辑
func _spawn_ghost():
	if not target_sprite:
		push_warning("TrailEffect: 没有绑定 target_sprite！")
		return
		
	var ghost = Sprite2D.new()
	ghost.texture = target_sprite.texture
	
	# 原本的帧数切分模式
	ghost.vframes = target_sprite.vframes
	ghost.hframes = target_sprite.hframes
	ghost.frame = target_sprite.frame
	
	# 🌟【关键修复】：把 Region (区域裁剪) 的属性也完全复制过来
	ghost.region_enabled = target_sprite.region_enabled
	ghost.region_rect = target_sprite.region_rect
	
	# 🌟【关键修复】：把 Offset (中心点偏移量) 也复制过来，防止残影位置错位
	ghost.offset = target_sprite.offset
	
	ghost.flip_h = target_sprite.flip_h
	ghost.scale = target_sprite.scale
	
	# 获取目标精灵的真实全局位置
	ghost.global_position = target_sprite.global_position
	ghost.modulate = trail_color
	
	# 加到当前场景的根节点
	get_tree().current_scene.add_child(ghost)
	
	var tween = get_tree().create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, ghost_lifetime)
	tween.tween_callback(ghost.queue_free)
