## v0.3: a party of four heroes against goblins and an orc in one room.
## Talisman-style rules: fights are one d6 roll each plus Strength (or Craft),
## and the loser loses a Life. Heroes are steered by the player or by HeroAI;
## both use the same actions below.
extends Node3D

const HERO_STATS: Array[UnitStats] = [
	preload("res://data/units/fighter.tres"),
	preload("res://data/units/cleric.tres"),
	preload("res://data/units/rogue.tres"),
	preload("res://data/units/wizard.tres"),
]
const HERO_STARTS: Array[Vector2i] = [Vector2i(2, 4), Vector2i(1, 4), Vector2i(2, 5), Vector2i(1, 5)]
const GOBLIN: UnitStats = preload("res://data/units/goblin.tres")
const ORC: UnitStats = preload("res://data/units/orc.tres")

const ROOM_WIDTH := 14
const ROOM_HEIGHT := 10

enum Phase { SETUP, HERO, BUSY, OVER }

var board: Board
var hud: Hud
var camera_rig: CameraRig
var heroes: Array[Figure] = []
var monsters: Array[Figure] = []

var phase := Phase.SETUP
var round_number := 1
var active: Figure  # the hero whose turn it is
var has_rolled := false
var moves_left := 0
var has_acted := false
var selected_card: CardData  # card waiting for the player to pick a target

var _hero_index := -1
var _reachable := {}  # cell -> steps, for the active hero's move
var _torches: Array[OmniLight3D] = []
var _time := 0.0


func _ready() -> void:
	randomize()
	_build_atmosphere()

	board = Board.new()
	add_child(board)
	var pillars: Array[Vector2i] = [Vector2i(4, 2), Vector2i(4, 7), Vector2i(9, 2), Vector2i(9, 7)]
	board.build(ROOM_WIDTH, ROOM_HEIGHT, pillars)
	_add_torches()

	camera_rig = CameraRig.new()
	add_child(camera_rig)

	for i in HERO_STATS.size():
		heroes.append(_spawn(HERO_STATS[i], HERO_STARTS[i]))
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.75, 0.45)
	lantern.light_energy = 1.2
	lantern.omni_range = 5.0
	lantern.position.y = 1.6
	heroes[0].add_child(lantern)
	monsters.append(_spawn(GOBLIN, Vector2i(12, 2)))
	monsters.append(_spawn(GOBLIN, Vector2i(11, 4)))
	monsters.append(_spawn(GOBLIN, Vector2i(12, 8)))
	monsters.append(_spawn(ORC, Vector2i(11, 6)))
	for m in monsters:
		m.face(heroes[0].position)
	for h in heroes:
		h.face(monsters[0].position)

	hud = Hud.new()
	add_child(hud)
	hud.roll_pressed.connect(_on_roll)
	hud.end_turn_pressed.connect(_on_end_turn)
	hud.card_pressed.connect(_on_card_pressed)
	hud.restart_pressed.connect(func(): get_tree().reload_current_scene())
	hud.seats_chosen.connect(begin_quest)

	_refresh_ui()
	var names: Array = []
	for h in heroes:
		names.append(h.stats.display_name)
	hud.show_seat_setup(names)


func _process(delta: float) -> void:
	_time += delta
	for i in _torches.size():
		var t := _torches[i]
		t.light_energy = 1.6 + 0.3 * sin(_time * 9.0 + i * 1.7) + 0.2 * sin(_time * 23.0 + i)


## `ai_flags[i]` is true when hero i is steered by the computer.
func begin_quest(ai_flags: Array) -> void:
	for i in heroes.size():
		heroes[i].is_ai = ai_flags[i]
	hud.log_line("[color=#a99]The cellar door slams shut behind you. Something snickers in the dark.[/color]")
	_start_round()


# --- Turn order ------------------------------------------------------------

func _start_round() -> void:
	_hero_index = -1
	_next_hero()


func _next_hero() -> void:
	if phase == Phase.OVER:
		return
	if active != null:
		active.set_active(false)
	_hero_index += 1
	while _hero_index < heroes.size() and not heroes[_hero_index].is_alive():
		_hero_index += 1
	if _hero_index >= heroes.size():
		active = null
		_dungeon_turn()
		return

	active = heroes[_hero_index]
	has_rolled = false
	moves_left = 0
	has_acted = false
	selected_card = null
	active.set_active(true)
	camera_rig.focus_on(active.position)
	hud.set_turn("Round %d  ·  %s's turn" % [round_number, active.stats.display_name])

	if active.is_ai:
		phase = Phase.BUSY
		_refresh_ui()
		await HeroAI.new(self).take_turn(active)
		_next_hero()
	else:
		phase = Phase.HERO
		_refresh_ui()


