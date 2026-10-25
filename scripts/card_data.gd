## One ability or spell card, like the cards in HeroQuest.
## Each card is a .tres file in data/cards; heroes list their cards in UnitStats.
class_name CardData
extends Resource

enum Timing { AT_WILL, PER_QUEST }
enum Target { SELF, ENEMY, ALLY, AREA }
enum Effect {
	WEAPON_ATTACK,  ## Weapon attack on an adjacent enemy, with extra_dice more damage dice.
	SNEAK_ATTACK,   ## Weapon attack; adds dice_count d die damage if another hero is next to the target.
	SPELL_ATTACK,   ## d20 + spell attack bonus vs AC, then dice_count d die damage.
	SAVE_DAMAGE,    ## Target rolls a Dex save vs spell DC or takes damage (doubled dice vs undead).
	MAGIC_MISSILE,  ## count darts that never miss, each dice_count d die + bonus.
	HEAL,           ## Heal dice_count d die + bonus.
	BLESS,          ## Heroes within range add a d4 to attack rolls for duration rounds.
	SLEEP,          ## Living monsters in the area skip their next duration turns.
	DASH,           ## Roll movement dice again and add them.
}

@export var title: String = "Card"
@export_multiline var description: String = ""
@export var timing: Timing = Timing.AT_WILL
@export var uses_per_quest: int = 1
@export var target: Target = Target.ENEMY
@export var effect: Effect = Effect.WEAPON_ATTACK
## Range in squares (counting diagonals as 1). 1 means adjacent.
@export var card_range: int = 1
@export var dice_count: int = 1
@export var die: int = 6
@export var bonus: int = 0
@export var extra_dice: int = 0
@export var count: int = 1
@export var duration: int = 0
## For area cards: 1 means a 3x3 square around the chosen cell.
@export var area_radius: int = 0


func timing_text(uses_left: int) -> String:
	if timing == Timing.AT_WILL:
		return "At will"
	if uses_per_quest > 1:
		return "Once per quest  (%d left)" % uses_left
	return "Once per quest"
