extends CanvasLayer

@onready var _score_label: Label = $Panel/Score
@onready var _best_label: Label = $Panel/Best
@onready var _distance_label: Label = $Panel/Distance
@onready var _speed_label: Label = $Panel/Speed
@onready var _fuel_bar: ColorRect = $Panel/FuelBar/Fill
@onready var _fuel_value: Label = $Panel/FuelBar/Value
@onready var _fuel_group: Control = $Panel/FuelBar
@onready var _lives_margin: MarginContainer = $LivesMargin
@onready var _life_icons: Array[TextureRect] = [$LivesMargin/LivesBar/Life1, $LivesMargin/LivesBar/Life2, $LivesMargin/LivesBar/Life3, $LivesMargin/LivesBar/Life4, $LivesMargin/LivesBar/Life5]
@onready var _mode_level_label: Label = $Panel/ModeLevel
@onready var _jump_bar: ColorRect = $Panel/JumpBar/Fill
@onready var _jump_container: Control = $Panel/JumpBar
@onready var _jump_glow: ColorRect = $Panel/JumpBar/Glow
@onready var _jump_label: Label = $Panel/JumpBar/Value
@onready var _message: Label = $Message
@onready var _countdown: Label = $Countdown
@onready var _game_over_actions: Control = $GameOverActions
@onready var _pause_button: Button = $PauseButton
@onready var _pause_overlay: Control = $PauseOverlay
@onready var _pause_audio_button: Button = $PauseOverlay/Audio
@onready var _pause_controls_button: Button = $PauseOverlay/Controls
@onready var _pause_hand_button: Button = $PauseOverlay/Hand
@onready var _pause_auto_gas_button: Button = $PauseOverlay/AutoGas
@onready var _game_over_info: Control = $GameOverInfo
@onready var _game_over_mode: Label = $GameOverInfo/ModeLevel
@onready var _game_over_score: Label = $GameOverInfo/Score
@onready var _game_over_distance: Label = $GameOverInfo/Distance
@onready var _game_over_best: Label = $GameOverInfo/Best
@onready var _new_best: Label = $GameOverInfo/NewBest
@onready var _life_popup: Label = $LifePopup
@onready var _pause_title: Label = $PauseOverlay/Title
@onready var _pause_buttons: Array[Button] = [
	$PauseOverlay/Resume,
	$PauseOverlay/Menu,
	$PauseOverlay/Audio,
	$PauseOverlay/Controls,
	$PauseOverlay/Hand,
	$PauseOverlay/AutoGas,
	$PauseOverlay/Retry,
]

const LABEL_WIDTH: float = 64.0
const INFO_WIDTH: float = 176.0
const INFO_ROW_HEIGHT: float = 18.0
const INFO_ROW_GAP: float = 4.0
const INFO_TOP_RATIO: float = 0.30
const ACTION_WIDTH: float = 150.0
const ACTION_HEIGHT: float = 34.0
const ACTION_GAP: float = 6.0
const PAUSE_WIDTH: float = 176.0
const PAUSE_MAX_HEIGHT: float = 320.0
const PAUSE_SIDE_MARGIN: float = 12.0
const PAUSE_TITLE_HEIGHT: float = 32.0
const PAUSE_ROW_MIN_HEIGHT: float = 20.0
const PAUSE_ROW_MAX_HEIGHT: float = 32.0
const PAUSE_ROW_GAP: float = 4.0
const LIFE_SHAKE_OFFSET: float = 3.0
const LIFE_SHAKE_STEPS: int = 4
const LIFE_POP_SCALE: float = 1.3
const LIFE_ANIMATION_DURATION: float = 0.25
const HEART_FULL_TEXTURE: Texture2D = preload("res://assets/heart_full.png")
const HEART_EMPTY_TEXTURE: Texture2D = preload("res://assets/heart_empty.png")

var _last_lives: int = -1
var _heart_tweens: Dictionary = {}
var _pulse_tween: Tween

