# Hollow Tide – Prototype (Godot 4): mechanics, assets and levels

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

## Week 4 – Level design and environment
Two complete levels are playable (switch with the **1** and **2** keys, or press **N** after finishing a level):

1. **Shallows of Veyra** – tutorial level that teaches tide control and swimming.
2. **The Market Quarter** – longer level with a pressure-plate gate puzzle, a patrolling eel,
   a checkpoint lantern, story murals, market-stall platforms and an aqueduct that needs High tide.

New interactive elements: pressure plate + iron gate, patrolling eel, checkpoint lantern, story murals,
level switching. New environment art: eel, lantern, mural, gate, plate, stall awning, seaweed, pillar, bubble.

Level blueprint (maps, interactive elements, playtest notes): see the Week 4 level design document.

## Week 5 - debugging and optimisation
See `CHANGELOG.md`. Press **F3** in the game for live statistics and **F4** for a 10-second benchmark
(saved in the project's user data folder). Set `OPTIMIZE` to `false` in `main.gd` to measure the "before" state.
