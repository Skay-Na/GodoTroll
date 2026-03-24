extends Node

# 这个脚本将被配置为 Autoload (单例)，永远在后台运行
var empty_block_source_id: int = 2
var empty_block_atlas_coords: Vector2i = Vector2i(4, 0)

const QUESTION_ANIM_SCENE = preload("uid://di6bxvq1b3reh")
const BRICK_PARTICLES_SCENE = preload("uid://si2tj5coc0tm")
const COIN_SCENE = preload("uid://nxh4u48eahux")
const MUSHROOM_SCENE = preload("uid://bgei5ldiavn6v")
const FLOWER_SCENE = preload("uid://dk8p42y28o1rf")
const FIREBAR_SCENE = preload("uid://dw7urmu8rv1fp")
const EXTRA_LIFE_SCENE = preload("uid://ta5lyg80trgn")

var initial_tile_states: Dictionary = {}
var coins: int = 0
var lives: int = 18
var player_state: int = 0 
var target_teleporter_id: String = ""
var transition_target_scene: String = "" # 过渡场景结束后的目标场景路径
var transition_target_id: String = ""    # 过渡场景结束后的目标传送门 ID
var checkpoint_position: Vector2 = Vector2.ZERO # 🌟【新增】持久化存储存档点坐标
var pending_respawn_traps: Array = [] # 🌟【新增】持久化陷阱

# ==========================================
# 在原有变量下方添加倒计时相关变量
# ==========================================
var default_level_time: int = 150 # 默认关卡时间（例如300秒）
var time_left: int = 0
var level_timer: Timer

# 用于存储当前关卡显示的文本
var current_level_name: String = "WORLD 1-1"
# signal score_changed(new_score) (REMOVED)
signal coins_changed(new_coins)
signal lives_changed(new_lives)
signal reset_level
signal time_changed(new_time) # 用于更新 UI 界面
signal time_up # 时间到的专属信号，方便通知 Player 播放死亡动画（可选）

# 【关卡名】当关卡名字更新时通知 HUD
signal level_name_changed(new_name)

func _ready():
	get_tree().node_added.connect(_on_node_added)
	reset_level.connect(_on_reset_level)
	
	# 🌟【时间系统】动态初始化关卡计时器
	level_timer = Timer.new()
	level_timer.wait_time = 1.0 # 每秒触发一次
	level_timer.autostart = false
	level_timer.timeout.connect(_on_level_timer_timeout)
	add_child(level_timer)
	
	call_deferred("init_current_scene")

func _on_node_added(node: Node):
	if node is TileMapLayer:
		call_deferred("_process_tilemap", node, false)

func init_current_scene():
	# 🌟【重要修复】单例在重新加载场景时不会重置，必须手动清空旧字典，否则会导致严重内存泄漏！
	initial_tile_states.clear() 
	var scene = get_tree().current_scene
	if scene:
		var new_level_name = scene.level_display_name if "level_display_name" in scene else "UNKNOWN AREA"
		
		# 🌟【新增】如果关卡名字变了（说明是换关，而不是复活重载），重置存档点
		if new_level_name != current_level_name:
			checkpoint_position = Vector2.ZERO
			current_level_name = new_level_name
			print("【GameManager 🚩】检测到进入新关卡 [", current_level_name, "]，已重置存档点。")
		
		level_name_changed.emit(current_level_name)
		scan_all_tilemaps(scene)
		if scene.name != "StartMenu":
			start_level_timer()
		else:
			stop_level_timer()
	call_deferred("restore_pending_traps")


# 🌟【精简优化】利用 Godot 4 原生查找功能，直接砍掉旧的 _gather_tilemaps 递归函数
func scan_all_tilemaps(node: Node, is_reset: bool = false):
	# 🌟【健壮性修复】如果主场景正在切换，get_tree().current_scene 可能是 null
	if not node:
		return
		
	if node is TileMapLayer:
		_process_tilemap(node, is_reset)
	for tilemap in node.find_children("*", "TileMapLayer", true, false):
		_process_tilemap(tilemap, is_reset)

