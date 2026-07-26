class_name Paragliding
extends NodeStateMachine

@export var stop_action: StringName = &"action"

var _this_state := NodeStateMachine.States.PARAGLIDING


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Stop "paragliding" and start "falling"
	if event.is_action_pressed(stop_action) and not event.is_echo():
		player.state_machine.travel(_this_state, NodeStateMachine.States.FALLING)
		return


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
	var camera_basis = player.spring_arm.global_transform.basis
	var target_dir = camera_basis * Vector3(player.player_input.motion.x, 0.0, -player.player_input.motion.y)
	target_dir = target_dir.slide(player.up_direction)
	if target_dir.length_squared() > 0.001 and not player.is_firing_arrow:
		# Slerp model orientation toward flight direction for smooth, frame-rate independent turning.
		target_dir = target_dir.normalized()
		var q_from: Quaternion = player.orientation.basis.get_rotation_quaternion()
		var q_to: Quaternion = Basis.looking_at(-target_dir, player.up_direction).get_rotation_quaternion()
		player.orientation.basis = Basis(q_from.slerp(q_to, delta * player.rotation_interpolate_speed))

	# Keep horizontal momentum while enforcing a minimum forward glide speed for controllability.
	var current_h_vel = player.velocity.slide(player.up_direction)
	var glide_speed := max(current_h_vel.length(), 4.0)
	if target_dir.length_squared() > 0.001:
		current_h_vel = target_dir.normalized() * glide_speed

	# Only allow descent while gliding: gravity is damped and capped to avoid excessive dive speed.
	var vertical_speed = player.velocity.dot(player.up_direction)
	vertical_speed = min(vertical_speed, 0.0)
	vertical_speed += player.get_gravity().dot(player.up_direction) * 0.35 * delta
	vertical_speed = max(vertical_speed, -4.0)
	player.velocity = current_h_vel + (player.up_direction * vertical_speed)
	player.update_movement_and_rotation(delta)


## Start "paragliding".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "paragliding"
	player.is_paragliding = true
	# Hide equipped item visuals while gliding to avoid clipping into the paraglider.
	player.inventory.set_equipment_visibility(false)
	# Teleport locomotion playback into the Paragliding animation state. Normally the is_paragliding flag would work but then it would need each transition added to the AnimationTree graph.
	player.locomotion_state.start("Paragliding")
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
	# Restore equipped item visuals when exiting glide.
	player.inventory.set_equipment_visibility(true)
