class_name Swimming
extends NodeStateMachine

@export_category("Swimming Controls")
@export_group("Keyboard/Mouse Actions")
@export var keyboard_climb_out_action: StringName = &"jump"
@export var keyboard_sprint_action: StringName = &"sprint"
@export var keyboard_crouch_action: StringName = &"crouch"

@export_group("Controller/Touch Actions")
@export var pad_climb_out_action: StringName = &"jump"
@export var pad_sprint_action: StringName = &"sprint"
@export var pad_crouch_action: StringName = &"crouch"

@export_group("Diving")
@export var enable_diving: bool = true ## Allows diving below the surface by holding the crouch action.
@export var dive_vertical_speed: float = 2.5 ## Vertical swim speed while descending/ascending (m/s).
@export var dive_entry_depth: float = 1.2 ## Depth below the surface (m) at which surface swimming becomes diving.
@export var dive_buoyancy_factor: float = 0.6 ## Passive float-back-up speed factor when shallow and not descending.
@export var dive_model_pitch_speed: float = 6.0 ## Interpolation speed of the dive body pitch.

var _this_state := NodeStateMachine.States.SWIMMING
var _vertical_swim_effort: float = 0.0 ## 0-1 stroke effort from active vertical dive input (drives the swim blend without stick input).

const WATER_SURFACE_SNAP_RATIO := 0.75
const SURFACE_EPSILON := 0.05 ## Depth (m) below which the player counts as being at the surface.


