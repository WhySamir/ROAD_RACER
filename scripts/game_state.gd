extends Node

signal fuel_changed(value: float)
signal speed_changed(value: float)
signal score_changed(value: int)
signal game_over
signal jump_meter_changed(value: float)

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

func _ready() -> void:
	_load_high_score()

func set_game_over() -> void:
	if score > high_score:
		high_score = score
		_save_high_score()
	game_over.emit()

func _load_high_score() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		high_score = int(config.get_value("score", "high_score", 0))

func _save_high_score() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("score", "high_score", high_score)
	config.save(SAVE_PATH)