func _process_tilemap(tilemap: TileMapLayer, is_reset: bool = false):
	if not tilemap.tile_set or tilemap.tile_set.get_custom_data_layer_by_name("tile_type") < 0:
		return
		
	var used_cells = tilemap.get_used_cells()
	var count = 0
	var coin_count = 0
	var firebar_count = 0
	
	for cell_pos in used_cells:
		var tile_data = tilemap.get_cell_tile_data(cell_pos)
		if not tile_data: continue
			
		var tile_type = tile_data.get_custom_data("tile_type")
		var item_type = tile_data.get_custom_data("item_type")
		
		# 1. 记录需要复原的砖块状态
		if not is_reset and (tile_type == "question" or (tile_type in ["brick", "brick_green"] and item_type in ["powerup", "extraLife"])):
			# 🌟【精简优化】更优雅的字符串格式化拼接
			var key_str = "%d_%d_%d" % [tilemap.get_instance_id(), cell_pos.x, cell_pos.y]
			if not initial_tile_states.has(key_str):
				initial_tile_states[key_str] = {
					"tilemap": tilemap, "coords": cell_pos,
					"source_id": tilemap.get_cell_source_id(cell_pos),
					"atlas_coords": tilemap.get_cell_atlas_coords(cell_pos),
					"alternative_tile": tilemap.get_cell_alternative_tile(cell_pos)
				}
				
		# 2. 生成发光问号
		if tile_type == "question":
			var anim_name = "Anim_%d_%d" % [cell_pos.x, cell_pos.y]
			if tilemap.has_node(anim_name): continue
				
			var anim_instance = QUESTION_ANIM_SCENE.instantiate()
			anim_instance.name = anim_name
			anim_instance.add_to_group("question_anims")
			anim_instance.global_position = tilemap.to_global(tilemap.map_to_local(cell_pos))
			tilemap.add_child(anim_instance)
			count += 1
			
		# 3. 替换实体金币
		elif tile_type == "coin" and not is_reset:
			var coin_instance = COIN_SCENE.instantiate()
			coin_instance.global_position = tilemap.to_global(tilemap.map_to_local(cell_pos))
			tilemap.add_child(coin_instance)
			tilemap.set_cell(cell_pos, -1)
			coin_count += 1
			
		# 4. 生成火把
		if item_type == "firebar" and not is_reset and FIREBAR_SCENE:
			var firebar_instance = FIREBAR_SCENE.instantiate()
			firebar_instance.global_position = tilemap.to_global(tilemap.map_to_local(cell_pos))
			tilemap.add_child(firebar_instance)
			tilemap.set_cell(cell_pos, -1) # 防止重复生成
			firebar_count += 1
			
	if count > 0 or coin_count > 0 or firebar_count > 0:
		print("【GameManager ✔️】地图 [", tilemap.name, "] 铺设: ", count, "个问号, ", coin_count, "个金币, ", firebar_count, "个火把")

func _on_reset_level():
	print("【GameManager】收到重置信号，正在刷新地图砖块...")
	for key in initial_tile_states:
		var state = initial_tile_states[key]
		if is_instance_valid(state.tilemap):
			state.tilemap.set_cell(state.coords, state.source_id, state.atlas_coords, state.alternative_tile)
	
	call_deferred("scan_all_tilemaps", get_tree().current_scene, true)

func save_pending_traps():
	# === 收集当前场景中的限制陷阱 ===
	pending_respawn_traps.clear()
	var horses = get_tree().get_nodes_in_group("ActiveHorse")
	for trap in horses:
		if is_instance_valid(trap):
			pending_respawn_traps.append({
				"scene_file_path": trap.scene_file_path,
				"type": "horse",
				"count": trap.loops_remaining,
				"required_presses": trap.get("required_presses") if "required_presses" in trap else 20
			})
			
	var talismans = get_tree().get_nodes_in_group("active_binding_talisman")
	for trap in talismans:
		if is_instance_valid(trap):
			pending_respawn_traps.append({
				"scene_file_path": trap.scene_file_path,
				"type": "talisman",
				"count": trap.stack_count
			})
			
	var shoes = get_tree().get_nodes_in_group("giant_shoes")
	for trap in shoes:
		if is_instance_valid(trap):
			pending_respawn_traps.append({
				"scene_file_path": trap.scene_file_path,
				"type": "shoe",
				"required_polishes": trap.required_polishes,
				"current_polishes": trap.current_polishes,
				"global_position": trap.global_position
			})
	# ==============================

