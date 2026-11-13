extends Area2D

const SCORE_VALUE: int = 100
const OFFSCREEN_Y: float = 460.0

func _ready() -> void:
	add_to_group("pickup")
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	global_position.y += GameState.speed * delta
	if global_position.y > OFFSCREEN_Y:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox") and GameState.game_phase == "PLAYING":
		GameState.fuel = 100.0
		GameState.add_score(SCORE_VALUE)
		AudioManager.play(&"pickup", 0.0, 0.03)
		queue_free()
