# Hollow Tide – Prototype with Week 3 Assets (Godot 4)

A 2D puzzle-platformer prototype where the player controls the tide.

## How to run
1. Install Godot 4.2+ (https://godotengine.org/download).
2. Open Godot > Import > select `project.godot` in this folder.
3. Press F5 (Play).

## Controls
| Key | Action |
|---|---|
| A / D or Left / Right | Move |
| Space / W / Up | Jump (on land) / swim up (in water) |
| E | Raise tide (Low > Mid > High) |
| Q | Lower tide |
| R | Restart |

## Implemented mechanics
- Character movement, jumping, swimming, breath meter
- Collision detection (terrain, crate, hazards, pickups, exit)
- Tide system with 3 states and limited tide charges
- Buoyancy for a physics crate
- Scoring: pearls (+10), respawn penalty (-5), time/charge bonus on completion
- HUD showing score, pearls, time, tide, charges and breath

## Goal
Collect pearls and reach the exit on top of the tall block. Hint: the wall is
too tall to jump – you need High tide.

## Files
- `main.gd` – level building, tide, buoyancy, scoring, HUD
- `player.gd` – movement, swimming, breath, crate pushing
- `main.tscn`, `project.godot` – scene and project settings

## Week 3 – Game assets
All art and audio were created with the Python scripts in `tools/` and live in `assets/`.

- `assets/art/` – animated player sheet, crate, pearls, urchin, beacon, ground/moss/water tiles, sky and ruined-city background
- `assets/audio/` – 6 sound effects (jump, pearl, splash, tide, hurt, win) and a 32-second looping ambient music track
- `tools/make_art.py` – regenerates all sprites and tiles (needs Pillow)
- `tools/make_audio.py` – regenerates all audio (needs NumPy)
- `asset_util.gd` – helpers that slice sprite sheets into animations and tile textures

To regenerate the assets: `pip install pillow numpy`, then run both scripts from the project folder.
