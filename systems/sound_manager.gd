extends Node

# ==========================================
# SoundManager (Autoload)
# 统一管理全游戏的音效播放
# ==========================================

func _ready():
	# 确保在游戏暂停（如玩家变身动画时）音效依然能即时播放
	process_mode = Node.PROCESS_MODE_ALWAYS

@export_group("Player")
@export var small_jump_sfx: AudioStream
@export var big_jump_sfx: AudioStream
@export var powerup_sfx: AudioStream
@export var damage_sfx: AudioStream
@export var death_sfx: AudioStream
@export var death_sounds: Array[AudioStream] = []
@export var pipe_sfx: AudioStream
@export var one_up_sfx: AudioStream
@export var fireball_sfx: AudioStream

@export_group("Environment")
@export var bump_sfx: AudioStream
@export var break_sfx: AudioStream
@export var coin_sfx: AudioStream
@export var flagpole_sfx: AudioStream

@export_group("Enemies")
@export var stomp_sfx: AudioStream
@export var kick_sfx: AudioStream

# --- 核心播放函数 ---
# 默认使用 AudioStreamPlayer (适合全局背景或UI音效)
# 如果提供 global_pos，则在对应位置创建 AudioStreamPlayer2D
func play(stream: AudioStream, global_pos: Vector2 = Vector2.ZERO, volume_db: float = 0.0):
	if stream == null:
		return
		
	var player
	if global_pos == Vector2.ZERO:
		player = AudioStreamPlayer.new()
	else:
		player = AudioStreamPlayer2D.new()
		player.global_position = global_pos
		
	player.stream = stream
	player.volume_db = volume_db
	# 加入 SoundManager 节点下，随 Manager 一起常驻
	add_child(player)
	player.play()
	
	# 播完自动销毁，释放内存
	player.finished.connect(player.queue_free)

# --- 语义化快捷调用接口 ---

func play_jump(is_big: bool = false): 
	if is_big:
		play(big_jump_sfx)
	else:
		play(small_jump_sfx)

func play_powerup(): 
	play(powerup_sfx)

func play_1up():
	play(one_up_sfx)

func play_damage(): 
	play(damage_sfx)

func play_death(): 
	# 如果有随机死亡音效集，随机播放一个
	if death_sounds.size() > 0:
		var random_index = randi() % death_sounds.size()
		play(death_sounds[random_index])
	else:
		# 否则播放默认死亡音效
		play(death_sfx)

func play_pipe(): 
	play(pipe_sfx)

func play_bump(pos: Vector2 = Vector2.ZERO): 
	play(bump_sfx, pos)

func play_break(pos: Vector2 = Vector2.ZERO): 
	play(break_sfx, pos)

func play_coin(pos: Vector2 = Vector2.ZERO): 
	play(coin_sfx, pos)

func play_flagpole(): 
	play(flagpole_sfx)

func play_stomp(pos: Vector2 = Vector2.ZERO): 
	play(stomp_sfx, pos)

func play_kick(pos: Vector2 = Vector2.ZERO): 
	play(kick_sfx, pos)

func play_fireball():
	play(fireball_sfx)
