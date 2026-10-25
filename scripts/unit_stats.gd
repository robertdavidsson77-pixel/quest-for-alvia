## Stats for one kind of hero or monster, Talisman style. Each kind is a .tres
## file in data/units, so a new monster is a new file you can edit in the Inspector.
class_name UnitStats
extends Resource

@export var display_name: String = "Unit"
@export var is_hero: bool = false
## Added to 1d6 in physical fights.
@export var strength: int = 1
## Added to 1d6 in magic fights.
@export var craft: int = 1
@export var lives: int = 1
## Rerolls a hero may use during a quest.
@export var fate: int = 0
## Squares moved per turn. 0 means the unit rolls 2d6 instead (heroes).
@export var speed: int = 0
@export var color: Color = Color.WHITE
@export var model_height: float = 1.0

@export_group("Gear")
@export var weapon_name: String = "claws"
@export var weapon_bonus: int = 0
@export var armour_name: String = ""
## A hero who loses a fight saves the Life on this roll or higher (1d6). 0 means no armour.
@export var armour_save: int = 0

@export_group("Specials")
## Rolls two dice in Strength fights and keeps the higher (the Fighter).
@export var best_of_two: bool = false
## Added to fights against undead (the Cleric).
@export var bonus_vs_undead: int = 0
@export var is_undead: bool = false
## Fights with Craft instead of Strength, even in melee (ghosts).
@export var fights_with_craft: bool = false

@export_group("Spells")
@export var cards: Array[CardData] = []
