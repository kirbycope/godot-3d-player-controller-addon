class_name RingCourse
extends Node3D
## A course of rings to fly through in order: each child [Area3D] is a ring, the next one lit, the rest dim.
## A Player passing through the lit ring moves the course on and [signal ring_passed] fires; the last ring
## fires [signal course_finished] with the seconds taken. [method restart] resets it. A ring passed out of order
## does nothing, so the course has to be flown as laid out.

signal ring_passed(index: int, total: int)
signal course_finished(seconds: float)

@export var lit_color: Color = Color(0.4, 0.9, 1.0, 1.0)
@export var next_color: Color = Color(1.0, 0.85, 0.3, 1.0)
@export var dim_color: Color = Color(0.5, 0.5, 0.6, 0.35)

var next_index: int = 0
var started_at: float = -1.0
var finished: bool = false

var _rings: Array[Area3D] = []


func _ready() -> void:
	for child: Node in get_children():
		if child is Area3D:
			_rings.append(child)
			(child as Area3D).body_entered.connect(_on_ring_body_entered.bind(_rings.size() - 1))
	_tint()


func total() -> int:
	return _rings.size()


func restart() -> void:
	next_index = 0
	started_at = -1.0
	finished = false
	_tint()


func _on_ring_body_entered(body: Node3D, index: int) -> void:
	if finished or index != next_index or not body is Player:
		return
	if started_at < 0.0:
		started_at = Time.get_ticks_msec() / 1000.0
	next_index += 1
	ring_passed.emit(index, _rings.size())
	if next_index >= _rings.size():
		finished = true
		course_finished.emit(Time.get_ticks_msec() / 1000.0 - started_at)
	_tint()


func _tint() -> void:
	for i: int in _rings.size():
		var colour: Color = dim_color
		if i == next_index:
			colour = next_color
		elif i < next_index:
			colour = lit_color
		for mesh: Node in _rings[i].find_children("*", "MeshInstance3D", true, false):
			var instance: MeshInstance3D = mesh as MeshInstance3D
			var material: StandardMaterial3D = instance.get_surface_override_material(0) as StandardMaterial3D
			if material == null:
				material = StandardMaterial3D.new()
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.emission_enabled = true
				instance.set_surface_override_material(0, material)
			material.albedo_color = colour
			material.emission = colour
			material.emission_energy_multiplier = 2.0 if i == next_index else 0.6
