extends Node

@export var countdown_duration: float = 10.0 # 每次触发增加的倒计时时间
@export var countdown_label: Label           # 在编辑器中关联的倒计时标签

var is_inverted: bool = false
var current_rotation: float = 0.0 # 记录当前屏幕角度
var remaining_time: float = 0.0

# 获取我们刚才创建的滤镜节点
@onready var color_rect = $EffectLayer/ColorRect

func _process(delta: float):
	if remaining_time > 0:
		remaining_time -= delta
		if countdown_label:
			countdown_label.text = "TIMER : %d" % ceil(remaining_time)
			countdown_label.visible = true
		
		if remaining_time <= 0:
			remaining_time = 0
			if countdown_label: countdown_label.visible = false
			if is_inverted:
				_perform_invert(false) # 倒计时结束，恢复正向

func invert_screen():
	if not is_inverted:
		# 第一次进入翻转状态
		_perform_invert(true)
		remaining_time = countdown_duration
	else:
		# 已经是翻转状态，累加时间
		remaining_time += countdown_duration
		print("【画面反转】时长累加！当前剩余：", remaining_time)

# 执行物理翻转动作
func _perform_invert(invert: bool):
	is_inverted = invert
	var target_rotation = 180.0 if is_inverted else 0.0
	
	# 用 Tween 平滑过渡滤镜的角度参数
	var tween = create_tween()
	tween.tween_method(set_shader_rotation, current_rotation, target_rotation, 0.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
		
	current_rotation = target_rotation
	print("【画面反转】切换状态！当前角度：", target_rotation)

# 专门用来修改 Shader 参数的小助手函数
func set_shader_rotation(value: float):
	if color_rect and color_rect.material:
		color_rect.material.set_shader_parameter("rotation_degrees", value)
		