func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.best_score_changed.connect(_on_best_changed)
	GameState.distance_changed.connect(_on_distance_changed)
	GameState.speed_changed.connect(_on_speed_changed)
	GameState.fuel_changed.connect(_on_fuel_changed)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.countdown_changed.connect(_on_countdown_changed)
	GameState.jump_meter_changed.connect(_on_jump_meter_changed)
	GameState.jump_charges_changed.connect(_on_jump_charges_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.extra_life_gained.connect(_on_extra_life_gained)
	GameState.selection_changed.connect(_on_selection_changed)
	$GameOverActions/Retry.pressed.connect(_on_retry_pressed)
	$GameOverActions/Menu.pressed.connect(_on_menu_pressed)
	$PauseButton.pressed.connect(_on_pause_pressed)
	$PauseOverlay/Resume.pressed.connect(_on_resume_pressed)
	$PauseOverlay/Menu.pressed.connect(_on_menu_pressed)
	$PauseOverlay/Audio.pressed.connect(_on_pause_audio_pressed)
	$PauseOverlay/Controls.pressed.connect(_toggle_control_scheme)
	$PauseOverlay/Hand.pressed.connect(_toggle_hand)
	$PauseOverlay/AutoGas.pressed.connect(_toggle_auto_gas)
	$PauseOverlay/Retry.pressed.connect(_on_pause_retry_pressed)
	_on_score_changed(GameState.score)
	_on_best_changed(GameState.high_score)
	_on_distance_changed(GameState.distance)
	_on_speed_changed(GameState.speed)
	_on_fuel_changed(GameState.fuel)
	_on_phase_changed(GameState.game_phase)
	ScreenMetrics.changed.connect(_layout_hud)
	_layout_hud()
	_refresh_audio_button()
	_refresh_touch_settings()
	_refresh_auto_gas()
	_on_jump_meter_changed(GameState.jump_meter)
	_on_jump_charges_changed(GameState.jump_charges)
	_apply_safe_area()
	_on_lives_changed(GameState.lives, GameState.MAX_LIVES)
	_on_selection_changed()
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
	_fuel_bar.size.x = 48.0 * ratio
	_fuel_bar.color = Color("55cc66") if value > 50.0 else (Color("e6c84f") if value > 20.0 else Color("e64f4f"))
	_fuel_value.text = "FUEL %03d" % int(value)

func _on_phase_changed(value: String) -> void:
	_message.visible = value == "MENU"
	_message.text = "ROAD RACER\nPRESS W / UP TO START" if value == "MENU" else "GAME OVER\nPRESS W / UP TO RETRY"
	_countdown.visible = value == "COUNTDOWN"
	_game_over_actions.visible = value == "GAME_OVER"
	_pause_button.visible = value == "PLAYING" and not get_tree().paused
	_game_over_info.visible = value == "GAME_OVER"
	if value == "GAME_OVER":
		_game_over_mode.text = "%s · %s" % [DifficultyConfig.mode_name(GameState.mode), DifficultyConfig.level_name(GameState.level)]
		_game_over_score.text = "SCORE %d" % GameState.score
		_game_over_distance.text = "DISTANCE %dm" % int(GameState.distance)
		_game_over_best.text = "BEST %d" % GameState.high_score
		_new_best.visible = GameState.game_over_new_best
		if GameState.game_over_new_best:
			var blink: Tween = create_tween().set_loops()
			blink.tween_property(_new_best, "modulate:a", 0.25, 0.35)
			blink.tween_property(_new_best, "modulate:a", 1.0, 0.35)

func _on_countdown_changed(value: int) -> void:
	_countdown.text = str(value) if value > 0 else "GO!"

func _on_jump_meter_changed(value: float) -> void:
	var ratio: float = clampf(value / 100.0, 0.0, 1.0)
	_jump_bar.size.x = 48.0 * ratio
	_jump_glow.visible = GameState.jump_charges > 0
	_jump_label.text = "JUMP %d/%d" % [GameState.jump_charges, GameState.MAX_JUMP_CHARGES]

func _on_jump_charges_changed(value: int) -> void:
	_jump_glow.visible = value > 0
	_jump_label.text = "JUMP %d/%d" % [value, GameState.MAX_JUMP_CHARGES]

func _on_lives_changed(value: int, max_lives: int) -> void:
	var lives_mode: bool = GameState.is_fuel_mode()
	_fuel_group.visible = lives_mode
	_lives_margin.visible = lives_mode
	var visible_slots: int = mini(_life_icons.size(), maxi(GameState.START_LIVES, mini(max_lives, value)))
	if _last_lives < 0:
		_set_hearts_immediately(value, visible_slots)
	elif lives_mode and value < _last_lives:
		_animate_life_loss(value, visible_slots)
	elif lives_mode and value > _last_lives and not (value == GameState.START_LIVES and _last_lives <= 0):
		_animate_life_gain(value, visible_slots)
	else:
		_set_hearts_immediately(value, visible_slots)
	_last_lives = value
	_update_low_life_pulse(value)

func _on_selection_changed() -> void:
	_mode_level_label.text = "%s · %s" % [DifficultyConfig.mode_name(GameState.mode), DifficultyConfig.level_name(GameState.level)]

func _on_extra_life_gained(_value: int) -> void:
	_life_popup.visible = true
	_life_popup.modulate.a = 1.0
	var popup_tween: Tween = create_tween()
	popup_tween.tween_property(_life_popup, "position:y", _life_popup.position.y - 8.0, 0.7)
	popup_tween.parallel().tween_property(_life_popup, "modulate:a", 0.0, 0.7)
	popup_tween.finished.connect(func() -> void:
		_life_popup.visible = false
		_life_popup.position.y += 8.0
	)

func _apply_safe_area() -> void:
	_lives_margin.add_theme_constant_override("margin_top", int(6.0 + ScreenMetrics.safe_top))

func _layout_hud() -> void:
	_apply_safe_area()
	var view: Vector2 = ScreenMetrics.view_size
	var width: float = view.x
	var safe_top: float = ScreenMetrics.safe_top
	var safe_right: float = ScreenMetrics.safe_right
	var safe_left: float = ScreenMetrics.safe_left
	var center_x: float = width * 0.5
	var center_left: float = center_x - LABEL_WIDTH * 0.5
	var right_x: float = width - safe_right - LABEL_WIDTH
	# Keep center labels from colliding with right labels on narrow phones.
	if center_left + LABEL_WIDTH > right_x - 8.0:
		center_left = right_x - LABEL_WIDTH - 8.0
	center_left = maxf(center_left, safe_left + 6.0)
	_score_label.position = Vector2(center_left, 6.0 + safe_top)
	_best_label.position = Vector2(center_left, 20.0 + safe_top)
	_mode_level_label.position = Vector2(center_left, 34.0 + safe_top)
	_distance_label.position = Vector2(right_x, 6.0 + safe_top)
	_speed_label.position = Vector2(right_x, 24.0 + safe_top)
	_jump_container.position = Vector2(right_x, 42.0 + safe_top)
	_jump_container.size = Vector2(70.0, 24.0)
	_jump_label.position = Vector2(right_x, 64.0 + safe_top)
	_fuel_group.position = Vector2(6.0 + safe_left, 52.0 + safe_top)
	_life_popup.position = Vector2(6.0 + safe_left, 78.0 + safe_top)
	_pause_button.position = Vector2(width - safe_right - 32.0, 6.0 + safe_top)
	_pause_button.size = Vector2(32.0, 28.0)
	for label: Label in [_score_label, _best_label, _mode_level_label, _distance_label, _speed_label, _jump_label]:
		label.size = Vector2(LABEL_WIDTH, 14.0)
	_layout_center_overlays(view, safe_top)

## Places every centered overlay against the current canvas height so tall
## phones do not leave the menu text or buttons floating in the middle.
func _layout_center_overlays(view: Vector2, safe_top: float) -> void:
	var center_x: float = view.x * 0.5
	var message_top: float = maxf(view.y * 0.40, safe_top + 110.0)
	_message.position = Vector2(center_x - INFO_WIDTH * 0.5, message_top)
	_message.size = Vector2(INFO_WIDTH, 56.0)
	_countdown.position = Vector2(center_x - 32.0, message_top - 30.0)
	_countdown.size = Vector2(64.0, 70.0)
	var info_top: float = maxf(view.y * INFO_TOP_RATIO, safe_top + 110.0)
	var row_y: float = info_top
	for label: Label in [_game_over_mode, _game_over_score, _game_over_distance, _game_over_best, _new_best]:
		label.position = Vector2(center_x - INFO_WIDTH * 0.5, row_y)
		label.size = Vector2(INFO_WIDTH, INFO_ROW_HEIGHT)
		row_y += INFO_ROW_HEIGHT + INFO_ROW_GAP
	var actions_top: float = row_y + 12.0
	var retry_button: Button = $GameOverActions/Retry
	var menu_button: Button = $GameOverActions/Menu
	retry_button.position = Vector2(center_x - ACTION_WIDTH * 0.5, actions_top)
	retry_button.size = Vector2(ACTION_WIDTH, ACTION_HEIGHT)
	menu_button.position = Vector2(center_x - ACTION_WIDTH * 0.5, actions_top + ACTION_HEIGHT + ACTION_GAP)
	menu_button.size = Vector2(ACTION_WIDTH, ACTION_HEIGHT)
	_layout_pause_overlay(view, safe_top)

func _layout_pause_overlay(view: Vector2, safe_top: float) -> void:
	var available_height: float = view.y - safe_top - ScreenMetrics.safe_bottom - 40.0
	var panel_size: Vector2 = Vector2(minf(PAUSE_WIDTH, view.x - PAUSE_SIDE_MARGIN * 2.0), minf(PAUSE_MAX_HEIGHT, available_height))
	_pause_overlay.position = Vector2((view.x - panel_size.x) * 0.5, safe_top + (available_height - panel_size.y) * 0.5 + 20.0)
	_pause_overlay.size = panel_size
	_pause_title.position = Vector2(PAUSE_SIDE_MARGIN, 8.0)
	_pause_title.size = Vector2(panel_size.x - PAUSE_SIDE_MARGIN * 2.0, PAUSE_TITLE_HEIGHT - 8.0)
	var rows: int = _pause_buttons.size()
	var content_top: float = PAUSE_TITLE_HEIGHT
	var content_height: float = panel_size.y - content_top - PAUSE_SIDE_MARGIN
	var row_height: float = clampf((content_height - PAUSE_ROW_GAP * float(rows - 1)) / float(rows), PAUSE_ROW_MIN_HEIGHT, PAUSE_ROW_MAX_HEIGHT)
	var button_width: float = panel_size.x - PAUSE_SIDE_MARGIN * 2.0
	for index: int in rows:
		var button: Button = _pause_buttons[index]
		button.position = Vector2(PAUSE_SIDE_MARGIN, content_top + float(index) * (row_height + PAUSE_ROW_GAP))
		button.size = Vector2(button_width, row_height)

func _set_hearts_immediately(lives_value: int, visible_slots: int) -> void:
	_kill_all_heart_tweens()
	for index: int in _life_icons.size():
		var heart: TextureRect = _life_icons[index]
		heart.visible = GameState.is_fuel_mode() and index < visible_slots
		heart.texture = HEART_FULL_TEXTURE if index < lives_value else HEART_EMPTY_TEXTURE
		heart.modulate = Color.WHITE
		heart.scale = Vector2.ONE

func _animate_life_loss(lives_value: int, visible_slots: int) -> void:
	var lost_index: int = clampi(lives_value, 0, _life_icons.size() - 1)
	for index: int in _life_icons.size():
		_life_icons[index].visible = GameState.is_fuel_mode() and index < visible_slots
	var heart: TextureRect = _life_icons[lost_index]
	var original_x: float = heart.position.x
	_kill_heart_tween(lost_index)
	heart.modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tween: Tween = create_tween()
	_heart_tweens[lost_index] = tween
	for step: int in LIFE_SHAKE_STEPS:
		tween.tween_property(heart, "position:x", heart.position.x + (LIFE_SHAKE_OFFSET if step % 2 == 0 else -LIFE_SHAKE_OFFSET), LIFE_ANIMATION_DURATION / float(LIFE_SHAKE_STEPS))
	tween.tween_property(heart, "position:x", original_x, LIFE_ANIMATION_DURATION / float(LIFE_SHAKE_STEPS))
	tween.parallel().tween_property(heart, "modulate", Color.WHITE, LIFE_ANIMATION_DURATION)
	tween.finished.connect(func() -> void:
		heart.texture = HEART_EMPTY_TEXTURE
		heart.position.x = original_x
		_heart_tweens.erase(lost_index)
	)

func _animate_life_gain(lives_value: int, visible_slots: int) -> void:
	for index: int in _life_icons.size():
		_life_icons[index].visible = GameState.is_fuel_mode() and index < visible_slots
	var gained_index: int = clampi(lives_value - 1, 0, _life_icons.size() - 1)
	var heart: TextureRect = _life_icons[gained_index]
	_kill_heart_tween(gained_index)
	heart.texture = HEART_FULL_TEXTURE
	heart.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	_heart_tweens[gained_index] = tween
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(heart, "scale", Vector2(LIFE_POP_SCALE, LIFE_POP_SCALE), LIFE_ANIMATION_DURATION * 0.55)
	tween.tween_property(heart, "scale", Vector2.ONE, LIFE_ANIMATION_DURATION * 0.45)
	_heart_tweens[gained_index] = tween

func _update_low_life_pulse(lives_value: int) -> void:
	if is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
		_pulse_tween = null
	for heart: TextureRect in _life_icons:
		heart.scale = Vector2.ONE
	if GameState.is_fuel_mode() and lives_value == 1:
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(_life_icons[0], "scale", Vector2(1.15, 1.15), 0.5)
		_pulse_tween.tween_property(_life_icons[0], "scale", Vector2.ONE, 0.5)

func _kill_heart_tween(index: int) -> void:
	if _heart_tweens.has(index) and is_instance_valid(_heart_tweens[index]):
		_heart_tweens[index].kill()
	_heart_tweens.erase(index)

func _kill_all_heart_tweens() -> void:
	for index: int in _heart_tweens.keys():
		_kill_heart_tween(index)
	if is_instance_valid(_pulse_tween):
		_pulse_tween.kill()
		_pulse_tween = null

func _exit_tree() -> void:
	_kill_all_heart_tweens()

func _on_retry_pressed() -> void:
	AudioManager.play(&"click")
	AudioManager.stop_all()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	AudioManager.play(&"click")
	AudioManager.stop_all()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_pause_pressed() -> void:
	AudioManager.play(&"click")
	get_tree().paused = true
	AudioManager.set_paused(true)
	_pause_button.visible = false
	_pause_overlay.visible = true
	$PauseOverlay/Retry.grab_focus()

func _on_resume_pressed() -> void:
	AudioManager.play(&"click")
	_pause_overlay.visible = false
	get_tree().paused = false
	AudioManager.set_paused(false)
	_pause_button.visible = true

func _on_pause_retry_pressed() -> void:
	AudioManager.play(&"click")
	AudioManager.stop_all()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_pause_audio_pressed() -> void:
	AudioManager.play(&"click")
	AudioManager.set_muted(not GameState.muted)
	_refresh_audio_button()

func _refresh_audio_button() -> void:
	_pause_audio_button.text = "SFX OFF" if GameState.muted else "SFX ON"

func _toggle_control_scheme() -> void:
	AudioManager.play(&"click")
	GameState.set_control_scheme(GameState.ControlScheme.BUTTONS if GameState.control_scheme == GameState.ControlScheme.SWIPE else GameState.ControlScheme.SWIPE)
	_refresh_touch_settings()

func _toggle_hand() -> void:
	AudioManager.play(&"click")
	GameState.set_hand_side(GameState.HandSide.LEFT if GameState.hand_side == GameState.HandSide.RIGHT else GameState.HandSide.RIGHT)
	_refresh_touch_settings()

func _refresh_touch_settings() -> void:
	_pause_controls_button.text = "CONTROLS: SWIPE" if GameState.control_scheme == GameState.ControlScheme.SWIPE else "CONTROLS: BUTTONS"
	_pause_hand_button.text = "HAND: RIGHT" if GameState.hand_side == GameState.HandSide.RIGHT else "HAND: LEFT"

func _toggle_auto_gas() -> void:
	GameState.set_auto_accelerate(not GameState.auto_accelerate)
	_refresh_auto_gas()

func _refresh_auto_gas() -> void:
	_pause_auto_gas_button.text = "AUTO GAS: ON" if GameState.auto_accelerate else "AUTO GAS: OFF"
