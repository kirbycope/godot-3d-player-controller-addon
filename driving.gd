class_name Driving
extends NodeStateMachine

var _this_state := NodeStateMachine.States.DRIVING


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Exit { Microsoft: Ⓧ, Nintendo: Ⓨ, Sony: 🟗, Keyboard: [Alt] }
	if Input.is_action_just_pressed("attack"):
		# Flag the Player as exiting the vehicle
		player.is_exiting_vehicle = true
		# Open (and then close) the driver's car door
		await _open_and_close_drivers_door()


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set
	if not player: return

	# Check if the "EnterCar" animation has finished
	var was_entering_vehicle = player.is_entering_vehicle
	player.is_entering_vehicle = player.locomotion_state.get_current_node() == "EnteringCar"
	if was_entering_vehicle \
	and not player.is_entering_vehicle:
		# Move player to Driver's seat
		var driver_seat = player.is_driving_in.get_node("DriverSeat")
		if driver_seat:
			player.global_position = driver_seat.global_position
			player.orientation = driver_seat.global_transform
			player.orientation.origin = Vector3.ZERO
			player.player_model.global_transform = driver_seat.global_transform
			player.reparent(driver_seat)

	# Check if "ExitCar" animation has finished
	var was_exiting_vehicle = player.is_exiting_vehicle
	player.is_exiting_vehicle = player.locomotion_state.get_current_node() == "ExitingCar"
	if was_exiting_vehicle \
	and not player.is_exiting_vehicle:
		# Stop "driving" and start "standing"
		player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)

	# Accelerate { Microsoft: Ⓑ, Nintendo: Ⓐ, Sony: Ⓞ, Keyboard: [Shift] }
	if Input.is_action_pressed("sprint") \
	and player.is_driving_in != null \
	and not player.is_entering_vehicle \
	and not player.is_exiting_vehicle:
		player.is_driving_in.engine_force = 100.0
	else:
		if player.is_driving_in != null:
			player.is_driving_in.engine_force = 0.0

	# Brake { Microsoft: Ⓐ, Nintendo: Ⓑ, Sony: Ⓧ, Keyboard: [E] }
	if Input.is_action_pressed("action") \
	and player.is_driving_in != null \
	and not player.is_entering_vehicle \
	and not player.is_exiting_vehicle:
		# TODO: If player is moving forward, apply brake. If player is moving backward, apply engine_force.
		player.is_driving_in.brake = 100.0
		player.is_driving_in.engine_force = -100.0
	else:
		if player.is_driving_in != null:
			player.is_driving_in.brake = 0.0

	# Steering { Controller: Left-Stick, Keyboard: [A] / [D] }
	if player.is_driving_in != null \
	and not player.is_entering_vehicle \
	and not player.is_exiting_vehicle:
		var steer_input := Input.get_axis("move_right", "move_left")
		player.is_driving_in.steering = steer_input * deg_to_rad(30.0)


## Start "driving".
func start() -> void:
	# Enable _this_ state node
	process_mode = Node.PROCESS_MODE_INHERIT
	# Set the player's new state
	player.current_state = _this_state
	# Flag the player as "driving"
	player.is_driving = true
	player.is_entering_vehicle = true
	player.is_exiting_vehicle = false
	# Disable player collision
	player.collision_shape.disabled = true
	# Open (and then close) the driver's car door
	await _open_and_close_drivers_door()
	# Update the labels in the UI to reflect the driving state controls
	if player.controls:
		player.controls.set_labels({
			player.controls.joypad_button_0_label: "Brake",
			player.controls.joypad_button_1_label: "Accelerate",
			player.controls.joypad_button_2_label: "Exit",
			player.controls.left_joystick_label: "Steer",
			player.controls.right_joystick_label: "Camera",
		})


## Stop "driving".
func stop() -> void:
	# Disable _this_ state node
	process_mode = Node.PROCESS_MODE_DISABLED
	# Clear the player's state (if it is currently set to _this_ state)
	if player.current_state == _this_state:
		player.current_state = -1
	# Flag the player as not "driving"
	player.is_driving = false
	player.is_driving_in = null
	player.is_entering_vehicle = false
	player.is_exiting_vehicle = false
	# [Re]Enable player collision
	player.collision_shape.disabled = false
	# Reparent the player back to its initial parent
	player.reparent(player.initial_parent)
	# Reset the labels in the UI to reflect the original control labels
	if player.controls:
		player.controls.reset_labels()


func _open_and_close_drivers_door() -> void:
	var animation_player = player.is_driving_in.get_node("AnimationPlayer")
	if animation_player:
		await get_tree().create_timer(1.1333).timeout
		animation_player.play("open")
		await get_tree().create_timer(2.6).timeout
		animation_player.play("close")
