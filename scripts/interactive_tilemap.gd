extends TileMapLayer

func hit_tile_by_mario(map_pos: Vector2i, is_big: bool, is_superman: bool = false):
	var tile_data = get_cell_tile_data(map_pos)
	if not tile_data:
		return
		
	var type = tile_data.get_custom_data("tile_type")
	var item_type = tile_data.get_custom_data("item_type")
	var global_pos = to_global(map_to_local(map_pos))
	
	# 如果是问号块，或者藏了东西的普通砖块
	if type == "question" or (item_type != null and item_type != ""):
		var anim_name = "Anim_" + str(map_pos.x) + "_" + str(map_pos.y)
		if has_node(anim_name):
			get_node(anim_name).queue_free()
			
		if item_type != null and item_type != "":
			var p_state = 1 if is_big else 0 # 简化起见，传 1 当作非小人
			GameManager.spawn_item(item_type, global_pos, p_state)
			
		# 顶道具砖不播放撞击音效（通常道具自己有音效）
		GameManager.play_block_bounce(self, map_pos, global_pos, false)
			
	# 2. 处理普通砖块 (brick)
	elif type == "brick" or type == "brick_green":
		if is_big:
			# 大人顶普通砖块 -> 碎裂 (音效在 GameManager 里播放)
			GameManager.spawn_brick_particles(global_pos, tile_data)
			set_cell(map_pos, -1)
		else:
			# 小人顶普通砖块 -> 弹跳动画 + 音效
			var source_id = get_cell_source_id(map_pos)
			var atlas_coords = get_cell_atlas_coords(map_pos)
			GameManager.play_regular_block_bounce(self, map_pos, global_pos, source_id, atlas_coords)
			
	# 3. 其他所有无法破坏的情况（已经是空块、地面等）
	else:
		# 仅播放音效，不播放弹跳动画
		# 新增：超人形态撞墙/地不播放音效
		if not is_superman and has_node("/root/SoundManager"):
			get_node("/root/SoundManager").play_bump(global_pos)
