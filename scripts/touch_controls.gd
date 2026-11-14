extends CanvasLayer

## Touch/mouse input for mobile.
##
## Steering is screen-wide: touching or holding the left half of the screen
## steers left, the right half steers right, and dragging across the middle
## switches sides. Multiple fingers work (steer left while holding gas), and a
## touch that starts on the gas, brake or jump button never steers.

const SWIPE_JUMP_DISTANCE_PX: float = 40.0
const JUMP_HOLD_FRAMES: int = 2
const GLOW_MIN_ALPHA: float = 0.45
const GLOW_MAX_ALPHA: float = 1.0
const GLOW_PULSE_SPEED: float = 7.0
const HINT_DURATION: float = 3.0

const JUMP_RIGHT_OFFSET: float = 40.0
const JUMP_BOTTOM_OFFSET: float = 56.0
const GAS_OFFSET: Vector2 = Vector2(0.0, -78.0)
const BRAKE_OFFSET: Vector2 = Vector2(-117.0, -44.0)
const PEDAL_HALF_SIZE: Vector2 = Vector2(28.0, 21.0)
const JUMP_HALF_SIZE: Vector2 = Vector2(32.0, 32.0)
const PEDAL_ZONE_PADDING: float = 8.0
const JUMP_ZONE_PADDING: float = 4.0

const HINT_TOP_RATIO: float = 0.22
const HINT_ROW_HEIGHT: float = 24.0
const HINT_SIDE_MARGIN: float = 12.0
const OPTIONS_Y_RATIO: float = 0.62
const OPTIONS_SIZE: Vector2 = Vector2(120.0, 26.0)

const LEFT_SIDE: int = -1
const NO_SIDE: int = 0
const RIGHT_SIDE: int = 1

@onready var _swipe_area: Control = $SwipeArea
@onready var _button_scheme: Control = $ButtonScheme
@onready var _jump: TouchScreenButton = $ButtonScheme/Jump
@onready var _gas: TouchScreenButton = $ButtonScheme/Gas
@onready var _brake: TouchScreenButton = $ButtonScheme/Brake
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

var _touch_sides: Dictionary = {}
var _touch_pedals: Dictionary = {}
var _left_holds: int = 0
var _right_holds: int = 0
var _swipe_index: int = -1
var _swipe_start: Vector2 = Vector2.ZERO
var _swipe_jump_used: bool = false
var _jump_zone: Rect2 = Rect2()
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
	if get_tree().paused:
		return
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			if _hint_overlay.visible:
				_dismiss_hint()
				return
			_begin_touch(touch.index, touch.position)
		else:
			_end_touch(touch.index)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		_update_touch(drag.index, drag.position)

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
	elif what == NOTIFICATION_PAUSED:
		# A finger held during pause never sends its release, so drop all holds.
		_clear_touches()

func _begin_touch(index: int, position: Vector2) -> void:
	if _touch_sides.has(index) or _touch_pedals.has(index):
		return
	if _is_swipe_scheme():
		if _gas_zone.has_point(position):
			_hold_pedal(index, &"accelerate")
			return
		if _brake_zone.has_point(position):
			_hold_pedal(index, &"brake")
			return
	elif _jump_zone.has_point(position) or _gas_zone.has_point(position) or _brake_zone.has_point(position):
		# The on-screen pedals and jump button own these touches.
		return
	_begin_steer(index, position)

func _update_touch(index: int, position: Vector2) -> void:
	if _touch_sides.has(index):
		_apply_steer(index, position)
		if index == _swipe_index:
			_check_swipe_jump(position)

func _end_touch(index: int) -> void:
	if _touch_sides.has(index):
		_set_steer_side(index, NO_SIDE)
		_touch_sides.erase(index)
	if _touch_pedals.has(index):
		Input.action_release(_touch_pedals[index] as StringName)
		_touch_pedals.erase(index)
	if index == _swipe_index:
		_swipe_index = -1
		_swipe_jump_used = false

func _begin_steer(index: int, position: Vector2) -> void:
	_touch_sides[index] = NO_SIDE
	_apply_steer(index, position)
	# The first finger owns the swipe-up gesture; extra fingers only steer.
	if _is_swipe_scheme() and _swipe_index == -1:
		_swipe_index = index
		_swipe_start = position
		_swipe_jump_used = false

func _apply_steer(index: int, position: Vector2) -> void:
	var side: int = LEFT_SIDE if position.x < ScreenMetrics.view_size.x * 0.5 else RIGHT_SIDE
	if int(_touch_sides.get(index, NO_SIDE)) == side:
		return
	_set_steer_side(index, side)

