## Quest 1: the cellar stairs. The hero starts in a small stair room; behind its
## door waits the goblin's hall, with two more doors that are locked for now.
##
## Map legend (one character per square, rows top to bottom):
##   #  wall              *  wall with a torch
##   .  floor             H  hero start
##   D  door (closed)     L  locked door
##   S  stairs up         g  goblin
##   T  table             C  chest           B  bookcase
##   (space) solid rock, never shown
class_name QuestCellar
extends RefCounted

const TITLE := "The Cellar Stairs"
const INTRO := "You descend the cellar stairs. Behind you, the trapdoor slams shut. Somewhere beyond the door, something snickers."
const VICTORY := "The goblin lies still. The other doors are locked... for now."

const MAP: Array[String] = [
	"#####L##*####",
	"#...........#",
	"#.TT.....C..#",
	"*...........L",
	"#.B....g....#",
	"#...........*",
	"######D######",
	"     #...#   ",
	"     *.H.#   ",
	"     #.S.#   ",
	"     #####   ",
]
