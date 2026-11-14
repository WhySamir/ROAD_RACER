extends Node

signal fuel_changed(value: float)
signal speed_changed(value: float)
signal score_changed(value: int)
signal game_over
signal jump_meter_changed(value: float)
signal jump_charges_changed(value: int)
signal distance_changed(value: float)
signal stage_changed(value: int)
signal phase_changed(value: String)
signal countdown_changed(value: int)
signal best_score_changed(value: int)
signal camera_shake_requested(amount: float)
signal selection_changed
signal lives_changed(lives: int, max_lives: int)
signal extra_life_gained(value: int)

const SAVE_PATH: String = "user://save.cfg"
const SETTINGS_SECTION: String = "settings"
const SCORES_SECTION: String = "scores"
const LEGACY_SECTION: String = "score"
const LEGACY_KEY: String = "high_score"
const LEGACY_TARGET_SLOT: String = "medium_fuel"
const MAX_LIVES: int = 3
const START_LIVES: int = 3
const MAX_JUMP_CHARGES: int = 5

## Touch control schemes.
enum ControlScheme { SWIPE, BUTTONS }
## Which thumb the gas/brake buttons belong to.
enum HandSide { RIGHT, LEFT }

const ALL_LEVELS: Array = [
	DifficultyConfig.Level.EASY,
	DifficultyConfig.Level.MEDIUM,
	DifficultyConfig.Level.HARD,
]
const ALL_MODES: Array = [
	DifficultyConfig.Mode.FUEL,
	DifficultyConfig.Mode.CONTINUOUS,
]

var level: DifficultyConfig.Level = DifficultyConfig.Level.MEDIUM
var mode: DifficultyConfig.Mode = DifficultyConfig.Mode.FUEL
var muted: bool = false
var auto_accelerate: bool = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
var seen_swipe_hint: bool = false
var control_scheme: ControlScheme = ControlScheme.BUTTONS
var hand_side: HandSide = HandSide.RIGHT
var high_score: int = 0
var game_over_new_best: bool = false

## Per-slot bests, keyed by "<level>_<mode>" (easy_fuel, medium_fuel, ...).
var bests: Dictionary = {}

var speed: float = 0.0:
	set(value):
		speed = maxf(value, 0.0)
		speed_changed.emit(speed)
var fuel: float = 100.0:
	set(value):
		fuel = clampf(value, 0.0, 100.0)
		fuel_changed.emit(fuel)

var score: int = 0:
	set(value):
		score = maxi(value, 0)
		score_changed.emit(score)

var distance: float = 0.0
var stage: int = 1
var game_phase: String = "MENU"
var lives: int = START_LIVES

var jump_meter: float = 0.0:
	set(value):
		jump_meter = clampf(value, 0.0, 100.0)
		jump_meter_changed.emit(jump_meter)
var jump_charges: int = 0

func _ready() -> void:
	var existed: bool = _load_from_disk()
	if not existed:
		# First run: create the save file so settings and scores have a home.
		_save_to_disk()
	_sync_high_score()

func set_level(value: DifficultyConfig.Level) -> void:
	if level == value:
		return
	level = value
	_save_to_disk()
	_sync_high_score()
	selection_changed.emit()

func set_mode(value: DifficultyConfig.Mode) -> void:
	if mode == value:
		return
	mode = value
	_save_to_disk()
	_sync_high_score()
	selection_changed.emit()

func set_muted(value: bool) -> void:
	if muted == value:
		return
	muted = value
	_save_to_disk()

## Switches between the swipe and button control schemes.
func set_control_scheme(value: ControlScheme) -> void:
	if control_scheme == value:
		return
	control_scheme = value
	_save_to_disk()
	selection_changed.emit()

## Moves the gas/brake buttons to the left or right thumb.
func set_hand_side(value: HandSide) -> void:
	if hand_side == value:
		return
	hand_side = value
	_save_to_disk()
	selection_changed.emit()

func set_auto_accelerate(value: bool) -> void:
	auto_accelerate = value
	_save_to_disk()

func set_seen_swipe_hint(value: bool) -> void:
	if seen_swipe_hint == value:
		return
	seen_swipe_hint = value
	_save_to_disk()

func get_preset() -> Dictionary:
	return DifficultyConfig.get_preset(level)

func is_fuel_mode() -> bool:
	return mode == DifficultyConfig.Mode.FUEL

