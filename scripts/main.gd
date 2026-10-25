## The Fighter's first quest: start at the foot of the stairs, open the door,
## face what lies beyond. Runs the turn loop: the hero's turn (roll, move, act),
## then the dungeon's turn. Opening a door is free; it does not use the action.
extends Node3D

const FIGHTER: UnitStats = preload("res://data/units/fighter.tres")
const GOBLIN: UnitStats = preload("res://data/units/goblin.tres")
const MONSTERS := {"g": GOBLIN}  # map character -> monster

enum Phase { HERO, BUSY, OVER }

const BEAT := 0.45  # a short pause between actions, so each one can land
const MONSTER_THINK := 0.8  # how long a monster eyes the hero before acting

var board: Board
var hud: Hud
var camera_rig: CameraRig
var hero: Figure
var monsters: Array[Figure] = []

var phase := Phase.BUSY
var round_number := 1
var has_rolled := false
var moves_left := 0
var has_acted := false
var _reachable := {}  # cell -> steps, for the hero's current move

var _time := 0.0


func _ready() -> void:
	randomize()
	_build_atmosphere()

	board = Board.new()
	add_child(board)
	board.build(QuestCellar.MAP)

	camera_rig = CameraRig.new()
	add_child(camera_rig)

	hero = _spawn(FIGHTER, board.hero_start)
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.75, 0.45)
	lantern.light_energy = 1.2
	lantern.omni_range = 4.0
	lantern.position.y = 1.6
	hero.add_child(lantern)

	# Monsters wait in the dark, unseen, until their room is revealed.
	for spawn in board.spawns:
		var m := _spawn(MONSTERS[spawn["char"]], spawn["cell"])
		m.visible = false
		monsters.append(m)
	hero.face(hero.position + Vector3.FORWARD)
	camera_rig.focus_on(hero.position)

	hud = Hud.new()
	add_child(hud)
	hud.roll_pressed.connect(_on_roll)
	hud.end_turn_pressed.connect(_on_end_turn)
	hud.restart_pressed.connect(func(): get_tree().reload_current_scene())
	hud.volume_changed.connect(func(v: float): Sound.volume = v)
	hud.mute_pressed.connect(func():
		Sound.toggle_mute()
		hud.set_volume(Sound.volume, Sound.muted))
	hud.set_volume(Sound.volume, Sound.muted)

	hud.log_line("[b]%s[/b]" % QuestCellar.TITLE)
	hud.log_line("[color=#a99]%s[/color]" % QuestCellar.INTRO)
	await board.reveal_room(board.room_at(board.hero_start), board.hero_start)
	await _start_hero_turn()


