extends Node

# 暴露在右侧检查器中，你可以直接在这里增删改查你的关卡路径！
@export var level_list: Array[String] = [
	"uid://vvfqdyybbry4", # 替换成你的第 1 关路径
	"uid://bihrelsmqtart", # 替换成你的第 2 关路径
	"uid://bwicj5vislwgy",
	"uid://dneqb5u3sv25v", # 替换成你的第 3 关路径
	"uid://8783dlolhuu",
	"uid://40ktrvkogjnn",
	"uid://dkdi7hp0v44g4",
	"uid://6s70cytjmmg7",
	"uid://bjq8xfl3ymjic"
]

# 核心切关逻辑：接收司令部的命令（-1 或 1）
func switch_level(step: int):
	# 1. 获取当前场景的绝对路径
	var current_path = get_tree().current_scene.scene_file_path
	
	# 尝试获取当前场景的 UID
	var current_uid = ""
	var current_uid_id = ResourceLoader.get_resource_uid(current_path)
	if current_uid_id != -1:
		current_uid = ResourceUID.id_to_text(current_uid_id)
	
	# 2. 在我们的清单里查一下，当前关卡排第几？
	var current_index = -1
	for i in range(level_list.size()):
		# 兼容传统的 res:// 路径和新的 uid:// 格式
		if level_list[i] == current_path or (current_uid != "" and level_list[i] == current_uid):
			current_index = i
			break
	
	# 防错机制：如果当前场景不在清单里
	if current_index == -1:
		print("【切关失败】当前场景不在 LevelSwitcher 的清单中！")
		print("当前路径：", current_path)
		if current_uid != "":
			print("当前 UID：", current_uid)
		return
		
	# 3. 计算目标关卡的索引
	var target_index = current_index + step
	
	# 4. 安全检查：防止越界
	if target_index < 0:
		print("【切关】已经是第一关了，前面没有了！")
		return
	elif target_index >= level_list.size():
		print("【切关】已经是最后一关了，后面没有了！")
		return
		
	# 5. 正式加载新关卡！
	print("【切关】正在前往：", level_list[target_index])
	get_tree().change_scene_to_file(level_list[target_index])
