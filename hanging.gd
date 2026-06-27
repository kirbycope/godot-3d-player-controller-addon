class_name Hanging
extends StateMachine


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Crouch { Controller: Left Stick, Keyboard: Left Control }
	if event.is_action_pressed("crouch"):
		# Stop "hanging"
		player.is_hanging_braced = false
		player.is_hanging_free = false
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
		# "Stop "hanging"
		stop()
		# Start "standing"
		player.locomotion_state.travel("StandingLocomotion")

	# Check if braced "hanging" player is [now] free
	if player.is_hanging_braced \
	and not player.hanging_braced_detection.is_colliding():
		player.locomotion_state.travel("FreeHangingLocomotion")
		player.is_hanging_braced = false
		player.is_hanging_free = true

	# Check if free "hanging" player is [now] braced
	if player.is_hanging_free \
	and player.hanging_braced_detection.is_colliding():
		player.locomotion_state.travel("BracedHangLocomotion")
		player.is_hanging_braced = true
		player.is_hanging_free = false


## Start "hanging".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = States.HANGING
	# Flag the player as "hanging"
	player.is_hanging_braced = true
	player.is_hanging_free = true


## Stop "hanging".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Flag the player as not "hanging"
	player.is_hanging_braced = false
	player.is_hanging_free = false
