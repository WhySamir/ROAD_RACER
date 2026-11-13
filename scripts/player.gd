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
const JUMP_DURATION: float = 1.1
const BASE_SPRITE_SCALE: float = 2.0
const JUMP_STEERING_RATIO: float = 0.6
const LANDING_SQUASH_DURATION: float = 0.12
const LANDING_SHAKE_AMOUNT: float = 2.0
const PLAYER_COLLISION_LAYER: int = 1
const PLAYER_COLLISION_MASK: int = 10
const CAR_GROUND_Y: float = 0.0
const CAR_JUMP_HEIGHT: float = 14.0
const JUMP_CAR_SCALE: float = 2.6
const OIL_FUEL_COST: float = 10.0

enum State { DRIVING, SPINNING, JUMPING, DEAD }

@export_group("Driving")
@export var speed: float = 0.0
@export var steering_smoothing: float = 8.0

var is_off_road: bool = false
var _sprite: Sprite2D
var _base_sprite_rotation: float = 0.0
var _invulnerable: bool = false
var _spinning: bool = false
var _state: State = State.DRIVING
var _jump_elapsed: float = 0.0
var _landing_in_progress: bool = false

func _ready() -> void:
	add_to_group("player")
	_sprite = $Sprite2D
	_base_sprite_rotation = _sprite.rotation
	_sprite.position.y = CAR_GROUND_Y
	GameState.speed = speed
	$Hitbox.add_to_group("player_hitbox")
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)
	$Shadow.visible = false
	$Hitbox.monitoring = true
	$Hitbox.monitorable = true

func _physics_process(delta: float) -> void:
	if GameState.game_phase != "PLAYING":
		velocity = Vector2.ZERO
		GameState.speed = 0.0
		return
	if _state == State.DRIVING and Input.is_action_just_pressed("jump") and GameState.jump_charges > 0:
		_start_jump()
	if _state != State.JUMPING:
		_update_speed(delta)
	else:
		_update_jump_visual(delta)
	_update_steering(delta)
	move_and_slide()
	global_position.x = clampf(global_position.x, SCREEN_LEFT, SCREEN_RIGHT)
	is_off_road = global_position.x < ROAD_LEFT or global_position.x > ROAD_RIGHT
	_sprite.rotation = _base_sprite_rotation + (sin(Time.get_ticks_msec() * 0.025) * SPRITE_WOBBLE if is_off_road else 0.0)
	if _invulnerable:
		_sprite.visible = (Time.get_ticks_msec() / BLINK_INTERVAL_MS) % 2 == 0
	else:
		_sprite.visible = true
	if _state == State.JUMPING:
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
	var steering_ratio: float = JUMP_STEERING_RATIO if _state == State.JUMPING else 1.0
	var speed_factor: float = clampf(speed / MAX_SPEED, 0.0, 1.0) * steering_ratio
	var target_velocity_x: float = steering_input * STEERING_SPEED * speed_factor
	velocity.x = lerpf(velocity.x, target_velocity_x, clampf(steering_smoothing * delta, 0.0, 1.0))
	velocity.y = 0.0

func _on_hitbox_area_entered(area: Area2D) -> void:
	if _invulnerable or is_airborne():
		return
	if area.is_in_group("hazard"):
		receive_hazard_hit(area)
		return
	if not area.is_in_group("traffic"):
		return
	var other: Node2D = area as Node2D
	var vertical_distance: float = absf(global_position.y - other.global_position.y)
	var side_swipe_limit: float = 52.0 * SIDE_SWIPE_HEIGHT_RATIO
	if vertical_distance < side_swipe_limit:
		_start_spin(other, true)
	else:
		_start_hard_crash()
	if not is_airborne() and area.has_method("bump_from_player"):
		area.call("bump_from_player")

func is_airborne() -> bool:
	return _state == State.JUMPING

func receive_traffic_hit(traffic: Node2D) -> void:
	_on_hitbox_area_entered(traffic as Area2D)

func receive_hazard_hit(hazard: Node2D) -> void:
	if _invulnerable or _state == State.JUMPING:
		return
	if str(hazard.get("hazard_type")) == "oil":
		_start_oil_effect()
	else:
		_start_hard_crash()

func _start_spin(other: Node2D, should_push: bool) -> void:
	if _invulnerable or _spinning or _state == State.JUMPING:
		return
	_spinning = true
	_state = State.SPINNING
	_invulnerable = true
	Input.vibrate_handheld(100)
	speed *= SIDE_SWIPE_SPEED_RATIO
	GameState.speed = speed
	if should_push and is_instance_valid(other):
		var push_direction: float = signf(global_position.x - other.global_position.x)
		if is_zero_approx(push_direction):
			push_direction = 1.0
		global_position.x = clampf(global_position.x + push_direction * 18.0, SCREEN_LEFT, SCREEN_RIGHT)
	var spin_tween: Tween = create_tween()
	spin_tween.tween_property(_sprite, "rotation", _base_sprite_rotation + TAU * 2.0, SIDE_SWIPE_DURATION)
	if GameState.is_fuel_mode():
		GameState.fuel -= SIDE_SWIPE_FUEL_COST
	await spin_tween.finished
	_sprite.rotation = _base_sprite_rotation
	_spinning = false
	_state = State.DRIVING
	await get_tree().create_timer(INVULNERABLE_DURATION).timeout
	_invulnerable = false

