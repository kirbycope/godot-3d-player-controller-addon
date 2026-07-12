class_name Skateboarding
extends NodeStateMachine

var _this_state := NodeStateMachine.States.SKATEBOARDING


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

	# If player leaves the ground while skateboarding, transition to falling.
	if not player.is_on_floor():
		player.state_machine.travel(_this_state, NodeStateMachine.States.FALLING)
		return

	# Use camera-relative steering similar to paragliding, but constrained to floor movement.
	var camera_basis := player.spring_arm.global_transform.basis
	var target_dir := camera_basis * Vector3(player.player_input.motion.x, 0.0, -player.player_input.motion.y)
	target_dir = target_dir.slide(player.up_direction)
	if target_dir.length_squared() <= 0.001 and player.player_input.motion.y > 0.0:
		# Fallback: make move_up always push forward even if camera-forward projects poorly.
		target_dir = -player.orientation.basis.z.slide(player.up_direction)

	if target_dir.length_squared() > 0.001 and not player.is_firing_arrow:
		target_dir = target_dir.normalized()
		var q_from: Quaternion = player.orientation.basis.get_rotation_quaternion()
		var q_to: Quaternion = Basis.looking_at(-target_dir).get_rotation_quaternion()
		player.orientation.basis = Basis(
			q_from.slerp(q_to, delta * player.rotation_interpolate_speed)
		)

	# Preserve momentum by default, but consume root-motion displacement for move_up.
	var current_h_vel := player.velocity.slide(player.up_direction)
	if player.player_input.motion.y > 0.0:
		# Use root-motion displacement directly when moving forward.
		var root_motion := Transform3D(
			player.animation_tree.get_root_motion_rotation(),
			player.animation_tree.get_root_motion_position()
		)
		player.orientation *= root_motion
		current_h_vel = player.orientation.origin.slide(player.up_direction) / max(delta, 0.001)
	elif target_dir.length_squared() > 0.001:
		var skate_speed: float = max(current_h_vel.length(), 4.0)
		current_h_vel = target_dir.normalized() * skate_speed

	# Keep grounded by damping upward velocity and applying gravity along up_direction.
	var vertical_speed := player.velocity.dot(player.up_direction)
	vertical_speed = min(vertical_speed, 0.0)
	vertical_speed += player.get_gravity().dot(player.up_direction) * delta

	player.velocity = current_h_vel + (player.up_direction * vertical_speed)
	player.set_velocity(player.velocity)
	player.set_up_direction(player.up_direction)
	player.move_and_slide()

	# Avoid orientation drift after repeated interpolation.
	player.orientation.origin = Vector3()
	player.orientation = player.orientation.orthonormalized()
	player.player_model.global_transform.basis = player.orientation.basis



## Start "skateboarding".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "skateboarding"
	player.is_skateboarding = true
	# Prevent carrying upward velocity into grounded skateboarding movement.
	var vertical_speed := player.velocity.dot(player.up_direction)
	vertical_speed = min(vertical_speed, 0.0)
	player.velocity = player.velocity.slide(player.up_direction) + (player.up_direction * vertical_speed)


## Stop "skateboarding".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "skateboarding"
	player.is_skateboarding = false