func _dungeon_turn() -> void:
	phase = Phase.BUSY
	_refresh_ui()
	hud.set_turn("Round %d  ·  The dungeon stirs" % round_number)
	for m in living_monsters():
		await get_tree().create_timer(0.3).timeout
		if not m.is_alive():
			continue
		if m.sleep_turns > 0:
			m.sleep_tick()
			continue
		var prey := _choose_prey(m)
		if prey == null:
			break
		if not Board.are_adjacent(m.cell, prey.cell):
			var path := board.path_to_adjacent(m.cell, prey.cell, occupied_except(m))
			if path.size() > m.stats.speed:
				path = path.slice(0, m.stats.speed)
			await m.move_along(path)
		# Anyone next to it after moving is fair game; the weakest first.
		var target: Figure = null
		for h in living_heroes():
			if Board.are_adjacent(m.cell, h.cell) and (target == null or h.lives < target.lives):
				target = h
		if target != null:
			await _fight(m, target, false, m.stats.weapon_name)
			if _check_end():
				return
		else:
			m.face(prey.position)
	round_number += 1
	_start_round()


## Monsters go for the hero they can reach soonest, the weakest if tied.
func _choose_prey(m: Figure) -> Figure:
	var best: Figure = null
	var best_steps := 1 << 30
	for h in living_heroes():
		var steps := 0
		if not Board.are_adjacent(m.cell, h.cell):
			var path := board.path_to_adjacent(m.cell, h.cell, occupied_except(m))
			steps = path.size() if not path.is_empty() else 1000 + Board.distance(m.cell, h.cell)
		if steps < best_steps or (steps == best_steps and h.lives < best.lives):
			best = h
			best_steps = steps
	return best


# --- Actions (used by the player's clicks and by HeroAI) ---------------------

func roll_movement() -> void:
	if has_rolled:
		return
	var rolls := Dice.roll_many(2, 6)
	await hud.show_dice("%s moves (2d6)" % active.stats.display_name, 6, rolls)
	moves_left += Dice.total(rolls)
	has_rolled = true
	hud.log_line("%s may move [b]%d[/b] squares." % [_name(active), moves_left])


func reachable_cells() -> Dictionary:
	if moves_left <= 0:
		return {}
	return board.flood(active.cell, moves_left, occupied_except(active))["dist"]


func move_active_to(cell: Vector2i) -> void:
	var path := Board.path_from_flood(board.flood(active.cell, moves_left, occupied_except(active)), cell)
	if path.is_empty():
		return
	board.clear_highlights()
	await active.move_along(path)
	moves_left -= path.size()


## Attack an adjacent monster with your weapon: a Strength fight.
func weapon_attack(target: Figure) -> void:
	has_acted = true
	board.clear_highlights()
	await _fight(active, target, false, active.stats.weapon_name)
	_check_end()


## Squares the card can be aimed at from where `fig` stands.
func card_targets(fig: Figure, card: CardData) -> Array:
	var cells: Array = []
	match card.target:
		CardData.Target.ENEMY:
			for m in living_monsters():
				if card.effect == CardData.Effect.SLEEP and m.stats.is_undead:
					continue
				if Board.distance(fig.cell, m.cell) <= card.card_range and board.has_line_of_sight(fig.cell, m.cell):
					cells.append(m.cell)
		CardData.Target.ALLY:
			for h in living_heroes():
				if Board.distance(fig.cell, h.cell) <= card.card_range:
					cells.append(h.cell)
		CardData.Target.EMPTY_SQUARE:
			var occupied := occupied_except(null)
			for x in board.width:
				for y in board.height:
					var c := Vector2i(x, y)
					if board.is_walkable(c) and not occupied.has(c) and Board.distance(fig.cell, c) <= card.card_range:
						cells.append(c)
	return cells


