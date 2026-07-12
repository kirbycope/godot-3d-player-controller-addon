class_name Paragliding
extends NodeStateMachine

var _this_state := NodeStateMachine.States.PARAGLIDING


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Crouch { Controller: Left Stick, Keyboard: Left Control }
	if event.is_action_pressed("crouch"):
		# Stop "paragliding" and start "falling"
		player.state_machine.travel(_this_state, NodeStateMachine.States.FALLING)


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Check if the player has reached the floor
	if player.is_on_floor():
		# Start "standing"
		player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
		return

	# While paragliding, regular locomotion is blocked and movement is driven directly (below)
	# Use camera-relative input, then remove any component along up_direction so glide steering stays tangential.
	var camera_basis := player.spring_arm.global_transform.basis
	var target_dir := camera_basis * Vector3(player.player_input.motion.x, 0.0, -player.player_input.motion.y)
	target_dir = target_dir.slide(player.up_direction)
	if target_dir.length_squared() > 0.001 and not player.is_firing_arrow:
		# Slerp model orientation toward flight direction for smooth, frame-rate independent turning.
		target_dir = target_dir.normalized()
		var q_from: Quaternion = player.orientation.basis.get_rotation_quaternion()
		var q_to: Quaternion = Basis.looking_at(-target_dir).get_rotation_quaternion()
		player.orientation.basis = Basis(q_from.slerp(q_to, delta * player.rotation_interpolate_speed))

	# Keep horizontal momentum while enforcing a minimum forward glide speed for controllability.
	var current_h_vel := player.velocity.slide(player.up_direction)
	var glide_speed := max(current_h_vel.length(), 4.0)
	if target_dir.length_squared() > 0.001:
		current_h_vel = target_dir.normalized() * glide_speed

	# Only allow descent while gliding: gravity is damped and capped to avoid excessive dive speed.
	var vertical_speed := player.velocity.dot(player.up_direction)
	vertical_speed = min(vertical_speed, 0.0)
	vertical_speed += player.get_gravity().dot(player.up_direction) * 0.35 * delta
	vertical_speed = max(vertical_speed, -4.0)
	player.velocity = current_h_vel + (player.up_direction * vertical_speed)
	player.set_velocity(player.velocity)
	player.set_up_direction(player.up_direction)
	player.move_and_slide()

	# Normalize orientation every tick to prevent drift after repeated quaternion interpolation.
	player.orientation.origin = Vector3()
	player.orientation = player.orientation.orthonormalized()
	player.player_model.global_transform.basis = player.orientation.basis


## Start "paragliding".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
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
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "paragliding"
	player.is_paragliding = false
