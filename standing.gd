class_name Standing
extends NodeStateMachine


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Check if the player is no longer on the floor
	if not player.is_on_floor():
		# Start "falling"
		player.state_machine.travel(NodeStateMachine.States.FALLING)


## Start "standing".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = NodeStateMachine.States.STANDING
	# Flag the player as "standing"
	player.is_standing = true
	# Transition the locomotion state to Standing
	player.locomotion_state.travel("Standing")


## Stop "standing".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == NodeStateMachine.States.STANDING:
		player.current_state = -1
	# Flag the player as not "standing"
	player.is_standing = false