func play_card(card: CardData, cell: Vector2i) -> void:
	var fig := active
	has_acted = true
	selected_card = null
	fig.spend(card)
	board.clear_highlights()
	_refresh_ui()
	hud.log_line("%s casts [color=#f2c14e]%s[/color]." % [_name(fig), card.title])
	var target := figure_at(cell)

	match card.effect:
		CardData.Effect.MAGIC_FIGHT:
			var damage := card.undead_damage if target.stats.is_undead else 1
			await _fight(fig, target, true, card.title, true, damage)
		CardData.Effect.SLEEP:
			fig.face(target.position)
			target.fall_asleep(card.amount)
			hud.log_line("%s slumps to the floor, asleep." % _name(target))
		CardData.Effect.HEAL:
			target.heal(card.amount)
			hud.log_line("%s regains [b]%d[/b] Lives." % [_name(target), card.amount])
		CardData.Effect.TELEPORT:
			await fig.teleport_to(cell)
	_check_end()


# --- Fights ----------------------------------------------------------------

## A Talisman-style fight: both sides roll 1d6 and add Strength (or Craft in a
## magic fight). The higher total wins and the loser loses a Life; a tie is a
## standoff. A hero about to lose spends a Fate point to reroll, if they have one.
## In a `ranged` fight (a spell) the attacker is never hurt, and a losing
## defender loses `damage` Lives.
func _fight(attacker: Figure, defender: Figure, magic: bool, what: String, ranged := false, damage := 1) -> void:
	magic = magic or attacker.stats.fights_with_craft or defender.stats.fights_with_craft
	if ranged:
		attacker.face(defender.position)
	else:
		await attacker.play_attack(defender)
	var a := await _roll_for(attacker, defender, magic)
	var d := await _roll_for(defender, attacker, magic)
	if a < d and attacker.fate_left > 0 and not ranged:
		a = await _use_fate(attacker, defender, magic)
	elif d < a and defender.fate_left > 0:
		d = await _use_fate(defender, attacker, magic)

	var how := "%s (%d against %d)" % [what, a, d]
	if a == d:
		hud.log_line("%s and %s are evenly matched: %s. A standoff." % [_name(attacker), _name(defender), how])
		defender.show_float_text("Standoff", Color(0.8, 0.8, 0.8))
	elif a > d:
		hud.log_line("%s wins the fight: %s." % [_name(attacker), how])
		await _lose_lives(defender, damage)
	elif ranged:
		hud.log_line("%s resists the %s (%d against %d)." % [_name(defender), what, d, a])
		defender.show_float_text("Resisted", Color(0.8, 0.8, 0.8))
	else:
		hud.log_line("%s loses the fight: %s." % [_name(attacker), how])
		await _lose_lives(attacker, 1)
	_refresh_ui()


## One side's roll: 1d6 (best of two for the Fighter in Strength fights) plus bonus.
func _roll_for(f: Figure, opponent: Figure, magic: bool) -> int:
	var dice := Dice.roll_many(2 if f.stats.best_of_two and not magic else 1, 6)
	var bonus := _fight_bonus(f, opponent, magic)
	var stat := "Craft" if magic else "Strength"
	var best := " (best of two)" if dice.size() > 1 else ""
	await hud.show_dice("%s: d6 + %d %s%s" % [f.stats.display_name, bonus, stat, best], 6, dice)
	return int(dice.max()) + bonus


func _fight_bonus(f: Figure, opponent: Figure, magic: bool) -> int:
	if magic:
		return f.stats.craft
	var bonus := f.stats.strength + f.stats.weapon_bonus
	if opponent.stats.is_undead:
		bonus += f.stats.bonus_vs_undead
	return bonus


func _use_fate(f: Figure, opponent: Figure, magic: bool) -> int:
	f.fate_left -= 1
	hud.log_line("%s spends a Fate point to reroll." % _name(f))
	f.show_float_text("Fate!", Color(0.7, 0.85, 1.0))
	return await _roll_for(f, opponent, magic)


## Armour gets a roll to save each lost Life.
func _lose_lives(f: Figure, amount: int) -> void:
	if f.stats.armour_save > 0:
		var save := Dice.roll(6)
		await hud.show_dice("%s's %s saves on %d+" % [f.stats.display_name, f.stats.armour_name, f.stats.armour_save], 6, [save])
		if save >= f.stats.armour_save:
			hud.log_line("%s's %s turns the blow." % [_name(f), f.stats.armour_name])
			f.show_float_text("Saved", Color(0.8, 0.85, 0.9))
			return
	await f.lose_lives(amount)
	if not f.is_alive():
		hud.log_line("[color=#c33]%s falls.[/color]" % f.stats.display_name)


