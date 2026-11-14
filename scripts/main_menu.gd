extends Node2D

const MENU_ROAD_SPEED: float = 200.0
const DECORATIVE_CAR_SPEEDS: Array[float] = [70.0, 105.0, 145.0, 190.0]
const PRESS_SCALE: float = 0.96
const PRESS_DURATION: float = 0.06
const FOCUS_COLOR: Color = Color("ffd23f")
const PANEL_MARGIN: float = 12.0
const MAIN_PANEL_WIDTH: float = 180.0
const MAIN_PANEL_HEIGHT: float = 352.0
const LEVEL_PANEL_HEIGHT: float = 328.0
const SCORES_PANEL_WIDTH: float = 208.0
const SCORES_PANEL_HEIGHT: float = 360.0
const RESET_PANEL_HEIGHT: float = 110.0
const MUTE_WIDTH: float = 54.0
const MUTE_HEIGHT: float = 28.0

@onready var _ui: Control = $UI/Root
@onready var _main_screen: Control = $UI/Root/MainScreen
@onready var _level_screen: Control = $UI/Root/LevelScreen
@onready var _scores_screen: Control = $UI/Root/ScoresScreen
@onready var _mute_button: Button = $UI/Root/MuteButton
@onready var _controls_button: Button = $UI/Root/MainScreen/Panel/Content/Controls
@onready var _hand_button: Button = $UI/Root/MainScreen/Panel/Content/Hand
@onready var _auto_gas_button: Button = $UI/Root/MainScreen/Panel/Content/AutoGas
@onready var _level_label: Label = $UI/Root/MainScreen/Panel/Content/Level
@onready var _level_buttons: Array[Button] = [
	$UI/Root/LevelScreen/Panel/Content/Easy,
	$UI/Root/LevelScreen/Panel/Content/Medium,
	$UI/Root/LevelScreen/Panel/Content/Hard,
]
@onready var _score_labels: Array[Label] = [
	$UI/Root/ScoresScreen/Panel/Content/Easy/Fuel,
	$UI/Root/ScoresScreen/Panel/Content/Easy/Continuous,
	$UI/Root/ScoresScreen/Panel/Content/Medium/Fuel,
	$UI/Root/ScoresScreen/Panel/Content/Medium/Continuous,
	$UI/Root/ScoresScreen/Panel/Content/Hard/Fuel,
	$UI/Root/ScoresScreen/Panel/Content/Hard/Continuous,
]
@onready var _decorative_cars: Array[Sprite2D] = [
	$Background/DecorativeCars/CarBlue,
	$Background/DecorativeCars/CarYellow,
	$Background/DecorativeCars/CarGreen,
	$Background/DecorativeCars/CarPurple,
]

var _screen: String = "MAIN"

func _ready() -> void:
	get_tree().paused = false
	AudioManager.stop_all()
	GameState.speed = MENU_ROAD_SPEED
	_connect_buttons()
	_mute_button.pressed.connect(_toggle_mute)
	_controls_button.pressed.connect(_toggle_control_scheme)
	_hand_button.pressed.connect(_toggle_hand)
	_auto_gas_button.pressed.connect(_toggle_auto_gas)
	GameState.selection_changed.connect(_refresh_selection)
	_refresh_selection()
	_refresh_mute()
	_refresh_controls()
	_refresh_auto_gas()
	_show_screen("MAIN", false)
	ScreenMetrics.changed.connect(_layout_background)
	_layout_background()
	for index: int in _decorative_cars.size():
		_decorative_cars[index].position.x = ScreenMetrics.lane_center(index)
		_decorative_cars[index].position.y = -80.0 - float(index * 125)

func _process(delta: float) -> void:
	GameState.speed = MENU_ROAD_SPEED
	for index: int in _decorative_cars.size():
		var car: Sprite2D = _decorative_cars[index]
		var direction: float = 1.0 if index % 2 == 0 else -1.0
		car.position.y += DECORATIVE_CAR_SPEEDS[index] * direction * delta
		if direction > 0.0 and car.position.y > ScreenMetrics.view_size.y + 40.0:
			car.position.y = -80.0
		elif direction < 0.0 and car.position.y < -80.0:
			car.position.y = ScreenMetrics.view_size.y + 40.0

func _layout_background() -> void:
	for index: int in _decorative_cars.size():
		_decorative_cars[index].position.x = ScreenMetrics.lane_center(index)
	_layout_screens()

