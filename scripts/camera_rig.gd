## Dungeon Keeper style camera that orbits around a point on the board.
## Right mouse drag: rotate and tilt freely.   Q / E (hold): rotate.
## R / F (hold): tilt.   Mouse wheel: zoom.   W A S D: pan.
## T: toggle a straight top-down view.   C: reset the view.
class_name CameraRig
extends Node3D

@export var start_yaw := 30.0
@export var start_pitch := -55.0
@export var start_distance := 15.0
@export var min_pitch := -88.0
@export var max_pitch := -15.0
@export var min_distance := 4.0
@export var max_distance := 24.0
@export var pan_speed := 8.0
@export var key_rotate_speed := 120.0  # degrees per second
@export var mouse_sensitivity := 0.3   # degrees per pixel

var camera: Camera3D

var _yaw := 0.0
var _pitch := 0.0
var _distance := 0.0
var _target_yaw := 0.0
var _target_pitch := 0.0
var _target_distance := 0.0
var _target_position := Vector3.ZERO
var _dragging := false
var _saved_pitch := 0.0  # pitch to return to when leaving top-down view


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 50.0
	add_child(camera)
	reset_view()
	_yaw = _target_yaw
	_pitch = _target_pitch
	_distance = _target_distance
	_apply()


func reset_view() -> void:
	_target_yaw = start_yaw
	_target_pitch = start_pitch
	_target_distance = start_distance
	_target_position = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = maxf(min_distance, _target_distance - 1.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = minf(max_distance, _target_distance + 1.0)
	elif event is InputEventMouseMotion and _dragging:
		_target_yaw -= event.relative.x * mouse_sensitivity
		_target_pitch = clampf(_target_pitch - event.relative.y * mouse_sensitivity, min_pitch, max_pitch)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			reset_view()
		elif event.keycode == KEY_T:
			_toggle_top_down()


func _process(delta: float) -> void:
	# Held keys: rotate and tilt smoothly.
	if Input.is_physical_key_pressed(KEY_Q):
		_target_yaw -= key_rotate_speed * delta
	if Input.is_physical_key_pressed(KEY_E):
		_target_yaw += key_rotate_speed * delta
	if Input.is_physical_key_pressed(KEY_R):
		_target_pitch = clampf(_target_pitch - key_rotate_speed * 0.5 * delta, min_pitch, max_pitch)
	if Input.is_physical_key_pressed(KEY_F):
		_target_pitch = clampf(_target_pitch + key_rotate_speed * 0.5 * delta, min_pitch, max_pitch)

	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		input.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		input.x += 1
	if Input.is_physical_key_pressed(KEY_W):
		input.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		input.y += 1
	if input != Vector2.ZERO:
		# Pan relative to where the camera is looking, faster when zoomed out.
		var move := Vector3(input.x, 0, input.y).normalized().rotated(Vector3.UP, deg_to_rad(_yaw))
		_target_position += move * pan_speed * (_distance / start_distance) * delta

	var smooth := 1.0 - exp(-12.0 * delta)
	_yaw = lerpf(_yaw, _target_yaw, smooth)
	_pitch = lerpf(_pitch, _target_pitch, smooth)
	_distance = lerpf(_distance, _target_distance, smooth)
	position = position.lerp(_target_position, smooth)
	_apply()


## Glides the camera to look at a point on the board, keeping angle and zoom.
func focus_on(point: Vector3) -> void:
	_target_position = Vector3(point.x, 0, point.z)


## The point on the floor (y = 0) under a screen position, or null.
func floor_point(screen_pos: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)


func _toggle_top_down() -> void:
	if _target_pitch <= min_pitch + 0.5:
		_target_pitch = _saved_pitch
	else:
		_saved_pitch = _target_pitch
		_target_pitch = min_pitch


func _apply() -> void:
	rotation_degrees = Vector3(0, _yaw, 0)
	var pitch := deg_to_rad(_pitch)
	camera.position = Vector3(0, -sin(pitch) * _distance, cos(pitch) * _distance)
	camera.rotation = Vector3(pitch, 0, 0)
