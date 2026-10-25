## The game board: a grid of stone tiles with walls and pillars.
## Grid cells are Vector2i(x, y); the board is centred on the world origin.
class_name Board
extends Node3D

const DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const WALL_HEIGHT := 1.4

var width := 0
var height := 0
var blocked := {}  # Vector2i -> true for pillars and other solid squares

var _highlights: Array[MeshInstance3D] = []
var _hover: MeshInstance3D
var _move_material: StandardMaterial3D
var _attack_material: StandardMaterial3D


func build(w: int, h: int, pillars: Array[Vector2i]) -> void:
	width = w
	height = h
	for p in pillars:
		blocked[p] = true

	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(0.96, 0.1, 0.96)
	for x in width:
		for y in height:
			var cell := Vector2i(x, y)
			if blocked.has(cell):
				_add_pillar(cell)
				continue
			var tile := MeshInstance3D.new()
			tile.mesh = tile_mesh
			var shade := randf_range(0.17, 0.24)
			tile.material_override = _stone_material(Color(shade, shade * 0.95, shade * 0.9))
			tile.position = cell_to_world(cell) + Vector3(0, -0.05, 0)
			add_child(tile)

	# Walls all the way around the room.
	for x in range(-1, width + 1):
		_add_wall(Vector2i(x, -1))
		_add_wall(Vector2i(x, height))
	for y in height:
		_add_wall(Vector2i(-1, y))
		_add_wall(Vector2i(width, y))

	_move_material = _highlight_material(Color(0.45, 0.75, 1.0, 0.4))
	_attack_material = _highlight_material(Color(0.85, 0.15, 0.1, 0.45))
	_hover = _make_highlight(_highlight_material(Color(1, 1, 1, 0.25)))
	_hover.visible = false


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x - width / 2.0 + 0.5, 0.0, cell.y - height / 2.0 + 0.5)


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x + width / 2.0), floori(pos.z + height / 2.0))


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_walkable(cell: Vector2i) -> bool:
	return is_inside(cell) and not blocked.has(cell)


static func are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


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


func show_move_cells(cells: Array) -> void:
	_show_cells(cells, _move_material)


func show_attack_cells(cells: Array) -> void:
	_show_cells(cells, _attack_material, false)


func clear_highlights() -> void:
	for h in _highlights:
		h.queue_free()
	_highlights.clear()


func set_hover(cell: Vector2i) -> void:
	_hover.visible = is_walkable(cell)
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


func _add_wall(cell: Vector2i) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1.0, WALL_HEIGHT, 1.0)
	var wall := MeshInstance3D.new()
	wall.mesh = box
	wall.material_override = _stone_material(Color(0.13, 0.12, 0.12))
	wall.position = cell_to_world(cell) + Vector3(0, WALL_HEIGHT / 2.0 - 0.1, 0)
	add_child(wall)


func _add_pillar(cell: Vector2i) -> void:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.4
	cyl.height = WALL_HEIGHT + 0.6
	var pillar := MeshInstance3D.new()
	pillar.mesh = cyl
	pillar.material_override = _stone_material(Color(0.16, 0.15, 0.15))
	pillar.position = cell_to_world(cell) + Vector3(0, cyl.height / 2.0 - 0.1, 0)
	add_child(pillar)


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
