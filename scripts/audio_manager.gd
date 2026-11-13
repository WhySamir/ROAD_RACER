extends Node

const SFX: Dictionary = {
	&"accelerate": preload("res://audio/sfx_accelerate.wav"),
	&"brake": preload("res://audio/sfx_brake_screech.wav"),
	&"oil": preload("res://audio/sfx_oil_slip.wav"),
	&"crash": preload("res://audio/sfx_crash.wav"),
	&"sideswipe": preload("res://audio/sfx_sideswipe.wav"),
	&"jump": preload("res://audio/sfx_jump_fly.wav"),
	&"land": preload("res://audio/sfx_land.wav"),
	&"pickup": preload("res://audio/sfx_pickup.wav"),
	&"click": preload("res://audio/sfx_ui_click.wav"),
}

const ENGINE_LOOP_PATH: String = "res://audio/sfx_engine_loop.wav"

const ONE_SHOT_POOL_SIZE: int = 8
const SOUND_COOLDOWN_SECONDS: float = 0.1
const BRAKE_RETRIGGER_SECONDS: float = 0.45
const BRAKE_MIN_SPEED: float = 150.0
const BRAKE_FADE_SECONDS: float = 0.1
const ENGINE_FADE_SECONDS: float = 0.25
const ENGINE_MIN_PITCH: float = 0.8
const ENGINE_MAX_PITCH: float = 2.4
const ENGINE_PITCH_STEP: float = 0.08
const SPINNING_STATE: int = 1
const JUMPING_STATE: int = 2

var _one_shots: Array[AudioStreamPlayer] = []
var _one_shot_started: Array[float] = []
var _last_sound_times: Dictionary = {}
var _engine: AudioStreamPlayer
var _engine_pitch: float = ENGINE_MIN_PITCH
var _engine_fade: Tween
var _brake_players: Array[AudioStreamPlayer] = []
var _brake_index: int = 0
var _brake_timer: float = 0.0
var _braking_active: bool = false
var _braking_speed: float = 0.0
var _paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_audio_nodes()
	_configure_engine_stream()
	GameState.game_over.connect(stop_all)
	set_muted(GameState.muted, false)

func _process(delta: float) -> void:
	if _paused:
		return
	if _braking_active and _braking_speed > BRAKE_MIN_SPEED:
		_brake_timer -= delta
		if _brake_timer <= 0.0:
			_play_brake_screech()
			_brake_timer = BRAKE_RETRIGGER_SECONDS

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_paused(true)

func _build_audio_nodes() -> void:
	for index: int in ONE_SHOT_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_one_shots.append(player)
		_one_shot_started.append(-INF)
	_engine = AudioStreamPlayer.new()
	_engine.bus = &"ENGINE"
	add_child(_engine)
	for index: int in 2:
		var screech: AudioStreamPlayer = AudioStreamPlayer.new()
		screech.bus = &"SFX"
		add_child(screech)
		_brake_players.append(screech)

func _configure_engine_stream() -> void:
	var engine_source: AudioStream = load(ENGINE_LOOP_PATH) as AudioStream
	if engine_source == null:
		push_warning("AudioManager: engine loop '%s' could not be loaded" % ENGINE_LOOP_PATH)
		return
	var engine_stream: AudioStreamWAV = engine_source.duplicate() as AudioStreamWAV
	if engine_stream != null:
		engine_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		engine_stream.loop_begin = 0
		engine_stream.loop_end = engine_stream.data.size() / 2
		_engine.stream = engine_stream
	_engine.pitch_scale = ENGINE_MIN_PITCH
	_engine.volume_db = -8.0

func play(name: StringName, volume_db: float = 0.0, pitch_variation: float = 0.0) -> void:
	if not SFX.has(name) or _paused:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last_sound_times.get(name, -INF)) < SOUND_COOLDOWN_SECONDS:
		return
	_last_sound_times[name] = now
	var player_index: int = _find_one_shot_player()
	var player: AudioStreamPlayer = _one_shots[player_index]
	player.stream = SFX[name] as AudioStream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation) if pitch_variation > 0.0 else 1.0
	player.play()
	_one_shot_started[player_index] = now

func _find_one_shot_player() -> int:
	var oldest_index: int = 0
	var oldest_time: float = INF
	for index: int in _one_shots.size():
		if not _one_shots[index].playing:
			return index
		if _one_shot_started[index] < oldest_time:
			oldest_time = _one_shot_started[index]
			oldest_index = index
	return oldest_index

func update_engine(current_speed: float, max_speed: float, throttle: bool, braking: bool, state: int) -> void:
	if _engine == null or _paused:
		return
	var speed_ratio: float = clampf(current_speed / max_speed, 0.0, 1.0)
	var target_pitch: float = lerpf(ENGINE_MIN_PITCH, ENGINE_MAX_PITCH, speed_ratio)
	if state == JUMPING_STATE:
		target_pitch += 0.15
	_engine_pitch = move_toward(_engine_pitch, target_pitch, ENGINE_PITCH_STEP)
	_engine.pitch_scale = _engine_pitch
	if state == SPINNING_STATE:
		_engine.volume_db = -12.0
	elif state == JUMPING_STATE:
		_engine.volume_db = -6.0
	elif braking:
		_engine.volume_db = -10.0
	elif throttle:
		_engine.volume_db = -3.0
	else:
		_engine.volume_db = -8.0

func start_engine() -> void:
	if _engine == null or _paused:
		return
	if is_instance_valid(_engine_fade):
		_engine_fade.kill()
	_engine.volume_db = -8.0
	if not _engine.playing:
		_engine.play()

func stop_engine() -> void:
	if _engine == null or not _engine.playing:
		return
	if is_instance_valid(_engine_fade):
		_engine_fade.kill()
	_engine_fade = create_tween()
	_engine_fade.tween_property(_engine, "volume_db", -60.0, ENGINE_FADE_SECONDS)
	_engine_fade.finished.connect(func() -> void:
		_engine.stop()
		_engine.volume_db = -8.0
	)

func set_braking(active: bool, current_speed: float) -> void:
	var should_brake: bool = active and current_speed > BRAKE_MIN_SPEED
	_braking_speed = current_speed
	if should_brake and not _braking_active:
		_brake_timer = 0.0
	elif not should_brake and _braking_active:
		_fade_brakes()
	_braking_active = should_brake

func _play_brake_screech() -> void:
	var player: AudioStreamPlayer = _brake_players[_brake_index]
	_brake_index = (_brake_index + 1) % _brake_players.size()
	player.stream = SFX[&"brake"] as AudioStream
	player.volume_db = lerpf(-14.0, -4.0, clampf((_braking_speed - BRAKE_MIN_SPEED) / 270.0, 0.0, 1.0))
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()

func _fade_brakes() -> void:
	for player: AudioStreamPlayer in _brake_players:
		if player.playing:
			var fade: Tween = create_tween()
			fade.tween_property(player, "volume_db", -60.0, BRAKE_FADE_SECONDS)
			fade.finished.connect(player.stop)

func stop_all() -> void:
	stop_engine()
	_fade_brakes()
	_braking_active = false
	for player: AudioStreamPlayer in _one_shots:
		player.stop()

func set_paused(paused: bool) -> void:
	_paused = paused
	if _engine != null:
		_engine.stream_paused = paused
	for player: AudioStreamPlayer in _one_shots:
		player.stream_paused = paused
	for player: AudioStreamPlayer in _brake_players:
		player.stream_paused = paused

func set_muted(muted: bool, persist: bool = true) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), muted)
	if persist:
		GameState.set_muted(muted)
