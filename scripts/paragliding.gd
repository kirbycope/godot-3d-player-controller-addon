class_name Paragliding
extends NodeStateMachine

@export_category("Paragliding Controls")
@export_group("Keyboard/Mouse Actions")
@export var keyboard_stop_action: StringName = &"action"
@export var keyboard_dive_action: StringName = &"crouch"

@export_group("Controller/Touch Actions")
@export var pad_stop_action: StringName = &"action"
@export var pad_dive_action: StringName = &"crouch"

var _this_state := NodeStateMachine.States.PARAGLIDING
var is_in_updraft: bool = false
var is_diving: bool = false


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if the player is not set or is paused/ragdolling
	if not player or player.is_paused or player.is_ragdolling: return

	var input_type = player.controls.current_input_type if player.controls else 0
	var current_stop_action = keyboard_stop_action if input_type == 0 else pad_stop_action

	# Stop "paragliding" and start "falling"
	if event.is_action_pressed(current_stop_action) and not event.is_echo():
		player.state_machine.travel(_this_state, NodeStateMachine.States.FALLING)
		return


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if the player is not set
	if not player: return

	# Check if the player has reached the floor
	if player.is_on_floor():
		# Start "standing"
		player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
		return

	# Check if the player is exhausted — close the paraglider
	if player.is_exhausted:
		# Start "falling"
		player.state_machine.travel(_this_state, NodeStateMachine.States.FALLING)
		return

	# Check for thermal updraft areas
	is_in_updraft = _check_in_updraft()

	var input_type = player.controls.current_input_type if player.controls else 0
	var current_dive_action = keyboard_dive_action if input_type == 0 else pad_dive_action
	is_diving = Input.is_action_pressed(current_dive_action)

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
	var base_speed := 8.0 if is_diving else 4.0
	var glide_speed := max(current_h_vel.length(), base_speed)
	if target_dir.length_squared() > 0.001:
		current_h_vel = target_dir.normalized() * glide_speed

	var vertical_speed = player.velocity.dot(player.up_direction)

	if is_in_updraft:
		# Thermal updraft lifts player and recovers stamina
		vertical_speed = min(vertical_speed + delta * 20.0, 8.5)
		if player.enable_stamina and player.stamina:
			player.stamina.value = min(player.stamina.value + delta * 40.0, player.stamina.max_value)
	elif is_diving:
		# Steep dive downwards
		vertical_speed = max(vertical_speed - delta * 15.0, -12.0)
	else:
		# Normal damped descent
		vertical_speed = min(vertical_speed, 0.0)
		vertical_speed += player.get_gravity().dot(player.up_direction) * 0.35 * delta
		vertical_speed = max(vertical_speed, -4.0)

	player.velocity = current_h_vel + (player.up_direction * vertical_speed)
	player.update_movement_and_rotation(delta)


func _check_in_updraft() -> bool:
	if not is_inside_tree():
		return false
	var tree = get_tree()
	if tree == null:
		return false

	var pool: Array[Node] = []
	pool.append_array(tree.get_nodes_in_group("Updraft"))
	pool.append_array(tree.get_nodes_in_group("Thermal"))

	for node in pool:
		if node is Area3D:
			var area = node as Area3D
			if area.overlaps_body(player):
				return true
			var col_shape: CollisionShape3D = area.find_child("CollisionShape3D", true, false) as CollisionShape3D
			if col_shape and col_shape.shape:
				var local_p = area.to_local(player.global_position)
				if col_shape.shape is BoxShape3D:
					var box = col_shape.shape as BoxShape3D
					var half = box.size * 0.5
					if abs(local_p.x) <= half.x and abs(local_p.y) <= half.y and abs(local_p.z) <= half.z:
						return true
				elif col_shape.shape is CylinderShape3D:
					var cyl = col_shape.shape as CylinderShape3D
					var half_h = cyl.height * 0.5
					var horiz_d = Vector2(local_p.x, local_p.z).length()
					if abs(local_p.y) <= half_h and horiz_d <= cyl.radius:
						return true
				elif col_shape.shape is CapsuleShape3D:
					var cap = col_shape.shape as CapsuleShape3D
					var half_h = cap.height * 0.5
					var horiz_d = Vector2(local_p.x, local_p.z).length()
					if abs(local_p.y) <= half_h and horiz_d <= cap.radius:
						return true
			elif area.global_position.distance_to(player.global_position) < 10.0:
				return true
	return false


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
	# Teleport locomotion playback into the Paragliding animation state.
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
	is_in_updraft = false
	is_diving = false
	# Restore equipped item visuals when exiting glide.
	player.inventory.set_equipment_visibility(true)


func get_contextual_controls(input_type: int) -> Dictionary:
	if not player or not player.controls: return {}

	var controls = {
		player.controls.joypad_button_4_label: "Perspective",
		player.controls.joypad_button_15_label: "Screenshot",
		player.controls.joypad_button_6_label: "Pause Menu",
		player.controls.left_joystick_label: "Steer",
		player.controls.right_joystick_label: "Camera",
	}

	if input_type == 0:
		controls[player.controls.joypad_button_7_label] = "Cancel"
		controls[player.controls.joypad_button_1_label] = "Dive"
	else:
		controls[player.controls.joypad_button_0_label] = "Cancel"
		controls[player.controls.joypad_button_1_label] = "Dive"

	return controls
