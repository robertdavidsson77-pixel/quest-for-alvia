## The game board, built from a quest's text map (see scripts/quests).
## Map legend: # wall, * wall with torch, . floor, H hero start, D door,
## L locked door, S stairs, g goblin, T table, C chest, B bookcase, space = rock.
## Rooms are found automatically: floor squares joined together, bounded by walls
## and doors. Every room starts hidden and is revealed when a door to it opens.
## Grid cells are Vector2i(x, y); the map is centred on the world origin.
class_name Board
extends Node3D

const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const WALL_HEIGHT := 1.4
const ROOM_CHARS := ".HgTCBS"  # squares that belong to a room
const WALKABLE_CHARS := ".Hg"   # room squares you can stand on (the rest is furniture)
const REVEAL_STAGGER := 0.035   # seconds of delay per square of distance from the door

var width := 0
var height := 0
var hero_start := Vector2i.ZERO
var spawns: Array[Dictionary] = []  # {"char": "g", "cell": Vector2i}
var torch_lights: Array[OmniLight3D] = []

var _tiles := {}        # cell -> map character
var _room_of := {}      # cell -> room id, for room squares
var _doors := {}        # cell -> {"locked": bool, "open": bool, "panel": Node3D, "rooms": Array}
var _room_nodes := {}   # room id -> Array of nodes shown when the room is revealed
var _revealed := {}     # room id -> true

var _highlights: Array[MeshInstance3D] = []
var _hover: MeshInstance3D
var _move_material: StandardMaterial3D
var _attack_material: StandardMaterial3D
var _door_material: StandardMaterial3D


func build(map: Array[String]) -> void:
	height = map.size()
	for line in map:
		width = maxi(width, line.length())
	for y in height:
		for x in width:
			var c: String = map[y][x] if x < map[y].length() else " "
			_tiles[Vector2i(x, y)] = c
			if c == "H":
				hero_start = Vector2i(x, y)
			elif c == "g":
				spawns.append({"char": c, "cell": Vector2i(x, y)})
	_find_rooms()

	for cell in _tiles:
		var c: String = _tiles[cell]
		if ROOM_CHARS.contains(c):
			_add_floor(cell)
			_add_furniture(cell, c)
		elif c == "#" or c == "*":
			_add_wall(cell, c == "*")
		elif c == "D" or c == "L":
			_add_door(cell, c == "L")

	_move_material = _highlight_material(Color(0.45, 0.75, 1.0, 0.4))
	_attack_material = _highlight_material(Color(0.85, 0.15, 0.1, 0.45))
	_door_material = _highlight_material(Color(1.0, 0.8, 0.3, 0.5))
	_hover = _make_highlight(_highlight_material(Color(1, 1, 1, 0.25)))
	_hover.visible = false


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x - width / 2.0 + 0.5, 0.0, cell.y - height / 2.0 + 0.5)


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x + width / 2.0), floori(pos.z + height / 2.0))


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_walkable(cell: Vector2i) -> bool:
	var c: String = _tiles.get(cell, " ")
	if WALKABLE_CHARS.contains(c):
		return true
	return _doors.has(cell) and _doors[cell]["open"]


static func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


# --- Rooms and doors -------------------------------------------------------

## The room a square belongs to, or -1 for walls, doors and rock.
func room_at(cell: Vector2i) -> int:
	return _room_of.get(cell, -1)


func is_room_revealed(room: int) -> bool:
	return _revealed.has(room)


func is_door(cell: Vector2i) -> bool:
	return _doors.has(cell)


func is_door_closed(cell: Vector2i) -> bool:
	return _doors.has(cell) and not _doors[cell]["open"]


func is_door_locked(cell: Vector2i) -> bool:
	return _doors.has(cell) and _doors[cell]["locked"]


## Closed doors next to `cell` that can be seen (they border a revealed room).
func closed_doors_next_to(cell: Vector2i) -> Array:
	var found: Array = []
	for d in DIRECTIONS:
		var n: Vector2i = cell + d
		if is_door_closed(n):
			found.append(n)
	return found


