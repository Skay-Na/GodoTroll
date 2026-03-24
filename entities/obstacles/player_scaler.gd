extends Node

# エクスポート変数：インスペクターで調整可能 (导出变量：可在右侧检查器中随意调整)
@export var scale_step_up: float = 2.0 # 1回大きくなる量 (每次变大增加的尺寸)
@export var scale_step_down: float = 0.4 # 1回小さくなる量 (每次变小减小的尺寸)
@export var max_scale: float = 14.5 # 最大スケール (最大体型，超过直接撑爆)
@export var min_scale: float = 0.2 # 最小スケール (最小体型保底)
@export var duration_per_step: float = 3.0 # 1段階の持続時間 (每一级的持续时间/秒)
@export var timer_font: Font = null # 计时器字体 (在检查器中选择)
@export var timer_font_size: int = 24 # 计时器字号 (在检查器中调整)
@export var timer_screen_offset: Vector2 = Vector2(0, -60) # 屏幕偏移 (X=水平偏移，Y=距底部偏移，负数向上)

var current_step_offset: int = 0 # 現在の段階 (当前的缩放级数，0为原大小，正数为变大，负数为变小)
var time_left: float = 0.0 # 残り時間 (倒计时总剩余时间)
var original_scale: Vector2 = Vector2.ZERO # 元のサイズ (玩家最初始的大小)
var timer_label: Label = null # カウントダウンテキスト (显示倒计时的标签)
var canvas_layer: CanvasLayer = null # 用于 UI 隔离的画布层

func _process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not player: return

	# 初回のみ元のサイズを記録 (首次运行记录玩家初始大小)
	if original_scale == Vector2.ZERO:
		original_scale = player.scale

	# ラベルがなければ作成 (如果没有标签，就动态创建)
	if not is_instance_valid(timer_label):
		_create_label()

	# 👇 🌟 新增判定：如果玩家身上贴了 "riding_horse" 的免死金牌，就不算死亡！
	if time_left > 0 and not player.is_physics_processing() and not player.has_meta("riding_horse"):
		time_left = 0.0
		current_step_offset = 0
		_apply_scale(player)

	# タイムダウン処理 (倒计时逻辑)
	if time_left > 0:
		time_left -= delta
		if time_left <= 0:
			time_left = 0
			current_step_offset = 0
			_apply_scale(player)
		else:
			# 現在の時間から、あるべき段階を計算 (根据剩余时间，计算当前应该处于第几级)
			# 例如：剩余 5.9 秒，除以 3 = 1.96，向上取整就是 2 级。
			var expected_steps = ceil(time_left / duration_per_step)
			var changed = false
			
			if current_step_offset > 0 and current_step_offset > expected_steps:
				current_step_offset = expected_steps
				changed = true
			elif current_step_offset < 0 and abs(current_step_offset) > expected_steps:
				current_step_offset = -expected_steps
				changed = true
				
			if changed:
				_apply_scale(player) # 时间跨过 3 秒边界，自动执行降级！

		# 固定在屏幕下方中央
		var viewport_size = get_viewport().get_visible_rect().size
		var label_x = viewport_size.x / 2.0 + timer_screen_offset.x
		var label_y = viewport_size.y + timer_screen_offset.y
		timer_label.position = Vector2(label_x, label_y)
		
		var prefix = ""
		if current_step_offset > 0:
			prefix = "变大时间: "
		elif current_step_offset < 0:
			prefix = "变小时间: "

		timer_label.visible = true
		timer_label.text = prefix + "%.1f s" % time_left
	else:
		if is_instance_valid(timer_label):
			timer_label.visible = false

# プレイヤーを拡大 (放大玩家，按键 8 呼叫)
func increase_scale() -> void:
	_change_scale(1)

# プレイヤーを縮小 (缩小玩家，按键 9 呼叫)
func decrease_scale() -> void:
	_change_scale(-1)

# スケール変更のコアロジック (修改体型的核心逻辑：处理累计和抵消)
func _change_scale(direction: int) -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not player: return

	# 相殺の判定 (判断玩家是不是在变大状态时按了缩小，用于互相抵消)
	var is_cancellation = (current_step_offset > 0 and direction < 0) or (current_step_offset < 0 and direction > 0)

	current_step_offset += direction

	if current_step_offset == 0:
		time_left = 0.0
	else:
		if is_cancellation:
			time_left -= duration_per_step # 相殺 (精准抵消 3 秒)
		else:
			time_left += duration_per_step # 累積 (精准累计 3 秒)

	_apply_scale(player)

# 実際のスケール適用と死亡判定 (实际应用体型缩放与死亡判定)
# 実際のスケール適用 (实际应用体型缩放与极限大小限制)
func _apply_scale(player: Node2D) -> void:
	var target_scale_val = original_scale.x
	
	if current_step_offset > 0:
		target_scale_val += current_step_offset * scale_step_up
	elif current_step_offset < 0:
		target_scale_val -= abs(current_step_offset) * scale_step_down

	# 最小値の制限 (保底大小，防止缩到看不见)
	if target_scale_val < min_scale:
		target_scale_val = min_scale

	# 最大値の制限 (达到极限不再变大，取消死亡惩罚！)
	if target_scale_val > max_scale:
		target_scale_val = max_scale
		print("最大サイズ到達！(已达到最大体型，安全锁定！)")
		
		# 💡 进阶：如果你希望即使玩家按了 100 次，倒计时也不会累积到 300 秒那么夸张，
		# 你可以取消下面这两行代码的注释，强制把时间也锁死在最大级数上：
		# current_step_offset = int((max_scale - original_scale.x) / scale_step_up)
		# time_left = current_step_offset * duration_per_step

	# トゥイーンで滑らかにアニメーション (用 Tween 让每一级变化有 Q 弹的过渡效果)
	var target_scale = Vector2(target_scale_val, target_scale_val)
	var tween = create_tween()
	tween.tween_property(player, "scale", target_scale, 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	
	print("サイズ変更！現在のレベル：(体型变化！当前级数：)", current_step_offset, " 残り時間：", time_left)
	return

# ラベルの生成 (代码动态生成标签)
func _create_label() -> void:
	# 创建 CanvasLayer，UI 完全独立于游戏世界的缩放
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	timer_label = Label.new()
	canvas_layer.add_child(timer_label)
	
	# LabelSettings 确保字体和字号设置生效
	var settings = LabelSettings.new()
	if timer_font:
		settings.font = timer_font
	settings.font_size = timer_font_size
	settings.font_color = Color.WHITE
	settings.outline_color = Color.BLACK
	settings.outline_size = 4
	
	timer_label.label_settings = settings
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