func _process(delta: float) -> void:
	_time += delta
	for i in board.torch_lights.size():
		var t := board.torch_lights[i]
		if t.visible:
			var flicker := 1.6 + 0.3 * sin(_time * 9.0 + i * 1.7) + 0.2 * sin(_time * 23.0 + i)
			t.light_energy = flicker * t.get_meta("fade", 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _cell_under_mouse(event.position)
		board.set_hover(cell)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cell_clicked(_cell_under_mouse(event.position))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			Sound.toggle_mute()
			hud.set_volume(Sound.volume, Sound.muted)
		elif event.keycode == KEY_SPACE:
			_on_roll()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_on_end_turn()


# --- Hero turn -------------------------------------------------------------

func _start_hero_turn() -> void:
	phase = Phase.BUSY
	has_rolled = false
	moves_left = 0
	has_acted = false
	hud.set_turn("Round %d  ·  %s's turn" % [round_number, hero.stats.display_name])
	_refresh_hero_ui()
	hud.set_buttons(false, false)
	camera_rig.focus_on(hero.position)
	await hud.show_banner("YOUR TURN", "Round %d" % round_number, Hud.BONE)
	phase = Phase.HERO
	_refresh_hero_ui()


func _on_roll() -> void:
	if phase != Phase.HERO or has_rolled:
		return
	phase = Phase.BUSY
	_refresh_hero_ui()
	var rolls := Dice.roll_many(2, 6)
	await hud.show_dice("Movement (2d6)", 6, rolls)
	moves_left = Dice.total(rolls)
	has_rolled = true
	hud.log_line("You may move [b]%d[/b] squares." % moves_left)
	phase = Phase.HERO
	_refresh_hero_ui()


func _on_cell_clicked(cell: Vector2i) -> void:
	if phase != Phase.HERO:
		return
	if board.is_door_closed(cell):
		if not Board.are_adjacent(hero.cell, cell):
			hud.log_line("[color=#888]Move next to the door first.[/color]")
		elif board.is_door_locked(cell):
			hud.log_line("[color=#888]The door is barred from the other side. It will not budge... (to be continued)[/color]")
		else:
			await _open_door(cell)
		return
	var target := _monster_at(cell)
	if target != null:
		if has_acted:
			hud.log_line("[color=#888]You have already acted this turn.[/color]")
		elif not Board.are_adjacent(hero.cell, cell):
			hud.log_line("[color=#888]Too far away. Move next to it first.[/color]")
		else:
			await _hero_attack(target)
		return
	if _reachable.has(cell) and cell != hero.cell:
		await _hero_move(cell)


func _hero_move(cell: Vector2i) -> void:
	phase = Phase.BUSY
	board.clear_highlights()
	var path := Board.path_from_flood(board.flood(hero.cell, moves_left, _occupied_except(hero)), cell)
	await hero.move_along(path)
	moves_left -= path.size()
	await _beat()
	phase = Phase.HERO
	_refresh_hero_ui()
	_end_turn_if_done()


func _open_door(cell: Vector2i) -> void:
	phase = Phase.BUSY
	board.clear_highlights()
	hud.log_line("The door groans open...")
	camera_rig.focus_on(board.cell_to_world(cell))
	Sound.play("door_creak")
	Sound.play("door")
	await board.open_door(cell)
	for m in monsters:
		if not m.visible and board.is_room_revealed(board.room_at(m.cell)):
			await _wake(m)
	phase = Phase.HERO
	_refresh_hero_ui()


## A monster steps out of the dark: it pops up and turns to face the hero.
func _wake(m: Figure) -> void:
	m.face(hero.position)
	var final_scale := m.scale
	m.scale = Vector3(final_scale.x, 0.01, final_scale.z)
	m.visible = true
	Sound.play(m.stats.voice + "_wake")
	var tween := create_tween()
	tween.tween_property(m, "scale", final_scale, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	m.show_float_text("!", Color(0.95, 0.3, 0.2))
	hud.log_line("[color=#c66]A %s! It has seen you.[/color]" % m.stats.display_name.to_lower())


func _hero_attack(target: Figure) -> void:
	phase = Phase.BUSY
	board.clear_highlights()
	await _resolve_attack(hero, target)
	has_acted = true
	await _beat()
	if _living_monsters().is_empty():
		_finish(true)
		return
	phase = Phase.HERO
	_refresh_hero_ui()
	_end_turn_if_done()


func _end_turn_if_done() -> void:
	if has_acted and has_rolled and moves_left == 0:
		_on_end_turn()


func _on_end_turn() -> void:
	if phase != Phase.HERO:
		return
	phase = Phase.BUSY
	board.clear_highlights()
	_reachable.clear()
	_refresh_hero_ui()
	await _dungeon_turn()


func _refresh_hero_ui() -> void:
	var moves := str(moves_left) if has_rolled else "roll first"
	var action := "used" if has_acted else "ready"
	hud.set_stats("HP %d/%d   ·   AC %d   ·   Moves: %s   ·   Action: %s" % [
		hero.hp, hero.stats.max_hp, hero.stats.armor_class, moves, action])
	var my_turn := phase == Phase.HERO
	hud.set_buttons(my_turn and not has_rolled, my_turn)

	if not my_turn:
		return
	_reachable = {}
	if has_rolled and moves_left > 0:
		_reachable = board.flood(hero.cell, moves_left, _occupied_except(hero))["dist"]
		var cells := _reachable.keys()
		cells.erase(hero.cell)
		board.show_move_cells(cells)
	else:
		board.clear_highlights()
	board.show_door_cells(board.closed_doors_next_to(hero.cell))
	if not has_acted:
		var targets: Array = []
		for m in _living_monsters():
			if Board.are_adjacent(hero.cell, m.cell):
				targets.append(m.cell)
		board.show_attack_cells(targets)


# --- Dungeon turn ----------------------------------------------------------

func _dungeon_turn() -> void:
	hud.set_turn("Round %d  ·  The dungeon stirs" % round_number)
	await _beat()
	var awake := _awake_monsters()
	if not awake.is_empty():
		await hud.show_banner("THE DUNGEON STIRS", "", Hud.BLOOD)
	for m in awake:
		# The monster turns, eyes its prey, and only then acts.
		camera_rig.focus_on(m.position)
		m.face(hero.position)
		await get_tree().create_timer(MONSTER_THINK).timeout
		if not Board.are_adjacent(m.cell, hero.cell):
			var path := board.path_to_adjacent(m.cell, hero.cell, _occupied_except(m))
			if path.size() > m.stats.speed:
				path = path.slice(0, m.stats.speed)
			await m.move_along(path)
			await _beat()
		if Board.are_adjacent(m.cell, hero.cell):
			await _resolve_attack(m, hero)
			if not hero.is_alive():
				_finish(false)
				return
			await _beat()
		else:
			m.face(hero.position)
	round_number += 1
	await _start_hero_turn()


# --- Combat ----------------------------------------------------------------

## d20 + attack bonus against armour class. A natural 20 always hits and
## doubles the damage dice; a natural 1 always misses.
func _resolve_attack(attacker: Figure, defender: Figure) -> void:
	var a := attacker.stats
	var d20 := Dice.roll(20)
	var total := d20 + a.attack_bonus
	await hud.show_dice("%s attacks: d20 + %d vs AC %d" % [a.display_name, a.attack_bonus, defender.stats.armor_class], 20, [d20])
	await _beat()
	Sound.play(a.voice)
	await attacker.play_attack(defender)

	var crit := d20 == 20
	var hit := d20 != 1 and (crit or total >= defender.stats.armor_class)
	var who := "[b]%s[/b]" % a.display_name
	if not hit:
		var why := "a natural 1" if d20 == 1 else "%d" % total
		hud.log_line("%s swings the %s: %s, a miss." % [who, a.weapon_name, why])
		Sound.play("miss")
		defender.show_float_text("Miss", Color(0.8, 0.8, 0.8))
		return

	Sound.play("hit")
	if crit:
		Sound.play("crit")
	var dice_count := a.damage_dice_count * (2 if crit else 1)
	var rolls := Dice.roll_many(dice_count, a.damage_die)
	await hud.show_dice("Damage: %dd%d + %d" % [dice_count, a.damage_die, a.damage_bonus], a.damage_die, rolls)
	var damage := Dice.total(rolls) + a.damage_bonus
	if crit:
		hud.log_line("%s rolls a [color=#f5c040]NATURAL 20[/color]! The %s bites deep for [b]%d[/b] damage." % [who, a.weapon_name, damage])
		defender.show_float_text("CRITICAL!", Color(0.95, 0.75, 0.25))
	else:
		hud.log_line("%s hits with the %s (%d): [b]%d[/b] damage." % [who, a.weapon_name, total, damage])
	await defender.take_damage(damage)
	if not defender.is_alive():
		hud.log_line("[color=#c33]%s falls.[/color]" % defender.stats.display_name)
	_refresh_hero_ui()


# --- Helpers ---------------------------------------------------------------

func _beat() -> void:
	await get_tree().create_timer(BEAT).timeout


func _spawn(stats: UnitStats, cell: Vector2i) -> Figure:
	var f := Figure.new()
	add_child(f)
	f.setup(stats, board, cell)
	return f


func _finish(won: bool) -> void:
	phase = Phase.OVER
	board.clear_highlights()
	if won:
		hud.show_end("VICTORY", QuestCellar.VICTORY, true)
	else:
		hud.show_end("YOU HAVE FALLEN", "Your Fighter's name will not be remembered in Alvia.", false)


func _living_monsters() -> Array[Figure]:
	var alive: Array[Figure] = []
	for m in monsters:
		if m.is_alive():
			alive.append(m)
	return alive


## Living monsters whose room has been revealed; the rest sleep in the dark.
func _awake_monsters() -> Array[Figure]:
	var awake: Array[Figure] = []
	for m in _living_monsters():
		if m.visible:
			awake.append(m)
	return awake


func _monster_at(cell: Vector2i) -> Figure:
	for m in _awake_monsters():
		if m.cell == cell:
			return m
	return null


func _occupied_except(me: Figure) -> Dictionary:
	var occupied := {}
	for f in _living_monsters() + [hero]:
		if f != me and f.is_alive():
			occupied[f.cell] = true
	return occupied


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

