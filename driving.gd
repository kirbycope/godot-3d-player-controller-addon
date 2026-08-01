class_name Driving
extends NodeStateMachine

@export_category("Driving Controls")
@export_group("Keyboard/Mouse Actions")
@export var keyboard_accelerate_action: StringName = &"jump"
@export var keyboard_brake_action: StringName = &"sprint"
@export var keyboard_exit_action: StringName = &"action"

@export_group("Controller/Touch Actions")
@export var pad_accelerate_action: StringName = &"shoot"
@export var pad_brake_action: StringName = &"focus"
@export var pad_exit_action: StringName = &"jump"

var _this_state := NodeStateMachine.States.DRIVING


## Returns the accelerate action name based on the player's current input type.
func get_current_accelerate_action() -> StringName:
	var input_type: int = player.controls.current_input_type if player and player.controls else 0
	return keyboard_accelerate_action if input_type == 0 else pad_accelerate_action


## Returns the brake action name based on the player's current input type.
func get_current_brake_action() -> StringName:
	var input_type: int = player.controls.current_input_type if player and player.controls else 0
	return keyboard_brake_action if input_type == 0 else pad_brake_action


## Returns true if the accelerate action is currently pressed.
func is_accelerate_pressed() -> bool:
	return Input.is_action_pressed(get_current_accelerate_action())


## Returns true if the brake action is currently pressed.
func is_brake_pressed() -> bool:
	return Input.is_action_pressed(get_current_brake_action())


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Do nothing if the player is not set or is paused/ragdolling
	if not player or player.is_paused or player.is_ragdolling: return

	var input_type = player.controls.current_input_type if player.controls else 0
	var current_exit_action = keyboard_exit_action if input_type == 0 else pad_exit_action

	# Exit
	if not player.is_entering_vehicle and not player.is_exiting_vehicle:
		if Input.is_action_just_pressed(current_exit_action):
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
	if player.locomotion_state:
		player.is_entering_vehicle = player.locomotion_state.get_current_node() == "EnteringCar"
	if was_entering_vehicle \
	and not player.is_entering_vehicle:
		# Move player to Driver's seat
		var driver_seat = player.is_driving_in.get_node("DriverSeat") if player.is_driving_in else null
		if driver_seat:
			player.global_position = driver_seat.global_position
			player.orientation = driver_seat.global_transform
			player.orientation.origin = Vector3.ZERO
			player.player_model.global_transform = driver_seat.global_transform

	if player.is_driving_in and not player.is_entering_vehicle and not player.is_exiting_vehicle:
		var driver_seat = player.is_driving_in.get_node("DriverSeat")
		if driver_seat:
			player.global_position = driver_seat.global_position
			player.orientation = driver_seat.global_transform
			player.orientation.origin = Vector3.ZERO
			player.player_model.global_transform = driver_seat.global_transform

	# Check if "ExitCar" animation has finished
	var was_exiting_vehicle = player.is_exiting_vehicle
	if player.locomotion_state:
		player.is_exiting_vehicle = player.locomotion_state.get_current_node() == "ExitingCar"
	if was_exiting_vehicle \
	and not player.is_exiting_vehicle:
		# Stop "driving" and start "standing"
		if player.state_machine:
			player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
		return

	# Determine the vehicle's forward velocity relative to world horizontal heading
	var forward_speed := 0.0
	if player.is_driving_in != null:
		var car = player.is_driving_in
		var heading := Vector3(car.global_transform.basis.z.x, 0.0, car.global_transform.basis.z.z).normalized()
		forward_speed = heading.dot(car.linear_velocity) if heading != Vector3.ZERO else car.global_transform.basis.z.dot(car.linear_velocity)

	# Accelerate, Brake, and Reverse
	if player.is_driving_in != null \
	and not player.is_entering_vehicle \
	and not player.is_exiting_vehicle:
		var car = player.is_driving_in
		var is_car_disabled: bool = car.get("is_on_fire") == true or car.get("has_exploded") == true or player.is_paused or player.is_ragdolling
		if is_car_disabled:
			car.engine_force = 0.0
			car.brake = 0.0
		else:
			var accelerate_pressed := is_accelerate_pressed()
			var brake_pressed := is_brake_pressed()

			# If braking/reversing is pressed
			if brake_pressed:
				# If moving forward, or if accelerate is also held, brake to stop
				if forward_speed > 0.5 or accelerate_pressed:
					var brake_force: float = car.max_brake_force if car.max_brake_force else 50.0
					car.brake = lerp(car.brake, brake_force, delta * 5.0)
					car.engine_force = 0.0
				# Otherwise, reverse
				else:
					var reverse_force: float = car.max_reverse_force if car.max_reverse_force else -50.0
					car.brake = 0.0
					car.engine_force = lerp(car.engine_force, reverse_force, delta * 5.0)
			# If only accelerating is pressed
			elif accelerate_pressed:
				var acceleration_force: float = car.max_acceleration_force if car.max_acceleration_force else 50.0
				car.brake = 0.0
				car.engine_force = lerp(car.engine_force, acceleration_force, delta * 5.0)
			# Otherwise, coast
			else:
				car.brake = 0.0
				car.engine_force = 0.0

	# Steering { Controller: Left-Stick, Keyboard: [A] / [D] }
	if player.is_driving_in != null \
	and not player.is_entering_vehicle \
	and not player.is_exiting_vehicle:
		var car = player.is_driving_in
		var is_car_disabled: bool = car.get("is_on_fire") == true or car.get("has_exploded") == true or player.is_paused or player.is_ragdolling
		if is_car_disabled:
			car.steering = 0.0
		else:
			var steer_input := Input.get_axis("move_right", "move_left")
			car.steering = steer_input * deg_to_rad(30.0)


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
	# Disable crosshair
	player.crosshair.hide()
	# Open (and then close) the driver's car door
	await _open_and_close_drivers_door()


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
	# [Re]Enable crosshair
	player.crosshair.show()


func _open_and_close_drivers_door() -> void:
	var animation_player = player.is_driving_in.get_node("AnimationPlayer")
	if animation_player:
		await get_tree().create_timer(1.1333).timeout
		animation_player.play("open")
		await get_tree().create_timer(2.6).timeout
		animation_player.play("close")


func get_contextual_controls(input_type: int) -> Dictionary:
	if not player or not player.controls: return {}

	if input_type == 0: # KEYBOARD_MOUSE
		return {
			player.controls.joypad_button_4_label: "Perspective",
			player.controls.joypad_button_15_label: "Screenshot",
			player.controls.joypad_button_6_label: "Pause Menu",

			player.controls.joypad_button_3_label: "Accelerate",
			player.controls.joypad_button_1_label: "Brake",
			player.controls.joypad_button_0_label: "Exit",
			player.controls.left_joystick_label: "Steer",
			player.controls.right_joystick_label: "Camera",
		}
	else:
		return {
			player.controls.joypad_button_4_label: "Perspective",
			player.controls.joypad_button_15_label: "Screenshot",
			player.controls.joypad_button_6_label: "Pause Menu",

			player.controls.joypad_axis_4_plus_label: "Brake",
			player.controls.joypad_axis_5_plus_label: "Accelerate",
			player.controls.joypad_button_3_label: "Exit",
			player.controls.left_joystick_label: "Steer",
			player.controls.right_joystick_label: "Camera",
		}
