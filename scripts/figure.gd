## A hero or monster standing on the board, like a painted miniature.
## The look is built from simple shapes until we have real models.
class_name Figure
extends Node3D

signal died(figure: Figure)

const STEP_TIME := 0.36
const STEP_PAUSE := 0.08  # a beat between squares, like lifting a miniature again

var stats: UnitStats
var hp := 0
var cell := Vector2i.ZERO
var board: Board

var _body: Node3D
var _label: Label3D
var _body_material: StandardMaterial3D


func setup(unit_stats: UnitStats, on_board: Board, start: Vector2i) -> void:
	stats = unit_stats
	board = on_board
	hp = stats.max_hp
	cell = start
	position = board.cell_to_world(start)
	_build_model()
	_update_label()


func is_alive() -> bool:
	return hp > 0


func move_along(path: Array[Vector2i]) -> void:
	for step in path:
		var target := board.cell_to_world(step)
		face(target)
		var tween := create_tween()
		tween.tween_property(self, "position", target, STEP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# A heavy hop, like moving a miniature by hand, then a thud on landing.
		tween.parallel().tween_property(_body, "position:y", 0.22, STEP_TIME / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(_body, "position:y", 0.0, STEP_TIME / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): Sound.play("step"))
		# Squash a little as it lands.
		tween.tween_property(_body, "scale", Vector3(1.08, 0.9, 1.08), 0.05)
		tween.tween_property(_body, "scale", Vector3.ONE, 0.1)
		await tween.finished
		cell = step
		await get_tree().create_timer(STEP_PAUSE).timeout


func face(target: Vector3) -> void:
	var flat := Vector3(target.x, position.y, target.z)
	if position.distance_to(flat) > 0.01:
		look_at(flat, Vector3.UP)


## Winds up and swings at `target`. Returns at the moment the blow lands;
## call recover() afterwards to step back.
func lunge(target: Figure) -> void:
	face(target.position)
	var tween := create_tween()
	# Rear back and raise the weapon...
	tween.tween_property(_body, "position", Vector3(0, 0, 0.18), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_body, "rotation_degrees:x", 14.0, 0.3)
	tween.tween_interval(0.12)
	# ...then strike hard and fast.
	tween.tween_property(_body, "position", Vector3(0, 0, -0.4), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_body, "rotation_degrees:x", -18.0, 0.08)
	await tween.finished


func recover() -> void:
	var tween := create_tween()
	tween.tween_property(_body, "position", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_body, "rotation_degrees:x", 0.0, 0.3)
	await tween.finished


## Sways aside as a blow from `attacker` goes wide, kicking up dust.
func dodge(attacker: Figure) -> void:
	show_float_text("Miss", Color(0.75, 0.75, 0.75))
	Effects.dust_puff(get_parent(), position + Vector3(0, 0.1, 0))
	var side := (position - attacker.position).normalized().cross(Vector3.UP) * 0.25
	var tween := create_tween()
	tween.tween_property(_body, "global_position", _body.global_position + side, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "position", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_SINE)
	await tween.finished


## Takes a blow from `attacker`: flash, blood, knockback and a damage number.
func take_damage(amount: int, attacker: Figure = null, crit := false) -> void:
	hp = maxi(0, hp - amount)
	_update_label()
	var color := Color(1.0, 0.75, 0.2) if crit else Color(1, 0.25, 0.15)
	show_float_text("-%d" % amount, color, 1.6 if crit else 1.2)
	# A few droplets that land and stay on the floor.
	Effects.blood_pool(get_parent(), position + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), 0.3)
	Sound.play(stats.voice)
	var away := Vector3.BACK.rotated(Vector3.UP, rotation.y)
	if attacker != null:
		away = (position - attacker.position).normalized()
	Effects.blood_burst(get_parent(), position + Vector3(0, stats.model_height * 0.6, 0), away, 40 if crit else 24)

	var tween := create_tween()
	tween.tween_property(_body_material, "emission_energy_multiplier", 4.0, 0.04)
	tween.tween_property(_body_material, "emission_energy_multiplier", 0.0, 0.5)
	var knock := create_tween()
	knock.tween_property(_body, "global_position", _body.global_position + away * (0.35 if crit else 0.2), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	knock.parallel().tween_property(_body, "rotation_degrees:z", randf_range(-12.0, 12.0), 0.08)
	knock.tween_property(_body, "position", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE)
	knock.parallel().tween_property(_body, "rotation_degrees:z", 0.0, 0.4)
	await knock.finished
	if hp == 0:
		await _die()


## A number or word that pops up over the figure, then drifts up and fades.
func show_float_text(text: String, color: Color, size := 1.0) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 64
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = position + Vector3(0, stats.model_height + 0.9, 0)
	label.scale = Vector3.ONE * 0.2
	get_parent().add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector3.ONE * size * 1.4, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE * size, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.5)
	tween.tween_property(label, "position:y", label.position.y + 0.8, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tween.parallel().tween_property(label, "outline_modulate:a", 0.0, 1.0).set_delay(0.3)
	tween.tween_callback(label.queue_free)


func _die() -> void:
	Sound.play(stats.voice, 0.0)
	_label.visible = false
	await get_tree().create_timer(0.25).timeout
	var tween := create_tween()
	# Sag to the knees, then topple.
	tween.tween_property(_body, "scale", Vector3(1.05, 0.85, 1.05), 0.3)
	tween.tween_property(_body, "rotation_degrees:x", -90.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_body, "position:y", 0.12, 0.6)
	tween.parallel().tween_property(_body_material, "albedo_color", stats.color.darkened(0.6), 1.5)
	tween.tween_callback(func(): Sound.play("step", 0.0))
	await tween.finished
	Effects.blood_pool(get_parent(), position)
	Effects.dust_puff(get_parent(), position, 12, 0.4)
	await get_tree().create_timer(0.6).timeout
	died.emit(self)


func _update_label() -> void:
	_label.text = "%s  %d/%d" % [stats.display_name, hp, stats.max_hp]


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
