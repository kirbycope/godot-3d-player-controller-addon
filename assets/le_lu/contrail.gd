# Based on Trail3D.gd in the [VFX Magic Projecticles (Premium)](https://leluvfx.gumroad.com/l/magic_projectiles_godot)
extends MeshInstance3D

@export var from_width: float = 0.05
@export var to_width: float = 0.0
@export var lifespan: float = 1.0
@export var point_spacing: float = 0.06
@export_range(0.0, 1.0) var wing_axis_smoothing: float = 0.35
@export_range(0.0, 1.0) var side_smoothing: float = 0.55
@export_range(0, 4, 1) var smoothing_passes: int = 1
@export var use_texture_uv: bool = true
@export var uv_tile_length: float = 0.35
@export var force_double_sided_geometry: bool = true
@export var left_wing_path: NodePath = NodePath("../LeftWing")
@export var right_wing_path: NodePath = NodePath("../RightWing")
@export var start_color: Color = Color(1, 1, 1, 0.1)
@export var end_color: Color = Color(1, 1, 1, 0)

var _points = []
var _ages = []
var _sides = []
var _last_side: Vector3 = Vector3.RIGHT

var _left_wing: Node3D
var _right_wing: Node3D

func _ready():
	mesh = ImmediateMesh.new()
	_resolve_wings()

func _process(delta: float):
	var i = 0
	while i < _ages.size():
		_ages[i] += delta
		if _ages[i] > lifespan:
			_ages.remove_at(i)
			_points.remove_at(i)
			_sides.remove_at(i)
			continue
		i += 1

	_append_sample_points(global_position, _get_current_side())
		
	mesh.clear_surfaces()
	if _points.size() < 2: return

	_draw_strip()

func _append_sample_points(current_pos: Vector3, current_side: Vector3):
	if _points.is_empty():
		_points.append(current_pos)
		_ages.append(0.0)
		_sides.append(current_side)
		return

	var spacing = maxf(point_spacing, 0.001)
	var last_idx = _points.size() - 1
	var last_point = _points[_points.size() - 1]
	var last_side = _sides[_sides.size() - 1]
	var delta_vec = current_pos - last_point
	var dist = delta_vec.length()
	if dist < spacing:
		_points[last_idx] = current_pos
		_sides[last_idx] = current_side
		_ages[last_idx] = 0.0
		return

	var dir = delta_vec / dist
	var travel = spacing
	var inserted = 0
	while travel <= dist and inserted < 64:
		var t = travel / dist
		var side = last_side.lerp(current_side, t)
		if side.length_squared() < 0.00001:
			side = current_side
		side = side.normalized()

		_points.append(last_point + dir * travel)
		_ages.append(0.0)
		_sides.append(side)
		travel += spacing
		inserted += 1

func _resolve_wings():
	_left_wing = get_node_or_null(left_wing_path) as Node3D
	_right_wing = get_node_or_null(right_wing_path) as Node3D

	if _left_wing == null and get_parent() != null:
		_left_wing = get_parent().get_node_or_null("LeftWing") as Node3D
	if _right_wing == null and get_parent() != null:
		_right_wing = get_parent().get_node_or_null("RightWing") as Node3D

func _get_current_side() -> Vector3:
	if _left_wing == null or _right_wing == null:
		_resolve_wings()

	var side = _last_side
	if _left_wing != null and _right_wing != null:
		var wing_delta = _right_wing.global_position - _left_wing.global_position
		if wing_delta.length_squared() > 0.00001:
			side = wing_delta.normalized()
	else:
		side = global_basis.x.normalized()

	if side.length_squared() < 0.00001:
		side = Vector3.RIGHT

	if _last_side.length_squared() > 0.0 and side.dot(_last_side) < 0.0:
		side = -side

	if wing_axis_smoothing > 0.0 and _last_side.length_squared() > 0.0:
		side = _last_side.slerp(side, wing_axis_smoothing).normalized()

	_last_side = side
	return side

func _draw_strip():
	var draw_sides = _build_draw_sides()
	var uv_u = _build_uv_u()
	_draw_strip_pass(draw_sides, uv_u, false)
	if force_double_sided_geometry:
		_draw_strip_pass(draw_sides, uv_u, true)

func _draw_strip_pass(draw_sides: Array, uv_u: Array, flip_winding: bool):
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	for iter_idx in range(_points.size()):
		var p_idx = _points.size() - 1 - iter_idx
		var t = _ages[p_idx] / lifespan
		var width = lerp(from_width, to_width, t)
		var c = start_color.lerp(end_color, t)
		var p = _points[p_idx]
		var side = draw_sides[p_idx] * (width * 0.5)
		var u = uv_u[p_idx]
		var v0 = to_local(p + side)
		var v1 = to_local(p - side)
		if flip_winding:
			var tmp = v0
			v0 = v1
			v1 = tmp

		mesh.surface_set_color(c)
		if use_texture_uv:
			mesh.surface_set_uv(Vector2(u, 0.0))
		mesh.surface_add_vertex(v0)
		mesh.surface_set_color(c)
		if use_texture_uv:
			mesh.surface_set_uv(Vector2(u, 1.0))
		mesh.surface_add_vertex(v1)

	mesh.surface_end()

func _build_uv_u() -> Array:
	var result = []
	result.resize(_points.size())

	if _points.size() == 0:
		return result

	var tile_len = maxf(uv_tile_length, 0.001)
	var accum = 0.0
	result[_points.size() - 1] = 0.0

	for i in range(_points.size() - 2, -1, -1):
		accum += _points[i + 1].distance_to(_points[i])
		result[i] = accum / tile_len

	return result

func _build_draw_sides() -> Array:
	var result = []
	result.resize(_sides.size())
	for i in range(_sides.size()):
		result[i] = _sides[i]

	var passes = maxi(smoothing_passes, 0)
	for _pass_idx in range(passes):
		var pass_sides = []
		pass_sides.resize(result.size())
		for i in range(result.size()):
			var side = result[i]

			if i > 0 and i < result.size() - 1:
				side = (result[i - 1] + result[i] * 2.0 + result[i + 1]).normalized()

			var tangent = _get_tangent(i)
			side -= tangent * side.dot(tangent)

			if side.length_squared() < 0.00001:
				side = tangent.cross(global_basis.y.normalized())
			if side.length_squared() < 0.00001:
				side = tangent.cross(Vector3.RIGHT)
			side = side.normalized()

			if i > 0 and side.dot(pass_sides[i - 1]) < 0.0:
				side = -side

			if i > 0 and side_smoothing > 0.0:
				side = pass_sides[i - 1].slerp(side, side_smoothing).normalized()

			pass_sides[i] = side

		result = pass_sides

	return result

func _get_tangent(p_idx: int) -> Vector3:
	if _points.size() < 2:
		return Vector3.FORWARD

	var tangent = Vector3.FORWARD
	if p_idx > 0 and p_idx < _points.size() - 1:
		tangent = (_points[p_idx + 1] - _points[p_idx - 1]).normalized()
	elif p_idx > 0:
		tangent = (_points[p_idx] - _points[p_idx - 1]).normalized()
	elif p_idx < _points.size() - 1:
		tangent = (_points[p_idx + 1] - _points[p_idx]).normalized()

	if tangent.length_squared() < 0.00001:
		return Vector3.FORWARD
	return tangent
