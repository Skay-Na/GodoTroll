extends Node

# 在右侧检查器里拖入 giant_shoe.tscn
@export var shoe_scene: PackedScene

## 落点相对玩家的水平偏移（正数 = 玩家前方）
@export var landing_x_offset: float = 150.0

## 落点相对玩家的垂直偏移（正数 = 玩家下方）
@export var landing_y_offset: float = 0.0

## 多个皮鞋时的水平偏移量（向左偏移）
@export var multi_shoe_offset_x: float = 10.0

## 【核心调节】擦鞋完成所需按键次数
@export var required_polishes: int = 15

## 【核心调节】皮鞋从多高砸下来（像素）
@export var stomp_drop_height: float = 800.0

func spawn_giant_shoe():
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not shoe_scene: return
	
	# 计算落点坐标（基于屏幕中心，不随玩家移动）
	var canvas = get_tree().root.get_canvas_transform()
	var screen_rect = player.get_viewport_rect()
	var screen_center = -canvas.origin / canvas.get_scale() + (screen_rect.size / canvas.get_scale() / 2.0)
	
	var existing_count = get_tree().get_nodes_in_group("giant_shoes").size()
	var final_blocking_pos = screen_center + Vector2(landing_x_offset + (existing_count * multi_shoe_offset_x), landing_y_offset)
	
	# 皮鞋のインスタンス化 (生成皮鞋)
	var new_shoe = shoe_scene.instantiate()
	get_tree().current_scene.add_child(new_shoe)
	new_shoe.add_to_group("giant_shoes")
	new_shoe.add_to_group("spawned_trash")
	
	# 大皮鞋のセットアップ (呼叫皮鞋的专属出场函数，告诉它砸在哪，以及需要擦多少次)
	if new_shoe.has_method("setup_and_start_stomp"):
		new_shoe.setup_and_start_stomp(final_blocking_pos, required_polishes, stomp_drop_height)
