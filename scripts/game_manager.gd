extends Node

const ROAD_LEFT: float = 24.0
const LANE_WIDTH: float = 44.0
const LANE_COUNT: int = 4
const SPAWN_Y: float = -90.0
const MIN_VERTICAL_GAP: float = 90.0
const BASE_SPAWN_INTERVAL: float = 1.65
const STAGE_DISTANCE: float = 1500.0
const FUEL_DRAIN_PER_SECOND: float = 1.6
const HIGH_SPEED_FUEL_DRAIN: float = 0.01
const PICKUP_MIN_INTERVAL: float = 8.0
const PICKUP_MAX_INTERVAL: float = 14.0
const HAZARD_INTERVAL: float = 5.0
const JUMP_DISTANCE_METERS: float = 250.0

@export var traffic_scene: PackedScene
@export var pickup_scene: PackedScene
@export var hazard_scene: PackedScene
@export var spawn_interval: float = BASE_SPAWN_INTERVAL

var distance_m: float = 0.0
var stage: int = 1
var _last_distance_score: int = 0
var _spawn_timer: float = 0.8
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
	distance_m += GameState.speed * delta / 10.0
	stage = maxi(1, int(distance_m / STAGE_DISTANCE) + 1)
	var distance_score: int = int(distance_m)
	if distance_score > _last_distance_score:
		GameState.score += distance_score - _last_distance_score
		_last_distance_score = distance_score
	GameState.jump_meter += GameState.speed * delta / 10.0 * 100.0 / JUMP_DISTANCE_METERS
	GameState.distance = distance_m
	GameState.distance_changed.emit(distance_m)
	if stage != GameState.stage:
		GameState.stage = stage
		GameState.stage_changed.emit(stage)
	var fuel_drain: float = FUEL_DRAIN_PER_SECOND + maxf(GameState.speed - 300.0, 0.0) * HIGH_SPEED_FUEL_DRAIN
	GameState.fuel -= fuel_drain * delta
	if GameState.fuel <= 0.0:
		GameState.set_game_over()
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		if _try_spawn_traffic():
			_spawn_timer = maxf(0.65, spawn_interval / (1.0 + 0.08 * float(stage - 1)))
		else:
			_spawn_timer = 0.2
	_pickup_timer -= delta
	if _pickup_timer <= 0.0:
		_spawn_pickup()
		_pickup_timer = _rng.randf_range(PICKUP_MIN_INTERVAL, PICKUP_MAX_INTERVAL)
	if stage >= 2:
		_hazard_timer -= delta
		if _hazard_timer <= 0.0:
			_spawn_hazard("rock" if stage >= 3 and _rng.randf() > 0.5 else "oil")
			_hazard_timer = HAZARD_INTERVAL

func _begin_countdown() -> void:
	_cleanup_world()
	var player: Node = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("reset_for_new_game"):
		player.call("reset_for_new_game")
	GameState.reset_game()
	distance_m = 0.0
	stage = 1
	_last_distance_score = 0
	GameState.set_phase("COUNTDOWN")
	_countdown_value = 3
	_countdown_timer = 1.0
	GameState.countdown_changed.emit(_countdown_value)

func _process_countdown(delta: float) -> void:
	_countdown_timer -= delta
	if _countdown_timer > 0.0:
		return
	_countdown_value -= 1
	GameState.countdown_changed.emit(_countdown_value)
	if _countdown_value <= 0:
		GameState.set_phase("PLAYING")
		_spawn_timer = 0.5
	else:
		_countdown_timer = 1.0

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
	pickup.position = Vector2(ROAD_LEFT + 22.0 + LANE_WIDTH * lane, SPAWN_Y)
	add_child(pickup)

func _spawn_hazard(hazard_type: String) -> void:
	if hazard_scene == null:
		return
	var hazard: Area2D = hazard_scene.instantiate() as Area2D
	hazard.set("hazard_type", hazard_type)
	var lane: int = _rng.randi_range(0, LANE_COUNT - 1)
	hazard.position = Vector2(ROAD_LEFT + 22.0 + LANE_WIDTH * lane, SPAWN_Y)
	add_child(hazard)

func _try_spawn_traffic() -> bool:
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
	car.set("stage_speed_multiplier", 1.0 + 0.06 * float(stage - 1))
	car.set("will_swerve", vehicle_type == "purple")
	car.set("swerve_dir", 1 if lane < 2 else -1)
	car.set("swerve_trigger_y", 150.0)
	car.position = Vector2(ROAD_LEFT + 22.0 + LANE_WIDTH * lane, SPAWN_Y)
	add_child(car)
	return true

func _lane_is_clear(lane: int) -> bool:
	var lane_x: float = ROAD_LEFT + 22.0 + LANE_WIDTH * lane
	for node: Node in get_tree().get_nodes_in_group("traffic"):
		var traffic: Node2D = node as Node2D
		if is_instance_valid(traffic) and absf(traffic.global_position.x - lane_x) < 20.0 and absf(traffic.global_position.y - SPAWN_Y) < MIN_VERTICAL_GAP:
			return false
	return true

func _choose_vehicle_type() -> String:
	var roll: float = _rng.randf()
	if roll < 0.28:
		return "blue"
	if roll < 0.48:
		return "yellow"
	if roll < 0.64:
		return "green"
	if roll < 0.78:
		return "purple"
	if roll < 0.94:
		return "white"
	return "truck"
