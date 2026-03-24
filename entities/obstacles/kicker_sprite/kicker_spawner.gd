extends Node

@export var kicker_scene: PackedScene # 右侧检查器拖入你的 KickerSprite.tscn
@export var spawn_sfx: AudioStream       # 出生时播放的音效

# 👇 专门给 K 键调用的方法
func spawn_from_left():
	_do_spawn(true)

# 👇 专门给 J 键调用的方法
func spawn_from_right():
	_do_spawn(false)

# 真正的核心生成逻辑
func _do_spawn(is_left: bool):
	# ⚠️ 必须在函数内部调用 get_tree()
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not kicker_scene: 
		return
	
	# 1. 计算屏幕边缘坐标和尺寸
	var canvas = get_tree().root.get_canvas_transform()
	var top_left = -canvas.origin / canvas.get_scale()
	var screen_rect = get_viewport().get_visible_rect()
	var current_screen_size = screen_rect.size / canvas.get_scale()
	
	# 2. 根据左右决定出生的 X 坐标
	var spawn_x: float
	if is_left:
		spawn_x = top_left.x - 100 # 左侧屏幕外
	else:
		spawn_x = top_left.x + current_screen_size.x + 100 # 右侧屏幕外
		
	var spawn_y = player.global_position.y
	
	# 3. 实例化急先锋
	var kicker = kicker_scene.instantiate()
	
	# 4. 设置它在世界中的坐标 (关键：要在旋转前设置好！)
	kicker.global_position = Vector2(spawn_x, spawn_y)
	
	# 5. 安全地传入“左/右”参数，绝对不会报变量找不到的错
	kicker.set("spawn_from_left", is_left)
	
# 6. 计算角度，让它的脚朝向角色！
	var kicker_sprite = kicker.get_node("Sprite2D")
	if kicker_sprite:
		var angle_to_player = (player.global_position - kicker.global_position).angle()
		
		# 👇 🌟 核心修复：分左右处理翻转与旋转 🌟 👇
		if is_left:
			# 从左边来，向右踢：开启水平翻转（脚朝右），并直接顺着真实夹角飞
			kicker_sprite.flip_h = true
			kicker_sprite.rotation = angle_to_player
		else:
			# 从右边来，向左踢：不翻转（脚朝左），角度减去 180 度 (PI) 来抵消基础方向
			kicker_sprite.flip_h = false
			kicker_sprite.rotation = angle_to_player - PI
	
	# 7. 正式加入游戏场景
	get_tree().current_scene.add_child(kicker)
	
	# 8. 播放音效 (调用全局音频管理器)
	if spawn_sfx and has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play(spawn_sfx, kicker.global_position)
	
	print("【发射器】已呼叫急先锋！突袭方向：", "左侧" if is_left else "右侧")
