extends SceneTree

# Plays whole games with a simple hero bot and reports results.
var games := 0
var wins := 0
var main: Node

func _initialize() -> void:
	_next_game()

func _next_game() -> void:
	if main:
		main.queue_free()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_play()

func _play() -> void:
	while true:
		await create_timer(0.05).timeout
		if main.phase == main.Phase.OVER:
			games += 1
			if main.hero.is_alive():
				wins += 1
			print("game %d over, rounds=%d hero_hp=%d won=%s" % [games, main.round_number, main.hero.hp, main.hero.is_alive()])
			if games >= 3:
				print("RESULT wins=%d/%d" % [wins, games])
				quit()
				return
			_next_game()
			return
		if main.phase != main.Phase.HERO:
			continue
		var gob = main._living_monsters()[0]
		if not main.has_acted and Board.are_adjacent(main.hero.cell, gob.cell):
			await main._on_cell_clicked(gob.cell)
			continue
		if not main.has_rolled:
			await main._on_roll()
			continue
		if main.moves_left > 0 and not Board.are_adjacent(main.hero.cell, gob.cell):
			var path = main.board.path_to_adjacent(main.hero.cell, gob.cell, main._occupied_except(main.hero))
			var goal = path[mini(path.size(), main.moves_left) - 1]
			await main._on_cell_clicked(goal)
			continue
		main._on_end_turn()