## Keeps the menu panels centered on any canvas size instead of assuming 224x400.
func _layout_screens() -> void:
	var view: Vector2 = ScreenMetrics.view_size
	_mute_button.position = Vector2(view.x - ScreenMetrics.safe_right - MUTE_WIDTH, 6.0 + ScreenMetrics.safe_top)
	_mute_button.size = Vector2(MUTE_WIDTH, MUTE_HEIGHT)
	_center_panel(_main_screen.get_node("Panel"), Vector2(MAIN_PANEL_WIDTH, MAIN_PANEL_HEIGHT))
	_center_panel(_level_screen.get_node("Panel"), Vector2(MAIN_PANEL_WIDTH, LEVEL_PANEL_HEIGHT))
	_center_panel(_scores_screen.get_node("Panel"), Vector2(SCORES_PANEL_WIDTH, SCORES_PANEL_HEIGHT))
	_center_panel(_scores_screen.get_node("ResetDialog"), Vector2(MAIN_PANEL_WIDTH, RESET_PANEL_HEIGHT))

func _center_panel(panel: Control, design_size: Vector2) -> void:
	var view: Vector2 = ScreenMetrics.view_size
	var available: Vector2 = Vector2(view.x - PANEL_MARGIN * 2.0, view.y - ScreenMetrics.safe_top - ScreenMetrics.safe_bottom - PANEL_MARGIN * 2.0)
	var panel_size: Vector2 = Vector2(minf(design_size.x, available.x), minf(design_size.y, available.y))
	panel.position = Vector2((view.x - panel_size.x) * 0.5, ScreenMetrics.safe_top + PANEL_MARGIN + (available.y - panel_size.y) * 0.5)
	panel.size = panel_size
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _screen != "MAIN":
			_show_screen("MAIN", true)

func _connect_buttons() -> void:
	$UI/Root/MainScreen/Panel/Content/Start.pressed.connect(_start_fuel_game)
	$UI/Root/MainScreen/Panel/Content/Continuous.pressed.connect(_start_continuous_game)
	$UI/Root/MainScreen/Panel/Content/ChooseLevel.pressed.connect(func() -> void: _show_screen("LEVEL", true))
	$UI/Root/MainScreen/Panel/Content/HighScores.pressed.connect(func() -> void: _show_screen("SCORES", true))
	$UI/Root/LevelScreen/Panel/Content/Easy.pressed.connect(func() -> void: _select_level(DifficultyConfig.Level.EASY))
	$UI/Root/LevelScreen/Panel/Content/Medium.pressed.connect(func() -> void: _select_level(DifficultyConfig.Level.MEDIUM))
	$UI/Root/LevelScreen/Panel/Content/Hard.pressed.connect(func() -> void: _select_level(DifficultyConfig.Level.HARD))
	$UI/Root/LevelScreen/Panel/Content/Back.pressed.connect(func() -> void: _show_screen("MAIN", true))
	$UI/Root/ScoresScreen/Panel/Content/Back.pressed.connect(func() -> void: _show_screen("MAIN", true))
	$UI/Root/ScoresScreen/Panel/Content/Reset.pressed.connect(_open_reset_dialog)
	$UI/Root/ScoresScreen/ResetDialog/Yes.pressed.connect(_confirm_reset)
	$UI/Root/ScoresScreen/ResetDialog/No.pressed.connect(_close_reset_dialog)
	for button: Button in _all_buttons():
		button.pressed.connect(_button_feedback.bind(button))

func _all_buttons() -> Array[Button]:
	return [
		$UI/Root/MainScreen/Panel/Content/Start,
		$UI/Root/MainScreen/Panel/Content/Continuous,
		$UI/Root/MainScreen/Panel/Content/ChooseLevel,
		$UI/Root/MainScreen/Panel/Content/HighScores,
		$UI/Root/LevelScreen/Panel/Content/Easy,
		$UI/Root/LevelScreen/Panel/Content/Medium,
		$UI/Root/LevelScreen/Panel/Content/Hard,
		$UI/Root/LevelScreen/Panel/Content/Back,
		$UI/Root/ScoresScreen/Panel/Content/Back,
		$UI/Root/ScoresScreen/Panel/Content/Reset,
		$UI/Root/ScoresScreen/ResetDialog/Yes,
		$UI/Root/ScoresScreen/ResetDialog/No,
		_controls_button,
		_hand_button,
	]

func _start_fuel_game() -> void:
	GameState.set_mode(DifficultyConfig.Mode.FUEL)
	_change_to_game()

func _start_continuous_game() -> void:
	GameState.set_mode(DifficultyConfig.Mode.CONTINUOUS)
	_change_to_game()

func _change_to_game() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _select_level(selected_level: DifficultyConfig.Level) -> void:
	GameState.set_level(selected_level)
	_show_screen("MAIN", true)

