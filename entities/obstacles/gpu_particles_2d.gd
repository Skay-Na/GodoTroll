# 挂在 particle_scene 上的小脚本
extends GPUParticles2D

func _ready():
	# 🌟 核心设置
	one_shot = true    # 只播一次
	emitting = true  # 刚进入场景就立刻播
	
	# 🌟 保底销毁设置：播完必须自我毁灭，否则大招放几次内存就会爆！
	# 假设你的生命周期 (Lifetime) 是1秒，这里设为 1.5 秒
	get_tree().create_timer(1.5).timeout.connect(queue_free)
