extends Node

# 通用视频播放管理器
# 使用方法：VideoManager.play_chroma_video(stream, options)

var chroma_shader = preload("uid://cw81q2sxfnoct")

## 播放带有绿幕去除效果的全屏视频
## @param stream: VideoStream - 要播放的视频流
## @param options: Dictionary - 可选参数，包括：
##   chroma_color: Color (默认绿色)
##   pickup_range: float (默认 0.15)
##   fade_range: float (默认 0.1)
##   spill_suppression: float (默认 0.5)
##   pause_game: bool (默认 true)
##   layer: int (默认 128)
func play_chroma_video(stream: VideoStream, options: Dictionary = {}):
	if not stream:
		push_error("VideoManager: 提供的视频流为空！")
		return

	# 1. 提取参数
	var chroma_color = options.get("chroma_color", Color.GREEN)
	var pickup_range = options.get("pickup_range", 0.15)
	var fade_range = options.get("fade_range", 0.1)
	var spill_suppression = options.get("spill_suppression", 0.5)
	var pause_game = options.get("pause_game", true)
	var layer = options.get("layer", 128)

	# 2. 暂停游戏
	if pause_game:
		get_tree().paused = true
	
	# 3. 创建 UI 层和播放器
	var video_canvas = CanvasLayer.new()
	video_canvas.layer = layer
	get_tree().current_scene.add_child(video_canvas)
	
	var video_player = VideoStreamPlayer.new()
	video_player.stream = stream
	video_player.expand = true
	video_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 确保在暂停时依然运行
	video_player.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 4. 应用着色器
	var mat = ShaderMaterial.new()
	mat.shader = chroma_shader
	mat.set_shader_parameter("chroma_key_color", chroma_color)
	mat.set_shader_parameter("pickup_range", pickup_range)
	mat.set_shader_parameter("fade_range", fade_range)
	mat.set_shader_parameter("spill_suppression", spill_suppression)
	video_player.material = mat
	
	video_canvas.add_child(video_player)
	video_player.play()
	
	# 5. 等待播放完成
	await video_player.finished
	
	# 6. 清理并恢复
	video_canvas.queue_free()
	if pause_game:
		get_tree().paused = false
	
	print("VideoManager: 视频播放完成")
