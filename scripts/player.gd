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
const SIDE_SWIPE_HEIGHT_RATIO: float = 0.7
const SIDE_SWIPE_DURATION: float = 1.0
const INVULNERABLE_DURATION: float = 1.5
const SIDE_SWIPE_SPEED_RATIO: float = 0.3
const SIDE_SWIPE_FUEL_COST: float = 5.0
const HARD_CRASH_FUEL_COST: float = 12.0
const BLINK_INTERVAL_MS: int = 83

@export_group("Driving")
@export var speed: float = 0.0
@export var steering_smoothing: float = 8.0

var is_off_road: bool = false
var _sprite: Sprite2D
var _base_sprite_rotation: float = 0.0
var _invulnerable: bool = false
var _spinning: bool = false

func _ready() -> void:
	add_to_group("player")
	_sprite = $Sprite2D
	_base_sprite_rotation = _sprite.rotation
	GameState.speed = speed
	$Hitbox.add_to_group("player_hitbox")
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
	if GameState.game_phase != "PLAYING":
		velocity = Vector2.ZERO
		GameState.speed = 0.0
		return
	_update_speed(delta)
	_update_steering(delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, SCREEN_LEFT, SCREEN_RIGHT)
	is_off_road = global_position.x < ROAD_LEFT or global_position.x > ROAD_RIGHT
	_sprite.rotation = _base_sprite_rotation + (sin(Time.get_ticks_msec() * 0.025) * SPRITE_WOBBLE if is_off_road else 0.0)
	if _invulnerable:
		_sprite.visible = (Time.get_ticks_msec() / BLINK_INTERVAL_MS) % 2 == 0
	else:
		_sprite.visible = true

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

func _on_hitbox_area_entered(area: Area2D) -> void:
	if _invulnerable or not area.is_in_group("traffic"):
		return
	var other: Node2D = area as Node2D
	var vertical_distance: float = absf(global_position.y - other.global_position.y)
	var side_swipe_limit: float = 52.0 * SIDE_SWIPE_HEIGHT_RATIO
	if vertical_distance < side_swipe_limit:
		_start_spin(other, true)
	else:
		_start_hard_crash()
	if area.has_method("bump_from_player"):
		area.call("bump_from_player")

func receive_traffic_hit(traffic: Node2D) -> void:
	_on_hitbox_area_entered(traffic as Area2D)

func receive_hazard_hit(hazard: Node2D) -> void:
	if _invulnerable:
		return
	if str(hazard.get("hazard_type")) == "oil":
		_start_spin(null, false)
	else:
		_start_hard_crash()

func _start_spin(other: Node2D, should_push: bool) -> void:
	if _invulnerable or _spinning:
		return
	_spinning = true
	_invulnerable = true
	speed *= SIDE_SWIPE_SPEED_RATIO
	GameState.speed = speed
	if should_push and is_instance_valid(other):
		var push_direction: float = signf(global_position.x - other.global_position.x)
		if is_zero_approx(push_direction):
			push_direction = 1.0
		global_position.x = clampf(global_position.x + push_direction * 18.0, SCREEN_LEFT, SCREEN_RIGHT)
	var spin_tween: Tween = create_tween()
	spin_tween.tween_property(_sprite, "rotation", _base_sprite_rotation + TAU * 2.0, SIDE_SWIPE_DURATION)
	GameState.fuel -= SIDE_SWIPE_FUEL_COST
	await spin_tween.finished
	_sprite.rotation = _base_sprite_rotation
	_spinning = false
	await get_tree().create_timer(INVULNERABLE_DURATION).timeout
	_invulnerable = false

func reset_for_new_game() -> void:
	speed = 0.0
	GameState.speed = 0.0
	global_position = Vector2(112.0, 310.0)
	velocity = Vector2.ZERO
	_invulnerable = false
	_spinning = false
	_sprite.visible = true
	_sprite.rotation = _base_sprite_rotation

func _start_hard_crash() -> void:
	if _invulnerable:
		return
	_invulnerable = true
	speed = 0.0
	GameState.speed = speed
	GameState.fuel -= HARD_CRASH_FUEL_COST
	var shake_tween: Tween = create_tween()
	shake_tween.tween_property(self, "position:x", position.x + 4.0, 0.06)
	shake_tween.tween_property(self, "position:x", position.x - 4.0, 0.06)
	shake_tween.tween_property(self, "position:x", position.x, 0.06)
	await get_tree().create_timer(INVULNERABLE_DURATION).timeout
	_invulnerable = false
