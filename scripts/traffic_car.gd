extends Area2D

const ROAD_LEFT: float = 24.0
const ROAD_WIDTH: float = 176.0
const LANE_WIDTH: float = 44.0
const PLAYER_Y: float = 310.0
const OFFSCREEN_Y: float = 460.0
const BASE_SPEEDS: Dictionary = {
	"blue": 180.0,
	"yellow": 230.0,
	"green": 300.0,
	"purple": 250.0,
	"white": 270.0,
	"truck": 160.0,
}
const TEXTURES: Dictionary = {
	"blue": "res://assets/car_blue.png",
	"yellow": "res://assets/car_yellow.png",
	"green": "res://assets/car_green.png",
	"purple": "res://assets/car_purple.png",
	"white": "res://assets/car_white.png",
	"truck": "res://assets/truck_orange.png",
}

@export var vehicle_type: String = "blue"
@export var traffic_speed: float = 180.0
@export var stage_speed_multiplier: float = 1.0

var _player: Node
var _sprite: Sprite2D
var _passed: bool = false
var _bump_velocity: float = 0.0
var _swerve_started: bool = false

@export var will_swerve: bool = false
@export var swerve_dir: int = 1
@export var swerve_trigger_y: float = 150.0

func _ready() -> void:
	add_to_group("traffic")
	_player = get_tree().get_first_node_in_group("player")
	_sprite = $Sprite2D
	_sprite.texture = load(TEXTURES.get(vehicle_type, TEXTURES["blue"])) as Texture2D
	traffic_speed = float(BASE_SPEEDS.get(vehicle_type, BASE_SPEEDS["blue"])) * stage_speed_multiplier
	monitoring = true
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	area_exited.connect(_on_area_exited)
	if vehicle_type == "truck":
		$CollisionShape2D.shape.size = Vector2(28.0, 80.0)

func _physics_process(delta: float) -> void:
	var player_speed: float = GameState.speed
	global_position.y += (player_speed - traffic_speed) * delta
	global_position.x += _bump_velocity * delta
	_bump_velocity = move_toward(_bump_velocity, 0.0, 220.0 * delta)
	global_position.x = clampf(global_position.x, ROAD_LEFT, ROAD_LEFT + ROAD_WIDTH)
	if vehicle_type == "purple" and will_swerve and not _swerve_started and global_position.y >= swerve_trigger_y:
		_start_swerve()
	if not _passed and global_position.y > PLAYER_Y + 32.0:
		_passed = true
		GameState.score += 50
		GameState.jump_meter += 3.0
	if global_position.y > OFFSCREEN_Y or global_position.y < -160.0:
		queue_free()

func _start_swerve() -> void:
	_swerve_started = true
	var lane: int = int(round((global_position.x - (ROAD_LEFT + 22.0)) / LANE_WIDTH))
	var target_lane: int = clampi(lane + swerve_dir, 0, 3)
	var target_x: float = ROAD_LEFT + 22.0 + LANE_WIDTH * target_lane
	create_tween().tween_property(self, "global_position:x", target_x, 0.45).set_trans(Tween.TRANS_SINE)

func _on_area_entered(area: Area2D) -> void:
	var player: Node = area.get_parent()
	if player.has_method("is_airborne") and player.is_airborne():
		return
	if area.is_in_group("player_hitbox") and area.has_method("receive_traffic_hit"):
		area.call("receive_traffic_hit", self)

func _on_body_entered(body: Node) -> void:
	var player: Node = body
	if player.has_method("is_airborne") and player.is_airborne():
		return

func _on_area_exited(area: Area2D) -> void:
	var player: Node = area.get_parent()
	if player.has_method("is_airborne") and player.is_airborne():
		return

func bump_from_player() -> void:
	var direction: float = signf(global_position.x - ROAD_LEFT - 88.0)
	if is_instance_valid(_player):
		direction = signf(global_position.x - _player.global_position.x)
	if is_zero_approx(direction):
		direction = 1.0
	_bump_velocity = direction * 90.0
	traffic_speed *= 0.6
