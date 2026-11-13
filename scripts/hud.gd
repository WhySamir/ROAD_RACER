extends CanvasLayer

@onready var _score_label: Label = $Panel/Score
@onready var _best_label: Label = $Panel/Best
@onready var _distance_label: Label = $Panel/Distance
@onready var _speed_label: Label = $Panel/Speed
@onready var _fuel_bar: ColorRect = $Panel/FuelBar/Fill
@onready var _fuel_value: Label = $Panel/FuelBar/Value
@onready var _message: Label = $Message
@onready var _countdown: Label = $Countdown

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.best_score_changed.connect(_on_best_changed)
	GameState.distance_changed.connect(_on_distance_changed)
	GameState.speed_changed.connect(_on_speed_changed)
	GameState.fuel_changed.connect(_on_fuel_changed)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.countdown_changed.connect(_on_countdown_changed)
	_on_score_changed(GameState.score)
	_on_best_changed(GameState.high_score)
	_on_distance_changed(GameState.distance)
	_on_speed_changed(GameState.speed)
	_on_fuel_changed(GameState.fuel)
	_on_phase_changed(GameState.game_phase)

func _on_score_changed(value: int) -> void:
	_score_label.text = "SCORE %06d" % value

func _on_best_changed(value: int) -> void:
	_best_label.text = "BEST %06d" % value

func _on_distance_changed(value: float) -> void:
	_distance_label.text = "DIST %04dm" % int(value)

func _on_speed_changed(value: float) -> void:
	_speed_label.text = "SPD %03dkm/h" % int(value / 2.2)

func _on_fuel_changed(value: float) -> void:
	var ratio: float = clampf(value / 100.0, 0.0, 1.0)
	_fuel_bar.size.x = 80.0 * ratio
	_fuel_bar.color = Color("55cc66") if value > 50.0 else (Color("e6c84f") if value > 20.0 else Color("e64f4f"))
	_fuel_value.text = "FUEL %03d" % int(value)

func _on_phase_changed(value: String) -> void:
	_message.visible = value == "MENU" or value == "GAME_OVER"
	_message.text = "ROAD RACER\nPRESS W / UP TO START" if value == "MENU" else "GAME OVER\nPRESS W / UP TO RETRY"
	_countdown.visible = value == "COUNTDOWN"

func _on_countdown_changed(value: int) -> void:
	_countdown.text = str(value) if value > 0 else "GO!"
