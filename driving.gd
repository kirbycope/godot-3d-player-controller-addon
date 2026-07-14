class_name Driving
extends NodeStateMachine

var _this_state := NodeStateMachine.States.DRIVING


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Exit { Microsoft: Ⓧ, Nintendo: Ⓨ, Sony: 🟗, Keyboard: [Alt] }
	if Input.is_action_just_pressed("attack"):
		# Stop "driving" and start "standing"
		player.state_machine.travel(player.current_state, NodeStateMachine.States.STANDING)


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return


## Start "driving".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "driving"
	player.is_driving = true
	# Disable player collision
	player.collision_shape.disabled = true
	# Move the player to the $EnterCar [Marker3D] position and orientation
	var enter_car_marker := player.is_driving_in.get_node("EnterCar") as Marker3D
	player.global_transform = enter_car_marker.global_transform
	player.player_model.global_transform = enter_car_marker.global_transform


## Stop "driving".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "driving"
	player.is_driving = false
	player.is_driving_in = null
	# [Re]Enable player collision
	player.collision_shape.disabled = false
