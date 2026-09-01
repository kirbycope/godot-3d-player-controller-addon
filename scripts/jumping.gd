class_name Jumping
extends NodeStateMachine

var _this_state := NodeStateMachine.States.JUMPING


## Called when there is an input event.
func _input(event: InputEvent) -> void:

	# Do nothing if the player is not set
	if not player or player.is_paused or player.is_ragdolling: return

	# Jump action triggers while jumping
	if event.is_action_pressed("jump") and not player.is_on_floor():
		if player.ledge_detection_horizontal.is_colliding():
			# Exhausted players cannot grab the wall
			if not player.is_exhausted:
				player.state_machine.travel(_this_state, NodeStateMachine.States.CLIMBING)
				get_viewport().set_input_as_handled()
			return
		elif player.paraglider_raycast.is_colliding() and not player.is_jump_queued:
			player.state_machine.travel(_this_state, NodeStateMachine.States.FLYING)
			get_viewport().set_input_as_handled()
			return
		elif not player.paraglider_raycast.is_colliding() and not player.is_exhausted:
			player.state_machine.travel(_this_state, NodeStateMachine.States.PARAGLIDING)
			get_viewport().set_input_as_handled()
			return


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:

	# Do nothing if the player is not set
	if not player: return

	# Check if the player has reached the floor
	if player.is_on_floor() and not player.is_jump_queued:
		var falling_state := player.state_machine.get_node_or_null("Falling") as Falling
		var lethal_velocity := falling_state.lethal_velocity if falling_state else 20.0
		if player.last_fall_speed >= lethal_velocity:
			player.state_machine.travel(_this_state, NodeStateMachine.States.RAGDOLLING)
		else:
			# Start "standing"
			player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
		return

	# Hand off to "falling" once the jump starts descending so is_falling drives the falling animation and air control.
	if not player.is_on_floor() and not player.is_jump_queued:
		var vertical_speed: float = player.velocity.dot(player.up_direction)
		if vertical_speed < 0.0:
			player.state_machine.travel(_this_state, NodeStateMachine.States.FALLING)
			return


## Start "jumping".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "jumping"
	player.is_jumping = true
	# Flag the player as having a "jump queued"
	player.is_jump_queued = true
	# HeavyBreathing has no direct jump edge; return to the normal locomotion graph.
	if player.current_locomotion_node == "HeavyBreathing":
		player.travel_locomotion("StandingLocomotion")


## Stop "jumping".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "jumping"
	player.is_jumping = false
	# Flag the player as not having a "jump queued"
	player.is_jump_queued = false
	# Flag the player as not "flipping"
	player.is_front_flipping = false
	player.is_back_flipping = false
