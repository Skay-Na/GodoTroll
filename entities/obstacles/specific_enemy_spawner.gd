extends Node

# エクスポート変数 (导出变量：让你在检查器里挂载3个不同的敌人场景)
@export var enemy_scene_1: PackedScene
@export var enemy_scene_2: PackedScene
@export var enemy_scene_3: PackedScene

@export_group("Spawn Settings")
@export_range(0.0, 1.0) var spawn_min_x_ratio: float = 0.7
@export_range(0.0, 1.0) var spawn_max_x_ratio: float = 1.0
@export var spawn_y_offset: float = -50.0

# 指定された敵を生成する (生成指定的敌人，通过传入的编号区分)
func spawn_specific_enemy(enemy_index: int):
	var player = get_tree().get_first_node_in_group("Player")
	if not player: return

	var scene_to_spawn: PackedScene = null

	# インデックスで判定 (根据编号判断生成哪个敌人)
	if enemy_index == 1: scene_to_spawn = enemy_scene_1
	elif enemy_index == 2: scene_to_spawn = enemy_scene_2
	elif enemy_index == 3: scene_to_spawn = enemy_scene_3

	if not scene_to_spawn:
		print("エラー：敵のシーンが設定されていません (报错：你还没有在右侧检查器里挂载敌人场景！)")
		return

	# 画面サイズを取得 (获取当前屏幕的尺寸和位置)
	var canvas = get_tree().root.get_canvas_transform()
	var screen_rect = player.get_viewport_rect()
	var top_left = -canvas.origin / canvas.get_scale()
	var screen_size = screen_rect.size / canvas.get_scale()

	# 画面の座標を計算 (计算屏幕坐标)
	# X座標: 画面の指定された範囲 (X坐标：屏幕指定比例的区域)
	var min_x = top_left.x + screen_size.x * spawn_min_x_ratio
	var max_x = top_left.x + screen_size.x * spawn_max_x_ratio
	var random_x = randf_range(min_x, max_x)
	
	# Y座標: 画面の少し上 (Y坐标：屏幕最上方边缘再往上偏移)
	var spawn_pos = Vector2(random_x, top_left.y + spawn_y_offset)

	# インスタンス化して追加 (实例化并添加到场景中)
	var new_enemy = scene_to_spawn.instantiate()
	get_tree().current_scene.add_child(new_enemy)
	new_enemy.global_position = spawn_pos
	
	print("右上に敵を生成しました！座標：(已在右上角空投指定敌人！坐标：)", spawn_pos)
