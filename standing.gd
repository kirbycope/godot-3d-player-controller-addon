class_name Standing
extends NodeStateMachine

var _this_state := NodeStateMachine.States.STANDING


## Called when there is an input event.
func _input(event: InputEvent) -> void:

	# Do nothing if the player is not set
	if not player or player.is_paused or player.is_ragdolling: return

	# Attack
	if event.is_action_pressed("attack") and player.inventory.can_player_attack:
		get_viewport().set_input_as_handled()
		player.state_machine.travel(_this_state, NodeStateMachine.States.ATTACKING)
		return

	# Jump
	if event.is_action_pressed("jump"):
		if player.is_boxing:
			player.is_boxing = false
		get_viewport().set_input_as_handled()
		player.state_machine.travel(_this_state, NodeStateMachine.States.JUMPING)
		return

	# Sprint
	if event.is_action_pressed("sprint") and (player.smoothed_motion.y > 0.0 if player.is_focusing else player.smoothed_motion.length() > 0.0):
		get_viewport().set_input_as_handled()
		player.state_machine.travel(_this_state, NodeStateMachine.States.SPRINTING)
		return

	# Crouch
	if event.is_action_pressed("crouch"):
		get_viewport().set_input_as_handled()
		player.state_machine.travel(_this_state, NodeStateMachine.States.CROUCHING)
		return


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:

	# Do nothing if the player is not set
	if not player: return

	# Check if the player is no longer on the floor
	if not player.is_on_floor() and not player.falling_raycast.is_colliding():
		# Start "falling"
		player.state_machine.travel(_this_state, NodeStateMachine.States.FALLING)
		return


## Start "standing".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "standing"
	player.is_standing = true
	# Transition directly to the grounded locomotion that matches the equipped state.
	player.locomotion_state.travel(String(player.get_grounded_locomotion_state()))


## Stop "standing".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "standing"
	player.is_standing = false
