## One-shot visual effects in the world: blood, dust, pools. Each effect adds
## itself to `parent` and frees itself when it is done.
class_name Effects
extends RefCounted

const BLOOD := Color(0.6, 0.03, 0.03)
const DUST := Color(0.45, 0.4, 0.35, 0.6)


## A spray of blood droplets from `pos`, thrown mostly along `direction`.
static func blood_burst(parent: Node, pos: Vector3, direction: Vector3, amount := 28) -> void:
	var p := _particles(amount, 0.9)
	p.position = pos
	p.direction = (direction.normalized() + Vector3.UP * 0.6).normalized()
	p.spread = 35.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.14
	p.mesh = _sphere(BLOOD, 0.5)
	_fire(parent, p)


## A low puff of grey dust around `pos`, for misses and doors.
static func dust_puff(parent: Node, pos: Vector3, amount := 18, radius := 0.3) -> void:
	var p := _particles(amount, 1.1)
	p.position = pos
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, -0.4, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.25
	var fade := Gradient.new()
	fade.set_color(0, DUST)
	fade.set_color(1, Color(DUST, 0.0))
	p.color_ramp = fade
	p.mesh = _sphere(Color.WHITE, 1.0, true)
	_fire(parent, p)


## A dark pool that slowly spreads under a fallen figure, and stays.
static func blood_pool(parent: Node, pos: Vector3, size := 1.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.01, 0.01)
	mat.roughness = 0.15
	mat.metallic = 0.3
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.42
	mesh.height = 0.01
	var pool := MeshInstance3D.new()
	pool.mesh = mesh
	pool.material_override = mat
	pool.position = Vector3(pos.x, 0.015, pos.z)
	pool.scale = Vector3(0.05, 1, 0.05)
	pool.rotation.y = randf() * TAU
	parent.add_child(pool)
	var tween := pool.create_tween()
	tween.tween_property(pool, "scale", Vector3(1.3, 1, 1.0) * size, 2.5 * size).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func _particles(amount: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	return p


static func _sphere(color: Color, size: float, use_vertex_color := false) -> SphereMesh:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.3
	if use_vertex_color:
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = mat
	return mesh


static func _fire(parent: Node, p: CPUParticles3D) -> void:
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
