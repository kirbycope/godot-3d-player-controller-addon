class_name Driving
extends NodeStateMachine

@export_category("Driving Controls")
@export_group("Keyboard/Mouse Actions")
@export var keyboard_accelerate_action: StringName = &"jump"
@export var keyboard_brake_action: StringName = &"sprint"
@export var keyboard_handbrake_action: StringName = &"throw"
@export var keyboard_exit_action: StringName = &"action"

@export_group("Controller/Touch Actions")
@export var pad_accelerate_action: StringName = &"shoot"
@export var pad_brake_action: StringName = &"focus"
@export var pad_handbrake_action: StringName = &"throw"
@export var pad_exit_action: StringName = &"jump"

@export_group("Steering Tuning")
@export var max_steering_angle: float = 30.0
@export var steering_speed: float = 3.5

var _this_state := NodeStateMachine.States.DRIVING
var reverse_delay_timer: float = 0.0
var forward_delay_timer: float = 0.0


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


## Returns the handbrake action name based on the player's current input type.
func get_current_handbrake_action() -> StringName:
	var input_type: int = player.controls.current_input_type if player and player.controls else 0
	return keyboard_handbrake_action if input_type == 0 else pad_handbrake_action


## Returns true if the handbrake action is currently pressed.
func is_handbrake_pressed() -> bool:
	return Input.is_action_pressed(get_current_handbrake_action())