func restore_pending_traps():
	if pending_respawn_traps.size() == 0: return
	var player = get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player): return
	
	var camera = player.get_viewport().get_camera_2d()
	var screen_center = camera.get_screen_center_position() if camera else player.global_position
	
	for t_data in pending_respawn_traps:
		var scene = load(t_data["scene_file_path"])
		if scene:
			var trap = scene.instantiate()
			get_tree().current_scene.add_child(trap)
			if t_data["type"] == "horse":
				if "required_presses" in trap: trap.required_presses = t_data.get("required_presses", 20)
				trap.start_riding(player, screen_center)
				trap.loops_remaining = t_data["count"]
				if trap.has_method("update_loop_ui"): trap.update_loop_ui()
			elif t_data["type"] == "talisman":
				trap.add_to_group("spawned_trash")
				trap.activate_talisman(player, screen_center)
				trap.stack_count = t_data["count"]
				if trap.has_method("_update_stack_ui"): trap._update_stack_ui()
			elif t_data["type"] == "shoe":
				trap.add_to_group("giant_shoes")
				trap.add_to_group("spawned_trash")
				trap.setup_and_start_stomp(t_data["global_position"], t_data["required_polishes"], 800.0)
				trap.current_polishes = t_data["current_polishes"]
				
	pending_respawn_traps.clear()

# ==========================================
# 倒计时系统管理
# ==========================================
func start_level_timer(time: int = default_level_time):
	time_left = time
	time_changed.emit(time_left)
	level_timer.start()
	print("【GameManager ⏱️】倒计时开始：", time_left, "秒")

func stop_level_timer():
	level_timer.stop()

func _on_level_timer_timeout():
	if time_left > 0:
		time_left -= 1
		time_changed.emit(time_left)
		
		# 当时间只剩 100 秒时，可以播放快节奏背景音乐（如果需要的话留个接口）
		if time_left == 100 and has_node("/root/SoundManager"):
			print("【GameManager ⚠️】时间不多了！")
			# get_node("/root/SoundManager").play_hurry_up()
			
		if time_left <= 0:
			_handle_time_up()

func _handle_time_up():
	stop_level_timer()
	print("【GameManager 💀】时间到！玩家死亡。")
	time_up.emit()
	
	var player = get_tree().get_first_node_in_group("Player")
	if is_instance_valid(player) and player.has_method("die"):
		player.die()
	else:
		save_pending_traps()
		lose_life()
	
# ==========================================
# 游戏状态管理
# ==========================================
# add_score(amount: int) (REMOVED)

func add_coin():
	coins += 1
	if coins >= 1999:
		coins = 0
		add_life()
	coins_changed.emit(coins)

func add_life():
	lives += 1
	lives_changed.emit(lives)
	print("1-UP! 当前生命:", lives)

func lose_life():
	stop_level_timer() # 死亡瞬间，时间停止
	
	lives -= 1
	lives_changed.emit(lives)
	
	if lives <= 0: 
		game_over()
	else:
		print("【GameManager】玩家死亡，正在重新加载当前关卡...")
		# 重新加载当前场景，触发新场景的 _ready()，进而重置时间
		get_tree().reload_current_scene()

func game_over():
	print("Game Over!")
	stop_level_timer() # 🌟【新增】停止计时
	pending_respawn_traps.clear()
	lives = 18
	coins = 0
	player_state = 0
	current_level_name = "WORLD 1-1" # 🌟【新增关卡名】重置为第一关
	checkpoint_position = Vector2.ZERO # 🌟【新增】重置存档点
	lives_changed.emit(lives)
	coins_changed.emit(coins)
	level_name_changed.emit(current_level_name) # 通知UI显示第一关名字
	get_tree().change_scene_to_file("res://scenes/hud/start_menu.tscn")

