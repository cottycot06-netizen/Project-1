# Cosmic Horror — Turn-Based Roguelike

A single-player, turn-based cosmic-horror roguelike built in **Godot 4** (GDScript).
Design notes and decisions live in [`GAME_NOTES.md`](GAME_NOTES.md).

## Current status: Combat MVP

The first playable slice is a **1-vs-1 turn-based fight** against a Zombie that
exercises the core systems:

- **You always act first**, then the enemy — looping until one side falls.
- **HP** — reach 0 and you die.
- **Sanity** — a *second* health bar (reach 0 and you also die) that:
  - drains every turn *after* a 2-turn grace period,
  - refills when a **basic Attack** lands (+3),
  - is spent by **Frenzied Strike** (−5) — a skill paid with sanity gives **no** refill.
- Actions: **Attack**, **Frenzied Strike**, **Bandage** (heal HP, ×2), **Flee** (50%).

## How to run

1. Install [Godot 4.2+](https://godotengine.org/download) (standard build, not .NET).
2. Open Godot → **Import** → select this folder's `project.godot`.
3. Press **F5** (Play). The combat scene launches directly.

## Project layout

```
project.godot              # Godot project config (main scene = combat)
icon.svg
scenes/combat/Combat.tscn  # tiny scene; UI is built in code
scenes/combat/Combat.gd    # combat controller, turn loop, sanity rules, UI
scripts/entities/combatant.gd  # fighter data + HP/Sanity logic
GAME_NOTES.md              # full design document
```

## Next steps

See the "Next steps" ideas in `GAME_NOTES.md` — exploration mode (16-bit
top-down), the starter wooden crate, enemy loot drops, and more enemies.
