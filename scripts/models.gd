## Loading the 3D models in res://models (see models/CREDITS.md).
## The OpenDungeons models come in many sizes, so they are measured and scaled
## to fit the board.
class_name Models
extends RefCounted


## A model scaled so its widest side is `width`, standing on the floor and
## centred on its parent's origin. With `top` the model's top sits at the
## origin instead (for floor tiles).
static func fitted(path: String, width: float, top := false) -> Node3D:
	var model: Node3D = load(path).instantiate()
	var box := bounds(model)
	var s := width / maxf(box.size.x, box.size.z)
	model.scale = Vector3.ONE * s
	var c := box.get_center()
	model.position = -Vector3(c.x, box.end.y if top else box.position.y, c.z) * s
	return model


## The box around all meshes in `node`, in its own space (rest pose).
static func bounds(node: Node, xf := Transform3D.IDENTITY) -> AABB:
	var out := AABB()
	var first := true
	for child in node.get_children():
		var child_xf := xf
		if child is Node3D:
			child_xf = xf * child.transform
		var box := bounds(child, child_xf)
		if child is MeshInstance3D:
			box = child_xf * (child as MeshInstance3D).get_aabb()
		if box.size != Vector3.ZERO:
			out = box if first else out.merge(box)
			first = false
	return out
