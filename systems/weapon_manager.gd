extends Node2D
class_name WeaponManager

# 1. 定义目前的三种武器（对应你的节点树）
enum WeaponType { PISTOL, MACHINE_GUN, FIREBALL }

# 默认给个火球方便测试，你可以随时改
var current_weapon: WeaponType = WeaponType.FIREBALL 

# 2. 导出变量，在右侧检查器中把你做好的子弹/火球场景拖进来
@export var pistol_scene: PackedScene
@export var machine_gun_scene: PackedScene
@export var fireball_scene: PackedScene

# 3. 获取对应的计时器节点 (严格对应你左侧的节点树)
@onready var pistol_timer = $Pistol/FireRateTimer
@onready var mg_timer = $MachineGun/FireRateTimer
@onready var fireball_timer = $Fireball/FireRateTimer

# 4. 马里奥调用的统一开火接口 (加入了 is_mario_on_floor 参数)
func shoot(direction: int, spawn_pos: Vector2, is_mario_on_floor: bool = true):
	match current_weapon:
		WeaponType.PISTOL:
			if pistol_timer.is_stopped():
				pistol_timer.start()
				_spawn_projectile(pistol_scene, direction, spawn_pos, is_mario_on_floor)
				
		WeaponType.MACHINE_GUN:
			if mg_timer.is_stopped():
				mg_timer.start()
				_spawn_projectile(machine_gun_scene, direction, spawn_pos, is_mario_on_floor)
				
		WeaponType.FIREBALL:
			if fireball_timer.is_stopped():
				fireball_timer.start()
				_spawn_projectile(fireball_scene, direction, spawn_pos, is_mario_on_floor)
				if has_node("/root/SoundManager"):
					get_node("/root/SoundManager").play_fireball()

# 5. 统一的生成逻辑
func _spawn_projectile(proj_scene: PackedScene, dir: int, pos: Vector2, is_mario_on_floor: bool):
	if proj_scene == null:
		push_warning("子弹场景未赋值！请在右侧检查器中拖入对应的 tscn 文件。")
		return
		
	var proj = proj_scene.instantiate()
	proj.direction = dir
	proj.global_position = pos
	
	# 如果生成的子弹脚本里有 is_bouncing_mode 这个变量（专门针对火球写的逻辑），就传给它
	if "is_bouncing_mode" in proj:
		proj.is_bouncing_mode = is_mario_on_floor
		
	# 将子弹添加到当前场景树的主节点下，防止跟着马里奥移动
	get_tree().current_scene.add_child(proj)

# 6. 切换武器接口
func switch_weapon(new_weapon: WeaponType):
	if current_weapon != new_weapon:
		current_weapon = new_weapon
		print("当前武器已切换为: ", current_weapon)
