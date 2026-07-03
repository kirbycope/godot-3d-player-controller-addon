class_name Hanging
extends NodeStateMachine


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Crouch { Controller: Left Stick, Keyboard: Left Control }
	if event.is_action_pressed("crouch"):
		# Stop "hanging"
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
		# "Stop "hanging"
		stop()
		# Start "standing"
		player.locomotion_state.travel("StandingLocomotion")

	# Ledge detection [Raycast]
	var ledge_detected = player.detect_ledge()

	# Update footing status if not climbing onto a ledge
	if not player.is_climbing_on:

		# Check if "hanging" (braced) [Raycast]
		if player.is_hanging_free \
		and player.hanging_braced_detection.is_colliding():
			player.locomotion_state.travel("BracedHangLocomotion")
			player.is_hanging_braced = true
			player.is_hanging_free = false

		# Check if "hanging" (free) [Raycast]
		if player.is_hanging_braced \
		and not player.hanging_braced_detection.is_colliding():
			player.locomotion_state.travel("FreeHangingLocomotion")
			player.is_hanging_braced = false
			player.is_hanging_free = true

	# Hanging, Climbing On [Status]
	if player.is_climbing_on:
		var was_climbing_on = player.is_climbing_on
		player.is_climbing_on = player.animation_tree.get(player.LOCOMOTION_STATE_PLAYBACK_PATH).get_current_node() in ["BracedHangClimbingOn", "FreeHangingClimbingOn"]
		if was_climbing_on and not player.is_climbing_on:
			player.global_position = player.climbing_on_target
			# Stop "hanging"
			stop()
			# Start "standing"
			player.locomotion_state.travel("StandingLocomotion")

	# Hanging, Climbing-On [Input] { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if Input.is_action_just_pressed("jump"):
		if player.is_hanging_braced:
			player.locomotion_state.travel("BracedHangClimbingOn")
		elif player.is_hanging_free:
			player.locomotion_state.travel("FreeHangingClimbingOn")
		player.is_climbing_on = true


## Start "hanging".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = NodeStateMachine.States.HANGING
	# Determine if the player can hang braced
	if player.hanging_braced_detection.is_colliding():
		# Travel to the "hanging" (braced) locomotion state
		player.locomotion_state.travel("BracedHangLocomotion")
		# Flag the player as "hanging" (braced)
		player.is_hanging_braced = true
	else:
		# Travel to the "hanging" (free) locomotion state
		player.locomotion_state.travel("FreeHangingLocomotion")
		# Flag the player as "hanging" (free)
		player.is_hanging_free = true


## Stop "hanging".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Flag the player as not "hanging"
	player.is_hanging_braced = false
	player.is_hanging_free = false
	# Clear ledge detection visuals
	player.ledge_detection_vertical.position = Vector3(0, 0, -1) # Reset to default
	player.ledge_detection_horizontal.hide()
	player.ledge_detection_marker.hide()