## Swings the door open (it sinks into the floor) and reveals the rooms behind it.
func open_door(cell: Vector2i) -> void:
	var door: Dictionary = _doors[cell]
	door["open"] = true
	var panel: Node3D = door["panel"]
	var tween := create_tween()
	tween.tween_property(panel, "position:y", -WALL_HEIGHT, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	panel.visible = false
	for room in door["rooms"]:
		if not is_room_revealed(room):
			await reveal_room(room, cell)


## Shows a room's floor, walls, furniture and torches, rising out of the dark
## outwards from `from_cell`.
func reveal_room(room: int, from_cell: Vector2i) -> void:
	_revealed[room] = true
	var longest := 0.0
	for node in _room_nodes.get(room, []):
		if node.visible:
			continue  # already shown with a neighbouring room
		var delay := Vector2(world_to_cell(node.position)).distance_to(Vector2(from_cell)) * REVEAL_STAGGER
		longest = maxf(longest, delay)
		_pop_in(node, delay)
	await get_tree().create_timer(longest + 0.35).timeout


func _door_seen(cell: Vector2i) -> bool:
	for room in _doors[cell]["rooms"]:
		if is_room_revealed(room):
			return true
	return false


func _pop_in(node: Node3D, delay: float) -> void:
	if node is OmniLight3D:
		# The "fade" meta (0..1) scales the torch flicker while it lights up.
		var light := node as OmniLight3D
		light.set_meta("fade", 0.0)
		light.visible = true
		var lt := create_tween()
		lt.tween_method(func(v: float): light.set_meta("fade", v), 0.0, 1.0, 0.5).set_delay(delay)
		return
	var final_scale := node.scale
	node.scale = Vector3(final_scale.x, 0.01, final_scale.z)
	node.visible = true
	var tween := create_tween()
	tween.tween_property(node, "scale", final_scale, 0.3).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Gives every connected group of room squares its own id.
func _find_rooms() -> void:
	var next_id := 0
	for cell in _tiles:
		if not ROOM_CHARS.contains(_tiles[cell]) or _room_of.has(cell):
			continue
		var queue: Array[Vector2i] = [cell]
		_room_of[cell] = next_id
		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			for d in DIRECTIONS:
				var n: Vector2i = current + d
				if not _room_of.has(n) and ROOM_CHARS.contains(_tiles.get(n, " ")):
					_room_of[n] = next_id
					queue.append(n)
		next_id += 1


## Rooms touching `cell`; walls use all 8 neighbours so corners show too.
func _rooms_around(cell: Vector2i, diagonals: bool) -> Array:
	var rooms: Array = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if (dx == 0 and dy == 0) or (not diagonals and dx != 0 and dy != 0):
				continue
			var room := room_at(cell + Vector2i(dx, dy))
			if room >= 0 and not rooms.has(room):
				rooms.append(room)
	return rooms


func _register(node: Node3D, rooms: Array) -> void:
	node.visible = false
	for room in rooms:
		if not _room_nodes.has(room):
			_room_nodes[room] = []
		_room_nodes[room].append(node)


# --- Movement --------------------------------------------------------------

## Breadth-first search from `start`, never entering walls or `occupied` cells.
## Returns {"dist": {cell: steps}, "parent": {cell: previous cell}}.
func flood(start: Vector2i, max_steps: int, occupied: Dictionary) -> Dictionary:
	var dist := {start: 0}
	var parent := {}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if dist[current] >= max_steps:
			continue
		for d in DIRECTIONS:
			var next: Vector2i = current + d
			if dist.has(next) or not is_walkable(next) or occupied.has(next):
				continue
			dist[next] = dist[current] + 1
			parent[next] = current
			queue.append(next)
	return {"dist": dist, "parent": parent}


## The steps from the flood's start to `goal`, not including the start.
static func path_from_flood(result: Dictionary, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var parent: Dictionary = result["parent"]
	var current := goal
	while parent.has(current):
		path.push_front(current)
		current = parent[current]
	return path


## Shortest path from `start` to any free square next to `target`.
## Empty if there is no way through.
func path_to_adjacent(start: Vector2i, target: Vector2i, occupied: Dictionary) -> Array[Vector2i]:
	var result := flood(start, width * height, occupied)
	var dist: Dictionary = result["dist"]
	var best := Vector2i(-1, -1)
	var best_dist := 1 << 30
	for d in DIRECTIONS:
		var cell: Vector2i = target + d
		if dist.has(cell) and dist[cell] < best_dist:
			best = cell
			best_dist = dist[cell]
	if best_dist == 1 << 30:
		return []
	return path_from_flood(result, best)


# --- Highlights ------------------------------------------------------------

func show_move_cells(cells: Array) -> void:
	_show_cells(cells, _move_material)


func show_attack_cells(cells: Array) -> void:
	_show_cells(cells, _attack_material, false)


func show_door_cells(cells: Array) -> void:
	_show_cells(cells, _door_material, false)


func clear_highlights() -> void:
	for h in _highlights:
		h.queue_free()
	_highlights.clear()


func set_hover(cell: Vector2i) -> void:
	_hover.visible = is_room_revealed(room_at(cell)) or (is_door(cell) and _door_seen(cell))
	if _hover.visible:
		_hover.position = cell_to_world(cell) + Vector3(0, 0.02, 0)


func _show_cells(cells: Array, material: StandardMaterial3D, clear_first := true) -> void:
	if clear_first:
		clear_highlights()
	for cell in cells:
		var h := _make_highlight(material)
		h.position = cell_to_world(cell) + Vector3(0, 0.01, 0)
		_highlights.append(h)


func _make_highlight(material: StandardMaterial3D) -> MeshInstance3D:
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var m := MeshInstance3D.new()
	m.mesh = quad
	m.material_override = material
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


# --- Building pieces -------------------------------------------------------

func _add_floor(cell: Vector2i) -> void:
	var shade := randf_range(0.17, 0.24)
	var tile := _box(Vector3(0.96, 0.1, 0.96), Color(shade, shade * 0.95, shade * 0.9))
	tile.position = cell_to_world(cell) + Vector3(0, -0.05, 0)
	_register(tile, [room_at(cell)])


## Placeholder furniture: simple boxes until we have real models.
func _add_furniture(cell: Vector2i, c: String) -> void:
	var base := cell_to_world(cell)
	var room := [room_at(cell)]
	match c:
		"T":  # table
			var table := _box(Vector3(0.95, 0.55, 0.85), Color(0.3, 0.18, 0.1))
			table.position = base + Vector3(0, 0.275, 0)
			_register(table, room)
		"C":  # chest
			var chest := _box(Vector3(0.65, 0.45, 0.45), Color(0.35, 0.2, 0.08))
			chest.position = base + Vector3(0, 0.225, 0)
			_register(chest, room)
			var band := _box(Vector3(0.67, 0.08, 0.47), Color(0.7, 0.55, 0.2))
			band.position = base + Vector3(0, 0.3, 0)
			_register(band, room)
		"B":  # bookcase
			var shelf := _box(Vector3(0.9, 1.4, 0.4), Color(0.22, 0.13, 0.08))
			shelf.position = base + Vector3(0, 0.7, 0)
			_register(shelf, room)
		"S":  # stairs, climbing towards the nearest wall
			var up := Vector2i.DOWN
			for d in DIRECTIONS:
				var n: Vector2i = cell + d
				if _tiles.get(n, " ") == "#" or _tiles.get(n, " ") == "*":
					up = d
					break
			for i in 4:
				var step := _box(Vector3(0.95, 0.25 * (i + 1), 0.25), Color(0.2, 0.19, 0.18))
				var along := -0.375 + 0.25 * i
				step.position = base + Vector3(up.x * along, 0.125 * (i + 1), up.y * along)
				if up.x != 0:
					step.rotation_degrees.y = 90
				_register(step, room)


func _add_wall(cell: Vector2i, torch: bool) -> void:
	var rooms := _rooms_around(cell, true)
	if rooms.is_empty():
		return  # buried in rock, never seen
	var wall := _box(Vector3(1.0, WALL_HEIGHT, 1.0), Color(0.13, 0.12, 0.12))
	wall.position = cell_to_world(cell) + Vector3(0, WALL_HEIGHT / 2.0 - 0.1, 0)
	_register(wall, rooms)
	if torch:
		_add_torch(cell)


func _add_torch(cell: Vector2i) -> void:
	var inward := Vector2i.ZERO
	for d in DIRECTIONS:
		if room_at(cell + d) >= 0:
			inward = d
			break
	var dir := Vector3(inward.x, 0, inward.y)
	var pos := cell_to_world(cell) + dir * 0.55 + Vector3(0, 1.1, 0)
	var rooms := [room_at(cell + inward)]

	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1, 0.6, 0.2)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1, 0.5, 0.15)
	flame_mat.emission_energy_multiplier = 4.0
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.08
	flame_mesh.height = 0.2
	var flame := MeshInstance3D.new()
	flame.mesh = flame_mesh
	flame.material_override = flame_mat
	flame.position = pos
	add_child(flame)
	_register(flame, rooms)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.25)
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.shadow_enabled = true
	light.position = pos + dir * 0.2
	add_child(light)
	_register(light, rooms)
	torch_lights.append(light)


