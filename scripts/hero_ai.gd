## Plays one hero's turn for the computer, using the same actions as the player.
## Simple rules of thumb: heal when hurt, put groups to sleep, finish wounded
## monsters, keep spellcasters at range and fighters up front.
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
	if await _try_act(hero, true):
		if _is_over():
			return
		await _pause()
		await _move_after_acting(hero)
		return

	if _is_over():
		return
	await _maybe_dash(hero)
	await _pause()
	await _move(hero)
	if _is_over():
		return
	await _try_act(hero, false)
	await _pause()


# --- Choosing an action ----------------------------------------------------

## Tries the best action available. With `only_urgent`, only takes actions
## that would not get better by moving first. Returns true if it acted.
func _try_act(hero: Figure, only_urgent: bool) -> bool:
	if game.has_acted:
		return false

	# 1. Heal whoever is badly hurt.
	for card in _cards(hero, CardData.Effect.HEAL):
		var patient := _most_hurt(game.card_targets(hero, card))
		if patient != null and patient.hp * 2 <= patient.stats.max_hp:
			await game.play_card(card, patient.cell)
			return true

	# 2. Bless the party when a fight is on.
	for card in _cards(hero, CardData.Effect.BLESS):
		if _awake_monsters_within(hero.cell, 6) >= 2:
			await game.play_card(card, hero.cell)
			return true

	# 3. Put two or more monsters to sleep.
	for card in _cards(hero, CardData.Effect.SLEEP):
		var best_cell := Vector2i(-1, -1)
		var best_count := 1
		for cell in game.card_targets(hero, card):
			var count := 0
			for m in game.living_monsters():
				if m.sleep_turns == 0 and Board.distance(cell, m.cell) <= card.area_radius:
					count += 1
			if count > best_count:
				best_cell = cell
				best_count = count
		if best_count >= 2:
			await game.play_card(card, best_cell)
			return true

	# 4. Melee: a monster is right next to us.
	var adjacent := _weakest(_adjacent_monster_cells(hero))
	if adjacent != null:
		for card in _cards(hero, CardData.Effect.WEAPON_ATTACK):
			var average := hero.stats.damage_bonus + hero.stats.damage_die / 2.0 + 0.5
			if adjacent.hp > average:
				await game.play_card(card, adjacent.cell)
				return true
		for card in _cards(hero, CardData.Effect.SNEAK_ATTACK):
			await game.play_card(card, adjacent.cell)
			return true
		if not _is_caster(hero) or _ranged_card(hero) == null:
			await game.weapon_attack(adjacent)
			return true

	# 5. Magic missile to finish off a monster that is threatening a wounded hero.
	for card in _cards(hero, CardData.Effect.MAGIC_MISSILE):
		for cell in game.card_targets(hero, card):
			var m: Figure = game.figure_at(cell)
			if m.hp <= 9 and _threatens_wounded_hero(m):
				await game.play_card(card, cell)
				return true

	# 6. Ranged attacks. Casters shoot even if they could still move closer.
	var ranged := _ranged_card(hero)
	if ranged != null and (_is_caster(hero) or not only_urgent):
		var target := _weakest(game.card_targets(hero, ranged))
		if target != null:
			await game.play_card(ranged, target.cell)
			return true

	# 7. A caster with a monster in its face and nothing better: stab it.
	if adjacent != null and not only_urgent:
		await game.weapon_attack(adjacent)
		return true
	return false


# --- Moving ----------------------------------------------------------------

func _move(hero: Figure) -> void:
	var reach: Dictionary = game.reachable_cells()
	if reach.is_empty():
		return
	if _is_caster(hero):
		var spot := _casting_spot(hero, reach)
		if spot != hero.cell:
			await game.move_active_to(spot)
		return
	if not _adjacent_monster_cells(hero).is_empty():
		return
	await _close_in(hero, reach)


## After acting, fighters step up to the nearest monster; casters stay put.
func _move_after_acting(hero: Figure) -> void:
	if _is_caster(hero) or not _adjacent_monster_cells(hero).is_empty():
		return
	var reach: Dictionary = game.reachable_cells()
	if not reach.is_empty():
		await _close_in(hero, reach)


func _close_in(hero: Figure, reach: Dictionary) -> void:
	var best: Array[Vector2i] = []
	for m in game.living_monsters():
		var path: Array[Vector2i] = game.board.path_to_adjacent(hero.cell, m.cell, game.occupied_except(hero))
		if not path.is_empty() and (best.is_empty() or path.size() < best.size()):
			best = path
	if best.is_empty():
		return
	# Walk as far along the path as our roll allows.
	var goal := hero.cell
	for step in best:
		if reach.has(step):
			goal = step
		else:
			break
	if goal != hero.cell:
		await game.move_active_to(goal)


