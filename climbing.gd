class_name Climbing
extends StateMachine


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Crouch { Controller: Left Stick, Keyboard: Left Control }
	if event.is_action_pressed("crouch"):
		# Stop "climbing"
		player.is_climbing = false
		player.is_climbing_hopping_left = false
		player.is_climbing_hopping_right = false
		player.is_climbing_hopping_up = false
		player.is_hopping_from_climbing = false
		# Start "falling"
		player.locomotion_state.travel("Falling")
		player.is_falling = true


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Ledge detection
	var ledge_detected := false
	if not player.is_on_floor() and player.ledge_detection_horizontal and player.ledge_detection_horizontal.is_colliding():
		var forward_direction := -player.ledge_detection_horizontal.global_transform.basis.z.normalized()
		player.ledge_detection_vertical.global_position = player.ledge_detection_horizontal.get_collision_point() + (forward_direction * 0.05) + player.up_direction
		player.ledge_detection_vertical.force_raycast_update()
		if player.ledge_detection_vertical.is_colliding():
			player.ledge_detection_marker.global_position = player.ledge_detection_vertical.get_collision_point() + (player.ledge_detection_vertical.get_collision_normal() * 0.02)
			ledge_detected = true

	# Show/hide ledge detection gizmos.
	if ledge_detected:
		player.ledge_detection_horizontal.show()
		player.ledge_detection_marker.show()
	else:
		player.ledge_detection_vertical.position = Vector3(0, 0, -1) # Reset to default
		player.ledge_detection_horizontal.hide()
		player.ledge_detection_marker.hide()

	# Check if "climbing" player has reached a ledge
	if ledge_detected and player.is_climbing and player.player_input.motion.length() > 0.1:
		var player_top_position = player.global_position.y + player.get_node("CollisionShape3D").shape.height + 0.1
		if player_top_position >= player.ledge_detection_marker.global_position.y:
			# Stop "climbing"
			player.is_climbing = false
			# Start "hanging" (braced)
			player.locomotion_state.travel("BracedHangLocomotion")
			player.is_hanging_braced = true
			player.is_hanging_free = false

	# Climbing, Hop Up { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if not player.is_on_floor() \
	and (player.is_climbing or player.is_hanging_braced) \
	and Input.is_action_just_pressed("jump") \
	and (player.locomotion_state.get_current_node() == "ClimbingLocomotion" or player.locomotion_state.get_current_node() == "BracedHangLocomotion"):
		var hop_left = player.player_input.motion.x < -0.1 and abs(player.player_input.motion.x) > abs(player.player_input.motion.y)
		var hop_right = player.player_input.motion.x > 0.1 and abs(player.player_input.motion.x) > abs(player.player_input.motion.y)
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
			else:
				player.locomotion_state.travel("BracedHangHopUp")
				player.is_hopping_from_climbing = player.is_climbing
				player.is_climbing_hopping_left = false
				player.is_climbing_hopping_right = false
				player.is_climbing_hopping_up = true
	
	# Climbing, Speed Up { Microsoft: Ⓑ, Nintendo: Ⓐ, Sony: Ⓞ, Keyboard: [Shift] }.
	if player.is_climbing \
	and Input.is_action_pressed("sprint"):
		player.animation_tree.set("parameters/LocomotionTimeScale/scale", 1.5)
		player.is_sprinting = true
	else:
		player.is_sprinting = false
		player.animation_tree.set("parameters/LocomotionTimeScale/scale", 1.0)


	# Check if the player has reached the floor
	#var climbing_down := player.is_climbing and player.player_input.motion.y < -0.1
	if player.is_on_floor():
		stop()
		# Start "standing"
		player.locomotion_state.travel("StandingLocomotion")


## Start "climbing".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = States.CLIMBING
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
	player.is_hopping_from_climbing = false