## Called when there is an input event.
func _input(event: InputEvent) -> void:

	# Do nothing if the player is not set or is paused/ragdolling
	if not player or player.is_paused or player.is_ragdolling: return

	var input_type = player.controls.current_input_type if player.controls else 0
	var current_climb_out_action = keyboard_climb_out_action if input_type == 0 else pad_climb_out_action

	# Swimming, Climbing-On [Input]
	if player.locomotion_state.get_current_node() == "SwimmingAtEdge" \
	and event.is_action_pressed(current_climb_out_action) \
	and not player.is_climbing_on:
		player.locomotion_state.travel("BracedHangClimbingOn")
		player.is_climbing_on = true


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:

	# Do nothing if the player is not set
	if not player: return

	# Water exhaustion check - respawn at safe shore position
	if player.is_exhausted and (player.is_swimming or player.current_state == _this_state):
		if player.last_safe_shore_position != Vector3.ZERO:
			player.global_position = player.last_safe_shore_position
		player.velocity = Vector3.ZERO
		player.is_swimming = false
		_reset_diving()
		if player.stamina:
			player.stamina.value = player.stamina.max_value * 0.35
			player.is_exhausted = false
		player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
		return

	var input_type: int = player.controls.current_input_type if player.controls else 0
	var current_climb_out_action: StringName = keyboard_climb_out_action if input_type == 0 else pad_climb_out_action
	var current_sprint_action: StringName = keyboard_sprint_action if input_type == 0 else pad_sprint_action
	var current_crouch_action: StringName = keyboard_crouch_action if input_type == 0 else pad_crouch_action

	# Water depth check
	var water_surface_along_up := get_water_surface_along_up()
	if not is_nan(water_surface_along_up):
		var current_position_along_up := player.up_direction.dot(player.global_position)
		var swim_depth_threshold: float = current_position_along_up + (_get_collision_height() * 0.5)
		if water_surface_along_up > swim_depth_threshold:
			if not player.is_swimming and not player.is_driving and player.is_driving_in == null and not player.is_entering_vehicle and not player.is_exiting_vehicle:
				player.state_machine.travel(player.current_state, NodeStateMachine.States.SWIMMING)
		else:
			if player.is_swimming:
				player.is_swimming = false

		# Diving [Vertical Swim Control]
		var shoulder_offset: float = _get_collision_height() * WATER_SURFACE_SNAP_RATIO
		var depth_below_surface: float = water_surface_along_up - (current_position_along_up + shoulder_offset)
		var was_diving: bool = player.is_diving
		player.is_diving = enable_diving and player.is_swimming and depth_below_surface > dive_entry_depth
		var vertical_input: float = 0.0
		_vertical_swim_effort = 0.0
		if player.is_swimming and not player.is_climbing_on:
			if enable_diving and Input.is_action_pressed(current_crouch_action):
				vertical_input = -1.0
				_vertical_swim_effort = 1.0
			elif depth_below_surface > SURFACE_EPSILON and Input.is_action_pressed(current_climb_out_action):
				vertical_input = 1.0
				_vertical_swim_effort = 1.0
			elif not player.is_diving and depth_below_surface > SURFACE_EPSILON:
				# Gentle buoyancy floats the player back up to the surface line
				vertical_input = dive_buoyancy_factor
			# Never swim up through the surface
			if vertical_input > 0.0 and depth_below_surface <= SURFACE_EPSILON:
				vertical_input = 0.0
				_vertical_swim_effort = 0.0
		player.swim_vertical_speed = vertical_input * dive_vertical_speed

		# Pitch the player model while diving so the body follows the swim direction (camera stays level)
		var target_pitch: float = 0.0
		if player.is_diving:
			var h_speed: float = player.velocity.slide(player.up_direction).length()
			# Model mesh faces +Z of the orientation basis, so descending needs a positive X rotation
			target_pitch = atan2(-player.swim_vertical_speed, maxf(h_speed, 1.0))
		player.model_pitch = lerp_angle(player.model_pitch, target_pitch, clampf(delta * dive_model_pitch_speed, 0.0, 1.0))

		# Refresh contextual HUD controls when the dive state flips
		if was_diving != player.is_diving:
			_on_input_type_changed(input_type)
	elif player.is_swimming:
		player.is_swimming = false
		_reset_diving()

	# Swimming, Climbing On [Status]
	if player.is_climbing_on:
		var was_climbing_on := player.is_climbing_on
		player.is_climbing_on = player.animation_tree.get(player.LOCOMOTION_STATE_PLAYBACK_PATH).get_current_node() in ["BracedHangClimbingOn", "FreeHangingClimbingOn"]
		if was_climbing_on and not player.is_climbing_on:
			player.global_position = player.climbing_on_target
			# Hide ledge detection gizmos
			player.ledge_detection_vertical.position = Vector3(0.0, 0.0, -1.0)
			player.ledge_detection_horizontal.hide()
			player.ledge_detection_marker.hide()
			# Start "standing"
			player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
			return

	# Stop "swimming" if the player has been flagged as not "swimming" (e.g. by exiting the pool)
	if not player.is_swimming \
	and player.locomotion_state.get_current_node() != "BracedHangClimbingOn":
		_reset_diving()
		# Start "standing" or "falling"
		player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING if player.is_on_floor() else NodeStateMachine.States.FALLING)
		return

	# Ledge detection [Raycast]
	var ledge_detected = player.detect_ledge()

	# Stop "swimming to edge" if the player is no longer colliding with the wall
	if player.locomotion_state.get_current_node() in ["SwimmingAtEdge", "SwimmingToEdge"] \
	and not ledge_detected:
		player.locomotion_state.travel("SwimmingLocomotion")

	# Swimming, To Edge (Raycast)
	if not player.locomotion_state.get_current_node() in ["SwimmingAtEdge", "SwimmingToEdge"] \
	and ledge_detected:
		player.locomotion_state.travel("SwimmingToEdge")

	# Swimming, Speed [Input]
	var has_swim_movement: bool = (player.smoothed_motion.y > 0.0 if player.is_focusing else player.smoothed_motion.length() > 0.0)
	if player.is_swimming \
	and not player.is_exhausted \
	and has_swim_movement \
	and Input.is_action_pressed(current_sprint_action):
		player.animation_tree.set("parameters/LocomotionTimeScale/scale", 1.5)
		player.swimming_root_motion_multiplier = 3
		player.is_sprinting = true
	else:
		player.animation_tree.set("parameters/LocomotionTimeScale/scale", 1.0)
		player.swimming_root_motion_multiplier = 2
		player.is_sprinting = false

	# While swimming, keep SwimmingLocomotion active and feed its BlendSpace1D.
	var current_swimming_node = player.locomotion_state.get_current_node()
	# Do not force SwimmingLocomotion while swimming to/at an edge or mantling out.
	if not current_swimming_node in ["BracedHangClimbingOn", "SwimmingAtEdge", "SwimmingToEdge"] \
	and current_swimming_node != "SwimmingLocomotion" \
	and not player.is_climbing_on:
		player.locomotion_state.travel("SwimmingLocomotion")
	# Feed the BlendSpace1D only while in normal swimming locomotion.
	# Vertical dive/ascend effort counts as stroke movement so diving animates without stick input.
	if current_swimming_node == "SwimmingLocomotion":
		if player.is_focusing: # or player.is_shooting:
			player.animation_tree.set(player.SWIMMING_LOCOMOTION_BLEND_POSITION_PATH, maxf(player.smoothed_motion.y, _vertical_swim_effort))
		else:
			player.animation_tree.set(player.SWIMMING_LOCOMOTION_BLEND_POSITION_PATH, maxf(player.smoothed_motion.length(), _vertical_swim_effort))


