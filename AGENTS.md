# PROJECT: "Road Racer" — a Road Fighter-style arcade racer (original art, original name)

## Local Godot executable

- Godot console executable: `C:\Users\Dell\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`

## Target

- Godot 4.4+ (stable), GDScript 2.0, STRICT typing everywhere (`var x: float`, `func f(a: int) -> void`).
- No Godot 3 syntax (no `onready var` without @, no `export`, no `yield`, no `connect("sig", obj, "fn")`). Use @export, @onready, await, Signal.connect(callable).
- PORTRAIT MOBILE FIRST (Android/iOS), also playable on desktop with keyboard.
- Renderer: Compatibility. Viewport 224x400, stretch mode `canvas_items`, aspect `expand`, orientation portrait,
  default texture filter = Nearest (pixel-perfect). Emulate touch from mouse ON for desktop testing.

## Z-Index Layering

- Grass = -2, Road = -1, Pickups = 0, Player & Traffic Cars = 10, Effects/Particles = 20, HUD = CanvasLayer.

## Current status — Task 1 (driving skeleton) complete

### Working file structure

```
res://
project.godot            # 224x400 portrait, canvas_items/expand, gl_compatibility, nearest filter,
                         # InputMap: steer_left/steer_right/accelerate/brake/jump, GameState autoload
AGENTS.md
assets/                  # pixel art (cars, tiles, hazards, pickups, shadow)
scenes/
  main.tscn              # RoadScroller (road + grass stacks) + Player
  player.tscn            # CharacterBody2D, car_player_red at scale 2, z_index 10
scripts/
  game_state.gd          # Autoload "GameState": fuel/speed/score/high score + signals
  difficulty_config.gd   # class_name DifficultyConfig: Level/Mode enums + tuning presets
  player.gd              # accel/brake/coast, steering, off-road slowdown, shake
  road_scroller.gd       # stacked whole-tprite tile looping (no region_rect, no texture_repeat)
```

### Difficulty data layer (Task 6A)

- `DifficultyConfig.Level` = EASY / MEDIUM / HARD, `DifficultyConfig.Mode` = FUEL / CONTINUOUS.
- `DifficultyConfig.get_preset(level)` returns the tuning dictionary; `GameState.get_preset()` returns the current level's preset.
- Preset keys: `spawn_interval`, `min_gap_px`, `swerver_chance`, `fuel_drain_pct_s`, `fuel_pickup_pct`,
  `oil_start_stage`, `rock_start_stage`, `stage_length_m`, `score_mult`, `jump_fill_mult`.
- All gameplay tunables read from `GameState.get_preset()`; MEDIUM is the reference baseline that reproduces the
  pre-Task-6A behaviour exactly (other levels scale off it via `_relative_factor`).
- Score gains go through `GameState.add_score()` (applies `score_mult`) and jump meter through
  `GameState.add_jump_meter()` (applies `jump_fill_mult`).
- High scores: one slot per (level, mode) = 6 slots, stored in `user://save.cfg` under `[scores]` as
  `<level>_<mode>_score` / `<level>_<mode>_dist`. Selection lives in `[settings]` as `level` / `mode`.
- The old single `high_score` value migrates once into the medium/fuel slot.

### Road X boundaries

- Viewport width = 224, road width = 176.
- `road_x = (224.0 - 176.0) / 2.0 = 24.0`
- Road spans x = 24 to x = 200; left grass x = 0 to 24, right grass x = 200 to 224 (symmetrical).
- Lane centers: 46, 90, 134, 178 (road_x + 22 + 44*i).
- Player off-road bounds use the exact inner road edges: `ROAD_LEFT = 24.0`, `ROAD_RIGHT = 200.0`.
- Player stays fixed at y = 310; the world scrolls downward.

### Z-index layers

| Layer | z_index |
| --- | --- |
| Grass tiles | -2 |
| Road tiles | -1 |
| Pickups | 0 |
| Player / Traffic cars | 10 |
| Effects / Particles | 20 |
| HUD | CanvasLayer |

## Assets (already in res://assets/, all pixel art, face UP, draw with Sprite2D scale (2,2), filter nearest)

car_player_red, car_blue, car_yellow, car_green, car_purple, car_white (14x26), truck_orange (14x40),
pickup_fuel, hazard_oil, hazard_rock, shadow, tile_road (176x64, 4 lanes x 44px, tiles vertically), tile_grass (64x64).
Road is 176px wide centered in the 224px viewport (24px grass each side). Lane centers x = 68, 112, 156, 200 minus...
(compute from road left edge = 24: lane centers = 24 + 22 + 44\*i).
NEVER require external art beyond these; if something is missing, draw it with \_draw().

## Architecture (create exactly these; keep files small and single-purpose)

res://
project.godot
scenes/main.tscn # Main: World + HUD + TouchControls + GameManager
scenes/player.tscn # CharacterBody2D (player.gd)
scenes/traffic_car.tscn # Area2D (traffic_car.gd)
scenes/pickup.tscn # Area2D (pickup.gd) fuel can
scenes/hazard.tscn # Area2D (hazard.gd) oil / rock
scenes/hud.tscn # CanvasLayer (hud.gd)
scenes/touch_controls.tscn # CanvasLayer (touch_controls.gd)
scripts/game_manager.gd # state machine + spawner + difficulty + scoring
scripts/player.gd
scripts/traffic_car.gd
scripts/pickup.gd
scripts/hazard.gd
scripts/road_scroller.gd # endless road + grass scrolling
scripts/hud.gd
scripts/touch_controls.gd
scripts/game_state.gd # Autoload "GameState": signals + high score (user://save.cfg)

