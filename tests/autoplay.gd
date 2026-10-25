## Plays whole games and prints the results. Run with:
##   godot --path . -s res://tests/autoplay.gd
## First a batch with every hero on AI, then a batch where a bot clicks
## through the same input handlers a player uses.
extends SceneTree

const AI_GAMES := 10
const PLAYER_GAMES := 4

var main: Node
var results := {"ai": [], "player": []}


func _initialize() -> void:
	_run_all()


func _run_all() -> void:
	for i in AI_GAMES:
		await _play_game(true)
	for i in PLAYER_GAMES:
		await _play_game(false)
	for mode in results:
		var wins := 0
		for r in results[mode]:
			if r["won"]:
				wins += 1
		print("RESULT %s: %d/%d won" % [mode, wins, results[mode].size()])
	quit()


func _play_game(all_ai: bool) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.begin_quest([all_ai, all_ai, all_ai, all_ai])
	var guard := 0
	while main.phase != main.Phase.OVER:
		guard += 1
		if guard > 20000:
			push_error("game did not finish")
			break
		await create_timer(0.05).timeout
		if not all_ai and main.phase == main.Phase.HERO:
			await _player_bot_step()
	var won: bool = not main.living_heroes().is_empty()
	var mode := "ai" if all_ai else "player"
	results[mode].append({"won": won})
	print("%s game: rounds=%d won=%s heroes_left=%d" % [mode, main.round_number, won, main.living_heroes().size()])
	main.queue_free()
	await process_frame


## One click's worth of play for the active hero, through the player input handlers.
func _player_bot_step() -> void:
	var hero: Figure = main.active
	if not main.has_rolled:
		await main._on_roll()
		return
	if not main.has_acted:
		# Try each card on its first target, then a plain attack.
		for i in hero.stats.cards.size():
			var card: CardData = hero.stats.cards[i]
			var targets: Array = main.card_targets(hero, card)
			if hero.can_play(card) and not targets.is_empty():
				if card.target == CardData.Target.ENEMY and main.figure_at(targets[0]) == null:
					continue
				await main._on_card_pressed(i)
				if main.phase == main.Phase.HERO and main.selected_card == card:
					await main._on_cell_clicked(targets[0])
				return
		for m in main.living_monsters():
			if Board.are_adjacent(hero.cell, m.cell):
				await main._on_cell_clicked(m.cell)
				return
	if main.moves_left > 0:
		for m in main.living_monsters():
			var path: Array[Vector2i] = main.board.path_to_adjacent(hero.cell, m.cell, main.occupied_except(hero))
			if not path.is_empty():
				var goal: Vector2i = path[mini(path.size(), main.moves_left) - 1]
				if main._reachable.has(goal):
					await main._on_cell_clicked(goal)
					return
	main._on_end_turn()
