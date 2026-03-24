extends GPUParticles2D

# 定义一个初始化函数，接收砖块的 TileData
func setup_particles(tile_data: TileData):
	if not tile_data:
		return
		
	# 1. 获取砖块类型或自定义贴图数据
	var type = tile_data.get_custom_data("tile_type")
	
	# 2. 根据类型选择贴图
	# 假设你有不同的碎片贴图存储在 res://assets/ 目录下
	if type == "brick_green":
		# 如果是普通砖块，可以使用蓝色的碎片纹理
		texture = load("res://picture/青砖.png")
	elif type == "brick":
		# 如果是红色砖块，切换纹理
		texture = load("res://picture/红砖.png")
	
	# 3. 如果你不想换贴图，只想改颜色（最快的方法）
	# var b_color = tile_data.get_custom_data("particle_color")
	# modulate = b_color

func _ready():
	# 现有的销毁逻辑保持不变
	await get_tree().create_timer(lifetime).timeout
	queue_free()
