## Stats for one kind of hero or monster. Each kind is a .tres file in data/units,
## so a new monster is a new file you can edit in the Inspector.
class_name UnitStats
extends Resource

@export var display_name: String = "Unit"
@export var is_hero: bool = false
@export var max_hp: int = 10
@export var armor_class: int = 10
@export var attack_bonus: int = 0
@export var weapon_name: String = "weapon"
@export var damage_dice_count: int = 1
@export var damage_die: int = 6
@export var damage_bonus: int = 0
## Squares moved per turn. 0 means the unit rolls 2d6 instead (heroes).
@export var speed: int = 0
@export var color: Color = Color.WHITE
## Height of the figure in squares.
@export var model_height: float = 1.0
## The 3D model, a .glb with Idle, Walk, Attack1 and Die animations.
## Empty means simple placeholder shapes.
@export_file("*.glb") var model_path: String = ""
## Seconds into the attack animation when the blow lands.
@export var hit_time: float = 0.45
## Where the red eyes glow in the dark, as a share of the figure's height.
@export var eye_height: float = 0.88
## Sound name for this unit's grunts (see scripts/sound.gd). Empty means silent.
## "<voice>_wake" plays when it first sees the hero.
@export var voice: String = ""
