# Road Racer

A Road Fighter-style arcade racer built with Godot 4 and GDScript, made for portrait mobile
(Android/iOS) first with full desktop keyboard support. Original pixel art, original name.

## Status: PROJECT CLOSED

This project is **archived and no longer under active development**. The final release state is
committed here for reference and for anyone who wants to fork or learn from it. No further
features, bug fixes, or builds are planned.

## Features

- Endless scrolling road with 4 lanes, accelerating traffic (straight, fast, lane-changing),
  trucks, oil slicks and rocks.
- Fuel as the life bar: fuel drains over time and faster at high speed; fuel cans replenish it.
- Signature jump mechanic: a charge meter fills as you drive and grows when you overtake cars,
  then you leap over traffic and hazards.
- Difficulty presets (easy / medium / hard) across fuel and continuous modes, with per-mode
  high-score slots persisted to `user://save.cfg`.
- Full touch control scheme: corner steer buttons, gas/brake pedals, jump button, plus a
  swipe gesture scheme. Multitouch is supported.
- SFX and music via audio buses, haptics on Android, pause on focus loss.

## Responsiveness work (final pass)

The last task was a full responsiveness pass so the game adapts to any phone or tablet:

- `scripts/screen_metrics.gd` (new autoload) owns the live canvas size and converts the display
  safe area into canvas units, so HUD and controls clear notches, status bars and gesture bars.
- Layout is no longer hardcoded to the 224x400 design rectangle. The road, lane centres, player
  position, HUD, main menu and touch controls are all recomputed from the current view size and
  react to viewport resize via the `ScreenMetrics.changed` signal.
- Two control schemes: buttons and swipe, with an on-screen hint overlay, an auto-accelerate
  option persisted in settings, and a pulsing glow on the jump button when a charge is ready.
- Touch button placement is anchored to the bottom corners of the actual canvas instead of the
  design rectangle.

## Running it

1. Open `project.godot` with Godot 4.4 or newer (built and tested against 4.7.2-stable).
2. Run the project. Keyboard controls: arrow keys / A-D to steer, Up / W to accelerate,
   Down / S to brake, Space to jump.

See `AGENTS.md` for the full technical specification and `EXPORT.md` for Android export steps.

## Credits

Everything here — art, audio, code and naming — is original work created for this project.
