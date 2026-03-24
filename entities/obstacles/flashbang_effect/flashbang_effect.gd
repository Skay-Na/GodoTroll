extends Node

# ==========================================
# 闪光弹效果控制器
# 依赖：WhiteFlash 节点需要挂载 white_flash.gdshader
#       BurnImage 节点需要挂载 burn_image.gdshader
# ==========================================

# --- 可调节参数（在 Inspector 中直接拖动数值调整）---
@export_group("白屏闪光")
@export var white_expand_time: float = 0.5  # 白光从中心扩散到全屏的时间（秒，越小越猛）
@export var white_stay_time: float = 0.6     # 全白停留的时间（秒，期间玩家完全致盲）
@export var white_fade_time: float = 3     # 白屏从全白淡出到透明的时间（秒）

@export_group("残像暂留")
@export var burn_stay_time: float = 0.5      # 残像开始消散前的停留时间（秒）
@export var burn_fade_time: float = 4.0      # 残像完全消散的时间（秒）
@export var center_strength: float = 2.5     # 中心暂留强度（越大越明显，对应 burn_image.gdshader）

# --- 节点引用 ---
@onready var burn_image = $UI_Layer/BurnImage
@onready var white_flash = $UI_Layer/WhiteFlash

# --- 状态变量 ---
var is_flashing: bool = false
var active_tween: Tween

# ==========================================
# 触发闪光弹
# ==========================================
func trigger_flashbang():
	# 如果有正在播放的动画，直接掐断，重新开始
	if active_tween and active_tween.is_running():
		active_tween.kill()
	
	is_flashing = true

	# --- 截取当前屏幕作为残像 ---
	var viewport_img = get_viewport().get_texture().get_image()
	# viewport_img.flip_y() # 若残像上下颠倒，取消此行注释
	var burn_texture = ImageTexture.create_from_image(viewport_img)
	burn_image.texture = burn_texture

	# --- 重置初始状态 ---
	# 白屏：一开始半径为 0（只有中心一个点），完全不透明
	white_flash.modulate.a = 1.0
	if white_flash.material:
		white_flash.material.set_shader_parameter("radius", 0.0)

	# 残像：更新中心强度参数，重置为完全可见（0.6->1.0 让重复触发时有明显的视觉"pop"）
	burn_image.modulate.a = 1.0
	if burn_image.material:
		burn_image.material.set_shader_parameter("center_strength", center_strength)

	# --- 创建并行 Tween 动画 ---
	var tween = create_tween().set_parallel(true)
	active_tween = tween

	# 1. 白光从中心向外扩散（radius: 0 -> 1.5）
	if white_flash.material:
		tween.tween_method(
			func(r): white_flash.material.set_shader_parameter("radius", r),
			0.0, 1.5, white_expand_time
		).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# 2. 扩散结束后，白屏保持 white_stay_time 秒，然后淡出
	# .from(1.0) 显式指定起点，确保重复触发时不会从上次中断的半透明值开始
	tween.tween_property(white_flash, "modulate:a", 0.0, white_fade_time)\
		.from(1.0)\
		.set_delay(white_expand_time + white_stay_time)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_OUT)

	# 3. 残像：延迟一段时间后，从外到内（由 shader 控制）渐渐消散
	# .from(1.0) 同理，保证每次触发残像都是从完全可见开始消散
	tween.tween_property(burn_image, "modulate:a", 0.0, burn_fade_time)\
		.from(1.0)\
		.set_delay(burn_stay_time)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	# 4. 所有动画结束后，解除状态锁
	active_tween.chain().tween_callback(func():
		is_flashing = false
		active_tween = null
		print("【闪光弹】效果完全散去，可以再次投掷。")
	)

	print("【闪光弹】砰！瞬间致盲，视觉暂留生效！")
