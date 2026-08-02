class_name Climbing
extends NodeStateMachine

@export_category("Climbing Controls")
@export_group("Keyboard/Mouse Actions")
@export var keyboard_drop_action: StringName = &"crouch"
@export var keyboard_hop_action: StringName = &"jump"
@export var keyboard_sprint_action: StringName = &"sprint"

@export_group("Controller/Touch Actions")
@export var pad_drop_action: StringName = &"crouch"
@export var pad_hop_action: StringName = &"jump"
@export var pad_sprint_action: StringName = &"sprint"

var _this_state = NodeStateMachine.States.CLIMBING


## Called when there is an input event.
func _input(event: InputEvent) -> void:

	# Do nothing if the player is not set or is paused/ragdolling
	if not player or player.is_paused or player.is_ragdolling: return

	var input_type = player.controls.current_input_type if player.controls else 0
	var current_drop_action = keyboard_drop_action if input_type == 0 else pad_drop_action
	var current_hop_action = keyboard_hop_action if input_type == 0 else pad_hop_action

	# Drop / Let go
	if event.is_action_pressed(current_drop_action):
		# Start "falling"
		player.state_machine.travel(_this_state, NodeStateMachine.States.FALLING)
		return

	# Climbing, Hopping [Input]
	if not player.is_on_floor() \
	and event.is_action_pressed(current_hop_action) \
	and not event.is_echo() \
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


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:

	# Do nothing if the player is not set
	if not player: return

	# Check if the player has reached the floor
	if player.is_on_floor():
		# Start "standing"
		player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
		return

	# Ledge detection [Raycast]
	var ledge_detected = player.detect_ledge()

	# Check if "climbing" player has reached a ledge -> Start "hanging" (braced)
	if ledge_detected and player.is_climbing and player.player_input.motion.length() > 0.1:
		var player_top_position = player.global_position.y + player.get_node("CollisionShape3D").shape.height + 0.1
		# Check if the player's top position has reached or exceeded the ledge detection marker's Y-position
		if player_top_position >= player.ledge_detection_marker.global_position.y:
			# Start "hanging"
			player.state_machine.travel(_this_state, NodeStateMachine.States.HANGING)
			return

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
		player.is_climbing_on = player.animation_tree.get(player.LOCOMOTION_STATE_PLAYBACK_PATH).get_current_node() in ["BracedHangClimbingOn", "FreeHangingClimbingOn"]
		if was_climbing_on and not player.is_climbing_on:
			player.global_position = player.climbing_on_target
			player.is_climbing_on = false

	var input_type = player.controls.current_input_type if player.controls else 0
	var current_sprint_action = keyboard_sprint_action if input_type == 0 else pad_sprint_action


	# Climbing, Speed Up [Input]
	if player.is_climbing \
	and Input.is_action_pressed(current_sprint_action):
		player.animation_tree.set("parameters/LocomotionTimeScale/scale", 1.5)
		player.is_sprinting = true
	else:
		player.animation_tree.set("parameters/LocomotionTimeScale/scale", 1.0)
		player.is_sprinting = false

	# Keep (rotate towards) facing the wall surface
	if player.ledge_detection_horizontal and player.ledge_detection_horizontal.is_colliding():
		var normal := player.ledge_detection_horizontal.get_collision_normal()
		var wall_dir := -normal
		wall_dir = wall_dir.slide(player.up_direction)
		if wall_dir.length_squared() > 0.001:
			wall_dir = wall_dir.normalized()
			var q_from: Quaternion = player.orientation.basis.get_rotation_quaternion()
			var q_to: Quaternion = Basis.looking_at(-wall_dir, player.up_direction).get_rotation_quaternion()
			player.orientation.basis = Basis(q_from.slerp(q_to, delta * player.rotation_interpolate_speed))
	
	if player.is_climbing:
		player.animation_tree.set(player.CLIMBING_LOCOMOTION_BLEND_POSITION_PATH, player.smoothed_motion)


## Start "climbing".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "climbing"
	player.is_climbing = true
	# Travel to the "climbing" locomotion state
	player.locomotion_state.travel("ClimbingLocomotion")


## Stop "climbing".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "climbing"
	player.is_climbing = false
	# Reset state variables
	player.is_climbing_hopping_left = false
	player.is_climbing_hopping_right = false
	player.is_climbing_hopping_up = false
	player.is_climbing_on = false
	# Reset timescale in case "sprint" action is still pressed
	player.animation_tree.set("parameters/LocomotionTimeScale/scale", 1.0)
	player.is_sprinting = false
	player.is_hopping_from_climbing = false
	# Clear ledge detection visuals
	player.ledge_detection_vertical.position = Vector3(0, 0, -1) # Reset to default
	player.ledge_detection_horizontal.hide()
	player.ledge_detection_marker.hide()


func get_contextual_controls(input_type: int) -> Dictionary:
	if not player or not player.controls: return {}

	return {
		player.controls.joypad_button_4_label: "Perspective",
		player.controls.joypad_button_15_label: "Screenshot",
		player.controls.joypad_button_6_label: "Pause Menu",

		player.controls.joypad_button_3_label: "Hop",
		player.controls.joypad_button_1_label: "Fast Climb",
		player.controls.joypad_button_7_label: "Drop",
		player.controls.left_joystick_label: "Climb",
		player.controls.right_joystick_label: "Camera",
	}
