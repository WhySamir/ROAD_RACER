extends Node

const LANE_COUNT: int = 4
const SPAWN_Y: float = -80.0
const BASE_SPAWN_INTERVAL: float = 1.65
const BASE_MIN_GAP_PX: float = 90.0
const MIN_SPAWN_INTERVAL: float = 0.65
const SPAWN_RETRY_DELAY: float = 0.2
const STAGE_DENSITY_STEP: float = 0.08
const STAGE_SPEED_STEP: float = 0.06
const HIGH_SPEED_FUEL_DRAIN: float = 0.01
const HIGH_SPEED_FUEL_THRESHOLD: float = 300.0
const PICKUP_MIN_INTERVAL: float = 8.0
const PICKUP_MAX_INTERVAL: float = 14.0
const HAZARD_INTERVAL: float = 5.0
const JUMP_DISTANCE_METERS: float = 250.0
const COUNTDOWN_STEP_SECONDS: float = 1.0
const COUNTDOWN_START_VALUE: int = 3
const PLAYING_SPAWN_DELAY: float = 0.5
const INITIAL_SPAWN_DELAY: float = 0.8
const SWERVE_TRIGGER_Y: float = 150.0
const VEHICLE_BLUE_CHANCE: float = 0.28
const VEHICLE_YELLOW_CHANCE: float = 0.20
const VEHICLE_GREEN_CHANCE: float = 0.16
const VEHICLE_WHITE_CHANCE: float = 0.16
const VEHICLE_TRUCK_CHANCE: float = 0.06
const NORMAL_VEHICLE_CHANCE_TOTAL: float = 0.86
const BASE_SWERVER_CHANCE: float = 0.14
const MAX_ACTIVE_TRAFFIC: int = 3
const EXTRA_LIFE_DISTANCE_M: float = 1500.0

@export var traffic_scene: PackedScene
@export var pickup_scene: PackedScene
@export var hazard_scene: PackedScene

var distance_m: float = 0.0
var stage: int = 1
var _last_distance_score: int = 0
var _next_life_distance_m: float = EXTRA_LIFE_DISTANCE_M
var _spawn_timer: float = INITIAL_SPAWN_DELAY
var _pickup_timer: float = PICKUP_MIN_INTERVAL
var _hazard_timer: float = HAZARD_INTERVAL
var _countdown_timer: float = 0.0
var _countdown_value: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if traffic_scene == null:
		traffic_scene = load("res://scenes/traffic_car.tscn") as PackedScene
	if pickup_scene == null:
		pickup_scene = load("res://scenes/pickup.tscn") as PackedScene
	if hazard_scene == null:
		hazard_scene = load("res://scenes/hazard.tscn") as PackedScene
	GameState.reset_game()
	GameState.set_phase("MENU")

func _process(delta: float) -> void:
	if GameState.game_phase == "MENU" or GameState.game_phase == "GAME_OVER":
		if Input.is_action_just_pressed("accelerate") or Input.is_action_just_pressed("jump"):
			_begin_countdown()
		return
	if GameState.game_phase == "COUNTDOWN":
		_process_countdown(delta)
		return
	if GameState.game_phase != "PLAYING":
		return
	_update_distance(delta)
	_update_fuel(delta)
	_update_spawning(delta)

func _update_distance(delta: float) -> void:
	var preset: Dictionary = GameState.get_preset()
	var stage_length_m: float = float(preset.get("stage_length_m", 1500.0))
	distance_m += GameState.speed * delta / 10.0
	stage = maxi(1, int(distance_m / stage_length_m) + 1)
	var distance_score: int = int(distance_m)
	if distance_score > _last_distance_score:
		GameState.add_score(distance_score - _last_distance_score)
		_last_distance_score = distance_score
	GameState.add_jump_meter(GameState.speed * delta / 10.0 * 100.0 / JUMP_DISTANCE_METERS)
	GameState.distance = distance_m
	GameState.distance_changed.emit(distance_m)
	if stage != GameState.stage:
		GameState.stage = stage
		GameState.stage_changed.emit(stage)
	if GameState.is_fuel_mode() and distance_m >= _next_life_distance_m:
		GameState.add_life()
		_next_life_distance_m += EXTRA_LIFE_DISTANCE_M

func _update_fuel(delta: float) -> void:
	if not GameState.is_fuel_mode():
		return
	var preset: Dictionary = GameState.get_preset()
	var base_drain: float = float(preset.get("fuel_drain_pct_s", 1.6))
	var fuel_drain: float = base_drain + maxf(GameState.speed - HIGH_SPEED_FUEL_THRESHOLD, 0.0) * HIGH_SPEED_FUEL_DRAIN
	GameState.fuel -= fuel_drain * delta
	if GameState.fuel <= 0.0:
		GameState.set_game_over()

func _update_spawning(delta: float) -> void:
	var preset: Dictionary = GameState.get_preset()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		if _try_spawn_traffic():
			_spawn_timer = _traffic_spawn_interval(preset)
		else:
			_spawn_timer = SPAWN_RETRY_DELAY
	if GameState.is_fuel_mode():
		_pickup_timer -= delta
		if _pickup_timer <= 0.0:
			_spawn_pickup()
			_pickup_timer = _rng.randf_range(PICKUP_MIN_INTERVAL, PICKUP_MAX_INTERVAL)
	if stage >= int(preset.get("oil_start_stage", 2)):
		_hazard_timer -= delta
		if _hazard_timer <= 0.0:
			_spawn_hazard(_choose_hazard_type(preset))
			_hazard_timer = HAZARD_INTERVAL