## Called when there is an input event.
func _input(event: InputEvent) -> void:

	# Do nothing if the player is not set or is paused/ragdolling
	if not player or player.is_paused or player.is_ragdolling: return

	var input_type = player.controls.current_input_type if player.controls else 0
	var current_exit_action = keyboard_exit_action if input_type == 0 else pad_exit_action

	# Exit
	if not player.is_entering_vehicle and not player.is_exiting_vehicle:
		if Input.is_action_just_pressed(current_exit_action):
			var speed := 0.0
			if player.is_driving_in:
				speed = player.is_driving_in.linear_velocity.length()
			
			if speed > 2.0:
				var exit_marker = player.is_driving_in.get_node_or_null("ExitCar")
				if not exit_marker:
					exit_marker = player.is_driving_in.get_node_or_null("EnterCar")
				
				if exit_marker:
					player.global_position = exit_marker.global_position
				
				var car_parent = player.is_driving_in.get_parent()
				if car_parent and player.get_parent() != car_parent:
					player.reparent(car_parent)
				
				if player.state_machine:
					player.state_machine.travel(_this_state, NodeStateMachine.States.STANDING)
			else:
				# Flag the Player as exiting the vehicle
				player.is_exiting_vehicle = true
				# Open (and then close) the driver's car door
				await _open_and_close_drivers_door()


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:

	# Do nothing if the player is not set
	if not player: return

	# Check if the "EnterCar" animation has finished
	var was_entering_vehicle = player.is_entering_vehicle
	if player.locomotion_state and player.is_entering_vehicle:
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

	# Determine the vehicle's forward and lateral velocity relative to world horizontal heading
	var forward_speed: float = 0.0
	var speed: float = 0.0
	if player.is_driving_in != null:
		var car = player.is_driving_in
		speed = car.linear_velocity.length()
		var heading: Vector3 = Vector3(car.global_transform.basis.z.x, 0.0, car.global_transform.basis.z.z).normalized()
		forward_speed = heading.dot(car.linear_velocity) if heading != Vector3.ZERO else car.global_transform.basis.z.dot(car.linear_velocity)

	# Accelerate, Brake, Reverse, Handbrake, Steering & Transmission
	if player.is_driving_in != null \
	and not player.is_entering_vehicle \
	and not player.is_exiting_vehicle:
		var car = player.is_driving_in
		var is_car_disabled: bool = car.get("is_on_fire") == true or car.get("has_exploded") == true or player.is_paused or player.is_ragdolling
		
		if is_car_disabled:
			var parked_brake: float = car.get("max_brake_force") if car.get("max_brake_force") != null else 1800.0
			for child in car.get_children():
				if child is VehicleWheel3D:
					child.engine_force = 0.0
					child.brake = parked_brake
			car.steering = 0.0
		else:
			var accelerate_pressed: bool = is_accelerate_pressed()
			var brake_pressed: bool = is_brake_pressed()
			var handbrake_pressed: bool = is_handbrake_pressed()

			var max_accel: float = car.get("max_acceleration_force") if car.get("max_acceleration_force") != null else 4500.0
			var max_brake: float = car.get("max_brake_force") if car.get("max_brake_force") != null else 3500.0
			var max_rev: float = car.get("max_reverse_force") if car.get("max_reverse_force") != null else -2500.0
			var drive_bias: float = car.get("drive_bias_front") if car.get("drive_bias_front") != null else 0.5
			var brake_bias: float = car.get("brake_bias_front") if car.get("brake_bias_front") != null else 0.65
			var handbrake_slip: float = car.get("handbrake_traction_loss") if car.get("handbrake_traction_loss") != null else 0.82

			# --- Transmission & Gear State Machine ---
			var gear_speeds: Array[float] = [8.0, 16.0, 25.0, 36.0, 50.0]
			var gear_torque_mults: Array[float] = [1.2, 1.0, 0.85, 0.7, 0.55]

			if car.clutch_timer > 0.0:
				car.clutch_timer -= delta

			var target_gear: int = 1
			if forward_speed >= -0.3:
				for g_idx in range(gear_speeds.size()):
					if speed <= gear_speeds[g_idx] or g_idx == gear_speeds.size() - 1:
						target_gear = g_idx + 1
						break
				# Aggressive handbrake downshift: reset gear when handbraking slows the vehicle
				if handbrake_pressed:
					if speed < 10.0:
						target_gear = 1
					elif speed < 18.0:
						target_gear = mini(target_gear, 2)
					elif speed < 28.0:
						target_gear = mini(target_gear, 3)
			else:
				target_gear = -1

			if target_gear != car.current_gear and target_gear > 0 and car.current_gear > 0:
				if handbrake_pressed:
					# Instant downshift on handbrake without shift lag
					car.clutch_timer = 0.0
					car.current_gear = target_gear
				else:
					car.clutch_timer = 0.12 # Brief clutch disengagement for shift sound drop
					car.current_gear = target_gear
			elif target_gear < 0 or car.current_gear < 0:
				car.current_gear = target_gear

			var is_grounded: bool = car.is_any_wheel_on_ground() if car.has_method("is_any_wheel_on_ground") else true
			var ground_speed: float = Vector2(car.linear_velocity.x, car.linear_velocity.z).length()

			# --- Target RPM Calculation ---
			var target_rpm: float = 0.0
			if not is_grounded and not accelerate_pressed:
				target_rpm = 0.1 # Gentle idle hum in mid-air
			elif car.current_gear > 0:
				var g_idx: int = car.current_gear - 1
				var min_g_spd: float = 0.0 if g_idx == 0 else gear_speeds[g_idx - 1]
				var max_g_spd: float = gear_speeds[g_idx]
				var progress: float = clampf((ground_speed - min_g_spd) / maxf(max_g_spd - min_g_spd, 1.0), 0.0, 1.0)
				if accelerate_pressed:
					target_rpm = lerp(0.35, 1.0, progress)
				else:
					target_rpm = lerp(0.1, 0.5, progress)
			elif car.current_gear == -1: # Reverse
				var progress: float = clampf(ground_speed / 12.0, 0.0, 1.0)
				target_rpm = lerp(0.3, 0.9, progress) if brake_pressed else 0.1

			if (brake_pressed or handbrake_pressed) and accelerate_pressed and speed < 2.5:
				target_rpm = 0.95 # Burnout redline

			if car.clutch_timer > 0.0:
				target_rpm = 0.25 # Clutch dip on gear shift

			car.current_rpm = lerp(car.current_rpm, target_rpm, delta * 12.0)

			# --- Force Calculation ---
			var target_engine_force: float = 0.0
			var target_brake_front: float = 0.0
			var target_brake_rear: float = 0.0
			var rear_slip_multiplier: float = 1.0

			var current_gear_mult: float = gear_torque_mults[clampi(car.current_gear - 1, 0, gear_torque_mults.size() - 1)] if car.current_gear > 0 else 1.0

			# 1. Acceleration Forward / Braking when in Reverse
			if accelerate_pressed:
				if forward_speed < -0.4:
					# Moving backward in reverse: Pressing accelerate smoothly brakes to a stop!
					forward_delay_timer = 0.6 # Set delay so car stops and holds firmly before driving forward
					target_brake_front = max_brake * brake_bias
					target_brake_rear = max_brake * (1.0 - brake_bias)
					target_engine_force = 0.0
				else:
					if absf(forward_speed) <= 0.4 and forward_delay_timer > 0.0 and not brake_pressed:
						# Hold standstill when stopped from reverse
						forward_delay_timer -= delta
						target_brake_front = max_brake
						target_brake_rear = max_brake
						target_engine_force = 0.0
					else:
						# Drive forward in forward gear
						target_engine_force = max_accel * current_gear_mult
			else:
				forward_delay_timer = 0.0

			# 2. Regular Braking Forward / Reversing
			if brake_pressed:
				if forward_speed > 0.4:
					# Moving forward: Smoothly brake to a stop
					reverse_delay_timer = 0.6 # Set delay so car stops and holds firmly first
					target_brake_front = max_brake * brake_bias
					target_brake_rear = max_brake * (1.0 - brake_bias)
					if not handbrake_pressed and not accelerate_pressed:
						target_engine_force = 0.0
				elif forward_speed < -0.4:
					# Already moving backward: Continue reverse unless accelerating
					if accelerate_pressed:
						target_brake_front = max_brake
						target_brake_rear = max_brake
						target_engine_force = 0.0
					else:
						target_engine_force = max_rev
						target_brake_front = 0.0
						target_brake_rear = 0.0
				else:
					# Standstill / Low speed (< 0.4 m/s)
					if accelerate_pressed:
						# Rev in place at standstill: hold all brakes firmly and cut drive force
						target_brake_front = max_brake
						target_brake_rear = max_brake
						target_engine_force = 0.0
					elif reverse_delay_timer > 0.0:
						# Hold standstill! Keeps brakes applied firmly so player can just stop
						reverse_delay_timer -= delta
						target_brake_front = max_brake
						target_brake_rear = max_brake
						target_engine_force = 0.0
					else:
						# Reverse delay passed: Engage reverse gear
						target_engine_force = max_rev
						target_brake_front = 0.0
						target_brake_rear = 0.0
			else:
				reverse_delay_timer = 0.0

			# 3. Handbrake (locks rear wheels only, enables progressive drift)
			if handbrake_pressed:
				target_brake_rear = max_brake * 1.5
				rear_slip_multiplier = handbrake_slip
				if not brake_pressed and not (accelerate_pressed and forward_speed < -0.4):
					target_brake_front = 0.0
				if accelerate_pressed and forward_speed >= -0.4:
					target_engine_force = max_accel * current_gear_mult

			# --- Apply Forces to Wheels ---
			for child in car.get_children():
				if child is VehicleWheel3D:
					if not child.has_meta("default_friction"):
						child.set_meta("default_friction", child.wheel_friction_slip)

					var default_fric: float = child.get_meta("default_friction")
					var is_rear: bool = child.position.z < 0.0

					var target_brake: float = target_brake_rear if is_rear else target_brake_front
					child.brake = lerp(child.brake, target_brake, delta * 10.0)

					if child.use_as_traction:
						if brake_pressed and forward_speed > 0.4 and not accelerate_pressed:
							child.engine_force = 0.0
						elif accelerate_pressed and forward_speed < -0.4 and not brake_pressed:
							child.engine_force = 0.0
						else:
							# Distribute torque according to drive_bias_front
							var wheel_torque_share: float = (1.0 - drive_bias) if is_rear else drive_bias
							var wheel_target_force: float = target_engine_force * wheel_torque_share * 2.0
							child.engine_force = lerp(child.engine_force, wheel_target_force, delta * 12.0)

					var target_slip: float = default_fric * (rear_slip_multiplier if is_rear else 1.0)
					var recovery_rate: float = 12.0 if handbrake_pressed else 25.0
					child.wheel_friction_slip = lerp(child.wheel_friction_slip, target_slip, delta * recovery_rate)

			# --- GTA Dynamic Speed-Sensitive Steering ---
			var steer_speed_factor: float = clampf(1.0 - (speed / 35.0) * 0.62, 0.35, 1.0)
			var steer_input: float = Input.get_axis("move_right", "move_left")
			var target_steering: float = steer_input * deg_to_rad(max_steering_angle * steer_speed_factor)
			car.steering = move_toward(car.steering, target_steering, delta * steering_speed)

			# --- Aerodynamic Downforce Stabilization ---
			if is_grounded:
				var downforce_mag: float = clampf(ground_speed * ground_speed * (car.get("downforce_coeff") if car.get("downforce_coeff") != null else 4.0), 0.0, 4000.0)
				car.apply_central_force(-car.global_transform.basis.y * downforce_mag)


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
	if player.locomotion_state:
		player.locomotion_state.start("EnteringCar")
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
	if player.is_driving_in and player.is_driving_in.has_method("set_driver"):
		player.is_driving_in.set_driver(null)
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

	var controls = {
		player.controls.joypad_button_4_label: "Perspective",
		player.controls.joypad_button_15_label: "Screenshot",
		player.controls.joypad_button_6_label: "Pause Menu",
		player.controls.joypad_button_10_label: "Handbrake",
		player.controls.joypad_button_13_label: "Prev\nStation",
		player.controls.joypad_button_14_label: "Next\nStation",
		player.controls.left_joystick_label: "Steer",
		player.controls.right_joystick_label: "Camera",
	}
	if input_type == 0: # KEYBOARD_MOUSE
		controls[player.controls.joypad_button_3_label] = "Accelerate"
		controls[player.controls.joypad_button_1_label] = "Brake"
		controls[player.controls.joypad_button_0_label] = "Exit"
		controls[player.controls.key_j_label] = "Prev\nStation"
		controls[player.controls.key_l_label] = "Next\nStation"
	else:
		controls[player.controls.joypad_axis_4_plus_label] = "Brake"
		controls[player.controls.joypad_axis_5_plus_label] = "Accelerate"
		controls[player.controls.joypad_button_3_label] = "Exit"
	
	return controls
