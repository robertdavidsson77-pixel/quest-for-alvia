## Dice helpers. All randomness in the rules goes through here.
class_name Dice
extends RefCounted


static func roll(sides: int) -> int:
	return randi_range(1, sides)


static func roll_many(count: int, sides: int) -> Array:
	var results: Array = []
	for i in count:
		results.append(roll(sides))
	return results


static func total(results: Array) -> int:
	var sum := 0
	for r in results:
		sum += int(r)
	return sum
