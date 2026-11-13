class_name DifficultyConfig
extends RefCounted

## Data layer for the main menu difficulty settings.
## Holds pure data + lookup helpers only, no gameplay logic and no UI.

enum Level { EASY, MEDIUM, HARD }
enum Mode { FUEL, CONTINUOUS }

const LEVEL_NAMES: Dictionary = {
	Level.EASY: "EASY",
	Level.MEDIUM: "MEDIUM",
	Level.HARD: "HARD",
}

const MODE_NAMES: Dictionary = {
	Mode.FUEL: "FUEL",
	Mode.CONTINUOUS: "CONTINUOUS",
}

## Returns the tuning preset for a level.
## Keys: spawn_interval, min_gap_px, swerver_chance, fuel_drain_pct_s, fuel_pickup_pct,
##       oil_start_stage, rock_start_stage, stage_length_m, score_mult, jump_fill_mult
static func get_preset(level: Level) -> Dictionary:
	match level:
		Level.EASY:
			return {
				"spawn_interval": 1.3,
				"min_gap_px": 130.0,
				"swerver_chance": 0.10,
				"fuel_drain_pct_s": 1.3,
				"fuel_pickup_pct": 30.0,
				"oil_start_stage": 3,
				"rock_start_stage": 5,
				"stage_length_m": 1200.0,
				"score_mult": 1.0,
				"jump_fill_mult": 1.3,
			}
		Level.HARD:
			return {
				"spawn_interval": 0.75,
				"min_gap_px": 85.0,
				"swerver_chance": 0.35,
				"fuel_drain_pct_s": 2.0,
				"fuel_pickup_pct": 20.0,
				"oil_start_stage": 1,
				"rock_start_stage": 2,
				"stage_length_m": 1800.0,
				"score_mult": 2.0,
				"jump_fill_mult": 0.8,
			}
		_:
			return {
				"spawn_interval": 1.0,
				"min_gap_px": 100.0,
				"swerver_chance": 0.20,
				"fuel_drain_pct_s": 1.6,
				"fuel_pickup_pct": 25.0,
				"oil_start_stage": 2,
				"rock_start_stage": 3,
				"stage_length_m": 1500.0,
				"score_mult": 1.5,
				"jump_fill_mult": 1.0,
			}

static func level_name(level: Level) -> String:
	return String(LEVEL_NAMES.get(level, LEVEL_NAMES[Level.MEDIUM]))

static func mode_name(mode: Mode) -> String:
	return String(MODE_NAMES.get(mode, MODE_NAMES[Mode.FUEL]))
