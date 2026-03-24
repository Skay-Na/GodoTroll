extends Area2D

## 救公主动画脚本 (双模版：Web 原生 H5 + 引擎内部播放器)

@export_group("视频设置")
## Web 端使用的视频路径 (相对导出文件夹)
@export var web_video_url: String = "./马里奥救公主.mp4" 
## 引擎内部使用的视频资源 (.ogv 或 .mp4，取决于 Godot 版本支持)
@export var native_video_resource: VideoStream 
@export var pause_game: bool = true
@export var play_once: bool = true

@export_group("跳转设置")
## 动画播放完毕后跳转到的场景路径
@export_file("*.tscn") var next_scene_path: String = ""

var _has_played: bool = false
# 必须将回调函数保存为全局或成员变量，防止被 Godot 的垃圾回收机制清理掉
var _js_callback: JavaScriptObject 

# 引擎内部播放器缓存
var _internal_player: VideoStreamPlayer = null

func _ready() -> void:
	print("【救公主动画】Area2D 已就绪。")
	
	# 主角在物理层的第 2 层
	collision_mask = 2 
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	var is_player = body.is_in_group("Player") or body.is_in_group("player") or body.name.to_lower().contains("player")
	
	if is_player and not _has_played:
		if play_once:
			_has_played = true
		
		print("【救公主动画】检测到主角进入: ", body.name)
		_play_video()

func _play_video() -> void:
	# 检查当前是否在 Web 浏览器环境中运行
	if OS.has_feature("web"):
		_play_h5_video()
	else:
		_play_internal_video()

func _play_internal_video() -> void:
	print("【救公主动画】正在调用引擎内部播放器...")
	
	if not native_video_resource:
		print("【警告】未配置引擎内部视频资源 (native_video_resource)！跳过播放。")
		_on_video_finished([])
		return

	# 1. 创建并配置播放器
	if not _internal_player:
		_internal_player = VideoStreamPlayer.new()
		# 设置全屏覆盖 (基于 CanvasLayer 确保在最上层)
		var cl = CanvasLayer.new()
		cl.layer = 100 # 确保足够高
		add_child(cl)
		cl.add_child(_internal_player)
		
		# 适应屏幕
		_internal_player.expand = true
		_internal_player.anchor_right = 1.0
		_internal_player.anchor_bottom = 1.0
		_internal_player.offset_right = 0
		_internal_player.offset_bottom = 0
		
		# 信号连接
		_internal_player.finished.connect(_on_internal_video_finished)

	_internal_player.stream = native_video_resource
	
	if pause_game:
		get_tree().paused = true
		_internal_player.process_mode = Node.PROCESS_MODE_ALWAYS

	_internal_player.show()
	_internal_player.play()

func _play_h5_video() -> void:
	print("【救公主动画】正在调用浏览器原生 HTML5 播放器...")
	
	if pause_game:
		get_tree().paused = true

	# 1. 创建 Godot 侧的回调函数，等待 JS 通知播放结束
	_js_callback = JavaScriptBridge.create_callback(_on_video_finished)

	# 2. 将 Godot 回调函数绑定到浏览器的 window 对象上
	var window = JavaScriptBridge.get_interface("window")
	window.godot_callback = _js_callback

	# 3. 编写注入浏览器的 JavaScript 代码
	# 创建一个全屏的 <video> 标签，盖在 Godot 画布的上方 (zIndex: 9999)
	var js_code = """
		var video = document.createElement('video');
		video.id = 'godot_h5_video';
		video.src = '{url}';
		video.style.position = 'absolute';
		video.style.top = '0';
		video.style.left = '0';
		video.style.width = '100vw';
		video.style.height = '100vh';
		video.style.backgroundColor = 'black';
		video.style.zIndex = '9999';
		video.style.objectFit = 'contain';
		video.autoplay = true;
		video.controls = false;

		document.body.appendChild(video);

		// 监听播放结束事件
		video.onended = function() {
			godot_callback(); // 呼叫 Godot
			video.remove();   // 把播放器从网页上删掉
		};

		// 尝试播放 (捕获可能的浏览器自动播放限制)
		video.play().catch(function(error) {
			console.log("浏览器的自动播放策略拦截了视频，显示进度条让玩家手动播放: ", error);
			video.controls = true; 
		});
	"""
	
	# 将代码中的 {url} 替换为你的 MP4 路径
	js_code = js_code.replace("{url}", web_video_url)
	
	# 4. 执行这段 JS 代码
	JavaScriptBridge.eval(js_code)

func _on_internal_video_finished() -> void:
	if _internal_player:
		_internal_player.hide()
		_internal_player.stop()
	_on_video_finished([])

# 统一的回调处理
func _on_video_finished(_args: Array) -> void:
	# 🌟【重玩处理】用户要求动画放完可以重玩，这里调用 GameManager 的重置并在返回主菜单
	GameManager.restart_game()
