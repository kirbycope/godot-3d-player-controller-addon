class_name NodeStateMachine
extends Node

enum States {
	ATTACKING,
	CLIMBING,
	CROUCHING,
	DRIVING,
	FALLING,
	FLYING,
	HANGING,
	JUMPING,
	PARAGLIDING,
	PUSHING,
	RAGDOLLING,
	SITTING,
	SKATEBOARDING,
	SLIDING,
	SPRINTING,
	STANDING,
	SWIMMING,
}

func _ready() -> void:
	set_process(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	set_process_input(is_multiplayer_authority())

@export var player: Player


## Helper function to get the state name from the `NodeStateMachine.States` enum value.
static func get_state_name(state: int) -> StringName:
	var state_name: Variant = States.find_key(state)
	if state_name == null:
		return &""
	return StringName(String(state_name).capitalize())


## Transition from one state to another.
func travel(from_state: States, to_state: States) -> void:
	if not _is_state_enabled(to_state):
		return

	# Block transition to RAGDOLLING if player is paused or Pause CanvasLayer is visible
	if to_state == States.RAGDOLLING and player and (player.is_paused or (player.pause and player.pause.visible)):
		return

	# Block transitions while ragdolling unless explicitly entering or exiting the RAGDOLLING state
	if player and player.is_ragdolling and to_state != States.RAGDOLLING and from_state != States.RAGDOLLING:
		return

	if from_state in States.values():
		var from_state_name: StringName = get_state_name(from_state)
		var from_state_node: Node = get_node_or_null(NodePath(from_state_name))
		if from_state_node == null:
			push_error("Invalid from_state: %s" % str(from_state_name))
		elif not from_state_node.has_method("stop"):
			push_error("State %s missing stop()" % str(from_state_name))
		else:
			if player and player.controls:
				if player.controls.input_type_changed.is_connected(from_state_node._on_input_type_changed):
					player.controls.input_type_changed.disconnect(from_state_node._on_input_type_changed)
				player.controls.reset_labels()
			from_state_node.call("stop")
	elif from_state != -1:
		push_warning("Invalid from_state: %s" % str(from_state))

	if to_state in States.values():
		var to_state_name: StringName = get_state_name(to_state)
		var to_state_node: Node = get_node_or_null(NodePath(to_state_name))
		if to_state_node == null:
			push_error("Invalid to_state: %s" % str(to_state_name))
		elif not to_state_node.has_method("start"):
			push_error("State %s missing start()" % str(to_state_name))
		else:
			if player and player.controls:
				var is_holding_object: bool = player.held_object \
						and player.held_object.is_holding_object()
				if is_holding_object:
					player.held_object.refresh_contextual_controls()
				else:
					if not player.controls.input_type_changed.is_connected(
						to_state_node._on_input_type_changed
					):
						player.controls.input_type_changed.connect(
							to_state_node._on_input_type_changed
						)
					to_state_node._on_input_type_changed(player.controls.current_input_type)
			to_state_node.call("start")
	else:
		push_warning("Invalid to_state: %s" % str(to_state))


func _is_state_enabled(state: States) -> bool:
	if player == null:
		return true

	match state:
		States.FLYING:
			return player.enable_flying
		States.PARAGLIDING:
			return player.enable_paraglider
		States.RAGDOLLING:
			return player.enable_ragdoll
		_:
			return true





## True if the player is moving into a wall (or heavy object) they are facing.
func is_player_pushing_into_wall() -> bool:
	if not player.has_move_input or not player.is_on_wall():
		return false
	var facing: Vector3 = player.get_facing_direction()
	if facing == Vector3.ZERO:
		return false
	for i in player.get_slide_collision_count():
		var collision: KinematicCollision3D = player.get_slide_collision(i)
		if collision.get_collider() is CharacterBody3D:
			continue
		var normal: Vector3 = collision.get_normal()
		# Skip floor/ceiling contacts
		if absf(normal.dot(player.up_direction)) > 0.3:
			continue
		# get_facing_direction() aligns with the pushed wall's normal (PlayerModel forward is +Z).
		if facing.dot(normal) > 0.8:
			return true
	return false


func _on_input_type_changed(input_type: int) -> void:
	if not player or not player.controls: return
	
	var controls = get_contextual_controls(input_type)
	if controls.is_empty():
		player.controls.reset_labels()
	else:
		player.controls.set_labels(controls)


func get_contextual_controls(_input_type: int) -> Dictionary:
	return {}
