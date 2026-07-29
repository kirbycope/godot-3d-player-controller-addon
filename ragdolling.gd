class_name Ragdolling
extends NodeStateMachine

var _this_state := NodeStateMachine.States.RAGDOLLING


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


## Start "ragdolling".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "ragdolling"
	player.is_ragdolling = true
	# Start skeleton physical bones simulation
	if player.physical_bone_simulator:
		player.physical_bone_simulator.physical_bones_start_simulation()
	# Disable main collision shape while ragdolling
	if player.collision_shape:
		player.collision_shape.disabled = true


## Stop "ragdolling".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "ragdolling"
	player.is_ragdolling = false
	# Stop skeleton physical bones simulation
	if player.physical_bone_simulator:
		player.physical_bone_simulator.physical_bones_stop_simulation()
	# Re-enable main collision shape
	if player.collision_shape:
		player.collision_shape.disabled = false