## Start "swimming".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "swimming"
	player.is_swimming = true
	# Unconditionally snap player to floating level upon starting swim state
	var up_direction: Vector3 = player.up_direction.normalized()
	var water_surface_along_up: float = get_water_surface_along_up()
	if not is_nan(water_surface_along_up):
		var shoulder_offset: float = _get_collision_height() * WATER_SURFACE_SNAP_RATIO
		var target_position_along_up := water_surface_along_up - shoulder_offset
		var current_position_along_up := up_direction.dot(player.global_position)
		player.global_position += up_direction * (target_position_along_up - current_position_along_up)


## Stop "swimming".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "swimming"
	player.is_swimming = false
	player.is_sprinting = false
	_reset_diving()


## Clears all diving state (called on exit, exhaustion respawn, and leaving water).
func _reset_diving() -> void:
	player.is_diving = false
	player.swim_vertical_speed = 0.0
	player.model_pitch = 0.0
	_vertical_swim_effort = 0.0


## Height of the player's collision shape, guarded against missing/atypical shapes.
func _get_collision_height() -> float:
	if not is_instance_valid(player.collision_shape) or player.collision_shape.shape == null:
		return 0.0
	var shape: Shape3D = player.collision_shape.shape
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).height
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size.y
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).height
	return 0.0


func get_contextual_controls(input_type: int) -> Dictionary:
	if not player or not player.controls: return {}

	var controls := {
		player.controls.joypad_button_4_label: "Perspective",
		player.controls.joypad_button_15_label: "Screenshot",
		player.controls.joypad_button_6_label: "Pause Menu",

		player.controls.joypad_button_1_label: "Fast Swim",
		player.controls.left_joystick_label: "Swim",
		player.controls.right_joystick_label: "Camera",
	}

	if player.is_diving:
		controls[player.controls.joypad_button_3_label] = "Surface"
		controls[player.controls.joypad_button_7_label] = "Dive Deeper"
	else:
		controls[player.controls.joypad_button_3_label] = "Climb Out"
		if enable_diving:
			controls[player.controls.joypad_button_7_label] = "Dive"

	return controls


func get_water_surface_along_up() -> float:
	if not player or not player.is_inside_tree():
		return NAN

	# Fast path: use active water area if set
	if is_instance_valid(player.current_water_area):
		var collision_shape := player.current_water_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision_shape and collision_shape.shape is BoxShape3D:
			var box_shape := collision_shape.shape as BoxShape3D
			var up_in_local: Vector3 = collision_shape.global_basis.inverse() * player.up_direction
			var half_size: Vector3 = box_shape.size * 0.5
			var half_extent_along_up: float = abs(up_in_local.x) * half_size.x \
				+ abs(up_in_local.y) * half_size.y \
				+ abs(up_in_local.z) * half_size.z
			var local_surface: Vector3 = up_in_local.normalized() * half_extent_along_up
			var world_surface: Vector3 = collision_shape.to_global(local_surface)
			return player.up_direction.dot(world_surface)

	var tree := player.get_tree()
	if not tree:
		return NAN

	var has_surface := false
	var highest_surface_along_up := 0.0
	var water_nodes := tree.get_nodes_in_group("WATER")

	for node in water_nodes:
		var water_area := node as Area3D
		if not water_area:
			continue

		var collision_shape := water_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if not collision_shape or not (collision_shape.shape is BoxShape3D):
			continue

		var box_shape := collision_shape.shape as BoxShape3D
		var overlapping := water_area.overlaps_body(player)
		if not overlapping:
			var local_pos: Vector3 = collision_shape.to_local(player.global_position)
			var half_size_box: Vector3 = box_shape.size * 0.5
			if abs(local_pos.x) > half_size_box.x or abs(local_pos.z) > half_size_box.z or local_pos.y < -half_size_box.y or local_pos.y > half_size_box.y + 2.0:
				continue

		var up_in_local: Vector3 = collision_shape.global_basis.inverse() * player.up_direction
		var half_size: Vector3 = box_shape.size * 0.5
		var half_extent_along_up: float = abs(up_in_local.x) * half_size.x \
			+ abs(up_in_local.y) * half_size.y \
			+ abs(up_in_local.z) * half_size.z

		var local_surface: Vector3 = up_in_local.normalized() * half_extent_along_up
		var world_surface: Vector3 = collision_shape.to_global(local_surface)
		var surface_along_up: float = player.up_direction.dot(world_surface)

		if not has_surface or surface_along_up > highest_surface_along_up:
			has_surface = true
			highest_surface_along_up = surface_along_up

	if not has_surface:
		return NAN

	return highest_surface_along_up