## Ends the quest if one side is wiped out. Returns true if it ended.
func _check_end() -> bool:
	if phase == Phase.OVER:
		return true
	if living_heroes().is_empty():
		_finish(false)
		return true
	if living_monsters().is_empty():
		_finish(true)
		return true
	return false


func _finish(won: bool) -> void:
	phase = Phase.OVER
	board.clear_highlights()
	if active != null:
		active.set_active(false)
	if won:
		var fallen := heroes.size() - living_heroes().size()
		var cost := "Nobody was lost." if fallen == 0 else "%d of you will not leave this cellar." % fallen
		hud.show_end("VICTORY", "The cellar falls silent. %s" % cost, true)
	else:
		hud.show_end("THE PARTY HAS FALLEN", "No one in Alvia will remember your names.", false)


# --- Player input ----------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _cell_under_mouse(event.position)
		board.set_hover(cell)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_cell_clicked(_cell_under_mouse(event.position))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_card()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_roll()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_end_turn()
		elif event.keycode == KEY_ESCAPE:
			_cancel_card()


func _on_roll() -> void:
	if phase != Phase.HERO or has_rolled:
		return
	await _run(roll_movement)


func _on_end_turn() -> void:
	if phase != Phase.HERO:
		return
	phase = Phase.BUSY
	selected_card = null
	board.clear_highlights()
	_next_hero()


func _on_card_pressed(index: int) -> void:
	if phase != Phase.HERO or has_acted:
		return
	var card: CardData = active.stats.cards[index]
	if not active.can_play(card):
		return
	if selected_card == card:
		_cancel_card()
	else:
		selected_card = card
		_refresh_ui()


func _cancel_card() -> void:
	if selected_card != null:
		selected_card = null
		_refresh_ui()


func _on_cell_clicked(cell: Vector2i) -> void:
	if phase != Phase.HERO:
		return
	if selected_card != null:
		if card_targets(active, selected_card).has(cell):
			var card := selected_card
			await _run(func(): await play_card(card, cell))
		else:
			hud.log_line("[color=#888]Not a target for %s.[/color]" % selected_card.title)
		return
	var target := monster_at(cell)
	if target != null:
		if has_acted:
			hud.log_line("[color=#888]%s has already acted this turn.[/color]" % active.stats.display_name)
		elif not Board.are_adjacent(active.cell, cell):
			hud.log_line("[color=#888]Too far away. Move next to it first.[/color]")
		else:
			await _run(func(): await weapon_attack(target))
		return
	if _reachable.has(cell) and cell != active.cell:
		await _run(func(): await move_active_to(cell))


## Locks input while an action plays out, then hands control back.
## Ends the turn by itself once the hero has moved and acted.
func _run(action: Callable) -> void:
	phase = Phase.BUSY
	_refresh_ui()
	await action.call()
	if phase == Phase.OVER:
		return
	phase = Phase.HERO
	_refresh_ui()
	if not active.is_alive() or (has_acted and has_rolled and moves_left == 0):
		_on_end_turn()


# --- UI --------------------------------------------------------------------

func _refresh_ui() -> void:
	var lines: Array[String] = []
	for h in heroes:
		var marker := "▶ " if h == active else "    "
		var who := "AI" if h.is_ai else "Player"
		if not h.is_alive():
			lines.append("%s[color=#933]%s, fallen[/color]" % [marker, h.stats.display_name])
			continue
		var lives_color := "#e66" if h.lives * 2 <= h.stats.lives else "#ddd"
		var s := h.stats
		lines.append("%s[b]%s[/b] [color=#888](%s)[/color]  [color=%s]Lives %d/%d[/color]  · Str %d  · Craft %d  · Fate %d" % [
			marker, s.display_name, who, lives_color, h.lives, s.lives, s.strength + s.weapon_bonus, s.craft, h.fate_left])
	hud.set_party("\n".join(PackedStringArray(lines)))

	var my_turn := phase == Phase.HERO
	if active != null and phase != Phase.OVER:
		var moves := str(moves_left) if has_rolled else "roll first"
		hud.set_status("Moves: %s   ·   Action: %s" % [moves, "used" if has_acted else "ready"])
	else:
		hud.set_status("")
	hud.set_buttons(my_turn and not has_rolled, my_turn)

	var playable: Array = []
	if active != null:
		for card in active.stats.cards:
			playable.append(my_turn and not has_acted and active.can_play(card) and not card_targets(active, card).is_empty())
	hud.show_hand(active if phase != Phase.OVER else null, playable, active.stats.cards.find(selected_card) if active != null and selected_card != null else -1)

	_reachable = {}
	if my_turn:
		_reachable = reachable_cells()
		_show_highlights()
	elif phase != Phase.BUSY:
		board.clear_highlights()