func score_multiplier() -> float:
	return float(get_preset().get("score_mult", 1.0))

func jump_fill_multiplier() -> float:
	return float(get_preset().get("jump_fill_mult", 1.0))

## Adds score after applying the current difficulty score multiplier.
func add_score(base_amount: int) -> void:
	score += int(round(float(base_amount) * score_multiplier()))

## Adds jump meter after applying the current difficulty jump fill multiplier.
func add_jump_meter(base_amount: float) -> void:
	if jump_charges >= MAX_JUMP_CHARGES:
		jump_meter = 100.0
		return
	var fill_amount: float = base_amount * jump_fill_multiplier()
	var accumulated: float = jump_meter + fill_amount
	while accumulated >= 100.0 and jump_charges < MAX_JUMP_CHARGES:
		accumulated -= 100.0
		jump_charges += 1
		jump_charges_changed.emit(jump_charges)
	if jump_charges >= MAX_JUMP_CHARGES:
		jump_meter = 100.0
	else:
		jump_meter = accumulated

func consume_jump_charge() -> bool:
	if jump_charges <= 0:
		return false
	jump_charges -= 1
	jump_charges_changed.emit(jump_charges)
	jump_meter = 0.0
	return true

func lose_life() -> void:
	if not is_fuel_mode() or game_phase == "GAME_OVER":
		return
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives, MAX_LIVES)
	if lives <= 0:
		set_game_over()

func add_life() -> void:
	if not is_fuel_mode() or lives >= MAX_LIVES:
		return
	lives += 1
	lives_changed.emit(lives, MAX_LIVES)
	extra_life_gained.emit(lives)

func set_game_over() -> void:
	if game_phase == "GAME_OVER":
		return
	game_over_new_best = submit_score(score, int(distance))
	game_phase = "GAME_OVER"
	phase_changed.emit(game_phase)
	game_over.emit()

func reset_game() -> void:
	speed = 0.0
	fuel = 100.0
	score = 0
	jump_meter = 0.0
	jump_charges = 0
	jump_charges_changed.emit(jump_charges)
	distance = 0.0
	stage = 1
	lives = 3
	game_over_new_best = false
	lives_changed.emit(lives, MAX_LIVES)
	distance_changed.emit(distance)
	stage_changed.emit(stage)
	best_score_changed.emit(high_score)

func set_phase(value: String) -> void:
	game_phase = value
	phase_changed.emit(game_phase)

func request_camera_shake(amount: float) -> void:
	camera_shake_requested.emit(amount)

## Records a result for the current level+mode. Returns true when it is a new best.
func submit_score(submitted_score: int, submitted_distance_m: int) -> bool:
	var slot: String = current_slot_key()
	var entry: Dictionary = bests.get(slot, {"score": 0, "distance_m": 0})
	if submitted_score <= int(entry.get("score", 0)):
		return false
	bests[slot] = {"score": submitted_score, "distance_m": submitted_distance_m}
	_save_to_disk()
	_sync_high_score()
	return true

## Best result for a given level+mode pair.
func get_best(best_level: DifficultyConfig.Level, best_mode: DifficultyConfig.Mode) -> Dictionary:
	var entry: Dictionary = bests.get(_slot_key(best_level, best_mode), {"score": 0, "distance_m": 0})
	return {"score": int(entry.get("score", 0)), "distance_m": int(entry.get("distance_m", 0))}

func reset_scores() -> void:
	bests.clear()
	_save_to_disk()
	_sync_high_score()

func current_slot_key() -> String:
	return _slot_key(level, mode)

func _slot_key(slot_level: DifficultyConfig.Level, slot_mode: DifficultyConfig.Mode) -> String:
	var level_key: String = DifficultyConfig.level_name(slot_level).to_lower()
	var mode_key: String = DifficultyConfig.mode_name(slot_mode).to_lower()
	return "%s_%s" % [level_key, mode_key]

func _sync_high_score() -> void:
	high_score = int(get_best(level, mode).get("score", 0))
	best_score_changed.emit(high_score)

