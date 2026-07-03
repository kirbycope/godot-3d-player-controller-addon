class_name Climbing
extends NodeStateMachine


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Crouch { Controller: Left Stick, Keyboard: Left Control }
	if event.is_action_pressed("crouch"):
		# Stop "climbing"
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

	# Check if "climbing" player has reached a ledge -> Start "hanging" (braced)
	if ledge_detected and player.is_climbing and player.player_input.motion.length() > 0.1:
		var player_top_position = player.global_position.y + player.get_node("CollisionShape3D").shape.height + 0.1
		# Check if the player's top position has reached or exceeded the ledge detection marker's Y-position
		if player_top_position >= player.ledge_detection_marker.global_position.y:
			# Start "hanging"
				player.state_machine.travel(NodeStateMachine.States.HANGING)

	# Climbing, Hopping [Status]
	if player.is_climbing or player.is_hanging_braced or player.is_climbing_hopping_left or player.is_climbing_hopping_right or player.is_climbing_hopping_up:
		var was_hopping := player.is_climbing_hopping_left or player.is_climbing_hopping_right or player.is_climbing_hopping_up
		var current_node = player.animation_tree.get(player.LOCOMOTION_STATE_PLAYBACK_PATH).get_current_node()
		player.is_climbing_hopping_left = current_node == "BracedHangHopLeft"
		player.is_climbing_hopping_right = current_node == "BracedHangHopRight"
		player.is_climbing_hopping_up = current_node == "BracedHangHopUp"
		if was_hopping and not (player.is_climbing_hopping_left or player.is_climbing_hopping_right or player.is_climbing_hopping_up):
			player.is_climbing = player.is_hopping_from_climbing
			player.is_hanging_braced = not player.is_hopping_from_climbing
			player.is_hanging_free = false
			player.is_hopping_from_climbing = false

	# Climbing, Climbing On [Status]
	if player.is_climbing_on:
		var was_climbing_on = player.is_climbing_on
		player.is_climbing_on = player.animation_tree.get(player.LOCOMOTION_STATE_PLAYBACK_PATH).get_current_node() == "BracedHangClimbingOn"
		if was_climbing_on and not player.is_climbing_on:
			player.global_position = player.climbing_on_target
			player.is_climbing_on = false

	# Climbing, Hopping [Input] { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if not player.is_on_floor() \
	and Input.is_action_just_pressed("jump") \
	and (player.locomotion_state.get_current_node() == "ClimbingLocomotion" or player.locomotion_state.get_current_node() == "BracedHangLocomotion"):
		# Check: Left input past 0.1 deadzone, and |x| > |y| ensures horizontal input dominance (<45° angle to -X).
		var hop_left = player.player_input.motion.x < -0.1 and abs(player.player_input.motion.x) > abs(player.player_input.motion.y)
		# Check: Right input past 0.1 deadzone, and |x| > |y| ensures horizontal input dominance (<45° angle to +X).
		var hop_right = player.player_input.motion.x > 0.1 and abs(player.player_input.motion.x) > abs(player.player_input.motion.y)
		# Check: Up input past 0.1 deadzone, and |y| > |x| ensures vertical input dominance (<45° angle to +Y).
		var hop_up = player.player_input.motion == Vector2.ZERO or (player.player_input.motion.y > 0.1 and abs(player.player_input.motion.y) > abs(player.player_input.motion.x))
		# Determine which hop direction to take based on input
		if hop_left:
			player.locomotion_state.travel("BracedHangHopLeft")
			player.is_hopping_from_climbing = player.is_climbing
			player.is_climbing_hopping_left = true
			player.is_climbing_hopping_right = false
			player.is_climbing_hopping_up = false
		elif hop_right:
			player.locomotion_state.travel("BracedHangHopRight")
			player.is_hopping_from_climbing = player.is_climbing
			player.is_climbing_hopping_left = false
			player.is_climbing_hopping_right = true
			player.is_climbing_hopping_up = false
		else:
			# Check if the player can climb on to the ledge detection target
			if player.is_hanging_braced and player.ledge_detection_vertical and player.ledge_detection_vertical.is_colliding():
				player.climbing_on_target = player.ledge_detection_vertical.get_collision_point()
				player.locomotion_state.travel("BracedHangClimbingOn")
				player.is_climbing = false
				player.is_climbing_on = true
				player.is_hanging_braced = false
				player.is_hanging_free = false
				player.is_climbing_hopping_left = false
				player.is_climbing_hopping_right = false
				player.is_climbing_hopping_up = false
			# If the ledge detection target is not valid, the player will hop up instead.
			elif hop_up:
				player.locomotion_state.travel("BracedHangHopUp")
				player.is_hopping_from_climbing = player.is_climbing
				player.is_climbing_hopping_left = false
				player.is_climbing_hopping_right = false
				player.is_climbing_hopping_up = true

	# Climbing, Speed Up [Input] { Microsoft: Ⓑ, Nintendo: Ⓐ, Sony: Ⓞ, Keyboard: [Shift] }.
	if player.is_climbing \
	and Input.is_action_pressed("sprint"):
		player.animation_tree.set("parameters/LocomotionTimeScale/scale", 1.5)
		player.is_sprinting = true
	else:
		player.animation_tree.set("parameters/LocomotionTimeScale/scale", 1.0)
		player.is_sprinting = false

	# Check if the player has reached the floor
	if player.is_on_floor():
		stop()
		# Start "standing"
		player.locomotion_state.travel("StandingLocomotion")


## Start "climbing".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = NodeStateMachine.States.CLIMBING
	# Flag the player as "climbing"
	player.is_climbing = true
	# Travel to the "climbing" locomotion state
	player.locomotion_state.travel("ClimbingLocomotion")


## Stop "climbing".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Flag the player as not "climbing"
	player.is_climbing = false
	player.is_climbing_hopping_left = false
	player.is_climbing_hopping_right = false
	player.is_climbing_hopping_up = false
	player.is_climbing_on = false
	player.is_hopping_from_climbing = false
	# Clear ledge detection visuals
	player.ledge_detection_vertical.position = Vector3(0, 0, -1) # Reset to default
	player.ledge_detection_horizontal.hide()
	player.ledge_detection_marker.hide()
