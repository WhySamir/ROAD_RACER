extends CanvasLayer

## Touch/mouse input for mobile. Both control schemes emit the shared InputMap
## actions (steer_left, steer_right, accelerate, brake, jump) so player.gd only
## ever reads Input actions. Layout is recomputed from ScreenMetrics.view_size so
## controls stay pinned to the bottom corners of any phone or tablet canvas.

const SWIPE_DEAD_ZONE_PX: float = 14.0
const SWIPE_JUMP_DISTANCE_PX: float = 40.0
const JUMP_HOLD_FRAMES: int = 2
const GLOW_MIN_ALPHA: float = 0.45
const GLOW_MAX_ALPHA: float = 1.0
const GLOW_PULSE_SPEED: float = 7.0
const HINT_DURATION: float = 3.0

const STEER_LEFT_OFFSET: float = 36.0
const STEER_RIGHT_OFFSET: float = 98.0
const STEER_BOTTOM_OFFSET: float = 36.0
const STEER_BUTTON_SIZE: float = 56.0
const JUMP_RIGHT_OFFSET: float = 40.0
const JUMP_BOTTOM_OFFSET: float = 56.0
const GAS_OFFSET: Vector2 = Vector2(0.0, -78.0)
const BRAKE_OFFSET: Vector2 = Vector2(-117.0, -44.0)
const PEDAL_HALF_SIZE: Vector2 = Vector2(28.0, 21.0)
const SWIPE_ZONE_PADDING: float = 8.0

const HINT_TOP_RATIO: float = 0.22
const HINT_ROW_HEIGHT: float = 24.0
const HINT_SIDE_MARGIN: float = 12.0
const OPTIONS_Y_RATIO: float = 0.62
const OPTIONS_SIZE: Vector2 = Vector2(110.0, 26.0)

@onready var _swipe_area: Control = $SwipeArea
@onready var _button_scheme: Control = $ButtonScheme
@onready var _steer_left: TouchScreenButton = $ButtonScheme/Left
@onready var _steer_right: TouchScreenButton = $ButtonScheme/Right
@onready var _jump: TouchScreenButton = $ButtonScheme/Jump
@onready var _gas: TouchScreenButton = $ButtonScheme/Gas
@onready var _brake: TouchScreenButton = $ButtonScheme/Brake
@onready var _left_back: ColorRect = $ButtonScheme/LeftBack
@onready var _right_back: ColorRect = $ButtonScheme/RightBack
@onready var _jump_glow: ColorRect = $ButtonScheme/Jump/Glow
@onready var _auto_toggle: CheckButton = $Options/AutoAccelerate
@onready var _options: Control = $Options
@onready var _hint_overlay: Control = $HintOverlay
@onready var _hint_rows: Array[Label] = [
	$HintOverlay/Title,
	$HintOverlay/Steer,
	$HintOverlay/Jump,
	$HintOverlay/Pedals,
	$HintOverlay/Dismiss,
]

var auto_accelerate: bool = false

var _swipe_index: int = -1
var _swipe_start: Vector2 = Vector2.ZERO
var _swipe_jump_used: bool = false
var _swipe_accelerating: bool = false
var _swipe_braking: bool = false
var _gas_zone: Rect2 = Rect2()
var _brake_zone: Rect2 = Rect2()
var _jump_hold_frames: int = 0
var _auto_action_pressed: bool = false
var _hint_timer: float = 0.0
var _glow_time: float = 0.0
var _paused_by_focus: bool = false

func _ready() -> void:
	auto_accelerate = GameState.auto_accelerate
	_auto_toggle.button_pressed = auto_accelerate
	_auto_toggle.toggled.connect(_on_auto_toggled)
	GameState.jump_charges_changed.connect(_on_jump_charges_changed)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.selection_changed.connect(_refresh_layout)
	ScreenMetrics.changed.connect(_refresh_layout)
	_on_jump_charges_changed(GameState.jump_charges)
	_refresh_layout()
	_on_phase_changed(GameState.game_phase)

