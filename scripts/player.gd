extends CharacterBody2D

const ACCELERATION: float = 140.0
const BRAKE_DECELERATION: float = 360.0
const COAST_DECELERATION: float = 60.0
const MAX_SPEED: float = 420.0
const OFF_ROAD_SPEED_RATIO: float = 0.45
const STEERING_SPEED: float = 150.0
const VIEW_WIDTH: float = 224.0
const ROAD_WIDTH: float = 176.0
const ROAD_LEFT: float = (VIEW_WIDTH - ROAD_WIDTH) / 2.0
const ROAD_RIGHT: float = ROAD_LEFT + ROAD_WIDTH
const SCREEN_LEFT: float = 14.0
const SCREEN_RIGHT: float = 210.0
const SPRITE_WOBBLE: float = 0.06

@export_group("Driving")
@export var speed: float = 0.0
@export var steering_smoothing: float = 8.0

var is_off_road: bool = false
var _sprite: Sprite2D
var _base_sprite_rotation: float = 0.0

func _ready() -> void:
	add_to_group("player")
	_sprite = $Sprite2D
	_base_sprite_rotation = _sprite.rotation
	GameState.speed = speed

func _physics_process(delta: float) -> void:
	_update_speed(delta)
	_update_steering(delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, SCREEN_LEFT, SCREEN_RIGHT)
	is_off_road = global_position.x < ROAD_LEFT or global_position.x > ROAD_RIGHT
	_sprite.rotation = _base_sprite_rotation + (sin(Time.get_ticks_msec() * 0.025) * SPRITE_WOBBLE if is_off_road else 0.0)

func _update_speed(delta: float) -> void:
	var target_max_speed: float = MAX_SPEED * (OFF_ROAD_SPEED_RATIO if is_off_road else 1.0)
	if Input.is_action_pressed("accelerate"):
		speed = move_toward(speed, target_max_speed, ACCELERATION * delta)
	elif Input.is_action_pressed("brake"):
		speed = move_toward(speed, 0.0, BRAKE_DECELERATION * delta)
	else:
		speed = move_toward(speed, 0.0, COAST_DECELERATION * delta)
	speed = minf(speed, target_max_speed)
	GameState.speed = speed

func _update_steering(delta: float) -> void:
	var steering_input: float = Input.get_axis("steer_left", "steer_right")
	var speed_factor: float = clampf(speed / MAX_SPEED, 0.0, 1.0)
	var target_velocity_x: float = steering_input * STEERING_SPEED * speed_factor
	velocity.x = lerpf(velocity.x, target_velocity_x, clampf(steering_smoothing * delta, 0.0, 1.0))
	velocity.y = 0.0
