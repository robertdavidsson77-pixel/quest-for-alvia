## A hero or monster standing on the board, like a painted miniature.
## The look is built from simple shapes until we have real models.
class_name Figure
extends Node3D

signal died(figure: Figure)

const STEP_TIME := 0.18

var stats: UnitStats
var hp := 0
var cell := Vector2i.ZERO
var board: Board
var is_ai := false
var card_uses := {}  # CardData -> uses left this quest
var sleep_turns := 0
var bless_until_round := 0

var _body: Node3D
var _label: Label3D
var _body_material: StandardMaterial3D
var _ring: MeshInstance3D


func setup(unit_stats: UnitStats, on_board: Board, start: Vector2i) -> void:
	stats = unit_stats
	board = on_board
	hp = stats.max_hp
	cell = start
	position = board.cell_to_world(start)
	for card in stats.cards:
		card_uses[card] = card.uses_per_quest
	_build_model()
	_update_label()


func is_alive() -> bool:
	return hp > 0


func can_play(card: CardData) -> bool:
	return card.timing == CardData.Timing.AT_WILL or card_uses.get(card, 0) > 0


func spend(card: CardData) -> void:
	if card.timing == CardData.Timing.PER_QUEST:
		card_uses[card] = maxi(0, card_uses.get(card, 0) - 1)


## Shows or hides the glowing ring that marks whose turn it is.
func set_active(active: bool) -> void:
	_ring.visible = active


func heal(amount: int) -> void:
	var before := hp
	hp = mini(stats.max_hp, hp + amount)
	_update_label()
	show_float_text("+%d" % (hp - before), Color(0.4, 1.0, 0.5))


func fall_asleep(turns: int) -> void:
	sleep_turns = turns
	_update_label()
	show_float_text("Zzz", Color(0.6, 0.7, 1.0))


## One dungeon turn spent asleep.
func sleep_tick() -> void:
	sleep_turns -= 1
	_update_label()
	show_float_text("Zzz" if sleep_turns > 0 else "Wakes!", Color(0.6, 0.7, 1.0))


func wake() -> void:
	if sleep_turns > 0:
		sleep_turns = 0
		_update_label()


func move_along(path: Array[Vector2i]) -> void:
	for step in path:
		var target := board.cell_to_world(step)
		face(target)
		var tween := create_tween()
		tween.tween_property(self, "position", target, STEP_TIME)
		# A little hop, like moving a miniature by hand.
		tween.parallel().tween_property(_body, "position:y", 0.15, STEP_TIME / 2.0)
		tween.chain().tween_property(_body, "position:y", 0.0, STEP_TIME / 2.0)
		await tween.finished
		cell = step


func face(target: Vector3) -> void:
	var flat := Vector3(target.x, position.y, target.z)
	if position.distance_to(flat) > 0.01:
		look_at(flat, Vector3.UP)


func play_attack(target: Figure) -> void:
	face(target.position)
	var lunge := Vector3(0, 0, -0.35)  # forward, since we now face the target
	var tween := create_tween()
	tween.tween_property(_body, "position", lunge, 0.1).as_relative()
	tween.tween_property(_body, "position", -lunge, 0.15).as_relative()
	await tween.finished


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	sleep_turns = 0
	_update_label()
	show_float_text("-%d" % amount, Color(1, 0.3, 0.2))
	var tween := create_tween()
	tween.tween_property(_body_material, "emission_energy_multiplier", 2.0, 0.05)
	tween.tween_property(_body_material, "emission_energy_multiplier", 0.0, 0.25)
	if hp == 0:
		await _die()


func show_float_text(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 64
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = position + Vector3(0, stats.model_height + 0.9, 0)
	get_parent().add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 0.8, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.tween_callback(label.queue_free)


func _die() -> void:
	_label.visible = false
	_ring.visible = false
	var tween := create_tween()
	tween.tween_property(_body, "rotation_degrees:x", -90.0, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_body, "position:y", 0.12, 0.4)
	await tween.finished
	died.emit(self)


func _update_label() -> void:
	_label.text = "%s  %d/%d%s" % [stats.display_name, hp, stats.max_hp, "  (asleep)" if sleep_turns > 0 else ""]


func _build_model() -> void:
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.08, 0.07, 0.07)
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.36
	base_mesh.bottom_radius = 0.4
	base_mesh.height = 0.08
	var base := MeshInstance3D.new()
	base.mesh = base_mesh
	base.material_override = base_mat
	base.position.y = 0.04
	add_child(base)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.8, 0.35)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.7, 0.25)
	ring_mat.emission_energy_multiplier = 2.0
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.4
	ring_mesh.outer_radius = 0.46
	_ring = MeshInstance3D.new()
	_ring.mesh = ring_mesh
	_ring.material_override = ring_mat
	_ring.position.y = 0.05
	_ring.visible = false
	add_child(_ring)

	_body = Node3D.new()
	add_child(_body)

	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = stats.color
	_body_material.roughness = 0.7
	_body_material.emission_enabled = true
	_body_material.emission = Color(1, 0.2, 0.1)
	_body_material.emission_energy_multiplier = 0.0

	var h := stats.model_height
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.2 * h + 0.04
	torso_mesh.height = 0.75 * h
	var torso := MeshInstance3D.new()
	torso.mesh = torso_mesh
	torso.material_override = _body_material
	torso.position.y = 0.08 + torso_mesh.height / 2.0
	_body.add_child(torso)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.14 * h + 0.02
	head_mesh.height = head_mesh.radius * 2.0
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.material_override = _body_material
	head.position.y = 0.08 + torso_mesh.height + head_mesh.radius * 0.8
	_body.add_child(head)

	# The weapon points forward (-Z), so you can see which way a figure faces.
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.75, 0.75, 0.78)
	blade_mat.metallic = 0.8
	blade_mat.roughness = 0.3
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.05, 0.05, 0.55 * h)
	var blade := MeshInstance3D.new()
	blade.mesh = blade_mesh
	blade.material_override = blade_mat
	blade.position = Vector3(0.22 * h + 0.06, 0.08 + torso_mesh.height * 0.55, -0.25 * h)
	_body.add_child(blade)

	_label = Label3D.new()
	_label.font_size = 40
	_label.outline_size = 10
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = h + 0.6
	add_child(_label)
