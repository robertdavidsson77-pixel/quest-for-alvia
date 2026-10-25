## Plays one hero's turn for the computer, using the same actions as the player.
## Rules of thumb: heal the badly hurt, spend spells on the strongest monster,
## fighters go for the weakest monster in reach, and the Wizard stays out of melee.
class_name HeroAI
extends RefCounted

const THINK_TIME := 0.35

var game: Node  # main.gd


func _init(for_game: Node) -> void:
	game = for_game


func take_turn(hero: Figure) -> void:
	await _pause()
	await game.roll_movement()

	# Act first if something good is on offer from where we stand, then move.
	if await _try_act(hero):
		if _done(hero):
			return
		await _pause()
		await _move_after_acting(hero)
		return
	if _done(hero):
		return
	await _pause()
	await _move(hero)
	if _done(hero):
		return
	await _try_act(hero)
	await _pause()


## Takes the best action available from where the hero stands. Returns true if it acted.
func _try_act(hero: Figure) -> bool:
	if game.has_acted:
		return false

	# 1. Heal whoever is badly hurt.
	for card in _cards(hero, CardData.Effect.HEAL):
		var patient := _most_hurt(game.card_targets(hero, card))
		if patient != null and patient.lives * 2 <= patient.stats.lives:
			await game.play_card(card, patient.cell)
			return true

	# 2. Magic fights are safe for the caster: aim them at the strongest monster.
	for card in _cards(hero, CardData.Effect.MAGIC_FIGHT):
		await game.play_card(card, _strongest(game.card_targets(hero, card)).cell)
		return true

	# 3. Put the strongest monster near the party to sleep.
	for card in _cards(hero, CardData.Effect.SLEEP):
		var target := _strongest(game.card_targets(hero, card))
		if target != null and target.sleep_turns == 0 and _distance_to_nearest_hero(target.cell) <= 3:
			await game.play_card(card, target.cell)
			return true

	# 4. A weak hero in melee slips away instead of fighting.
	if _is_frail(hero) and not _adjacent_monsters(hero).is_empty():
		for card in _cards(hero, CardData.Effect.TELEPORT):
			await game.play_card(card, _safest(game.card_targets(hero, card)))
			return true

	# 5. Fight the weakest monster next to us.
	var foes := _adjacent_monsters(hero)
	if not foes.is_empty() and (not _is_frail(hero) or game.moves_left == 0):
		await game.weapon_attack(_weakest(foes))
		return true
	return false


func _move(hero: Figure) -> void:
	var reach: Dictionary = game.reachable_cells()
	if reach.is_empty():
		return
	if _is_frail(hero):
		var spot := _back_line_spot(hero, reach)
		if spot != hero.cell:
			await game.move_active_to(spot)
		return
	# The Cleric walks to a badly hurt hero to heal them next.
	for card in _cards_any_target(hero, CardData.Effect.HEAL):
		for h in game.living_heroes():
			if h != hero and h.lives * 2 <= h.stats.lives:
				await _walk_towards(hero, h.cell, reach)
				return
	if not _adjacent_monsters(hero).is_empty():
		return
	var target := _nearest_monster(hero)
	if target != null:
		await _walk_towards(hero, target.cell, reach)


## After acting, fighters step up to the nearest monster; the frail stay back.
func _move_after_acting(hero: Figure) -> void:
	var reach: Dictionary = game.reachable_cells()
	if reach.is_empty():
		return
	if _is_frail(hero):
		var spot := _back_line_spot(hero, reach)
		if spot != hero.cell:
			await game.move_active_to(spot)
	elif _adjacent_monsters(hero).is_empty():
		var target := _nearest_monster(hero)
		if target != null:
			await _walk_towards(hero, target.cell, reach)


## Walks as far as the roll allows along the path to a square next to `goal`.
func _walk_towards(hero: Figure, goal: Vector2i, reach: Dictionary) -> void:
	var path: Array[Vector2i] = game.board.path_to_adjacent(hero.cell, goal, game.occupied_except(hero))
	var stop := hero.cell
	for step in path:
		if reach.has(step):
			stop = step
		else:
			break
	if stop != hero.cell:
		await game.move_active_to(stop)


