class_name Player
extends CharacterBody3D

# https://youtu.be/l4uWdObc4do?si=-nYMz-615jmEC9qs&t=402
# https://www.youtube.com/watch?v=fBcKIxgJv-c&t=247s
@export var animation_tree: AnimationTree
@export var camera: Camera3D
@export var locomotion_forward_blend_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/Standing/ForwardBlend/blend_position"
@export var locomotion_strafe_blend_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/Standing/StrafeBlend/blend_position"
@export var locomotion_crouch_blend_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/Crouching/blend_position"
@export var locomotion_mode_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/Standing/LocomotionSwitch/blend_amount"
@export var locomotion_stance_playback_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/playback"
@export var locomotion_state_playback_path: String = "parameters/LocomotionStateMachine/playback"

@export var transition_speed: float = 12.0 ## Blend interpolation rate (higher = snappier)
@export var turn_speed: float = 120.0
@export var turn_in_place_blend_gain: float = 32.0 ## Scales yaw delta into blend-space X while standing still
@export var turn_in_place_yaw_deadzone: float = 0.002 ## Minimum yaw delta (radians/frame) to trigger turn-in-place blend

@export var crouch_speed: float = 2.5 ## The player's movement speed while crouching
@export var crouch_exit_to_standing_speed_threshold: float = 0.1 ## If moving faster than this when uncrouching, skip transition clip
@export var jump_velocity: float = 4.5 ## The initial velocity applied to the player when a jump is executed
@export var speed: float = 5.0 ## The player's movement speed while standing/walking (not crouching or sprinting)
@export var slide_collision_height: float = 0.5 ## The capsule height used during running slide

@export_group("Animation State Names")
@export var locomotion_state_name: String = "Locomotion"
@export var jumping_state_name: String = "Jumping"
@export var running_jump_state_name: String = "RunningJump"
@export var running_slide_state_name: String = "RunningSlide"
@export var standing_state_name: String = "Standing"
@export var standing_to_crouched_state_name: String = "StandingToCrouched"
@export var crouching_state_name: String = "Crouching"
@export var crouched_to_standing_state_name: String = "CrouchedToStanding"

@onready var physical_bone_simulator: PhysicalBoneSimulator3D = $Pivot/RootMotion/PlayerModel/GeneralSkeleton/PhysicalBoneSimulator3D

var current_input_vector: Vector2 = Vector2.ZERO ## The smoothed [Input] vector used by animation blending
var target_input_vector: Vector2 = Vector2.ZERO ## The raw [Input] vector target set by movement logic
var current_velocity: Vector2 ## The current velocity of the player (no verticality)
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_crouching: bool = false ## Is the player "crouching"?
var is_sliding: bool = false ## Is the player "sliding"?
var is_sprinting: bool = false ## Is the player "sprinting"?
var is_strafing: bool = false ## Is the player "strafing"?
var jump_queued: bool ## Is the "jump" state queued (was the button _just_ pressed)
var standing_collision_height: float ## The standing capsule height used to restore after slide
var standing_collision_y: float ## The standing collision shape local Y position
var previous_rotation_y: float = 0.0 ## Cached yaw from previous physics frame for turn-in-place detection
var playback: AnimationNodeStateMachinePlayback:
	get:
		return animation_tree.get(locomotion_state_playback_path) as AnimationNodeStateMachinePlayback
var stance_playback: AnimationNodeStateMachinePlayback:
	get:
		return animation_tree.get(locomotion_stance_playback_path) as AnimationNodeStateMachinePlayback


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Ensure the player's [PhysicalBone3D]s do not collide with the [CollisionShape3D] required by the [CharacterBody3D]
	physical_bone_simulator.physical_bones_add_collision_exception(self)
	var capsule_shape := $CollisionShape3D.shape as CapsuleShape3D
	if capsule_shape:
		standing_collision_height = capsule_shape.height
	else:
		standing_collision_height = 1.8
	standing_collision_y = $CollisionShape3D.position.y
	previous_rotation_y = rotation.y


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Ignore input while in grounded standing jump state
	if is_on_floor() and playback.get_current_node() == jumping_state_name:
		return

	# If the player is on the floor...
	if is_on_floor():

		# If the "jump" button was just pressed...
		if Input.is_action_just_pressed("jump"):
			# If the player has some velocity...
			if velocity.length() > 0.1:
				# Queue a "running jump"
				begin_running_jump()
			# The player must be standing still
			else:
				# Queue a "standing jump"
				begin_standing_jump()


func _process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Smooth target blend input with time-scaled lerp.
	var blend_weight := clamp(transition_speed * delta, 0.0, 1.0)
	current_input_vector = current_input_vector.lerp(target_input_vector, blend_weight)

	if is_crouching:
		animation_tree.set(locomotion_crouch_blend_path, current_input_vector)
		speed = crouch_speed
	elif is_strafing:
		animation_tree.set(locomotion_mode_path, 1.0)
		if is_sprinting:
			animation_tree.set(locomotion_strafe_blend_path, current_input_vector * 1.5)
			if current_input_vector.y < -0.01:
				speed = 5.0
			else:
				speed = 7.5
		else:
			animation_tree.set(locomotion_strafe_blend_path, current_input_vector)
			speed = 5.0
	else:
		animation_tree.set(locomotion_mode_path, 0.0)
		if is_sprinting:
			animation_tree.set(locomotion_forward_blend_path, current_input_vector * Vector2(1, 1.5))
			if current_input_vector.y < -0.01:
				speed = 5.0
			else:
				speed = 7.5
		else:
			animation_tree.set(locomotion_forward_blend_path, current_input_vector)
			speed = 5.0


