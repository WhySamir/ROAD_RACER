extends CanvasLayer

@onready var _auto_toggle: CheckButton = $Controls/AutoAccelerate
@onready var _jump_glow: ColorRect = $Controls/Jump/Glow

var auto_accelerate: bool = false
var _auto_action_pressed: bool = false

func _ready() -> void:
	auto_accelerate = OS.has_feature("mobile")
	_auto_toggle.button_pressed = auto_accelerate
	_auto_toggle.toggled.connect(_on_auto_toggled)
	GameState.jump_meter_changed.connect(_on_jump_meter_changed)
	GameState.phase_changed.connect(_on_phase_changed)
	_on_jump_meter_changed(GameState.jump_meter)
	_on_phase_changed(GameState.game_phase)

func _process(_delta: float) -> void:
	if auto_accelerate and GameState.game_phase == "PLAYING":
		Input.action_press("accelerate")
		_auto_action_pressed = true
	elif _auto_action_pressed:
		Input.action_release("accelerate")
		_auto_action_pressed = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		get_tree().paused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		get_tree().paused = false

func _on_auto_toggled(enabled: bool) -> void:
	auto_accelerate = enabled

func _on_jump_meter_changed(value: float) -> void:
	_jump_glow.visible = value >= 100.0

func _on_phase_changed(value: String) -> void:
	_auto_toggle.visible = value == "MENU"
