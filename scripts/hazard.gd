extends Area2D

const OFFSCREEN_Y: float = 460.0

@export var hazard_type: String = "oil"

func _ready() -> void:
	add_to_group("hazard")
	area_entered.connect(_on_area_entered)
	if hazard_type == "rock":
		$Sprite2D.texture = load("res://assets/hazard_rock.png") as Texture2D

func _physics_process(delta: float) -> void:
	global_position.y += GameState.speed * delta
	if global_position.y > OFFSCREEN_Y:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player_hitbox"):
		return
	var player: Node = area.get_parent()
	if player.has_method("is_airborne") and player.is_airborne():
		return
	if player.has_method("receive_hazard_hit"):
		player.call("receive_hazard_hit", self)
		queue_free()