func _traffic_spawn_interval(preset: Dictionary) -> float:
	# The MEDIUM preset is the baseline; other levels scale the interval from it.
	var base_interval: float = BASE_SPAWN_INTERVAL * _relative_factor(preset, "spawn_interval")
	var stage_factor: float = 1.0 + STAGE_DENSITY_STEP * float(stage - 1)
	return maxf(MIN_SPAWN_INTERVAL, base_interval / stage_factor)

## Ratio of a preset value against the MEDIUM reference value for the same key.
func _relative_factor(preset: Dictionary, key: String) -> float:
	var medium_value: float = float(DifficultyConfig.get_preset(DifficultyConfig.Level.MEDIUM).get(key, 1.0))
	var current_value: float = float(preset.get(key, medium_value))
	if is_zero_approx(medium_value):
		return 1.0
	return current_value / medium_value

func _choose_hazard_type(preset: Dictionary) -> String:
	var rock_start_stage: int = int(preset.get("rock_start_stage", 3))
	if stage >= rock_start_stage and _rng.randf() > 0.5:
		return "rock"
	return "oil"

func _begin_countdown() -> void:
	_cleanup_world()
	var player: Node = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("reset_for_new_game"):
		player.call("reset_for_new_game")
	GameState.reset_game()
	distance_m = 0.0
	stage = 1
	_last_distance_score = 0
	_next_life_distance_m = EXTRA_LIFE_DISTANCE_M
	GameState.set_phase("COUNTDOWN")
	_countdown_value = COUNTDOWN_START_VALUE
	_countdown_timer = COUNTDOWN_STEP_SECONDS
	GameState.countdown_changed.emit(_countdown_value)

func _process_countdown(delta: float) -> void:
	_countdown_timer -= delta
	if _countdown_timer > 0.0:
		return
	_countdown_value -= 1
	GameState.countdown_changed.emit(_countdown_value)
	if _countdown_value <= 0:
		GameState.set_phase("PLAYING")
		_spawn_timer = PLAYING_SPAWN_DELAY
		AudioManager.start_engine()
	else:
		_countdown_timer = COUNTDOWN_STEP_SECONDS

func _cleanup_world() -> void:
	for group_name: String in ["traffic", "pickup", "hazard"]:
		for node: Node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node):
				node.queue_free()

func _spawn_pickup() -> void:
	if pickup_scene == null:
		return
	var pickup: Area2D = pickup_scene.instantiate() as Area2D
	var lane: int = _rng.randi_range(0, LANE_COUNT - 1)
	pickup.position = Vector2(ScreenMetrics.lane_center(lane), SPAWN_Y)
	add_child(pickup)

func _spawn_hazard(hazard_type: String) -> void:
	if hazard_scene == null:
		return
	var hazard: Area2D = hazard_scene.instantiate() as Area2D
	hazard.set("hazard_type", hazard_type)
	var lane: int = _rng.randi_range(0, LANE_COUNT - 1)
	hazard.position = Vector2(ScreenMetrics.lane_center(lane), SPAWN_Y)
	add_child(hazard)

func _try_spawn_traffic() -> bool:
	if get_tree().get_nodes_in_group("traffic").size() >= MAX_ACTIVE_TRAFFIC:
		return false
	var available_lanes: Array[int] = []
	for lane: int in LANE_COUNT:
		if _lane_is_clear(lane):
			available_lanes.append(lane)
	if available_lanes.is_empty():
		return false
	var lane: int = available_lanes[_rng.randi_range(0, available_lanes.size() - 1)]
	var car: Area2D = traffic_scene.instantiate() as Area2D
	var vehicle_type: String = _choose_vehicle_type()
	car.set("vehicle_type", vehicle_type)
	car.set("stage_speed_multiplier", 1.0 + STAGE_SPEED_STEP * float(stage - 1))
	car.set("will_swerve", vehicle_type == "purple")
	car.set("swerve_dir", 1 if lane < 2 else -1)
	car.set("swerve_trigger_y", SWERVE_TRIGGER_Y)
	car.position = Vector2(ScreenMetrics.lane_center(lane), SPAWN_Y)
	add_child(car)
	return true

func _lane_is_clear(lane: int) -> bool:
	var lane_x: float = ScreenMetrics.lane_center(lane)
	var min_gap_px: float = BASE_MIN_GAP_PX * _relative_factor(GameState.get_preset(), "min_gap_px")
	for node: Node in get_tree().get_nodes_in_group("traffic"):
		var traffic: Node2D = node as Node2D
		if is_instance_valid(traffic) and absf(traffic.global_position.x - lane_x) < 20.0 and absf(traffic.global_position.y - SPAWN_Y) < min_gap_px:
			return false
	return true

func _choose_vehicle_type() -> String:
	# The MEDIUM preset is the baseline; swerver chance scales off the original mix.
	var swerver_chance: float = BASE_SWERVER_CHANCE * _relative_factor(GameState.get_preset(), "swerver_chance")
	if _rng.randf() < swerver_chance:
		return "purple"
	# Remaining vehicles keep the original relative proportions.
	var normal_roll: float = _rng.randf() * NORMAL_VEHICLE_CHANCE_TOTAL
	if normal_roll < VEHICLE_BLUE_CHANCE:
		return "blue"
	if normal_roll < VEHICLE_BLUE_CHANCE + VEHICLE_YELLOW_CHANCE:
		return "yellow"
	if normal_roll < VEHICLE_BLUE_CHANCE + VEHICLE_YELLOW_CHANCE + VEHICLE_GREEN_CHANCE:
		return "green"
	if normal_roll < VEHICLE_BLUE_CHANCE + VEHICLE_YELLOW_CHANCE + VEHICLE_GREEN_CHANCE + VEHICLE_WHITE_CHANCE:
		return "white"
	return "truck"
