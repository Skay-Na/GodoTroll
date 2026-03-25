extends Node

@export var enemy_scenes: Array[PackedScene] = []

func _ready():
	print("【随机敌人模块】准备就绪，加载了 ", enemy_scenes.size(), " 种敌人！")

# ==========================================
# 核心：这是暴露给长官调用的专属技能
# ==========================================
func spawn_enemy():
	var player = get_tree().get_first_node_in_group("Player")
	if not player or enemy_scenes.is_empty(): return

	# 计算屏幕范围并扔下怪物
	var canvas = get_tree().root.get_canvas_transform()
	var screen_rect = player.get_viewport_rect()
	var top_left = -canvas.origin / canvas.get_scale()
	var screen_size = screen_rect.size / canvas.get_scale()

	var random_x = randf_range(top_left.x, top_left.x + screen_size.x)
	var spawn_pos = Vector2(random_x, top_left.y - 50) 

	var new_enemy = enemy_scenes.pick_random().instantiate()
	get_tree().current_scene.add_child(new_enemy)
	new_enemy.global_position = spawn_pos
	
	print("【随机敌人模块】收到长官命令，执行空投！坐标：", spawn_pos)
