# BOUNCE BACK  (Godot 4.3+, GDScript)

## Run it
1. Godot 4.3 or newer (Forward+ or Mobile renderer recommended for the neon glow).
2. Project Manager -> Import -> select `project.godot` -> Run (F5). Main scene is `menu.tscn`.

## Controls
| Key | Action |
|---|---|
| A / Left | Move left |
| D / Right | Move right |
| Space (also W / Up) | Extra jump (once per bounce) |
| Esc (or P) | Pause |
| R | Restart level |

Input Map actions (`move_left, move_right, jump, pause, restart`) are registered in
`game.gd -> _register_inputs()` so nothing needs to be set up by hand.

## Files and where each script is attached
| File | Attached to / role |
|---|---|
| `game.gd` | Autoload singleton `Game` (Project Settings -> Autoload, already set). Save data, volumes, procedural SFX + music, scene fade, UI helpers |
| `menu.tscn` + `menu.gd` | Root `Menu` (Control). Main menu, level select, settings |
| `level.tscn` + `level.gd` | Root `Level` (Node2D). Builds the level at runtime |
| `player.gd` | `Player` (CharacterBody2D) - created by level.gd |
| `platform.gd` | `NeonPlatform` (AnimatableBody2D): static / moving / disappearing / falling |
| `hazard.gd` | `Hazard` (Area2D): spike, sliding spike, rotor, laser, patrolling enemy |
| `pickup.gd` | `Pickup` (Area2D): coin, checkpoint, finish portal |
| `hud.gd` | `Hud` (CanvasLayer): score bar, pause menu, level-complete screen |
| `background.gd` | `NeonBackground` (Node2D): gradient, stars, drifting shapes |
| `level_gen.gd` | `LevelGen`: deterministic data for all 10 levels |

Reusable "scenes" are script classes that build their own nodes, so there are no
hand-edited .tscn files that can have broken references.

## Runtime scene hierarchy (Level)
```
Level (Node2D)
├─ CanvasLayer (layer -10)
│  └─ NeonBackground
├─ WorldEnvironment            (glow)
├─ World (Node2D)
│  ├─ NeonPlatform ...         (AnimatableBody2D > CollisionShape2D [+ Area2D trigger])
│  ├─ Hazard ...               (Area2D > CollisionShape2D)
│  └─ Pickup ...               (Area2D > CollisionShape2D)
├─ Player (CharacterBody2D)
│  ├─ CollisionShape2D
│  ├─ CPUParticles2D           (trail)
│  └─ Camera2D
└─ Hud (CanvasLayer, layer 10)
```

## Collision layers
| Layer | Name | Used by | Mask |
|---|---|---|---|
| 1 | world | platforms | - |
| 2 | player | Player | 1 |
| 3 | hazards | Hazard | 2 |
| 4 | coins | coins | 2 |
| 5 | checkpoint/goal | checkpoints, portal | 2 |

## Levels
1 First Bounce (tutorial) · 2 Moving platforms · 3 Spikes and gaps · 4 Moving obstacles ·
5 Disappearing platforms · 6 Lasers · 7 Difficult jumps (narrow, falling platforms) ·
8 Multiple hazards · 9 Extreme · 10 Final level with the portal.
Levels are generated from a fixed seed, so each is identical on every run.
Level N+1 unlocks when you finish level N. Progress and best scores are saved to
`user://bounce_back.cfg`.

## Scoring
coins x 100 + enemy stomps x 50 + time bonus (under 90 s) - deaths x 25.

## Tuning
Physics constants are at the top of `player.gd` (gravity, bounce, move speed).
Difficulty per level lives in `level_gen.gd -> params()`.
