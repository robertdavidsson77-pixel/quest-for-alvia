# The Quest for Alvia

A grim, turn-based dungeon board game in Godot 4.7, in the spirit of HeroQuest and Dungeon Keeper, using the DnD SRD 5.1 rules.

**Current version: v0.2**, a party of four heroes against a pack of goblins in a torch-lit cellar.

## How to run
1. Clone or download this repository.
2. In the Godot Project Manager, click **Import**, pick `project.godot`, then **Import & Edit**.
3. Press **F5** (Run Project).

## How to play
- Before the quest, click each hero to switch it between **Player** and **AI**. All Player is hot-seat or "steer them all"; mix as you like.
- Heroes take turns: Fighter, Cleric, Rogue, Wizard. Then every goblin moves and attacks.
- On your turn: **Space** rolls 2d6 for movement, and blue squares show where you can go. Move in as many steps as you like, before or after your one action.
- Your action is a weapon attack (click a goblin on a red square next to you) or a card.
- **Cards:** click a card, then a lit target square. Cards that only affect you (Second Wind, Bless, Dash) play at once. "At will" cards can be used every turn; "once per quest" cards turn face-down after use. Right-click or **Esc** cancels a card.
- **Enter** ends your turn.
- Camera: hold the right mouse button and drag to rotate and tilt freely. Hold Q / E to rotate, R / F to tilt, W A S D to pan, mouse wheel to zoom. T flips to a straight top-down view and back, C resets the camera.

## The heroes
| Hero | HP | AC | Weapon | Cards |
| --- | --- | --- | --- | --- |
| Fighter | 13 | 16 | Longsword +5, d8+3 | Mighty Blow, Second Wind |
| Cleric | 10 | 16 | Mace +4, d6+2 | Sacred Flame, Cure Wounds (x2), Bless |
| Rogue | 10 | 14 | Short sword +5, d6+3 | Sneak Attack, Dash |
| Wizard | 8 | 12 | Dagger +2, d4 | Fire Bolt, Magic Missile, Sleep |

Heroes who die stay dead for the rest of the quest.

## Where things live
- `data/units/*.tres` – stats for each hero and monster, including which cards a hero has. Double-click one in Godot to edit it in the Inspector.
- `data/cards/*.tres` – one file per card: range, dice, timing and effect.
- `scripts/main.gd` – turn order, the actions every hero can take, combat and card effects.
- `scripts/hero_ai.gd` – how the computer plays a hero.
- `scripts/board.gd` – the grid, walls, pillars, pathfinding and line of sight.
- `scripts/figure.gd` – a hero or monster on the board.
- `scripts/hud.gd` – party list, dice tray, card hand, log, buttons and screens.
- `scripts/camera_rig.gd` – the camera.

## Automated test
`tests/autoplay.gd` plays ten games with every hero on AI, then four where a bot clicks through the player controls, and prints the results:

```
godot --path . -s res://tests/autoplay.gd
```
