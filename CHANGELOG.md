# Changelog – Week 5 (debugging, optimisation, feature enhancement)

Code is annotated with tags so changes are easy to find (search the project for `WEEK5`):

- `[WEEK5-FIX]` bug or soft-lock fix
- `[WEEK5-OPT]` performance optimisation
- `[WEEK5-FEATURE]` feature enhancement

## Fixes
- Gate no longer closes on top of Mira (and uses `AnimatableBody2D`, the correct body type for a script-moved collider).
- Crate can no longer be lost: it resets automatically if it leaves the level, or manually with **C**.
- Running out of tide charges no longer leaves the player stuck: lanterns restore charges, and a hint is shown.

## Optimisations
- `OPTIMIZE` flag in `main.gd` turns all runtime optimisations on or off for before/after measurement.
- Sprite sheets share one `SpriteFrames` resource per animation set (Level 2: 14 -> 6 resources).
- Textures are cached; sound effects use a reusable player pool; the HUD text is rebuilt 10 times per second.
- No buoyancy force is applied to a dry crate so the physics engine can put it to sleep.
- Assets: sound effects 44.1 -> 22.05 kHz, music 22.05 -> 16 kHz, PNGs losslessly recompressed (-32.5 % total size).

## Features
- Coyote time, jump buffering and variable jump height.
- **M** mute, **C** reset crate, **F3** live performance overlay, **F4** 10-second benchmark saved to a text file.
- Lanterns restore tide charges.
