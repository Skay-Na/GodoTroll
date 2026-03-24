extends Node2D # 或者你根节点用的类型

# 把它暴露在面板上，以后不用开代码，直接在右侧属性栏就能修改当前关卡叫什么
@export var level_display_name: String = "WORLD 1-4"
func _ready():
	# 当这个关卡加载完成时，主动呼叫 GameManager 重新初始化
	# 这会触发 GameManager 读取新名字、重置倒计时、并通知 HUD 更新
	GameManager.init_current_scene()
