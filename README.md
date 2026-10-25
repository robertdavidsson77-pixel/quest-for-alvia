# The Quest for Alvia

A grim, turn-based dungeon board game in Godot 4.7, in the spirit of HeroQuest and Dungeon Keeper, using the DnD SRD 5.1 rules.

**Current version: v0.1**, one Fighter against one goblin in a torch-lit cellar.

## How to run
1. Clone or download this repository.
2. In the Godot Project Manager, click **Import**, pick `project.godot`, then **Import & Edit**.
3. Press **F5** (Run Project).

## How to play
- **Space** (or the button) rolls 2d6 for movement. Blue squares show where you can go.
- Click a blue square to move. You can split your movement before and after attacking.
- Click the goblin when it's next to you (red square) to attack: d20 + 5 against its armour class 15.
- **Enter** ends your turn. Then the goblin moves 8 squares and attacks.
- Camera: hold the right mouse button and drag to rotate and tilt freely. Hold Q / E to rotate, R / F to tilt, W A S D to pan, mouse wheel to zoom. T flips to a straight top-down view and back, C resets the camera.

## Where things live
- `data/units/*.tres` – stats for the Fighter and the goblin. Double-click one in Godot to change HP, AC, damage or colour in the Inspector.
- `scripts/main.gd` – the turn loop and combat rules.
- `scripts/board.gd` – the grid, walls, pillars and pathfinding.
- `scripts/figure.gd` – a hero or monster on the board.
- `scripts/hud.gd` – the dice tray, log and buttons.
- `scripts/camera_rig.gd` – the camera.

## Automated test
`tests/autoplay.gd` plays three games with a simple bot and prints the result:

```
godot --path . -s res://tests/autoplay.gd
```
