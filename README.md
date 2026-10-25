# The Quest for Alvia

A grim, turn-based dungeon board game in Godot 4.7. The board and dungeons follow HeroQuest, the stats and fights follow Talisman, and the camera is inspired by Dungeon Keeper.

**Current version: v0.3**, a party of four heroes against three goblins and an orc in a torch-lit cellar.

The DnD-rules version (v0.2) is kept on the `v0.2-party` branch as an idea for later.

## How to run
1. Clone or download this repository.
2. In the Godot Project Manager, click **Import**, pick `project.godot`, then **Import & Edit**.
3. Press **F5** (Run Project).

## How to play
- Before the quest, click each hero to switch it between **Player** and **AI**. All Player is hot-seat or "steer them all"; mix as you like.
- Heroes take turns: Fighter, Cleric, Rogue, Wizard. Then every goblin moves and attacks.
- On your turn: **Space** rolls 2d6 for movement, and blue squares show where you can go. Move in as many steps as you like, before or after your one action.
- Your action is a fight (click a monster on a red square next to you) or, for the Cleric and Wizard, a spell card.
- **Fights:** both sides roll 1d6 and add their Strength. The higher total wins and the loser loses 1 Life; a tie hurts nobody. Monsters that attack you can lose too.
- **Magic fights** (Fire Bolt, Holy Light, ghosts) use Craft instead of Strength. A spell never hurts its caster.
- **Fate:** a hero about to lose a fight spends a Fate point to reroll, if they have any left. **Chain mail** saves a lost Life on 5 or 6.
- **Spells:** click a card, then a lit target square. Each spell works once per quest. Right-click or **Esc** cancels.
- **Enter** ends your turn.
- Camera: hold the right mouse button and drag to rotate and tilt freely. Hold Q / E to rotate, R / F to tilt, W A S D to pan, mouse wheel to zoom. T flips to a straight top-down view and back, C resets the camera.

## The heroes
| Hero | Strength | Craft | Lives | Fate | Gear | Special |
| --- | --- | --- | --- | --- | --- | --- |
| Fighter | 3 (+1 sword) | 1 | 5 | 1 | Sword, chain mail | Rolls 2 dice in Strength fights, keeps the higher |
| Rogue | 3 (+1 short sword) | 3 | 4 | 2 | Short sword | Finds traps and secret doors (once traps exist) |
| Cleric | 2 (+1 mace) | 4 | 4 | 2 | Mace | +1 against undead; spells Heal and Holy Light |
| Wizard | 1 | 5 | 3 | 2 | Staff | Spells Fire Bolt, Sleep and Mist Step |

Monsters: goblin Strength 2, orc Strength 4, both with 1 Life. Heroes who die stay dead for the rest of the quest.

## Where things live
- `data/units/*.tres` – stats for each hero and monster, including which cards a hero has. Double-click one in Godot to edit it in the Inspector.
- `data/cards/*.tres` – one file per spell card: target, range and effect.
- `scripts/main.gd` – turn order, the actions every hero can take, fights and spell effects.
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