func _show_screen(screen_name: String, animate: bool) -> void:
	_screen = screen_name
	_main_screen.visible = screen_name == "MAIN"
	_level_screen.visible = screen_name == "LEVEL"
	_scores_screen.visible = screen_name == "SCORES"
	_refresh_selection()
	if screen_name == "SCORES":
		_refresh_scores()
	var target: Control = _main_screen if screen_name == "MAIN" else (_level_screen if screen_name == "LEVEL" else _scores_screen)
	target.modulate.a = 0.0 if animate else 1.0
	target.position.x = 8.0 if animate else 0.0
	if animate:
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(target, "modulate:a", 1.0, 0.15)
		tween.tween_property(target, "position:x", 0.0, 0.15)
	_grab_screen_focus(screen_name)

func _grab_screen_focus(screen_name: String) -> void:
	var target: Button = $UI/Root/MainScreen/Panel/Content/Start
	if screen_name == "LEVEL":
		target = $UI/Root/LevelScreen/Panel/Content/Medium
	elif screen_name == "SCORES":
		target = $UI/Root/ScoresScreen/Panel/Content/Back
	target.grab_focus.call_deferred()

func _refresh_selection() -> void:
	_level_label.text = "LEVEL: %s" % DifficultyConfig.level_name(GameState.level)
	for index: int in _level_buttons.size():
		var selected: bool = index == int(GameState.level)
		_level_buttons[index].modulate = FOCUS_COLOR if selected else Color.WHITE

func _refresh_scores() -> void:
	var combinations: Array[Dictionary] = [
		{"level": DifficultyConfig.Level.EASY, "mode": DifficultyConfig.Mode.FUEL},
		{"level": DifficultyConfig.Level.EASY, "mode": DifficultyConfig.Mode.CONTINUOUS},
		{"level": DifficultyConfig.Level.MEDIUM, "mode": DifficultyConfig.Mode.FUEL},
		{"level": DifficultyConfig.Level.MEDIUM, "mode": DifficultyConfig.Mode.CONTINUOUS},
		{"level": DifficultyConfig.Level.HARD, "mode": DifficultyConfig.Mode.FUEL},
		{"level": DifficultyConfig.Level.HARD, "mode": DifficultyConfig.Mode.CONTINUOUS},
	]
	for index: int in combinations.size():
		var combination: Dictionary = combinations[index]
		var entry: Dictionary = GameState.get_best(combination["level"], combination["mode"])
		_score_labels[index].text = "%d %dm" % [int(entry["score"]), int(entry["distance_m"])]
	var rows: Array[Control] = [
		$UI/Root/ScoresScreen/Panel/Content/Easy,
		$UI/Root/ScoresScreen/Panel/Content/Medium,
		$UI/Root/ScoresScreen/Panel/Content/Hard,
	]
	for index: int in rows.size():
		rows[index].modulate = FOCUS_COLOR if index == int(GameState.level) else Color.WHITE

func _open_reset_dialog() -> void:
	$UI/Root/ScoresScreen/ResetDialog.visible = true
	$UI/Root/ScoresScreen/ResetDialog/No.grab_focus()

func _close_reset_dialog() -> void:
	$UI/Root/ScoresScreen/ResetDialog.visible = false
	$UI/Root/ScoresScreen/Panel/Content/Reset.grab_focus()

func _confirm_reset() -> void:
	GameState.reset_scores()
	_refresh_scores()
	_close_reset_dialog()

func _button_feedback(button: Button) -> void:
	AudioManager.play(&"click")
	button.pivot_offset = button.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(button, "scale", Vector2(PRESS_SCALE, PRESS_SCALE), PRESS_DURATION)
	tween.tween_property(button, "scale", Vector2.ONE, PRESS_DURATION)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(15)

func _toggle_mute() -> void:
	AudioManager.play(&"click")
	AudioManager.set_muted(not GameState.muted)
	_refresh_mute()

func _refresh_mute() -> void:
	_mute_button.text = "SFX OFF" if GameState.muted else "SFX ON"

func _toggle_control_scheme() -> void:
	GameState.set_control_scheme(GameState.ControlScheme.BUTTONS if GameState.control_scheme == GameState.ControlScheme.SWIPE else GameState.ControlScheme.SWIPE)
	_refresh_controls()

func _toggle_hand() -> void:
	GameState.set_hand_side(GameState.HandSide.LEFT if GameState.hand_side == GameState.HandSide.RIGHT else GameState.HandSide.RIGHT)
	_refresh_controls()

func _refresh_controls() -> void:
	_controls_button.text = "CONTROLS: SWIPE" if GameState.control_scheme == GameState.ControlScheme.SWIPE else "CONTROLS: BUTTONS"
	_hand_button.text = "HAND: RIGHT" if GameState.hand_side == GameState.HandSide.RIGHT else "HAND: LEFT"

func _toggle_auto_gas() -> void:
	GameState.set_auto_accelerate(not GameState.auto_accelerate)
	_refresh_auto_gas()

func _refresh_auto_gas() -> void:
	_auto_gas_button.text = "AUTO GAS: ON" if GameState.auto_accelerate else "AUTO GAS: OFF"