## A reachable square away from the monsters but close to the other heroes.
func _back_line_spot(hero: Figure, reach: Dictionary) -> Vector2i:
	var best := hero.cell
	var best_score := -INF
	for cell in reach:
		var danger := _nearest_monster_distance(cell)
		var score := minf(danger, 4.0) * 2.0 - _distance_to_nearest_hero(cell, hero) * 0.5
		if _adjacent_to_monster(cell):
			score -= 100.0
		if score > best_score:
			best = cell
			best_score = score
	return best


# --- Helpers ---------------------------------------------------------------

func _cards(hero: Figure, effect: CardData.Effect) -> Array[CardData]:
	var found: Array[CardData] = []
	for card in _cards_any_target(hero, effect):
		if not game.card_targets(hero, card).is_empty():
			found.append(card)
	return found


func _cards_any_target(hero: Figure, effect: CardData.Effect) -> Array[CardData]:
	var found: Array[CardData] = []
	for card in hero.stats.cards:
		if card.effect == effect and hero.can_play(card):
			found.append(card)
	return found


## Heroes who should stay out of melee (the Wizard).
func _is_frail(hero: Figure) -> bool:
	return hero.stats.strength + hero.stats.weapon_bonus <= 1


func _adjacent_monsters(hero: Figure) -> Array[Figure]:
	var found: Array[Figure] = []
	for m in game.living_monsters():
		if Board.are_adjacent(hero.cell, m.cell):
			found.append(m)
	return found


func _adjacent_to_monster(cell: Vector2i) -> bool:
	for m in game.living_monsters():
		if Board.are_adjacent(cell, m.cell):
			return true
	return false


func _nearest_monster(hero: Figure) -> Figure:
	var best: Figure = null
	var best_steps := 1 << 30
	for m in game.living_monsters():
		var path: Array[Vector2i] = game.board.path_to_adjacent(hero.cell, m.cell, game.occupied_except(hero))
		if not path.is_empty() and path.size() < best_steps:
			best = m
			best_steps = path.size()
	return best


func _nearest_monster_distance(cell: Vector2i) -> int:
	var nearest := 1 << 30
	for m in game.living_monsters():
		nearest = mini(nearest, Board.distance(cell, m.cell))
	return nearest


func _distance_to_nearest_hero(cell: Vector2i, besides: Figure = null) -> int:
	var nearest := 1 << 30
	for h in game.living_heroes():
		if h != besides:
			nearest = mini(nearest, Board.distance(cell, h.cell))
	return nearest if nearest < 1 << 30 else 0


## The free square furthest from any monster.
func _safest(cells: Array) -> Vector2i:
	var best: Vector2i = cells[0]
	for cell in cells:
		if _nearest_monster_distance(cell) > _nearest_monster_distance(best):
			best = cell
	return best


func _strongest(cells: Array) -> Figure:
	var best: Figure = null
	for cell in cells:
		var f: Figure = game.figure_at(cell)
		if f != null and (best == null or f.stats.strength > best.stats.strength):
			best = f
	return best


func _weakest(foes: Array[Figure]) -> Figure:
	var best: Figure = foes[0]
	for f in foes:
		if f.stats.strength < best.stats.strength:
			best = f
	return best


## The hero on one of `cells` missing the largest share of their Lives.
func _most_hurt(cells: Array) -> Figure:
	var best: Figure = null
	for cell in cells:
		var f: Figure = game.figure_at(cell)
		if f != null and (best == null or float(f.lives) / f.stats.lives < float(best.lives) / best.stats.lives):
			best = f
	return best


func _done(hero: Figure) -> bool:
	return game.phase == game.Phase.OVER or not hero.is_alive()


func _pause() -> void:
	await game.get_tree().create_timer(THINK_TIME).timeout
