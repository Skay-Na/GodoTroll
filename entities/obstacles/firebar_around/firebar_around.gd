extends Node

@export_group("Circle Spawner Settings")
@export var item_scene: PackedScene 
@export var item_count: int = 8     
@export var radius: float = 100.0   
@export var circle_count: int = 1   # 圈数
@export var circle_spacing: float = 32.0 # 圈间隔
@export var face_center: bool = false 
@export var spawn_delay: float = 0.01 

func spawn_circle():
	if not item_scene:
		print("【生成失败】你忘了在右侧检查器把 item_scene 拖进去了！")
		return
		
	var player = get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player): 
		return

	var center_pos = player.global_position
	var angle_step = (PI * 2.0) / item_count 
	var top_angle = -PI / 2.0 # 正上方的基准角度
	
	# 👇 🌟 核心算法：提前计算好每一批要生成的角度
	var spawn_batches = []
	spawn_batches.append([top_angle]) # 第一批：永远只有头顶那 1 个
	
	var left_to_spawn = item_count - 1
	var step = 1
	
	while left_to_spawn > 0:
		var current_batch = []
		
		# 算右边的角度
		var angle_right = top_angle + (step * angle_step)
		current_batch.append(angle_right)
		left_to_spawn -= 1
		
		# 如果还没生完，就算左边的角度
		if left_to_spawn > 0:
			var angle_left = top_angle - (step * angle_step)
			current_batch.append(angle_left)
			left_to_spawn -= 1
			
		spawn_batches.append(current_batch)
		step += 1

	for circle_idx in range(circle_count):
		var current_radius = radius + circle_idx * circle_spacing
		
		# 👇 🌟 开始按批次生成，每一批生成完等一下（产生向两边滑落的视觉效果）
		for batch in spawn_batches:
			if not is_inside_tree() or not is_instance_valid(player):
				break
				
			for angle in batch:
				var offset = Vector2(cos(angle), sin(angle)) * current_radius
				var spawn_pos = center_pos + offset
				
				var item = item_scene.instantiate()
				get_tree().current_scene.add_child(item)
				item.global_position = spawn_pos
				
				if face_center:
					item.rotation = angle + PI 
				
				item.add_to_group("spawned_trash")
				
			# 每生成完一对（左右），停顿一下
			if spawn_delay > 0:
				await get_tree().create_timer(spawn_delay).timeout

	print("【双向包抄法阵】生成完成！")