## Returns true when a save file was found and loaded.
func _load_from_disk() -> bool:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(SAVE_PATH)
	if error != OK:
		# A missing file simply means no save exists yet.
		if error != ERR_FILE_NOT_FOUND:
			push_warning("GameState: failed to load %s (error %d)" % [SAVE_PATH, error])
		return false
	level = _level_from_index(int(config.get_value(SETTINGS_SECTION, "level", 1)))
	mode = _mode_from_index(int(config.get_value(SETTINGS_SECTION, "mode", 0)))
	muted = bool(config.get_value(SETTINGS_SECTION, "muted", false))
	auto_accelerate = bool(config.get_value(SETTINGS_SECTION, "auto_accelerate", OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()))
	seen_swipe_hint = bool(config.get_value(SETTINGS_SECTION, "seen_swipe_hint", false))
	control_scheme = _control_scheme_from_index(int(config.get_value(SETTINGS_SECTION, "control_scheme", -1)))
	hand_side = _hand_side_from_index(int(config.get_value(SETTINGS_SECTION, "hand_side", int(HandSide.RIGHT))))
	for slot_level: DifficultyConfig.Level in ALL_LEVELS:
		for slot_mode: DifficultyConfig.Mode in ALL_MODES:
			var slot: String = _slot_key(slot_level, slot_mode)
			bests[slot] = {
				"score": int(config.get_value(SCORES_SECTION, "%s_score" % slot, 0)),
				"distance_m": int(config.get_value(SCORES_SECTION, "%s_dist" % slot, 0)),
			}
	_migrate_legacy_save(config)
	return true

func _save_to_disk() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SETTINGS_SECTION, "level", int(level))
	config.set_value(SETTINGS_SECTION, "mode", int(mode))
	config.set_value(SETTINGS_SECTION, "muted", muted)
	config.set_value(SETTINGS_SECTION, "auto_accelerate", auto_accelerate)
	config.set_value(SETTINGS_SECTION, "seen_swipe_hint", seen_swipe_hint)
	config.set_value(SETTINGS_SECTION, "control_scheme", int(control_scheme))
	config.set_value(SETTINGS_SECTION, "hand_side", int(hand_side))
	for slot_level: DifficultyConfig.Level in ALL_LEVELS:
		for slot_mode: DifficultyConfig.Mode in ALL_MODES:
			var slot: String = _slot_key(slot_level, slot_mode)
			var entry: Dictionary = bests.get(slot, {"score": 0, "distance_m": 0})
			config.set_value(SCORES_SECTION, "%s_score" % slot, int(entry.get("score", 0)))
			config.set_value(SCORES_SECTION, "%s_dist" % slot, int(entry.get("distance_m", 0)))
	var error: Error = config.save(SAVE_PATH)
	if error != OK:
		push_warning("GameState: failed to save %s (error %d)" % [SAVE_PATH, error])

## Moves the old single "high_score" value into the medium/fuel slot exactly once.
func _migrate_legacy_save(config: ConfigFile) -> void:
	if not config.has_section(LEGACY_SECTION):
		return
	if not config.has_section_key(LEGACY_SECTION, LEGACY_KEY):
		return
	var legacy_score: int = int(config.get_value(LEGACY_SECTION, LEGACY_KEY, 0))
	var legacy_entry: Dictionary = bests.get(LEGACY_TARGET_SLOT, {"score": 0, "distance_m": 0})
	if legacy_score > int(legacy_entry.get("score", 0)):
		bests[LEGACY_TARGET_SLOT] = {"score": legacy_score, "distance_m": 0}
	config.erase_section_key(LEGACY_SECTION, LEGACY_KEY)
	_save_to_disk()

func _level_from_index(value: int) -> DifficultyConfig.Level:
	match value:
		0:
			return DifficultyConfig.Level.EASY
		2:
			return DifficultyConfig.Level.HARD
		_:
			return DifficultyConfig.Level.MEDIUM

func _mode_from_index(value: int) -> DifficultyConfig.Mode:
	if value == 1:
		return DifficultyConfig.Mode.CONTINUOUS
	return DifficultyConfig.Mode.FUEL

## Defaults to SWIPE on mobile and BUTTONS everywhere else.
func _control_scheme_from_index(value: int) -> ControlScheme:
	if value == int(ControlScheme.SWIPE):
		return ControlScheme.SWIPE
	if value == int(ControlScheme.BUTTONS):
		return ControlScheme.BUTTONS
	return ControlScheme.SWIPE if OS.has_feature("mobile") else ControlScheme.BUTTONS

func _hand_side_from_index(value: int) -> HandSide:
	if value == int(HandSide.LEFT):
		return HandSide.LEFT
	return HandSide.RIGHT