func _add_door(cell: Vector2i, locked: bool) -> void:
	var rooms := _rooms_around(cell, false)
	_add_floor_under_door(cell, rooms)
	# The door runs along the wall line: walls to its left and right, or above and below.
	var along_x := _is_wall(cell + Vector2i.LEFT) or _is_wall(cell + Vector2i.RIGHT)
	var size := Vector3(0.9, WALL_HEIGHT - 0.1, 0.12) if along_x else Vector3(0.12, WALL_HEIGHT - 0.1, 0.9)
	var color := Color(0.25, 0.15, 0.08) if not locked else Color(0.18, 0.1, 0.06)
	var panel := _box(size, color)
	panel.position = cell_to_world(cell) + Vector3(0, (WALL_HEIGHT - 0.1) / 2.0, 0)
	_register(panel, rooms)
	if locked:
		var bar := _box(Vector3(size.x + 0.04, 0.12, size.z + 0.04), Color(0.4, 0.4, 0.42))
		bar.position = Vector3(0, 0.1, 0)
		bar.reparent(panel, false)
	# Frame posts so the doorway reads as part of the wall.
	for side in [-1, 1]:
		var post := _box(Vector3(0.08, WALL_HEIGHT, 0.08), Color(0.1, 0.09, 0.09))
		var offset := Vector3(0.48 * side, 0, 0) if along_x else Vector3(0, 0, 0.48 * side)
		post.position = cell_to_world(cell) + offset + Vector3(0, WALL_HEIGHT / 2.0 - 0.1, 0)
		_register(post, rooms)
	_doors[cell] = {"locked": locked, "open": false, "panel": panel, "rooms": rooms}


func _add_floor_under_door(cell: Vector2i, rooms: Array) -> void:
	var tile := _box(Vector3(0.96, 0.1, 0.96), Color(0.16, 0.15, 0.14))
	tile.position = cell_to_world(cell) + Vector3(0, -0.05, 0)
	_register(tile, rooms)


func _is_wall(cell: Vector2i) -> bool:
	var c: String = _tiles.get(cell, " ")
	return c == "#" or c == "*"


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _stone_material(color)
	add_child(m)
	return m


static func _stone_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	return mat


static func _highlight_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