func reset_for_new_game() -> void:
	speed = 0.0
	GameState.speed = 0.0
	global_position = Vector2(112.0, 310.0)
	velocity = Vector2.ZERO
	_invulnerable = false
	_spinning = false
	_state = State.DRIVING
	_jump_elapsed = 0.0
	_landing_in_progress = false
	_sprite.visible = true
	_sprite.rotation = _base_sprite_rotation
	_sprite.scale = Vector2(BASE_SPRITE_SCALE, BASE_SPRITE_SCALE)
	_sprite.position.y = CAR_GROUND_Y
	$Shadow.visible = false
	$Shadow.scale = Vector2(BASE_SPRITE_SCALE, BASE_SPRITE_SCALE)
	$Shadow.modulate.a = 0.9
	$Hitbox.set_deferred("monitoring", true)
	$Hitbox.set_deferred("monitorable", true)
	$Hitbox.set_deferred("collision_layer", PLAYER_COLLISION_LAYER)
	$Hitbox.set_deferred("collision_mask", PLAYER_COLLISION_MASK)

func _start_hard_crash() -> void:
	if _invulnerable or _state == State.JUMPING:
		return
	_invulnerable = true
	Input.vibrate_handheld(180)
	speed = 0.0
	GameState.speed = speed
	if GameState.is_fuel_mode():
		GameState.fuel -= HARD_CRASH_FUEL_COST
		GameState.lose_life()
	var shake_tween: Tween = create_tween()
	shake_tween.tween_property(self, "position:x", position.x + 4.0, 0.06)
	shake_tween.tween_property(self, "position:x", position.x - 4.0, 0.06)
	shake_tween.tween_property(self, "position:x", position.x, 0.06)
	await get_tree().create_timer(INVULNERABLE_DURATION).timeout
	_invulnerable = false

func _start_oil_effect() -> void:
	if _invulnerable or _state == State.JUMPING:
		return
	_invulnerable = true
	if GameState.is_fuel_mode():
		GameState.fuel -= OIL_FUEL_COST
	Input.vibrate_handheld(100)
	await get_tree().create_timer(INVULNERABLE_DURATION).timeout
	_invulnerable = false

func _start_jump() -> void:
	_state = State.JUMPING
	_jump_elapsed = 0.0
	_landing_in_progress = false
	GameState.consume_jump_charge()
	$Hitbox.set_deferred("monitoring", false)
	$Hitbox.set_deferred("monitorable", false)
	$Hitbox.set_deferred("collision_layer", 0)
	$Hitbox.set_deferred("collision_mask", 0)
	$Shadow.visible = true
	$Shadow.scale = Vector2(BASE_SPRITE_SCALE, BASE_SPRITE_SCALE)
	$Shadow.modulate.a = 0.9

func _update_jump_visual(delta: float) -> void:
	_jump_elapsed += delta
	var progress: float = clampf(_jump_elapsed / JUMP_DURATION, 0.0, 1.0)
	var arc: float = sin(progress * PI)
	var current_scale: float = lerpf(BASE_SPRITE_SCALE, JUMP_CAR_SCALE, arc)
	_sprite.position.y = CAR_GROUND_Y - arc * CAR_JUMP_HEIGHT
	_sprite.scale = Vector2(current_scale, current_scale)
	var shadow_scale: float = lerpf(1.0, 0.7, arc)
	$Shadow.scale = Vector2(BASE_SPRITE_SCALE, BASE_SPRITE_SCALE) * shadow_scale
	$Shadow.modulate.a = lerpf(0.9, 0.35, arc)
	if progress >= 1.0 and not _landing_in_progress:
		_finish_jump()

func _finish_jump() -> void:
	_landing_in_progress = true
	$Hitbox.set_deferred("monitoring", true)
	$Hitbox.set_deferred("monitorable", true)
	$Hitbox.set_deferred("collision_layer", PLAYER_COLLISION_LAYER)
	$Hitbox.set_deferred("collision_mask", PLAYER_COLLISION_MASK)
	await get_tree().process_frame
	var landing_crash: bool = false
	for area: Area2D in $Hitbox.get_overlapping_areas():
		if area.is_in_group("traffic"):
			landing_crash = true
		if area.is_in_group("hazard") and str(area.get("hazard_type")) == "rock":
			landing_crash = true
	if landing_crash:
		_state = State.DRIVING
		_sprite.position.y = CAR_GROUND_Y
		$Shadow.visible = false
		_start_hard_crash()
	else:
		_state = State.DRIVING
		_sprite.position.y = CAR_GROUND_Y
		$Shadow.visible = false
		var squash_tween: Tween = create_tween()
		_sprite.scale = Vector2(BASE_SPRITE_SCALE, BASE_SPRITE_SCALE * 0.85)
		squash_tween.tween_property(_sprite, "scale", Vector2(BASE_SPRITE_SCALE, BASE_SPRITE_SCALE), LANDING_SQUASH_DURATION)
		GameState.request_camera_shake(LANDING_SHAKE_AMOUNT)
