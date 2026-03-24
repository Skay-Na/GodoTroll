extends Control

const FIRST_LEVEL_PATH = "uid://vvfqdyybbry4"
const TOKEN_FILE_PATH = "user://auth_token_v2.save"
const ENCRYPTION_KEY = "Mario_Super_Secret_Key_987654321" # 本地存档的加密锁

# 【新增】这是我们的“赛博调料包（盐）”，打死都不能泄露！
# 你可以随意修改里面这串字符，越乱越好
const PASSWORD_SALT = "My_Awesome_Game_Salt_778899_" 

# Gitee 云端直链
const AUTH_URL = "https://gitee.com/SKayNe/game-auth/raw/master/key.txt"

@onready var password_input = $PasswordInput
@onready var status_label = $StatusLabel

var auth_request: HTTPRequest
var real_password: String = ""
var is_authenticating: bool = false 

func _ready() -> void:
	password_input.hide()
	status_label.text = "" 
	password_input.text_submitted.connect(_on_password_submitted)
	
	auth_request = HTTPRequest.new()
	add_child(auth_request)
	auth_request.timeout = 5.0 
	auth_request.request_completed.connect(_on_server_responded)

func _input(event):
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed:
		if not is_authenticating and not password_input.visible:
			_start_authentication()

# 直接向云端发起请求，不需要再搜索局域网了！
func _start_authentication() -> void:
	is_authenticating = true
	status_label.text = "正在连接云端验证服务器..."
	status_label.show()
	
	# 【终极缓存克星】在网址后面加上当前时间戳，强迫 Gitee 给出最新文件！
	var current_time = str(Time.get_unix_time_from_system())
	var no_cache_url = AUTH_URL + "?t=" + current_time 
	
	var err = auth_request.request(no_cache_url) # 用这个带时间戳的新网址去请求
	if err != OK:
		status_label.text = "网络异常：无法连接云端！"
		is_authenticating = false

func _on_server_responded(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_label.text = "验证失败：云端服务器拒绝访问或未联网！"
		is_authenticating = false
		return 
		
	var raw_text = body.get_string_from_utf8()
	
	# 【注意】现在的 real_password 拿到的是 Gitee 上的那一长串哈希乱码
	real_password = raw_text.strip_edges().trim_prefix("\ufeff")
	
	print("\n====== 服务器返回信息 ======")
	#print("下载到的云端哈希值: [", real_password, "]")
	print("===========================\n")
	
	if _is_token_valid(): # 【测试用】强制进入密码输入界面
		status_label.text = "免密验证通过，游戏即将开始..."
		_enter_game()
	else:
		status_label.text = "验证已过期，请输入云端授权密码并按回车："
		password_input.show()
		password_input.grab_focus()

func _on_password_submitted(input_text: String) -> void:
	input_text = input_text.strip_edges() 
	
	# 【核心加密逻辑】把“盐”和“玩家输入的密码”强行拼接在一起
	var salted_input = PASSWORD_SALT + input_text
	
	# 把拼接后的文本扔进“榨汁机”，算出一串 64 位的哈希乱码
	var input_hash = salted_input.sha256_text()
	
	# ================== 算哈希神器 ==================
	# 【重要提示】如果你不知道往 Gitee 里填什么，就看这行打印！
	#print("\n[神机妙算] 你刚输入的密码算出的终极哈希值是：")
	#print(input_hash)
	#print("------------------------------------------\n")
	# =================================================
	
	# 拿本地算出来的哈希乱码，跟 Gitee 上下载的哈希乱码比对
	if input_hash == real_password:
		status_label.text = "权限获取成功！"
		_save_token() 
		_enter_game()
	else:
		status_label.text = "密码错误，请重新输入！"
		password_input.text = ""
		password_input.grab_focus()

func _enter_game() -> void:
	auth_request.queue_free()
	get_tree().change_scene_to_file(FIRST_LEVEL_PATH)

# ================= 凭证管理机制 (AES-256) =================
func _is_token_valid() -> bool:
	if not FileAccess.file_exists(TOKEN_FILE_PATH):
		return false
	var file = FileAccess.open_encrypted_with_pass(TOKEN_FILE_PATH, FileAccess.READ, ENCRYPTION_KEY)
	if file == null:
		return false
	var auth_data = file.get_var()
	file.close()
	
	if not auth_data is Dictionary:
		return false
	if not auth_data.has("time") or not auth_data.has("password"):
		return false
		
	# 本地存档核对的也是那一串哈希乱码
	if String(auth_data["password"]) != real_password:
		return false
		
	var saved_time = auth_data["time"]
	var current_time = Time.get_unix_time_from_system()
	if current_time - saved_time <= 172800: 
		return true
	return false

func _save_token() -> void:
	var file = FileAccess.open_encrypted_with_pass(TOKEN_FILE_PATH, FileAccess.WRITE, ENCRYPTION_KEY)
	if file == null:
		return
	var current_time = Time.get_unix_time_from_system()
	var auth_data = {
		"time": int(current_time),
		"password": real_password # 存进存档的也是哈希值，不是明文！
	}
	file.store_var(auth_data)
	file.close()
