class_name Sliding
extends NodeStateMachine

var _this_state := NodeStateMachine.States.SLIDING


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

	# Check if the player is no longer sliding
	if player.locomotion_state.get_current_node() != "RunningSlide":
		# Start "standing"
		player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
		return


## Start "sliding".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "sliding"
	player.is_sliding = true
	# Reduce the player's collision shape height and adjust its position to match the sliding posture
	player.collision_shape.shape.height = player.initial_collision_shape_height * 0.5
	player.collision_shape.position = Vector3(0, player.collision_shape.shape.height * 0.5, 0)


## Stop "sliding".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "sliding"
	player.is_sliding = false
	# Reset the player's collision shape to its initial height and position
	player.collision_shape.shape.height = player.initial_collision_shape_height
	player.collision_shape.position = player.initial_collision_shape_position