func _show_highlights() -> void:
	if selected_card != null:
		var targets := card_targets(active, selected_card)
		match selected_card.target:
			CardData.Target.ALLY:
				board.show_ally_cells(targets)
			CardData.Target.EMPTY_SQUARE:
				board.clear_highlights()
				board.show_area_cells(targets)
			_:
				board.show_attack_cells(targets, true)
		return
	var cells := _reachable.keys()
	cells.erase(active.cell)
	board.show_move_cells(cells)
	if not has_acted:
		var targets: Array = []
		for m in living_monsters():
			if Board.are_adjacent(active.cell, m.cell):
				targets.append(m.cell)
		board.show_attack_cells(targets)


# --- Helpers ---------------------------------------------------------------

func living_heroes() -> Array[Figure]:
	return _alive(heroes)


func living_monsters() -> Array[Figure]:
	return _alive(monsters)


func _alive(figures: Array[Figure]) -> Array[Figure]:
	var alive: Array[Figure] = []
	for f in figures:
		if f.is_alive():
			alive.append(f)
	return alive


func monster_at(cell: Vector2i) -> Figure:
	for m in living_monsters():
		if m.cell == cell:
			return m
	return null


func figure_at(cell: Vector2i) -> Figure:
	for f in living_heroes() + living_monsters():
		if f.cell == cell:
			return f
	return null


func occupied_except(me: Figure) -> Dictionary:
	var occupied := {}
	for f in living_heroes() + living_monsters():
		if f != me:
			occupied[f.cell] = true
	return occupied


func _name(f: Figure) -> String:
	return "[b]%s[/b]" % f.stats.display_name


func _spawn(stats: UnitStats, cell: Vector2i) -> Figure:
	var f := Figure.new()
	add_child(f)
	f.setup(stats, board, cell)
	return f


func _cell_under_mouse(screen_pos: Vector2) -> Vector2i:
	var point: Variant = camera_rig.floor_point(screen_pos)
	if point == null:
		return Vector2i(-1, -1)
	return board.world_to_cell(point)


func _build_atmosphere() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.28, 0.4)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.04, 0.05)
	env.fog_density = 0.02
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# Faint cold light from above, so the board never goes fully black.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.5, 0.55, 0.8)
	moon.light_energy = 0.25
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-60, 30, 0)
	add_child(moon)


func _add_torches() -> void:
	var spots: Array[Vector2i] = [
		Vector2i(-1, 2), Vector2i(-1, ROOM_HEIGHT - 3), Vector2i(ROOM_WIDTH, 2), Vector2i(ROOM_WIDTH, ROOM_HEIGHT - 3),
		Vector2i(3, -1), Vector2i(ROOM_WIDTH - 4, -1), Vector2i(3, ROOM_HEIGHT), Vector2i(ROOM_WIDTH - 4, ROOM_HEIGHT),
	]
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1, 0.6, 0.2)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1, 0.5, 0.15)
	flame_mat.emission_energy_multiplier = 4.0
	for spot in spots:
		var wall_pos := board.cell_to_world(spot)
		# Hang the torch on the wall face that looks into the room.
		var inner := Vector2i(clampi(spot.x, 0, ROOM_WIDTH - 1), clampi(spot.y, 0, ROOM_HEIGHT - 1))
		var inward := (board.cell_to_world(inner) - wall_pos).normalized()
		var pos := wall_pos + inward * 0.55 + Vector3(0, 1.1, 0)

		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = 0.08
		flame_mesh.height = 0.2
		var flame := MeshInstance3D.new()
		flame.mesh = flame_mesh
		flame.material_override = flame_mat
		flame.position = pos
		add_child(flame)

		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.25)
		light.omni_range = 6.0
		light.shadow_enabled = true
		light.position = pos + inward * 0.2
		add_child(light)
		_torches.append(light)
