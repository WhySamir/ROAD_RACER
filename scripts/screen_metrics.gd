extends Node

## Canvas metrics shared by gameplay and UI.
##
## The project stretches with `canvas_items` / `expand`, so the root viewport
## already reports the real canvas size in design units: 224 wide with extra
## height on tall phones, and extra width on wide screens. Layout code must read
## view_size instead of assuming the 224x400 design rectangle.

signal changed

const BASE_WIDTH: float = 224.0
const BASE_HEIGHT: float = 400.0
const ROAD_WIDTH: float = 176.0
const LANE_WIDTH: float = 44.0
const LANE_CENTER_OFFSET: float = 22.0
const EXTRA_BOTTOM_PADDING: float = 8.0
const MIN_VIEW_WIDTH: float = 160.0
const MIN_VIEW_HEIGHT: float = 320.0

var view_size: Vector2 = Vector2(BASE_WIDTH, BASE_HEIGHT)
var safe_top: float = 0.0
var safe_bottom: float = 0.0
var safe_left: float = 0.0
var safe_right: float = 0.0

func _ready() -> void:
	get_viewport().size_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var visible_size: Vector2 = get_viewport().get_visible_rect().size
	view_size = Vector2(maxf(visible_size.x, MIN_VIEW_WIDTH), maxf(visible_size.y, MIN_VIEW_HEIGHT))
	_update_safe_insets()
	changed.emit()

## Converts the display safe area (screen pixels) into canvas units so HUD and
## controls stay clear of notches, status bars and gesture bars.
func _update_safe_insets() -> void:
	safe_top = 0.0
	safe_bottom = 0.0
	safe_left = 0.0
	safe_right = 0.0
	if not OS.has_feature("mobile"):
		return
	var window_size: Vector2 = Vector2(get_window().size)
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return
	var to_canvas: Vector2 = view_size / window_size
	safe_top = maxf(float(safe_area.position.y), 0.0) * to_canvas.y
	safe_left = maxf(float(safe_area.position.x), 0.0) * to_canvas.x
	safe_right = maxf(window_size.x - float(safe_area.position.x + safe_area.size.x), 0.0) * to_canvas.x
	safe_bottom = maxf(window_size.y - float(safe_area.position.y + safe_area.size.y), 0.0) * to_canvas.y + EXTRA_BOTTOM_PADDING

func road_left() -> float:
	return (view_size.x - ROAD_WIDTH) * 0.5

func lane_center(index: int) -> float:
	return road_left() + LANE_CENTER_OFFSET + LANE_WIDTH * float(index)

func player_y() -> float:
	return minf(view_size.y * 0.72, view_size.y - 80.0)

func controls_top() -> float:
	return view_size.y - safe_bottom - 16.0 - 80.0
