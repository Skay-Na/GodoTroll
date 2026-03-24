extends CanvasLayer

@onready var coins_label = $MarginContainer/HBoxContainer/CoinsLabel
@onready var world_label = $MarginContainer/HBoxContainer/WorldLabel # 🌟【新增】获取世界关卡名 Label
@onready var lives_label = $MarginContainer/HBoxContainer/LivesLabel
@onready var time_label = $MarginContainer/HBoxContainer/TimeLabel

func _ready():
	# 初始化文本内容
	_on_coins_changed(GameManager.coins)
	_on_lives_changed(GameManager.lives)
	_on_time_changed(GameManager.time_left)
	_on_level_name_changed(GameManager.current_level_name) # 🌟【新增】初始化关卡名显示
	
	# 连接信号
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.time_changed.connect(_on_time_changed)
	GameManager.level_name_changed.connect(_on_level_name_changed) # 🌟【新增】监听关卡名变化信号

func _on_coins_changed(new_coins: int):
	coins_label.text = "COIN %02d" % new_coins

func _on_lives_changed(new_lives: int):
	lives_label.text = "LIVES %d" % new_lives

func _on_time_changed(new_time: int):
	# %03d 会强制显示3位数字，比如 99秒 会显示为 099，很有复古感！
	time_label.text = "TIME %03d" % new_time

# 🌟【新增】处理关卡名字更新的函数
func _on_level_name_changed(new_name: String):
	# 这里如果你想加个前缀也可以，比如：world_label.text = "WORLD " + new_name
	# 如果你在场景根节点里已经写全了，这里直接赋值就行
	world_label.text = new_name
