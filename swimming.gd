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

var _this_state := NodeStateMachine.States.SWIMMING

const WATER_SURFACE_SNAP_RATIO := 0.75


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

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
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

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
		# Start "standing"
		player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
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

	var input_type = player.controls.current_input_type if player.controls else 0
	var current_climb_out_action = keyboard_climb_out_action if input_type == 0 else pad_climb_out_action
	var current_sprint_action = keyboard_sprint_action if input_type == 0 else pad_sprint_action
	var current_crouch_action = keyboard_crouch_action if input_type == 0 else pad_crouch_action

	# Swimming, Up
	if not player.is_on_wall() \
	and Input.is_action_just_pressed(current_climb_out_action):
		pass

	# Swimming, Down
	if Input.is_action_just_pressed(current_crouch_action):
		pass

	# Swimming, Speed [Input]
	if player.is_swimming \
	and Input.is_action_pressed(current_sprint_action):
		player.animation_tree.set("parameters/LocomotionTimeScale/scale", 1.5)
		player.swimming_root_motion_multiplier = 3
		player.is_sprinting = true
	else:
		player.animation_tree.set("parameters/LocomotionTimeScale/scale", 1.0)
		player.swimming_root_motion_multiplier = 2
		player.is_sprinting = false


func _get_player_shoulder_offset() -> float:
	if not player or not player.collision_shape:
		return 0.0

	var shape: Shape3D = player.collision_shape.shape
	if not shape:
		return 0.0

	if shape is CapsuleShape3D:
		var capsule_shape := shape as CapsuleShape3D
		return capsule_shape.height * WATER_SURFACE_SNAP_RATIO

	if shape is BoxShape3D:
		var box_shape := shape as BoxShape3D
		return box_shape.size.y * WATER_SURFACE_SNAP_RATIO

	return 0.0


func _get_water_surface_along_up(up_direction: Vector3) -> float:
	if not is_inside_tree():
		return NAN

	var tree := get_tree()
	if not tree:
		return NAN

	var has_surface := false
	var highest_surface_along_up := 0.0
	
	var water_nodes := tree.get_nodes_in_group("WATER")

	for node in water_nodes:
		var water_area := node as Area3D
		if not water_area:
			continue
		
		# Check overlap or proximity
		var overlapping := water_area.overlaps_body(player)
		if not overlapping:
			continue

		var collision_shape := water_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if not collision_shape:
			continue

		var box_shape := collision_shape.shape as BoxShape3D
		if not box_shape:
			continue

		var up_in_local: Vector3 = collision_shape.global_basis.inverse() * up_direction
		var half_size: Vector3 = box_shape.size * 0.5
		var half_extent_along_up: float = abs(up_in_local.x) * half_size.x \
			+ abs(up_in_local.y) * half_size.y \
			+ abs(up_in_local.z) * half_size.z

		var local_surface: Vector3 = up_in_local.normalized() * half_extent_along_up
		var world_surface: Vector3 = collision_shape.to_global(local_surface)
		var surface_along_up: float = up_direction.dot(world_surface)

		if not has_surface or surface_along_up > highest_surface_along_up:
			has_surface = true
			highest_surface_along_up = surface_along_up

	if not has_surface:
		return NAN

	return highest_surface_along_up


## Start "swimming".
func start() -> void:
	# Do not start swimming if player is driving or in a vehicle
	if player and (player.is_driving or player.is_driving_in != null or player.is_entering_vehicle or player.is_exiting_vehicle):
		return

	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	
	var up_direction: Vector3 = player.up_direction.normalized()
	var water_surface_along_up: float = _get_water_surface_along_up(up_direction)
	if not is_nan(water_surface_along_up):
		var shoulder_offset := _get_player_shoulder_offset()
		var target_position_along_up := water_surface_along_up - shoulder_offset
		var current_position_along_up := up_direction.dot(player.global_position)
		
		# Unconditionally snap player to floating level upon starting swim state
		player.global_position += up_direction * (target_position_along_up - current_position_along_up)
			
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "swimming"
	player.is_swimming = true
	# Flag the player as not falling/jumping/flying
	player.is_falling = false
	player.is_jumping = false
	player.is_flying = false


## Stop "swimming".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "swimming"
	player.is_swimming = false


func get_contextual_controls(input_type: int) -> Dictionary:
	if not player or not player.controls: return {}

	if input_type == 0: # KEYBOARD_MOUSE
		return {
			player.controls.joypad_button_4_label: "Perspective",
			player.controls.joypad_button_15_label: "Screenshot",
			player.controls.joypad_button_6_label: "Pause Menu",

			player.controls.joypad_button_3_label: "Climb Out",
			player.controls.joypad_button_1_label: "Fast Swim",
			player.controls.left_joystick_label: "Swim",
			player.controls.right_joystick_label: "Camera",
		}
	else:
		return {
			player.controls.joypad_button_4_label: "Perspective",
			player.controls.joypad_button_15_label: "Screenshot",
			player.controls.joypad_button_6_label: "Pause Menu",

			player.controls.joypad_button_3_label: "Climb Out",
			player.controls.joypad_button_1_label: "Fast Swim",
			player.controls.left_joystick_label: "Swim",
			player.controls.right_joystick_label: "Camera",
		}
