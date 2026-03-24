extends Node

@export_group("Wave Turtle Settings")
@export var turtle_scene: PackedScene     # 飞行龟的场景
@export var columns: int = 3              # 列数 (一共有几波)
@export var turtles_per_column: int = 4   # 每列数量 (一波有几只)
@export var column_spacing: float = 150.0 # 列与列之间的横向间距
@export var row_spacing: float = 80.0     # 上下乌龟的间距

@export_group("Movement Settings")
@export var move_speed: float = 150.0      # 向左飞行的速度
@export var wave_amplitude: float = 80.0   # 波浪上下浮动的幅度 (越大越上下颠簸)
@export var wave_frequency: float = 4.0    # 波浪滚动的快慢 (频率)
@export var stop_screen_ratio: float = 0.25 # 停止在屏幕位置的比例 (0为最左侧，1为最右侧，0.25即1/4处)

# 司令部用来记录所有活着、还在飞的乌龟
var active_turtles: Array[Dictionary] = []

# 按键绑定的触发函数
func spawn_turtle_wave():
	if not turtle_scene:
		print("【生成失败】右边检查器忘了放飞行龟场景！")
		return
		
	var player = get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player): return
	
	# 1. 确定起点：基于屏幕计算（无视玩家高度就能铺满整个垂直屏幕）
	var canvas = get_tree().root.get_canvas_transform()
	var top_left = -canvas.origin / canvas.get_scale()
	var screen_rect = get_viewport().get_visible_rect()
	var current_screen_size = screen_rect.size / canvas.get_scale()
	
	var start_x = top_left.x + current_screen_size.x + 200.0
	var center_y = top_left.y + (current_screen_size.y / 2.0) # 屏幕垂直绝对居中
	
	# 算一下整列乌龟的总高度，好让它们在空中上下居中对齐
	var total_height = (turtles_per_column - 1) * row_spacing
	var start_y = center_y - (total_height / 2.0)
	
	# 2. 矩阵生成魔法
	for col in range(columns):
		for row in range(turtles_per_column):
			var t = turtle_scene.instantiate()
			get_tree().current_scene.add_child(t)
			
			var spawn_pos_x = start_x + (col * column_spacing)
			var spawn_pos_y = start_y + (row * row_spacing)
			t.global_position = Vector2(spawn_pos_x, spawn_pos_y)
			
			# 贴上垃圾标签，方便清场
			t.add_to_group("spawned_trash")
			
			# 让这个龟无视地形（清理掉碰撞遮罩，让它成为纯粹飞行的幽灵，但玩家还是能撞到它的 Layer）
			if t is CollisionObject2D:
				t.collision_mask = 0
				
			# 👇 🌟 核心：计算每只乌龟的“初始波浪相位”。
			# 加上 row 和 col 的偏移量，它们就不会直上直下，而是像蛇/波浪一样扭动前进！
			var phase_offset = col * 0.5 + row * 0.2 
			
			active_turtles.append({
				"node": t,
				"base_y": spawn_pos_y, # 记录它最初的高度基准线
				"time": phase_offset   # 给每个人不同的起始时间差
			})
			
	print("【飞行方阵】已生成！", columns, " 列 x ", turtles_per_column, " 行！")

# 3. 实时接管飞行轨迹
func _physics_process(delta):
	if active_turtles.is_empty():
		return
		
	# 计算屏幕的目标停止坐标 (相对于相机的 world 坐标)
	var canvas = get_tree().root.get_canvas_transform()
	var top_left = -canvas.origin / canvas.get_scale()
	var screen_rect = get_viewport().get_visible_rect()
	var current_screen_size = screen_rect.size / canvas.get_scale()
	var target_stop_x = top_left.x + current_screen_size.x * stop_screen_ratio

	# 必须用倒序遍历！因为如果有乌龟被玩家打死了，我们需要安全地把它从名单里删掉
	for i in range(active_turtles.size() - 1, -1, -1):
		var data = active_turtles[i]
		var t = data["node"]
		
		# 🌟 如果这只乌龟已经被玩家踩死/打死（节点被销毁了），直接移出名单，不再控制它
		if not is_instance_valid(t):
			active_turtles.remove_at(i)
			continue
			
		# 更新这只乌龟的波浪时间
		data["time"] += delta
		
		# 始终尝试往前飞 (根据 move_speed)
		var new_x = t.global_position.x - (move_speed * delta)
		
		# 动态拦截：如果越过了屏幕的停止线，就将其强行推回停止线
		# 这样如果镜头往右走，停止线往右，乌龟就会被“带”着往右走 (跟着往后移)
		# 如果镜头往左走（回退），停止线往左，乌龟不会瞬间跟着退，而是以正常速度继续左飞 (只会前进)
		if move_speed > 0 and new_x < target_stop_x:
			new_x = target_stop_x
		elif move_speed < 0 and new_x > target_stop_x:
			new_x = target_stop_x
				
		# 结合 sin (正弦波) 函数，算出它这一帧应该在什么高度
		var new_y = data["base_y"] + sin(data["time"] * wave_frequency) * wave_amplitude
		
		t.global_position = Vector2(new_x, new_y)
