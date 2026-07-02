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
		# Stop "paragliding"
		stop()
		# Start "falling"
		player.locomotion_state.travel("Falling")
		player.is_falling = true


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
		# Start "standing"
		player.locomotion_state.travel("StandingLocomotion")


## Start "paragliding".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = States.PARAGLIDING
	# Travel to the "Paragliding" locomotion state
	player.locomotion_state.travel("Paragliding")
	# Flag the player as "paragliding"
	player.is_paragliding = true
	# Limit the player's downward velocity
	player.velocity.y = min(player.velocity.y, 0.0)


## Stop "paragliding".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Flag the player as not "paragliding"
	player.is_paragliding = false
