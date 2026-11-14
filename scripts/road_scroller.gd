extends Node2D

const ROAD_WIDTH: float = 176.0
const EXTRA_BUFFER_TILES: int = 2
const SHAKE_AMOUNT: float = 1.5

@onready var _road: Sprite2D = $Road
@onready var _grass_left: Sprite2D = $GrassLeft
@onready var _grass_right: Sprite2D = $GrassRight

var _road_tiles: Array[Sprite2D] = []
var _grass_left_tiles: Array[Sprite2D] = []
var _grass_right_tiles: Array[Sprite2D] = []
var _road_positions: Array[float] = []
var _grass_left_positions: Array[float] = []
var _grass_right_positions: Array[float] = []
var _road_total_height: float = 0.0
var _grass_total_height: float = 0.0
var _player: Node
var _shake_timer: float = 0.0
var _shake_amount: float = 0.0

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	GameState.camera_shake_requested.connect(_on_camera_shake_requested)
	_road.position.x = ScreenMetrics.road_left()
	_grass_left.position.x = 0.0
	_grass_right.position.x = ScreenMetrics.road_left() + ROAD_WIDTH
	_road.z_index = -1
	_grass_left.z_index = -2
	_grass_right.z_index = -2
	ScreenMetrics.changed.connect(_on_screen_changed)
	_on_screen_changed()

func _on_screen_changed() -> void:
	_road.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_grass_left.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_grass_right.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_road.position.x = ScreenMetrics.road_left()
	_grass_left.position.x = 0.0
	_grass_right.position.x = ScreenMetrics.road_left() + ROAD_WIDTH
	_clear_stacks()
	_road_total_height = _setup_stack(_road, _road_tiles, _road_positions, ROAD_WIDTH)
	_grass_total_height = _setup_stack(_grass_left, _grass_left_tiles, _grass_left_positions, ScreenMetrics.road_left())
	_setup_stack(_grass_right, _grass_right_tiles, _grass_right_positions, maxf(ScreenMetrics.view_size.x - ScreenMetrics.road_left() - ROAD_WIDTH, 0.0))

func _clear_stacks() -> void:
	for tiles: Array[Sprite2D] in [_road_tiles, _grass_left_tiles, _grass_right_tiles]:
		for tile: Sprite2D in tiles:
			if tile != _road and tile != _grass_left and tile != _grass_right:
				tile.queue_free()
		tiles.clear()
	_road_positions.clear()
	_grass_left_positions.clear()
	_grass_right_positions.clear()

func _process(delta: float) -> void:
	var distance: float = GameState.speed * delta
	_advance_stack(_road_tiles, _road_positions, _road_total_height, distance)
	_advance_stack(_grass_left_tiles, _grass_left_positions, _grass_total_height, distance)
	_advance_stack(_grass_right_tiles, _grass_right_positions, _grass_total_height, distance)

	var is_off_road: bool = false
	if is_instance_valid(_player):
		is_off_road = bool(_player.get("is_off_road"))
	if _shake_timer > 0.0:
		_shake_timer -= delta
	var shake: float = _shake_amount if _shake_timer > 0.0 else (SHAKE_AMOUNT if is_off_road else 0.0)
	position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if shake > 0.0 else Vector2.ZERO

func _on_camera_shake_requested(amount: float) -> void:
	_shake_amount = amount
	_shake_timer = 0.16

func _setup_stack(source: Sprite2D, tiles: Array[Sprite2D], positions: Array[float], width: float) -> float:
	source.region_enabled = true
	source.centered = false
	var tile_height: int = source.texture.get_height()
	source.region_rect = Rect2(0.0, 0.0, width, float(tile_height))
	var count: int = ceili((ScreenMetrics.view_size.y + float(tile_height)) / float(tile_height)) + EXTRA_BUFFER_TILES
	var total_height: float = float(count * tile_height)
	for index: int in count:
		var tile: Sprite2D = source if index == 0 else source.duplicate() as Sprite2D
		if index > 0:
			add_child(tile)
		tile.region_enabled = true
		tile.centered = false
		tile.region_rect = Rect2(0.0, 0.0, width, float(tile_height))
		var tile_y: float = -float(tile_height) + float(index * tile_height)
		tile.position.y = roundf(tile_y)
		tiles.append(tile)
		positions.append(tile_y)
	return total_height

func _advance_stack(tiles: Array[Sprite2D], positions: Array[float], total_height: float, distance: float) -> void:
	for index: int in tiles.size():
		positions[index] += distance
		var wrap_y: float = ScreenMetrics.view_size.y + float(source_tile_height(tiles[index]))
		while positions[index] >= wrap_y:
			positions[index] -= total_height
		tiles[index].position.y = roundf(positions[index])

func source_tile_height(tile: Sprite2D) -> int:
	return tile.texture.get_height()
