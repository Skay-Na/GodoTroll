extends Node

# 司令部的两个通讯录
var hindrance_actions = {}
var shift_hindrance_actions = {} # 🌟 新增：专门给 Shift 组合键用的高级通讯录

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 建立通讯录：把按键 1 绑定给 RandomEnemies，把按键 2 绑定给 FireSpawner
	hindrance_actions = {
		   #这里删掉了Key 1 触发事件空出一个按键。⚠️ 随机敌人从天而降
		KEY_2: Callable($FireSpawner, "spawn_fire"),      # 👈 天火灭世
		KEY_3: Callable($ScreenInverter, "invert_screen"),  # 👈 画面颠倒
		KEY_4: Callable($FlashbangEffect, "trigger_flashbang"), # 👈 闪光弹
		KEY_5: Callable($SpecificEnemySpawner, "spawn_specific_enemy").bind(1), # 👈 召唤炮灰
		KEY_6: Callable($SpecificEnemySpawner, "spawn_specific_enemy").bind(2), # 👈 召唤炮灰
		KEY_7: Callable($SpecificEnemySpawner, "spawn_specific_enemy").bind(3), # 👈 召唤大哥
		KEY_8: Callable($PlayerScaler, "increase_scale"), # 👈 变大
		KEY_9: Callable($PlayerScaler, "decrease_scale"),  # 👈 变小
		KEY_0: Callable($DiscoFloor, "toggle_disco_mode"),  # DJ舞厅场景
		KEY_MINUS: Callable($ShoeSpawner, "spawn_giant_shoe"), # 给我擦皮鞋
		# KEY_P: Callable($HorseSpawner, "spawn_rocking_horse"),  # 骑大马
		KEY_O: Callable($TruckRushManager, "start_truck_rush_event"), # 撞大运
		KEY_I: Callable($FireRingSpawner, "spawn_fire_ring"), # 跳火圈
		KEY_U: Callable($BearTrapSpawner, "spawn_bear_trap"),  # 捕兽夹
		KEY_R: Callable($RandomSpawnerA, "spawn_random_item"), # 随机管道
		KEY_T: Callable($RandomSpawnerB, "spawn_random_item"),
		KEY_L: Callable($RandomSpawnerC, "spawn_random_item"),
		KEY_K: Callable($KickerSpawner, "spawn_from_left"),  # 从左边出，把人往右踢
		KEY_J: Callable($KickerSpawner, "spawn_from_right"), # 从右边出，把人往左踢
		KEY_H: Callable($Blink, "trigger_teleport"),		 # 传送
		# KEY_V: Callable($test, "play_test_video"), # ⚠️ 节点已缺失，暂时禁用防报错
		KEY_BRACKETLEFT: Callable($LevelSwitcher, "switch_level").bind(-1), # [ 键：上一关
		KEY_BRACKETRIGHT: Callable($LevelSwitcher, "switch_level").bind(1),  # ] 键：下一关
		KEY_F1: Callable($Re11, "back_to_level_1"), # F1 键：返回第一关
		KEY_F2: Callable($ReLocation, "reset_player_to_ground"), # F2 键：玩家复位
		KEY_F3: Callable($AddLife, "add_player_life"), # F3 键：增加生命
	}
	
	# 【特种兵营】🌟 把所有 Shift 组合键写在这里！极其清爽！
	shift_hindrance_actions = {
		KEY_1: Callable($RandomEnemies, "spawn_enemy"),  # 随机敌人
		KEY_T: Callable($TurtleWaveSpawner, "spawn_turtle_wave"),  # 竖排飞行龟
		KEY_M: Callable($RingSmashAttack, "execute_ultimate_attack"),  # 1000管道
		KEY_Y: Callable($TalismanSpawner, "spawn_talisman"),  # 定身符
		KEY_L: Callable($FirebarAround, "spawn_circle") # 👈 Shift + 1: 召唤隐藏大招
		# KEY_2: Callable($SomeNode, "some_function")         # 以后想加 Shift+2，直接在这写一行就行
	}
	# 👇 在 _ready 的最后加上这句，如果没打印，说明上面某行报错崩溃了！
	# print("【系统自检】司令部通讯录已建立，普通技能数量: ", hindrance_actions.size())
	

func _input(event: InputEvent) -> void:
	if get_tree().current_scene and get_tree().current_scene.name == "StartMenu":
		return
		
	if event is InputEventKey and event.pressed and not event.echo:
		
		# 🌟 修复魔法：优先获取键盘上的“物理实体按键”，无视输入法和符号变化
		var actual_key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		
		# print("按下了键位: ", actual_key, " | 字典中是否存在: ", hindrance_actions.has(actual_key))
		
		# 1. 如果玩家按住了 Shift，就去查【高级通讯录】
		if event.shift_pressed:
			if shift_hindrance_actions.has(actual_key):
				print("【特种指令】触发组合键！")
				shift_hindrance_actions[actual_key].call()
			# ⚠️ 拦截核心：只要按了 Shift，不管这个键有没有绑定特种技能，都直接 return！
			# 这样可以防止玩家瞎按 Shift+1 没配技能，却不小心把普通技能的 1 给放出来了。
			return 
			
		# 2. 如果玩家没按 Shift，就查【普通通讯录】
		if hindrance_actions.has(actual_key):
			hindrance_actions[actual_key].call()
			
	
# 👇 🌟 新增：司令部的“一键清场”总开关 🌟 👇
func clear_all_trash():
	# 司令部拿着大喇叭向全图广播：所有贴了 "spawned_trash" 标签的临时垃圾，立刻原地销毁！
	get_tree().call_group("spawned_trash", "queue_free")
	print("【司令部广播】战场打扫完毕！所有临时生成的物品已清除！")
