extends Node

## 🌟 玩家复位：从天而降的射线检测地板
func reset_player_to_ground():
	var player = get_tree().get_first_node_in_group("Player")
	if not is_instance_valid(player):
		print("【复位】未找到玩家节点！")
		return
	
	# 如果玩家已经挂了，也不复位了
	if player.get("is_dead"):
		return
		
	var space_state = player.get_world_2d().direct_space_state
	var x = player.global_position.x
	
	# 射线：从天上开启扫描，往下戳 5000 像素
	var from = Vector2(x, -1000)
	var to = Vector2(x, 5000)
	
	var query = PhysicsRayQueryParameters2D.create(from, to)
	# 排除玩家自身，防止射线还没出发就在玩家身上撞停了
	query.exclude = [player.get_rid()]
	# 层判定：碰撞层 1 (地形) 和 层 5 (地面)
	query.collision_mask = 16 # 1: Layer 1, 16: Layer 5 (2^4)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var target_pos = result.position
		# 稍微抬高一点点，防止脚陷进地板导致跳不起来
		player.global_position = target_pos - Vector2(0, 5)
		
		# 强制重置速度，防止带着之前的冲量飞出去
		if "velocity" in player:
			player.velocity = Vector2.ZERO
			
		print("【复位】魔法大搬运！玩家已传送到坐标: ", player.global_position)
	else:
		print("【复位】下方空空如也，传送失败！")
