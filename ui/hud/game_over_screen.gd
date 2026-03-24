extends CanvasLayer

signal confirmed

@onready var animation_player = $AnimationPlayer
@onready var color_rect = $ColorRect # 现在它只是个安静的黑背景

# 容器里的文字组合
@onready var world_label = $VBoxContainer2/World
@onready var lives_container = $VBoxContainer2/HBoxContainer
@onready var lives_label = $VBoxContainer2/HBoxContainer/Lives


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 1. 读取 GameManager 的数据
	world_label.text = GameManager.current_level_name
	lives_label.text = str(GameManager.lives - 1)
	
	# 4. 自动倒计时 3 秒后发出确认信号
	await get_tree().create_timer(3.0).timeout
	confirm()

func _input(event):
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		confirm()

func confirm():
	confirmed.emit()
	if GameManager.transition_target_scene != "":
		# 如果记录了目标关卡，就执行真正的跳转！
		var target = GameManager.transition_target_scene
		GameManager.transition_target_scene = "" # 清空变量以免干扰后续关卡
		print("📦 过渡场景播放结束，正在跳转关卡: ", target)
		get_tree().change_scene_to_file(target)
	else:
		# 否则（通常是死亡），就保持原有的销毁逻辑
		queue_free()