func _process(delta: float) -> void:
	_glow_time += delta
	if _jump_glow.visible:
		# Pulse the jump button glow while a charge is available.
		_jump_glow.modulate.a = lerpf(GLOW_MIN_ALPHA, GLOW_MAX_ALPHA, 0.5 + 0.5 * sin(_glow_time * GLOW_PULSE_SPEED))
	if _jump_hold_frames > 0:
		_jump_hold_frames -= 1
		if _jump_hold_frames == 0:
			Input.action_release("jump")
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			_dismiss_hint()
	_update_auto_accelerate()

func _input(event: InputEvent) -> void:
	if not _swipe_area.visible:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			if _swipe_index != -1:
				return
			if _hint_overlay.visible:
				_dismiss_hint()
				return
			_begin_swipe(touch.index, touch.position)
		elif touch.index == _swipe_index:
			_end_swipe()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == _swipe_index:
			_update_swipe(drag.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if GameState.game_phase == "PLAYING" and not get_tree().paused:
			get_tree().paused = true
			_paused_by_focus = true
			AudioManager.set_paused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _paused_by_focus:
			_paused_by_focus = false
			get_tree().paused = false
			AudioManager.set_paused(false)

func _update_auto_accelerate() -> void:
	# Braking overrides auto-gas so the brake button stays usable.
	var wants_auto: bool = auto_accelerate and GameState.game_phase == "PLAYING" and not Input.is_action_pressed("brake")
	if wants_auto and not _auto_action_pressed:
		Input.action_press("accelerate")
		_auto_action_pressed = true
	elif not wants_auto and _auto_action_pressed:
		Input.action_release("accelerate")
		_auto_action_pressed = false

func _begin_swipe(index: int, position: Vector2) -> void:
	_swipe_index = index
	_swipe_start = position
	_swipe_jump_used = false
	_swipe_accelerating = false
	_swipe_braking = false
	if _gas_zone.has_point(position) and not Input.is_action_pressed("accelerate"):
		_swipe_accelerating = true
		Input.action_press("accelerate")
	elif _brake_zone.has_point(position):
		_swipe_braking = true
		Input.action_press("brake")

func _update_swipe(position: Vector2) -> void:
	var horizontal: float = position.x - _swipe_start.x
	if horizontal <= -SWIPE_DEAD_ZONE_PX:
		Input.action_press("steer_left")
		Input.action_release("steer_right")
	elif horizontal >= SWIPE_DEAD_ZONE_PX:
		Input.action_press("steer_right")
		Input.action_release("steer_left")
	else:
		Input.action_release("steer_left")
		Input.action_release("steer_right")
	if not _swipe_jump_used and _swipe_start.y - position.y >= SWIPE_JUMP_DISTANCE_PX:
		_swipe_jump_used = true
		Input.action_press("jump")
		_jump_hold_frames = JUMP_HOLD_FRAMES

func _end_swipe() -> void:
	_swipe_index = -1
	_swipe_jump_used = false
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	if _swipe_accelerating:
		Input.action_release("accelerate")
		_swipe_accelerating = false
	if _swipe_braking:
		Input.action_release("brake")
		_swipe_braking = false
	if _jump_hold_frames > 0:
		_jump_hold_frames = 0
		Input.action_release("jump")

func _refresh_layout() -> void:
	var swipe_scheme: bool = GameState.control_scheme == GameState.ControlScheme.SWIPE
	if _swipe_area.visible != swipe_scheme:
		_end_swipe()
	_swipe_area.visible = swipe_scheme
	_button_scheme.visible = not swipe_scheme
	_layout_buttons()
	_layout_hint()
	_layout_options()

func _layout_buttons() -> void:
	var view: Vector2 = ScreenMetrics.view_size
	var bottom: float = view.y - ScreenMetrics.safe_bottom
	var steer_y: float = bottom - STEER_BOTTOM_OFFSET
	var jump: Vector2
	var steer_left: Vector2
	var steer_right: Vector2
	var brake_offset: Vector2 = BRAKE_OFFSET
	var left_handed: bool = GameState.hand_side == GameState.HandSide.LEFT
	if left_handed:
		# Mirror the whole cluster: pedals bottom-left, steering pad bottom-right.
		jump = Vector2(ScreenMetrics.safe_left + JUMP_RIGHT_OFFSET, bottom - JUMP_BOTTOM_OFFSET)
		steer_left = Vector2(view.x - ScreenMetrics.safe_right - STEER_RIGHT_OFFSET, steer_y)
		steer_right = Vector2(view.x - ScreenMetrics.safe_right - STEER_LEFT_OFFSET, steer_y)
		brake_offset = Vector2(-BRAKE_OFFSET.x, BRAKE_OFFSET.y)
	else:
		jump = Vector2(view.x - ScreenMetrics.safe_right - JUMP_RIGHT_OFFSET, bottom - JUMP_BOTTOM_OFFSET)
		steer_left = Vector2(ScreenMetrics.safe_left + STEER_LEFT_OFFSET, steer_y)
		steer_right = Vector2(ScreenMetrics.safe_left + STEER_RIGHT_OFFSET, steer_y)
	var gas: Vector2 = jump + GAS_OFFSET
	var brake: Vector2 = jump + brake_offset
	_steer_left.position = steer_left
	_steer_right.position = steer_right
	_jump.position = jump
	_gas.position = gas
	_brake.position = brake
	_left_back.position = steer_left - Vector2(STEER_BUTTON_SIZE, STEER_BUTTON_SIZE) * 0.5
	_left_back.size = Vector2(STEER_BUTTON_SIZE, STEER_BUTTON_SIZE)
	_right_back.position = steer_right - Vector2(STEER_BUTTON_SIZE, STEER_BUTTON_SIZE) * 0.5
	_right_back.size = Vector2(STEER_BUTTON_SIZE, STEER_BUTTON_SIZE)
	# Swipe zones follow the pedals so both schemes share the same muscle memory.
	var zone_size: Vector2 = PEDAL_HALF_SIZE * 2.0 + Vector2(SWIPE_ZONE_PADDING, SWIPE_ZONE_PADDING) * 2.0
	_gas_zone = Rect2(gas - zone_size * 0.5, zone_size)
	_brake_zone = Rect2(brake - zone_size * 0.5, zone_size)

func _layout_hint() -> void:
	var view: Vector2 = ScreenMetrics.view_size
	var top: float = maxf(view.y * HINT_TOP_RATIO, ScreenMetrics.safe_top + 8.0)
	var row_width: float = view.x - HINT_SIDE_MARGIN * 2.0
	for index: int in _hint_rows.size():
		var row: Label = _hint_rows[index]
		row.position = Vector2(HINT_SIDE_MARGIN, top + HINT_ROW_HEIGHT * float(index))
		row.size = Vector2(row_width, HINT_ROW_HEIGHT - 4.0)

func _layout_options() -> void:
	var view: Vector2 = ScreenMetrics.view_size
	_auto_toggle.position = Vector2((view.x - OPTIONS_SIZE.x) * 0.5, view.y * OPTIONS_Y_RATIO)
	_auto_toggle.size = OPTIONS_SIZE

func _on_auto_toggled(enabled: bool) -> void:
	auto_accelerate = enabled
	GameState.set_auto_accelerate(enabled)

func _on_jump_charges_changed(value: int) -> void:
	_jump_glow.visible = value > 0

func _on_phase_changed(value: String) -> void:
	_options.visible = value == "MENU"
	if value != "PLAYING":
		_end_swipe()
	if _swipe_area.visible and value == "PLAYING" and not GameState.seen_swipe_hint:
		_show_hint()
	else:
		_hint_overlay.visible = false
		_hint_timer = 0.0

func _show_hint() -> void:
	_hint_overlay.visible = true
	_hint_timer = HINT_DURATION

func _dismiss_hint() -> void:
	if not _hint_overlay.visible:
		return
	_hint_overlay.visible = false
	_hint_timer = 0.0
	GameState.set_seen_swipe_hint(true)
