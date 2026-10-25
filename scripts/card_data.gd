## One spell card. Each is cast once per quest and comes back at the next quest.
## Cards are .tres files in data/cards; heroes list theirs in UnitStats.
class_name CardData
extends Resource

enum Target { ENEMY, ALLY, EMPTY_SQUARE }
enum Effect {
	MAGIC_FIGHT,  ## d6 + Craft against the target's d6 + Craft. The caster is never hurt.
	SLEEP,        ## A living monster misses its next `amount` turns.
	HEAL,         ## The target regains `amount` Lives.
	TELEPORT,     ## The caster moves to the chosen free square.
}

@export var title: String = "Spell"
@export_multiline var description: String = ""
@export var target: Target = Target.ENEMY
@export var effect: Effect = Effect.MAGIC_FIGHT
## Range in squares, counting diagonals as one. 1 means adjacent.
@export var card_range: int = 1
@export var amount: int = 1
## Lives undead lose when they lose this card's magic fight.
@export var undead_damage: int = 1
