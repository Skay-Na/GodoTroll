extends Node2D

@onready var flag_sprite = $FlagSprite
@onready var pole_trigger = $PoleTrigger
# 旗子降落的距离（可以根据情况在检查器调整）
@export var flag_drop_distance: float = 129.0 

var triggered = false

func _physics_process(delta):
	if triggered:
		return
		
	# 每帧主动去看看，有没有人进到触发器里面？（不用连信号了）
	for body in pole_trigger.get_overlapping_bodies():
		if body.is_in_group("Player") or body.name == "Player":
			print("【关卡事件】主动检测到玩家碰到了旗杆！")
			triggered = true
			
			# 1. 旗子降落动画
			if flag_sprite:
				var tween = create_tween()
				var target_y = flag_sprite.position.y + flag_drop_distance
				tween.tween_property(flag_sprite, "position:y", target_y, 0.8) 
			
			# 2. 呼叫马里奥，告诉他他碰到的 X 坐标（让马里奥贴在线上滑下来）
			if body.has_method("start_flag_slide"):
				if "current_state" in body and body.current_state == 3: # PlayerState.SUPERMAN
					body.superman_time_left = 0.0
					if body.has_method("change_state"):
						body.change_state(body.pre_superman_state, true)
						
				body.start_flag_slide(global_position.x)
				
			# 3. 关掉自己的触发器
			$PoleTrigger/PoleTriggerShape.set_deferred("disabled", true)
			break
