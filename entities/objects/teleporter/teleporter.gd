extends Area2D

# 导出一个文件路径变量到检查器（Inspector）面板，允许你直接把目标场景拖进去
@export_file("*.tscn") var target_scene_path: String
@export var teleporter_id: String = "" # 给当前这个水管起个名字（比如 "A"）
@export var target_teleporter_id: String = "" # 传送到哪个水管的名字（比如 "B"）
@export var require_input: bool = false # 是否需要按下键才能触发传送
@export var transition_scene: PackedScene # 过渡场景变量（若存在，则先播放此场景再跳转）
@export var teleport_delay: float = 5.0 # 自动传送的延迟时间
@export var teleport_sound: AudioStream # 按下键传送时的音效


var player_node: CharacterBody2D = null


func _on_body_entered(body):
	# 判断进入的是否是玩家
	if body.name == "Player":
		player_node = body
		if not require_input:
			print("💡传送门：", teleport_delay, "秒后自动进入传送")
			await get_tree().create_timer(teleport_delay).timeout
			if player_node:
				teleport()

func _on_body_exited(body):
	if body == player_node:
		player_node = null

func _process(_delta):
	if require_input and player_node:
		if Input.is_action_just_pressed("ui_down"):
			print("💡传送门：按下键触发传送")
			if teleport_sound:
				if has_node("/root/SoundManager"):
					get_node("/root/SoundManager").play(teleport_sound, global_position)
			teleport()


func teleport():
	# 记录过关时，玩家当前的变身形态存到单例 GameManager 里
	if player_node:
		GameManager.player_state = player_node.current_state as int
	
	# 🌟【修复】跨关卡传送时立即重置存档点，防止干扰新场景
	if target_scene_path != "" and target_scene_path != null:
		print("🚩 跨关卡传送，正在重置存档点坐标")
		GameManager.checkpoint_position = Vector2.ZERO
	
	# 🌟【新增】过渡场景逻辑
	if transition_scene:
		GameManager.transition_target_scene = target_scene_path if target_scene_path != "" else get_tree().current_scene.scene_file_path
		GameManager.transition_target_id = target_teleporter_id
		# 同时兼容原有的 ID 传递机制
		GameManager.target_teleporter_id = target_teleporter_id
		print("🎬 正在前往过渡场景，最终目的地: ", GameManager.transition_target_scene)
		get_tree().call_deferred("change_scene_to_packed", transition_scene)
		return

	if target_scene_path != null and target_scene_path != "":
		# 🚀 跨地图传送
		# 只有在完全没有 ID 标识（纯关卡切换）时才播放音效
		if teleporter_id == "" and target_teleporter_id == "":
			if has_node("/root/SoundManager"):
				get_node("/root/SoundManager").play_pipe()
		
		GameManager.target_teleporter_id = target_teleporter_id
		print("🚀 正传送到下一关: ", target_scene_path, " 目标 ID: ", target_teleporter_id)
		get_tree().call_deferred("change_scene_to_file", target_scene_path)
	elif target_teleporter_id != "":
		# 🏠 同地图传送
		print("🏠 同地图传送，寻找目标: ", target_teleporter_id)
		var teleporters = get_tree().get_nodes_in_group("teleporters")
		for t in teleporters:
			if t is Area2D and t.get("teleporter_id") == target_teleporter_id:
				if player_node:
					player_node.global_position = t.global_position
					print("✅ 已传送到目标: ", target_teleporter_id)
				return
		print("❌ 错误：在当前地图找不到 ID 为 ", target_teleporter_id, " 的传送门！")
	else:
		print("❌ 传送门错误：既没填 target_scene_path 也没填 target_teleporter_id！")

func _ready():
	# 确保连接了碰撞信号
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# 将传送门加入组，方便同地图搜索
	add_to_group("teleporters")