func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Ignore movement input while in grounded standing jump state
	if is_on_floor() and playback.get_current_node() == jumping_state_name:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		target_input_vector = Vector2.ZERO
		move_and_slide()
		return

	# If the player is not on the floor...
	if not is_on_floor():
		# Apply gravity
		velocity.y -= gravity * delta
		# Set the "jump queue" flag to false
		jump_queued = false

	# If a jump is queued...
	if jump_queued:
		# Apply the jump velocity to the player
		velocity.y += jump_velocity
		# Reset the "jump queue" flag
		jump_queued = false

	# Get the vector from the player input
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var yaw_delta := wrapf(rotation.y - previous_rotation_y, -PI, PI)
	previous_rotation_y = rotation.y
	var locomotion_state := playback.get_current_node()
	var stance_state := stance_playback.get_current_node()

	# Cache if the player is "crouching"
	is_crouching = stance_state in [standing_to_crouched_state_name, crouching_state_name, crouched_to_standing_state_name]
	var crouch_held := Input.is_action_pressed("crouch")

	# Start crouch/slide on crouch press while grounded.
	if is_on_floor() and Input.is_action_just_pressed("crouch") and not is_crouching:
		if velocity.length() > 0.1 and Input.is_action_pressed("sprint"):
			begin_running_slide()
		else:
			begin_crouch()

	# If crouch key is no longer held, exit crouch as soon as crouch state is active.
	if is_on_floor() and not crouch_held and is_crouching and stance_state != crouched_to_standing_state_name:
		end_crouch()

	# Cache if the player is "sliding"
	is_sliding = locomotion_state == running_slide_state_name

	# Cache if the player is "sprinting"
	is_sprinting = Input.is_action_pressed("sprint") and not is_crouching

	# Cache if the player is "strafing"
	is_strafing = Input.is_action_pressed("aim")

	# Check if the player is "strafing" or "crouching"
	if is_strafing \
	or is_crouching:
		# Strafe mode: full 2D blend, camera controls facing direction
		var direction := (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			var local_velocity_point := to_local(global_position + velocity)
			target_input_vector = Vector2(local_velocity_point.x, -local_velocity_point.z).limit_length(1)
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
			target_input_vector = Vector2.ZERO
	else:
		# Free-move mode: A/D rotates player + turn animation, W/S = forward/backward
		if input_vector.x != 0.0:
			rotate(basis.y, deg_to_rad(-input_vector.x * turn_speed * delta))
		var forward_input := input_vector.y
		if abs(forward_input) > 0.01 or abs(input_vector.x) > 0.01:
			var direction := (transform.basis * Vector3(0, 0, forward_input)).normalized()
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			target_input_vector = Vector2(input_vector.x, -input_vector.y).limit_length(1)
		elif abs(yaw_delta) > turn_in_place_yaw_deadzone and Vector2(velocity.x, velocity.z).length() < 0.05:
			# Camera-driven idle rotation should drive left/right turn clips in ForwardBlend.
			target_input_vector = Vector2(clamp(yaw_delta * turn_in_place_blend_gain, -1.0, 1.0), 0.0)
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
			target_input_vector = Vector2.ZERO
		look_at(global_position - transform.basis.z, Vector3.UP)

	# Move the body based on `velocity`
	if Vector2(velocity.x, velocity.z).length() > speed:
		var clamped = Vector2(velocity.x, velocity.z).limit_length(speed)
		velocity.x = clamped.x
		velocity.z = clamped.y
	move_and_slide()


## Called when the "jump" (while standing) action is first executed. Transitions to the [jumping_state_name] state in the animation tree.
func begin_standing_jump():
	playback.travel(jumping_state_name)


## Called when the "jump" (while running) action is first executed. Transitions to the [running_jump_state_name] state in the animation tree.
func begin_running_jump():
	playback.travel(running_jump_state_name)


## Called when the "crouch" (while sprinting) action is first executed. Transitions to the [running_slide_state_name] state in the animation tree.
func begin_running_slide():
	playback.travel(running_slide_state_name)
	var capsule_shape := $CollisionShape3D.shape as CapsuleShape3D
	if not capsule_shape:
		return
	var slide_collision_y := standing_collision_y - ((standing_collision_height - slide_collision_height) * 0.5)
	# Create a [Tween] to resize the player's collision shape
	var tween_slide := create_tween()
	# Make the collision shape shorter, over time
	tween_slide.tween_property($CollisionShape3D.shape, "height", slide_collision_height, 0.4)
	# At the same time, move the collision shape's position so it stays at the player's feet
	tween_slide.parallel().tween_property($CollisionShape3D, "position:y", slide_collision_y, 0.4)
	# Wait for 0.4 seconds before continuing
	tween_slide.tween_interval(0.4)
	# Make the collision shape bigger, over time
	tween_slide.tween_property($CollisionShape3D.shape, "height", standing_collision_height, 0.4)
	# At the same time, move the collision shape's position so it stays at the player's feet
	tween_slide.parallel().tween_property($CollisionShape3D, "position:y", standing_collision_y, 0.4)


## Called when the "crouch" (while standing) action is first executed. Transitions to the [standing_to_crouched_state_name] state in the animation tree.
func begin_crouch() -> void:
	stance_playback.travel(standing_to_crouched_state_name)


## Called when the "end crouch" action is first executed. Transitions to the [crouched_to_standing_state_name] state in the animation tree.
func end_crouch() -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > crouch_exit_to_standing_speed_threshold:
		stance_playback.travel(standing_state_name)
	else:
		stance_playback.travel(crouched_to_standing_state_name)


## Called by the "jump start/mixamo_com" animation to execute the jump velocity at the correct time (0.5s) in the animation.
func execute_jump_velocity():
	jump_queued = true
