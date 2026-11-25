# Ammunition Works

A first-person WW2 incremental game made in Godot 4.7. You start in a bomb-damaged warehouse, packing pistol cartridges by hand at the one working bench. Earn contract money, buy machines, repairs and power, and work your way up to tank and heavy artillery shells. The game ends when you deliver 1,000 heavy shells for the war contract.

## Running it

Open Godot 4.7, choose **Import**, select `project.godot` in this folder, then press **F5**.

## Controls

| Key | Action |
| --- | --- |
| WASD / arrows | Move |
| Mouse | Look |
| Shift | Run |
| E / Left click | Work the highlighted step (hold to repeat) |
| Tab | Open the ledger (shop) |
| Esc | Menu (save, reset, quit) |

## How it plays

- **Benches.** Each product has a bench with four steps worked left to right. Bigger ammunition needs more clicks per step.
- **Automation.** Machines take over steps from the left, and each one draws power. Once all four steps are automated the line runs on its own. After that you can buy faster machinery and extra production lines.
- **Warehouse repairs.** Each repair raises output across the whole works and changes how the building looks (roof, lamps, windows, paint, dock and lorry, crane, canteen, sandbags, rail siding). Some products need a particular repair before you can take them on.
- **Power.** The dynamo gives 3 power. After that you buy a diesel generator, a coal boiler, a mains grid connection and finally a substation.
- **Saving.** The game autosaves every 20 seconds and when you quit. Fully automated lines keep producing at half speed while you're away, for up to 4 hours.

## Where things are

| File | Contents |
| --- | --- |
| `scripts/data.gd` | **All the balance numbers**: products, prices, repairs, power, cost growth |
| `scripts/main.gd` | Economy, purchases, interaction, saving |
| `scripts/station.gd` | A single bench: steps, automation, the work-piece, machines |
| `scripts/world.gd` | Builds the warehouse and swaps the broken and repaired parts |
| `scripts/ui.gd` | HUD, ledger, dialogs |
| `scripts/player.gd` | First-person controller |
| `scripts/sfx.gd` | Sound effects generated in code |
| `scripts/shapes.gd` | Helpers for building meshes from basic shapes |

Every model is built from basic shapes in code. To use real models, replace the `_build_*` functions in `station.gd` and `world.gd`.

## Debug runs

```
Godot --path . -- --shots=C:/some/folder   # plays a scripted run, saves screenshots, checks interaction
Godot --path . -- --bench                  # prints FPS after 6 seconds
Godot --path . -- --savetest               # save/load round-trip check
```
