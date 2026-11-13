extends Node

const ROAD_LEFT: float = 24.0
const LANE_WIDTH: float = 44.0
const LANE_COUNT: int = 4
const SPAWN_Y: float = -90.0
const MIN_VERTICAL_GAP: float = 90.0
const BASE_SPAWN_INTERVAL: float = 1.65
const STAGE_DISTANCE: float = 1500.0

@export var traffic_scene: PackedScene
@export var spawn_interval: float = BASE_SPAWN_INTERVAL

var distance_m: float = 0.0
var stage: int = 1
var _spawn_timer: float = 0.8
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if traffic_scene == null:
		traffic_scene = load("res://scenes/traffic_car.tscn") as PackedScene

func _process(delta: float) -> void:
	distance_m += GameState.speed * delta / 10.0
	stage = maxi(1, int(distance_m / STAGE_DISTANCE) + 1)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		if _try_spawn_traffic():
			_spawn_timer = maxf(0.65, spawn_interval / (1.0 + 0.08 * float(stage - 1)))
		else:
			_spawn_timer = 0.2

func _try_spawn_traffic() -> bool:
	var available_lanes: Array[int] = []
	for lane: int in LANE_COUNT:
		if _lane_is_clear(lane):
			available_lanes.append(lane)
	if available_lanes.is_empty():
		return false
	var lane: int = available_lanes[_rng.randi_range(0, available_lanes.size() - 1)]
	var car: Area2D = traffic_scene.instantiate() as Area2D
	car.set("vehicle_type", _choose_vehicle_type())
	car.set("stage_speed_multiplier", 1.0 + 0.06 * float(stage - 1))
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
