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
@export var model_height: float = 1.0

@export_group("Magic and saves")
@export var spell_attack_bonus: int = 0
@export var spell_save_dc: int = 10
@export var dex_save: int = 0
@export var is_undead: bool = false

@export_group("Cards")
@export var cards: Array[CardData] = []
