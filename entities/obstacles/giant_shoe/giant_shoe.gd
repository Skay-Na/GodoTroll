extends StaticBody2D

@export var required_polishes: int = 15  ## 擦鞋完成所需按键次数
@export var stomp_drop_height: float = 800.0  ## 皮鞋从多高砸下来（像素）

## 🔊 出场音效（皮鞋从天而降时播放）
@export var sfx_stomp: AudioStream
## 🔊 向左擦鞋音效
@export var sfx_polish_left: AudioStream
## 🔊 向右擦鞋音效
@export var sfx_polish_right: AudioStream

var current_polishes: int = 0
var player_in_zone: bool = false

@onready var shoe_sprite = $ShoeSprite
@onready var cloth_sprite = $ClothSprite
@onready var polish_area = $PolishArea
@onready var anim_player = $AnimationPlayer

func _ready():
	
	# area2D 信号連接 (连接感应区信号)
	polish_area.body_entered.connect(_on_polish_area_entered)
	polish_area.body_exited.connect(_on_polish_area_exited)
	
	# 最初先隐藏，等待 spawner 呼叫 setup
	visible = false

# Spawner から呼び出され、位置を設定して出勤する (被 Spawner 呼叫，设置位置，直接砸下来)
func setup_and_start_stomp(target_pos: Vector2, p_polishes: int = 15, p_height: float = 800.0):
	required_polishes = p_polishes
	stomp_drop_height = p_height
	
	visible = true
	global_position = target_pos + Vector2(0, -stomp_drop_height)
	
	# 🔊 播放出场音效
	_play_sfx_oneshot(sfx_stomp)
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, 0.4)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_IN)
	
	print("【大皮鞋】天降皮鞋！目标坐标：", target_pos)

# プレイヤー検知 (检测马里奥是否进入打工区)
func _on_polish_area_entered(body: Node2D):
	if body.is_in_group("Player"):
		player_in_zone = true
		print("【大皮鞋】马里奥已就位，请按左右键开始擦鞋！")

func _on_polish_area_exited(body: Node2D):
	if body.is_in_group("Player"):
		player_in_zone = false

# 入力処理：QTE 擦鞋核心逻辑 (带按键区分的动画反馈)
func _unhandled_input(event: InputEvent):
	# 如果马里奥不在工作区，直接无视按键
	if not player_in_zone: return
	
	# 👇 核心修复：精准区分左键和右键 👇
	var input_detected = false
	var anim_to_play = ""
	
	# 按下左键 (ui_left)
	if event.is_action_pressed("ui_left"):
		input_detected = true
		anim_to_play = "polish_left"
		_play_sfx_oneshot(sfx_polish_left)   # 🔊 左擦：每次新建实例，播完自动销毁
		
	# 按下右键 (ui_right)
	elif event.is_action_pressed("ui_right"):
		input_detected = true
		anim_to_play = "polish_right"
		_play_sfx_oneshot(sfx_polish_right)  # 🔊 右擦：每次新建实例，播完自动销毁
		
	# 如果触发了有效按键，执行擦鞋逻辑
	if input_detected:
		get_viewport().set_input_as_handled() # 关键：阻止事件传递给其他皮鞋
		current_polishes += 1
		
		# 动画反馈：播放对应的抹布动画（true = 强制从头播，保证连点反馈）
		if anim_player and anim_player.has_animation(anim_to_play):
			anim_player.play(anim_to_play, -1, 1.0, true)
		
		print("【大皮鞋】擦鞋进度: ", current_polishes, "/", required_polishes)
		
		# 检查是否完成指标
		if current_polishes >= required_polishes:
			finish_polishing()

# 磨き完了 (擦鞋完成，皮鞋升天离开)
func finish_polishing():
	player_in_zone = false # 停止接收按键
	print("【大皮鞋】皮鞋擦得很亮！大爷我走了！")
	
	var tween = create_tween()
	# 少し光る (让皮鞋闪闪发光一下)
	tween.tween_property(shoe_sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.2)
	# 上空へ飛んでいく (升天离开)
	tween.tween_property(self, "global_position:y", global_position.y - 800, 0.5)\
		.set_delay(0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_IN)
		
	tween.tween_callback(queue_free)

# 每次调用都新建一个 AudioStreamPlayer，播放完毕后自动 queue_free()
# 无论按得多快，每个声音都能完整播放，互不干扰
func _play_sfx_oneshot(stream: AudioStream) -> void:
	if not stream:
		return
	var p = AudioStreamPlayer.new()
	add_child(p)
	p.stream = stream
	p.finished.connect(p.queue_free)  # 播完自动销毁
	p.play()
