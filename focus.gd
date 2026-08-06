class_name Focus
extends Node
## Acquires and releases the lock-on focus target while the focus action is held.

@export var player: Player
@export var target_detection: Area3D ## Area used to find nearby focusable bodies.
@export var focus_target_marker: Marker3D ## Template marker duplicated onto the focused target.

var current_focus_target: Node3D = null ## The body currently locked on to, if any.
var current_focus_marker: Marker3D = null ## The marker instance attached to the focused body.


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_physics_process(is_multiplayer_authority())


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	if player == null:
		return

	if player.is_focusing:
		if not is_instance_valid(current_focus_target):
			_clear_focus_target()
			_acquire_focus_target()
	elif current_focus_target != null:
		_clear_focus_target()


## Locks on to the first focusable body overlapping the target detection area.
func _acquire_focus_target() -> void:
	for body in target_detection.get_overlapping_bodies():
		if body.is_in_group("Target") or body.is_in_group("Focusable") or "Guy" in body.name:
			current_focus_target = body
			current_focus_marker = focus_target_marker.duplicate() as Marker3D
			body.add_child(current_focus_marker)
			current_focus_marker.visible = true
			break


## Releases the current target and frees its marker.
func _clear_focus_target() -> void:
	if is_instance_valid(current_focus_marker):
		current_focus_marker.queue_free()
	current_focus_target = null
	current_focus_marker = null
