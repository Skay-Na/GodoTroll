extends Node

# エクスポート変数 (导出变量)
@export var truck_scene: PackedScene # 在检查器里把刚才做的 Truck.tscn 拖进来！
@export_group("Event Settings")
@export var event_duration: float = 12.0 # 默认持续时间（如果没有 BGM 时使用）
@export var start_delay: float = 3.0 # [新增] BGM 开始后的等待时长
@export var spawn_interval_min: float = 0.5 # 生成间隔最小值 (密度控制)
@export var spawn_interval_max: float = 1.2 # 生成间隔最大值 (密度控制)
@export var spawn_y_offset_min: float = -200.0 # 玩家上方边界
@export var spawn_y_offset_max: float = 50.0 # 玩家下方边界

@export_group("Audio")
@export var event_bgm: AudioStream # 活动背景音乐
@export var spawn_sfx: AudioStream # 每辆车生成的提示音效

var is_event_active: bool = false
var player_ref: Node2D = null

# 用来控制随机生成间隔的计时器
@onready var spawn_timer: Timer = Timer.new()
# 用来控制总时长的计时器
@onready var total_duration_timer: Timer = Timer.new()
# 用于播放 BGM 的播放器
@onready var bgm_player: AudioStreamPlayer = AudioStreamPlayer.new()

func _ready():
	# 生成计时器设置
	add_child(spawn_timer)
	spawn_timer.timeout.connect(_spawn_one_truck)
	
	# 总时长计时器设置
	add_child(total_duration_timer)
	total_duration_timer.one_shot = true
	total_duration_timer.timeout.connect(_on_event_finished)
	
	# BGM 播放器设置
	add_child(bgm_player)
	bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS # 确保暂停时也能播完

func _process(_delta):
	if not is_event_active: return
	
	# 动态获取玩家引用（防止玩家重置后引用失效）
	if not is_instance_valid(player_ref) or player_ref.is_queued_for_deletion():
		player_ref = get_tree().get_first_node_in_group("Player")
	
	# 判断是否需要暂停（玩家死亡或不存在时暂停）
	var should_pause = false
	if not is_instance_valid(player_ref) or player_ref.get("is_dead"):
		should_pause = true
		
	# 控制暂停与恢复
	bgm_player.stream_paused = should_pause
	spawn_timer.paused = should_pause
	total_duration_timer.paused = should_pause

# 专属技能：开启“撞大运”地狱模式
func start_truck_rush_event():
	if is_event_active: return # 已经在跑了，不重复触发
	
	player_ref = get_tree().get_first_node_in_group("Player")
	if not player_ref or not truck_scene: return
	
	is_event_active = true
	
	# 1. 处理 BGM
	var total_lifetime = event_duration
	if event_bgm:
		bgm_player.stream = event_bgm
		bgm_player.play()
		total_lifetime = event_bgm.get_length()
		print("【撞大运】事件开始！播放 BGM，时长：", total_lifetime)
	else:
		print("【撞大运】事件开始！无 BGM，使用默认时长：", total_lifetime)
	
	# 2. 开启总时长计时器 (整个事件的生命周期)
	total_duration_timer.start(total_lifetime)
	
	# 3. [新增] 启动延迟：等待 start_delay 秒后再生成第一辆车
	print("【撞大运】启动延迟中...等待 ", start_delay, " 秒后卡车来袭")
	get_tree().create_timer(start_delay).timeout.connect(func():
		if is_event_active: # 确保在等待期间事件没结束
			_spawn_one_truck()
	)

# 生成一辆卡车的具体逻辑
func _spawn_one_truck():
	# 如果总时长结束了，就不要再生了
	if not is_event_active: return
	
	# 确保玩家有效
	if not is_instance_valid(player_ref) or player_ref.is_queued_for_deletion():
		return
	
	# 计算屏幕座標雷达
	var canvas = get_tree().root.get_canvas_transform()
	var top_left = -canvas.origin / canvas.get_scale()
	var screen_rect = get_viewport().get_visible_rect()
	var current_screen_size = screen_rect.size / canvas.get_scale()
	
	# 1. 生成的 X 轴坐标（屏幕右边外 200 像素）
	var spawn_x = top_left.x + current_screen_size.x + 200
	
	# 2. 生成的 Y 轴坐标（基于配置的边界）
	var player_y = player_ref.global_position.y
	var spawn_y = randf_range(player_y + spawn_y_offset_min, player_y + spawn_y_offset_max) 
	
	var spawn_pos = Vector2(spawn_x, spawn_y)
	
	# 3. 实例化卡车
	var new_truck = truck_scene.instantiate()
	# 👇 🌟 核心修复：必须先设置好右侧的出生点坐标！ 👇
	new_truck.global_position = spawn_pos
	# 👇 🌟 然后再把它正式加入游戏世界！防瞬移 Bug！ 👇
	get_tree().current_scene.add_child(new_truck)
	
	# 4. 播放生成音效
	if spawn_sfx and has_node("/root/SoundManager"):
		# 优先使用 SoundManager 播放
		get_node("/root/SoundManager").play(spawn_sfx, spawn_pos)
	
	# 🌟 核心：设置下一次随机生成间隔
	var next_interval = randf_range(spawn_interval_min, spawn_interval_max)
	spawn_timer.start(next_interval) 

# 总时长结束，停止生成
func _on_event_finished():
	is_event_active = false
	print("【撞大运】持续时间结束，停止卡车生成。")
	spawn_timer.stop() 
	if bgm_player.playing:
		bgm_player.stop()
