class_name Focus
extends Node
## Acquires, cycles, and releases the lock-on focus target while the focus action is held.

@export var player: Player
@export var target_detection: Area3D ## Area used to find nearby focusable bodies.
@export var focus_target_marker: Marker3D ## Template marker duplicated onto the focused target.
@export var max_focus_distance: float = 25.0 ## Maximum distance before losing target lock-on.
@export var target_loss_grace_time: float = 0.5 ## Grace duration (seconds) before losing lock if out of range/area.

var current_focus_target: Node3D = null ## The body currently locked on to, if any.
var current_focus_marker: Marker3D = null ## The marker instance attached to the focused body.
var target_loss_timer: float = 0.0 ## Timer tracking duration the current target has been out of range/area.


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process_input(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	if player == null or player.is_paused or player.is_ragdolling:
		return

	# If focus is tapped while already locked on and holding a non-firearm, cycle to the next target
	if event.is_action_pressed("focus") and not event.is_echo():
		if not player.has_firearm_equipped and is_instance_valid(current_focus_target):
			cycle_focus_target(1)


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if player == null:
		return

	# If holding a firearm, free-aiming is used instead of lock-on targeting
	if player.has_firearm_equipped:
		if current_focus_target != null:
			_clear_focus_target()
		return

	if player.is_focusing:
		if not is_instance_valid(current_focus_target):
			_clear_focus_target()
			_acquire_focus_target()
		else:
			# Check distance and detection area presence
			var dist: float = player.global_position.distance_to(current_focus_target.global_position)
			var in_area: bool = target_detection == null or target_detection.overlaps_body(current_focus_target)
			if dist > max_focus_distance or not in_area:
				target_loss_timer += delta
				if target_loss_timer >= target_loss_grace_time:
					_clear_focus_target()
					_acquire_focus_target()
			else:
				target_loss_timer = 0.0

			if is_instance_valid(current_focus_marker) and is_instance_valid(current_focus_target):
				var target_pos: Vector3 = get_focus_target_position(current_focus_target)
				current_focus_marker.global_position = target_pos + Vector3(0, 0.4, 0)
	elif current_focus_target != null:
		_clear_focus_target()


## Returns the focus target marker node or focus point for the given body.
static func get_focus_target_node(body: Node3D) -> Node3D:
	if not is_instance_valid(body):
		return null
	var marker: Node3D = body.get_node_or_null("%Marker3D_FocusTarget") as Node3D
	if marker:
		return marker
	marker = body.get_node_or_null("%GeneralSkeleton/BoneAttachment3D/Marker3D_FocusTarget") as Node3D
	if marker:
		return marker
	marker = body.get_node_or_null("Mannequin_M/Armature/GeneralSkeleton/BoneAttachment3D/Marker3D_FocusTarget") as Node3D
	if marker:
		return marker
	marker = body.get_node_or_null("GeneralSkeleton/BoneAttachment3D/Marker3D_FocusTarget") as Node3D
	if marker:
		return marker
	marker = body.find_child("Marker3D_FocusTarget", true, false) as Node3D
	if marker:
		return marker
	return null


## Returns the global 3D position to focus on for the given body.
static func get_focus_target_position(body: Node3D) -> Vector3:
	if not is_instance_valid(body):
		return Vector3.ZERO
	var marker: Node3D = get_focus_target_node(body)
	if marker:
		return marker.global_position
	var col = body.find_child("CollisionShape3D", true, false) as CollisionShape3D
	if col:
		return col.global_position
	return body.global_position


## Returns all valid focusable bodies sorted by horizontal angular proximity to camera center.
func get_focusable_targets() -> Array[Node3D]:
	var candidates: Array[Node3D] = []
	var pool: Array[Node] = []
	if target_detection:
		pool.append_array(target_detection.get_overlapping_bodies())
	if get_tree():
		for node in get_tree().get_nodes_in_group("Target"):
			if not pool.has(node):
				pool.append(node)
		for node in get_tree().get_nodes_in_group("Focusable"):
			if not pool.has(node):
				pool.append(node)

	for body in pool:
		if not is_instance_valid(body) or body == player or not (body is Node3D):
			continue
		if body.is_in_group("Target") or body.is_in_group("Focusable") or "Guy" in body.name:
			var d: float = player.global_position.distance_to(body.global_position) if player else 0.0
			if d <= max_focus_distance:
				candidates.append(body as Node3D)

	if candidates.is_empty():
		return candidates

	# Sort candidates by angular difference to camera forward vector
	var cam_forward: Vector3 = Vector3.FORWARD
	if player and player.spring_arm:
		cam_forward = -player.spring_arm.global_transform.basis.z.slide(player.up_direction).normalized()
	var player_pos: Vector3 = player.global_position if player else Vector3.ZERO

	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		var dir_a: Vector3 = (a.global_position - player_pos).slide(player.up_direction if player else Vector3.UP).normalized()
		var dir_b: Vector3 = (b.global_position - player_pos).slide(player.up_direction if player else Vector3.UP).normalized()
		var dot_a: float = cam_forward.dot(dir_a)
		var dot_b: float = cam_forward.dot(dir_b)
		return dot_a > dot_b
	)

	return candidates


## Locks on to the best focusable body.
func _acquire_focus_target() -> void:
	var targets: Array[Node3D] = get_focusable_targets()
	if targets.is_empty():
		return
	_set_focus_target(targets[0])


## Cycles to the next or previous focusable target.
func cycle_focus_target(direction: int = 1) -> void:
	var targets: Array[Node3D] = get_focusable_targets()
	if targets.is_empty():
		_clear_focus_target()
		return
	if targets.size() == 1:
		if current_focus_target != targets[0]:
			_set_focus_target(targets[0])
		return

	var current_idx: int = targets.find(current_focus_target)
	var next_idx: int = 0
	if current_idx >= 0:
		next_idx = (current_idx + direction + targets.size()) % targets.size()
	_set_focus_target(targets[next_idx])


## Sets the current focus target and attaches the bouncing indicator marker.
func _set_focus_target(target: Node3D) -> void:
	if current_focus_target == target and is_instance_valid(current_focus_marker):
		return

	_clear_focus_target()
	current_focus_target = target
	target_loss_timer = 0.0

	if focus_target_marker and is_instance_valid(target):
		current_focus_marker = focus_target_marker.duplicate() as Marker3D
		target.add_child(current_focus_marker)
		current_focus_marker.top_level = true
		var target_pos: Vector3 = get_focus_target_position(target)
		current_focus_marker.global_position = target_pos + Vector3(0, 0.4, 0)
		current_focus_marker.visible = true
		var anim_player: AnimationPlayer = current_focus_marker.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if anim_player:
			anim_player.play("bounce")


## Releases the current target and frees its marker.
func _clear_focus_target() -> void:
	if is_instance_valid(current_focus_marker):
		current_focus_marker.queue_free()
	current_focus_target = null
	current_focus_marker = null
	target_loss_timer = 0.0