## Ref-counted so two fingers on the same side keep steering until both lift.
func _set_steer_side(index: int, side: int) -> void:
	var previous: int = int(_touch_sides.get(index, NO_SIDE))
	if previous == side:
		return
	if previous == LEFT_SIDE:
		_left_holds = maxi(_left_holds - 1, 0)
	elif previous == RIGHT_SIDE:
		_right_holds = maxi(_right_holds - 1, 0)
	_touch_sides[index] = side
	if side == LEFT_SIDE:
		_left_holds += 1
	elif side == RIGHT_SIDE:
		_right_holds += 1
	_sync_steer_actions()

func _sync_steer_actions() -> void:
	if _left_holds > 0:
		Input.action_press("steer_left")
	else:
		Input.action_release("steer_left")
	if _right_holds > 0:
		Input.action_press("steer_right")
	else:
		Input.action_release("steer_right")

func _check_swipe_jump(position: Vector2) -> void:
	if _swipe_jump_used:
		return
	if _swipe_start.y - position.y < SWIPE_JUMP_DISTANCE_PX:
		return
	_swipe_jump_used = true
	Input.action_press("jump")
	_jump_hold_frames = JUMP_HOLD_FRAMES

func _hold_pedal(index: int, action: StringName) -> void:
	if _touch_pedals.has(index):
		return
	_touch_pedals[index] = action
	Input.action_press(action)

func _clear_touches() -> void:
	for index: int in _touch_sides.keys():
		_set_steer_side(index, NO_SIDE)
	_touch_sides.clear()
	for index: int in _touch_pedals.keys():
		Input.action_release(_touch_pedals[index] as StringName)
	_touch_pedals.clear()
	_left_holds = 0
	_right_holds = 0
	_sync_steer_actions()
	_swipe_index = -1
	_swipe_jump_used = false
	if _jump_hold_frames > 0:
		_jump_hold_frames = 0
		Input.action_release("jump")

func _update_auto_accelerate() -> void:
	# Braking overrides auto-gas so the brake button stays usable.
	var wants_auto: bool = auto_accelerate and GameState.game_phase == "PLAYING" and not Input.is_action_pressed("brake")
	if wants_auto and not _auto_action_pressed:
		Input.action_press("accelerate")
		_auto_action_pressed = true
	elif not wants_auto and _auto_action_pressed:
		Input.action_release("accelerate")
		_auto_action_pressed = false

func _is_swipe_scheme() -> bool:
	return GameState.control_scheme == GameState.ControlScheme.SWIPE

func _refresh_layout() -> void:
	var swipe_scheme: bool = _is_swipe_scheme()
	if _swipe_area.visible != swipe_scheme:
		_clear_touches()
	_swipe_area.visible = swipe_scheme
	_button_scheme.visible = not swipe_scheme
	_layout_buttons()
	_layout_hint()
	_layout_options()

func _layout_buttons() -> void:
	var view: Vector2 = ScreenMetrics.view_size
	var bottom: float = view.y - ScreenMetrics.safe_bottom
	var jump: Vector2
	var brake_offset: Vector2 = BRAKE_OFFSET
	var left_handed: bool = GameState.hand_side == GameState.HandSide.LEFT
	if left_handed:
		jump = Vector2(ScreenMetrics.safe_left + JUMP_RIGHT_OFFSET, bottom - JUMP_BOTTOM_OFFSET)
		brake_offset = Vector2(-BRAKE_OFFSET.x, BRAKE_OFFSET.y)
	else:
		jump = Vector2(view.x - ScreenMetrics.safe_right - JUMP_RIGHT_OFFSET, bottom - JUMP_BOTTOM_OFFSET)
	var gas: Vector2 = jump + GAS_OFFSET
	var brake: Vector2 = jump + brake_offset
	_jump.position = jump
	_gas.position = gas
	_brake.position = brake
	var pedal_zone_size: Vector2 = PEDAL_HALF_SIZE * 2.0 + Vector2(PEDAL_ZONE_PADDING, PEDAL_ZONE_PADDING) * 2.0
	_gas_zone = Rect2(gas - pedal_zone_size * 0.5, pedal_zone_size)
	_brake_zone = Rect2(brake - pedal_zone_size * 0.5, pedal_zone_size)
	var jump_zone_size: Vector2 = JUMP_HALF_SIZE * 2.0 + Vector2(JUMP_ZONE_PADDING, JUMP_ZONE_PADDING) * 2.0
	_jump_zone = Rect2(jump - jump_zone_size * 0.5, jump_zone_size)

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
		_clear_touches()
	if _is_swipe_scheme() and value == "PLAYING" and not GameState.seen_swipe_hint:
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