## Coordinate / scroll model

- The PLAYER stays at a fixed y (~310). The WORLD scrolls DOWN. `GameManager.scroll_speed` (px/s) = player's forward speed.
- Traffic has its own forward speed v_t (< player's max). On-screen velocity.y = (player_speed - v_t).
  So slower cars move down the screen, cars faster than the player drift up.
- Distance (m) = accumulated player_speed \* delta / 10.

## Player rules (player.gd, CharacterBody2D, move manually, no physics collisions)

- Forward speed: accelerate 140 px/s², brake 360 px/s², coast decel 60 px/s². Max speed 420 (LOW gear cap 260 when not boosting).
- Steering: horizontal speed 150 px/s, with smoothing (lerp), steering strength scales with speed (can't steer at speed 0).
- Off-road (x outside the road edges): max speed capped at 45%, screen rumble, small sprite wobble. Clamp x inside grass bounds.
- Input: use InputMap actions: steer_left, steer_right, accelerate, brake, jump. Touch controls must emit the SAME actions
  via Input.action_press/release so player.gd only reads Input.get_axis / is_action_pressed.
- States (enum State { DRIVING, SPINNING, JUMPING, DEAD }).

## Collisions (Area2D hitbox on player; layers: 1 player, 2 traffic, 3 pickups, 4 hazards)

- SIDE-SWIPE (overlap mostly horizontal, |dy| < 70% of car height): player enters SPINNING for 1.0s —
  rotates 720° via Tween, speed drops to 30%, pushed sideways away from the other car, then 1.5s INVULNERABLE
  (sprite blinks at 12Hz, hitbox ignores traffic/hazards). Fuel -5%.
- REAR-END / HEAD-ON (|dy| large): hard crash — speed -> 0, fuel -12%, 1.5s invulnerable, small shake. Third-... no lives; fuel is the life bar.
- Oil puddle: spin-out like side-swipe but no push. Rock: hard crash.
- Traffic car hit by player also gets bumped sideways and slows briefly (no destruction).

## JUMP (signature mechanic)

- Jump meter 0..100 fills with distance driven (full at ~250 m of driving; faster when overtaking cars: +3 per car passed).
- When full: JUMP button glows. Pressing jump (or Space/Up) starts State.JUMPING for 1.1s.
- Visual: car sprite scale 2.0 -> 2.9 -> 2.0 (sine ease), `shadow` sprite stays on the ground and shrinks/fades, speed is kept.
- While airborne: hitbox ignores traffic, oil and rocks (can fly over), cannot collect fuel, steering at 60%.
- LANDING: when state ends, if the hitbox overlaps a traffic car or rock => treat as hard crash. Otherwise play landing
  squash tween (scale y 0.85 -> 1) and small camera shake. Meter resets to 0.

## Fuel (the "timer")

- Start 100%. Depletes 1.6%/s base, + extra when above 300 speed. Pickup: +25% (cap 100). When fuel hits 0: coast to stop, GAME OVER.
- Fuel can pickups spawn every ~8-14s in a random lane; they scroll down with the world.

## Traffic & difficulty (GameManager)

- Spawner picks a random lane, keeps minimum vertical gap (>= 90px) and NEVER fills all 4 lanes in a row (always a free path).
- Types: blue (slow, straight), yellow (medium, straight), green (fast), purple (swerves: changes lane once with a smooth tween when
  the player gets within 140px behind it), white (random), truck_orange (slow, long hitbox).
- Stage = every 1500 m. Each stage: +8% traffic density, +6% traffic speed, adds hazards (oil from stage 2, rocks from stage 3).
- Score = distance + 50 per overtaken car + 100 per fuel pickup. High score persisted.

## Game flow

MENU (tap to start) -> COUNTDOWN 3-2-1 -> PLAYING -> GAME_OVER (score, best, "TAP TO RETRY"). Pause on app focus loss.

## HUD

Top: SCORE, BEST, DIST m. Left vertical bar: FUEL (color shifts green->yellow->red, flashes under 20%). Right: SPEED km/h
(speed/2.2) and JUMP meter bar. Draw with Control nodes/\_draw, font = default theme font, size 8-10, Nearest filter.

## Touch controls (portrait, thumbs):

- Bottom-left: LEFT and RIGHT buttons (each ~56x56 px, semi-transparent).
- Bottom-right: big JUMP button (64px) with glow when ready, plus GAS (hold) above it and BRAKE to its left.
- Support multitouch (steer + gas + jump simultaneously). Use TouchScreenButton or InputEventScreenTouch tracking by index.
- Optional setting: auto-accelerate ON by default for mobile.

## Code quality rules

- Constants in UPPER_SNAKE_CASE at the top of each script; tunables as @export with sensible defaults and @export_group.
- Use signals (GameState.fuel_changed, speed_changed, score_changed, game_over, jump_meter_changed); no get_node("../../..") chains.
- Use groups ("traffic", "pickup", "hazard") and object pooling or queue_free() off-screen.
- No magic numbers inside functions; comment non-obvious math in one line.
- After EVERY change run: `godot --headless --path . --quit` (or `--check-only` on scripts) and fix all parse/type errors
  before reporting done. Do not refactor files unrelated to the current task.
