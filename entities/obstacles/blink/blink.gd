extends Node

# --- 传送参数设置 ---
@export_group("Teleport Settings")
@export var min_tp_distance: float = 100.0  # 传送的最小距离
@export var max_tp_distance: float = 300.0  # 传送的最大距离
@export var player_feet_offset: float = -10.0 # 玩家中心点到脚底的距离
@export var teleport_delay: float = 0.3      # 🌟 新增：传送前的延迟时间

@export_group("Effects")
@export var teleport_effect: PackedScene 
@export var portal_sfx: AudioStream    # 🌟 新增：传送阵音效（与特效同步）
@export var teleport_sfx: AudioStream  # 🌟 新增：瞬间移动音效（延迟后播放）

# 🌟 新增：传送状态锁，防止在暂停期间重复触发
var is_teleporting: bool = false 

# 👇 🌟 专属公共接口：供司令部呼叫 🌟 👇
func trigger_teleport():
	# 如果正在传送中，则不响应新的触发
	if is_teleporting: return
	
	var player = get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player): return

	var space_state = player.get_world_2d().direct_space_state
	
	var floor_mask = 1 << 4 
	var wall_mask = 1 << 3  

	var max_attempts = 15 
	
	for i in range(max_attempts):
		var direction = 1 if randf() <= 0.1 else -1
		var dist = randf_range(min_tp_distance, max_tp_distance)
		var target_x = player.global_position.x + (direction * dist)

		var ray_start = Vector2(target_x, player.global_position.y - 500)
		var ray_end = Vector2(target_x, player.global_position.y + 1000)
		
		var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end, floor_mask)
		var hit_result = space_state.intersect_ray(query)

		if hit_result:
			var floor_y = hit_result.position.y
			var target_y = floor_y - player_feet_offset
			var target_pos = Vector2(target_x, target_y)
			
			var point_query = PhysicsPointQueryParameters2D.new()
			point_query.position = target_pos + Vector2(0, -10) 
			point_query.collision_mask = wall_mask
			var wall_check = space_state.intersect_point(point_query)
			
			if wall_check.is_empty():
				
				# === 🌟 核心修改开始：时停与延迟逻辑 🌟 ===
				
				is_teleporting = true # 上锁
				
				# 1. 暂停游戏世界
				get_tree().paused = true
				
				# 2. 在原位置生成【离开特效】
				var old_feet_pos = player.global_position + Vector2(0, player_feet_offset)
				spawn_effect(old_feet_pos)
				
				# 3. 等待 0.3 秒
				# (Godot 4 的 create_timer 默认 process_always=true，所以在暂停时也会继续倒数)
				await get_tree().create_timer(teleport_delay).timeout
				
				# 4. 0.3秒后，真正移动玩家！
				if teleport_sfx and has_node("/root/SoundManager"):
					get_node("/root/SoundManager").play(teleport_sfx, target_pos)
					
				player.global_position = target_pos
				
				# 5. 在新位置生成【到达特效】
				var new_feet_pos = target_pos + Vector2(0, player_feet_offset)
				spawn_effect(new_feet_pos)
				
				# 6. 恢复游戏世界的时间流逝
				get_tree().paused = false
				
				# 7. 给玩家加上无敌帧，防止传送后立即受伤
				if player.has_method("start_invincibility"):
					player.start_invincibility(1.0)
				
				# === 🌟 核心修改结束 🌟 ===
				
				if player.has_method("set_velocity"):
					player.velocity = Vector2.ZERO
					
				print("【Blink 传送】成功！")
				
				is_teleporting = false # 解锁
				return 

	print("【Blink 传送】失败：找不到安全着陆点！")


# 👇 🌟 生成特效的辅助函数 🌟 👇
func spawn_effect(pos: Vector2):
	if teleport_effect == null:
		print("⚠️ 警告：还没有在检查器中设置 Teleport Effect！")
		return
		
	var effect = teleport_effect.instantiate()
	
	# 【最关键的一步】：设置特效无视暂停！
	# 这样即使 get_tree().paused = true，这个特效的动画依然会正常播放
	effect.process_mode = Node.PROCESS_MODE_ALWAYS
	
	get_tree().current_scene.add_child(effect)
	effect.global_position = pos
	
	# 🌟 新增：播放传送阵音效
	if portal_sfx and has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play(portal_sfx, pos)
