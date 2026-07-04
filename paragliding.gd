class_name Paragliding
extends NodeStateMachine


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Crouch { Controller: Left Stick, Keyboard: Left Control }
	if event.is_action_pressed("crouch"):
		# Stop "paragliding" and start "falling"
		player.state_machine.travel(NodeStateMachine.States.FALLING)


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Check if the player has reached the floor
	if player.is_on_floor():
		# Stop "paragliding"
		stop()


## Start "paragliding".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = NodeStateMachine.States.PARAGLIDING
	# Flag the player as "paragliding"
	player.is_paragliding = true
	# Limit the player's downward velocity
	var vertical_speed := player.velocity.dot(player.up_direction)
	vertical_speed = min(vertical_speed, 0.0)
	player.velocity = player.velocity.slide(player.up_direction) + (player.up_direction * vertical_speed)


## Stop "paragliding".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Flag the player as not "paragliding"
	player.is_paragliding = false