## The reachable square with a monster in range, not next to one, closest to
## where we already stand. Falls back to edging towards the monsters.
func _casting_spot(hero: Figure, reach: Dictionary) -> Vector2i:
	var card := _ranged_card(hero)
	var best := Vector2i(-1, -1)
	var best_score := INF
	for cell in reach:
		if _monster_adjacent_to(cell):
			continue
		var in_range := false
		for m in game.living_monsters():
			if Board.distance(cell, m.cell) <= card.card_range and game.board.has_line_of_sight(cell, m.cell):
				in_range = true
				break
		if not in_range:
			continue
		var score: float = reach[cell] - _nearest_monster_distance(cell) * 0.5
		if score < best_score:
			best = cell
			best_score = score
	if best != Vector2i(-1, -1):
		return best
	# No shot from anywhere we can reach: move closer but keep two squares away.
	var closest := hero.cell
	var closest_dist := _nearest_monster_distance(hero.cell)
	for cell in reach:
		var d := _nearest_monster_distance(cell)
		if d >= 2 and d < closest_dist:
			closest = cell
			closest_dist = d
	return closest


func _maybe_dash(hero: Figure) -> void:
	if _is_caster(hero) or not _adjacent_monster_cells(hero).is_empty():
		return
	for card in _cards(hero, CardData.Effect.DASH):
		var nearest := 1 << 30
		for m in game.living_monsters():
			var path: Array[Vector2i] = game.board.path_to_adjacent(hero.cell, m.cell, game.occupied_except(hero))
			if not path.is_empty():
				nearest = mini(nearest, path.size())
		if nearest > game.moves_left and nearest < 1 << 30:
			await game.play_card(card, hero.cell)


# --- Helpers ---------------------------------------------------------------

func _cards(hero: Figure, effect: CardData.Effect) -> Array[CardData]:
	var found: Array[CardData] = []
	for card in hero.stats.cards:
		if card.effect == effect and hero.can_play(card) and not game.card_targets(hero, card).is_empty():
			found.append(card)
	return found


## The hero's at-will card that hits from a distance, if any.
func _ranged_card(hero: Figure) -> CardData:
	for card in hero.stats.cards:
		if card.timing == CardData.Timing.AT_WILL and card.target == CardData.Target.ENEMY and card.card_range > 1:
			return card
	return null


## Casters are heroes whose at-will ranged spell beats their weapon (the Wizard).
func _is_caster(hero: Figure) -> bool:
	return _ranged_card(hero) != null and hero.stats.attack_bonus < hero.stats.spell_attack_bonus


func _adjacent_monster_cells(hero: Figure) -> Array:
	var cells: Array = []
	for m in game.living_monsters():
		if Board.are_adjacent(hero.cell, m.cell):
			cells.append(m.cell)
	return cells


func _monster_adjacent_to(cell: Vector2i) -> bool:
	for m in game.living_monsters():
		if Board.are_adjacent(cell, m.cell):
			return true
	return false


func _nearest_monster_distance(cell: Vector2i) -> int:
	var nearest := 1 << 30
	for m in game.living_monsters():
		nearest = mini(nearest, Board.distance(cell, m.cell))
	return nearest


func _awake_monsters_within(cell: Vector2i, squares: int) -> int:
	var count := 0
	for m in game.living_monsters():
		if m.sleep_turns == 0 and Board.distance(cell, m.cell) <= squares:
			count += 1
	return count


func _threatens_wounded_hero(m: Figure) -> bool:
	for h in game.living_heroes():
		if h.hp * 2 <= h.stats.max_hp and Board.distance(h.cell, m.cell) <= 2:
			return true
	return false


## The figure with the fewest HP standing on one of `cells`.
func _weakest(cells: Array) -> Figure:
	var best: Figure = null
	for cell in cells:
		var f: Figure = game.figure_at(cell)
		if f != null and (best == null or f.hp < best.hp):
			best = f
	return best


## The hero on one of `cells` missing the largest share of their HP.
func _most_hurt(cells: Array) -> Figure:
	var best: Figure = null
	for cell in cells:
		var f: Figure = game.figure_at(cell)
		if f != null and (best == null or float(f.hp) / f.stats.max_hp < float(best.hp) / best.stats.max_hp):
			best = f
	return best


func _is_over() -> bool:
	return game.phase == game.Phase.OVER


func _pause() -> void:
	await game.get_tree().create_timer(THINK_TIME).timeout
