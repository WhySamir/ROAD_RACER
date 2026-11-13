extends Node

signal fuel_changed(value: float)
signal speed_changed(value: float)
signal score_changed(value: int)
signal game_over
signal jump_meter_changed(value: float)
signal distance_changed(value: float)
signal stage_changed(value: int)
signal phase_changed(value: String)
signal countdown_changed(value: int)
signal best_score_changed(value: int)
signal camera_shake_requested(amount: float)

const SAVE_PATH: String = "user://save.cfg"

var high_score: int = 0

var speed: float = 0.0:
	set(value):
		speed = maxf(value, 0.0)
		speed_changed.emit(speed)
var fuel: float = 100.0:
	set(value):
		fuel = clampf(value, 0.0, 100.0)
		fuel_changed.emit(fuel)

var score: int = 0:
	set(value):
		score = maxi(value, 0)
		score_changed.emit(score)

var distance: float = 0.0
var stage: int = 1
var game_phase: String = "MENU"

var jump_meter: float = 0.0:
	set(value):
		jump_meter = clampf(value, 0.0, 100.0)
		jump_meter_changed.emit(jump_meter)

func _ready() -> void:
	_load_high_score()

func set_game_over() -> void:
	if game_phase == "GAME_OVER":
		return
	if score > high_score:
		high_score = score
		_save_high_score()
		best_score_changed.emit(high_score)
	game_phase = "GAME_OVER"
	phase_changed.emit(game_phase)
	game_over.emit()

func reset_game() -> void:
	speed = 0.0
	fuel = 100.0
	score = 0
	jump_meter = 0.0
	distance = 0.0
	stage = 1
	distance_changed.emit(distance)
	stage_changed.emit(stage)
	best_score_changed.emit(high_score)

func set_phase(value: String) -> void:
	game_phase = value
	phase_changed.emit(game_phase)

func request_camera_shake(amount: float) -> void:
	camera_shake_requested.emit(amount)

func _load_high_score() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		high_score = int(config.get_value("score", "high_score", 0))

func _save_high_score() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("score", "high_score", high_score)
	config.save(SAVE_PATH)