# ==========================================
# 互动视觉与生成逻辑
# ==========================================
func play_block_bounce(body: TileMapLayer, map_pos: Vector2i, global_pos: Vector2, play_sfx: bool = true):
	var anim_name = "Anim_%d_%d" % [map_pos.x, map_pos.y]
	var anim_node = body.get_node_or_null(anim_name)
	if anim_node: anim_node.free()
		
	body.set_cell(map_pos, -1)
	_animate_bounce(body, map_pos, global_pos, empty_block_source_id, empty_block_atlas_coords, play_sfx, -8, Color.WHITE)

func play_regular_block_bounce(body: TileMapLayer, map_pos: Vector2i, global_pos: Vector2, source_id: int, atlas_coords: Vector2i):
	body.set_cell(map_pos, -1)
	_animate_bounce(body, map_pos, global_pos, source_id, atlas_coords, true, -6, Color(3.0, 3.0, 3.0))

# 🌟【精简优化】把两种砖块弹跳的高度重合部分抽离出来，极大地精简了代码
func _animate_bounce(body: TileMapLayer, map_pos: Vector2i, global_pos: Vector2, source_id: int, atlas_coords: Vector2i, play_sfx: bool, y_offset: float, start_color: Color):
	var fake_block = Sprite2D.new()
	var source = body.tile_set.get_source(source_id) as TileSetAtlasSource
	fake_block.texture = source.texture
	fake_block.region_enabled = true
	var tile_size = body.tile_set.tile_size
	fake_block.region_rect = Rect2(atlas_coords.x * tile_size.x, atlas_coords.y * tile_size.y, tile_size.x, tile_size.y)
	fake_block.global_position = global_pos
	fake_block.modulate = start_color
	body.add_child(fake_block)
	
	var tween = create_tween()
	var start_y = global_pos.y
	tween.tween_property(fake_block, "position:y", start_y + y_offset, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if start_color != Color.WHITE: tween.parallel().tween_property(fake_block, "modulate", Color.WHITE, 0.15)
	
	if play_sfx and has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play_bump(global_pos)
		
	tween.tween_property(fake_block, "position:y", start_y, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		fake_block.queue_free()
		if is_instance_valid(body): body.set_cell(map_pos, source_id, atlas_coords)
	)

func spawn_item(item_type: String, global_pos: Vector2, p_state: int):
	var item_instance = null
	match item_type:
		"coin": item_instance = COIN_SCENE.instantiate() if COIN_SCENE else null
		"powerup": item_instance = (FLOWER_SCENE if p_state > 0 else MUSHROOM_SCENE).instantiate()
		"extraLife": item_instance = EXTRA_LIFE_SCENE.instantiate() if EXTRA_LIFE_SCENE else null
		_: print("【警告】未知的物品类型：", item_type)
	
	if item_instance:
		get_tree().current_scene.add_child(item_instance)
		item_instance.add_to_group("spawned_trash") # 贴上垃圾标签！
		item_instance.global_position = global_pos
		if item_instance.has_method("pop_out"): item_instance.pop_out()

func spawn_brick_particles(global_pos: Vector2, tile_data: TileData):
	if not BRICK_PARTICLES_SCENE: return
	var particles = BRICK_PARTICLES_SCENE.instantiate()
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_pos
	
	if has_node("/root/SoundManager"): get_node("/root/SoundManager").play_break(global_pos)
	if particles.has_method("setup_particles"): particles.setup_particles(tile_data)
	particles.emitting = true

# ==========================================
# 战场打扫逻辑
# ==========================================
func clear_all_trash():
	get_tree().call_group("spawned_trash", "queue_free")
	print("【GameManager 🧹】清场完毕！所有临时垃圾已被回收！")
