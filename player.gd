class_name Player
extends CharacterBody3D

const JUMP_VELOCITY = 4.5
const TURN_SPEED = 8.0
const SPEED = 5.0

@export_group("Animation Tree")
@export var animation_tree: AnimationTree
@export var locomotion_forward_blend_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/Standing/ForwardBlend/blend_position"
@export var locomotion_strafe_blend_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/Standing/StrafeBlend/blend_position"
@export var locomotion_crouch_blend_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/Crouching/blend_position"
@export var locomotion_mode_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/Standing/LocomotionSwitch/blend_amount"
@export var locomotion_stance_playback_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/playback"
@export var locomotion_state_playback_path: String = "parameters/LocomotionStateMachine/playback"

@export_group("Animation State Names")
@export var state_name_falling: String = "Falling"
@export var state_name_locomotion: String = "Locomotion"
@export var state_name_backflip: String = "Backflip"
@export var state_name_paragliding: String = "Paragliding"
@export var state_name_standing_jump: String = "Jumping"
@export var state_name_running_jump: String = "RunningJump"
@export var state_name_running_slide: String = "RunningSlide"
@export var state_name_standing: String = "Standing"
@export var state_name_standing_to_crouching: String = "StandingToCrouching"
@export var state_name_crouching: String = "Crouching"
@export var state_name_crouching_to_standing: String = "CrouchingToStanding"

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var input_vector: Vector2 = Vector2.ZERO ## The player's input vector (move_up, move_down, move_left, move_right)
var is_crouching: bool = false ## Is the player "crouching"?
var is_falling: bool = false ## Is the player "falling"?
var is_jumping: bool = false ## Is the player "jumping"?
var is_paragliding: bool = false ## Is the player "paragliding"?
var is_sliding: bool = false ## Is the player "sliding"?
var is_sprinting: bool = false ## Is the player "sprinting"?
var is_strafing: bool = false ## Is the player "strafing"?
var playback_locomotion: AnimationNodeStateMachinePlayback: # LocomotionStateMachine > playback
	get:
		return animation_tree.get(locomotion_state_playback_path) as AnimationNodeStateMachinePlayback
var playback_locomotion_state: String:
	get :
		return animation_tree.get(locomotion_state_playback_path).get_current_node() as String
var playback_stance: AnimationNodeStateMachinePlayback: # LocomotionStateMachine > StanceStateMachine > playback
	get:
		return animation_tree.get(locomotion_stance_playback_path) as AnimationNodeStateMachinePlayback
var playback_stance_state: String:
	get :
		return animation_tree.get(locomotion_stance_playback_path).get_current_node() as String

@onready var camera_sprint_arm: SpringArm3D = $CameraSpringArm
@onready var raycast_below: RayCast3D = $Pivot/Below
@onready var pivot: Node3D = $Pivot ## Used to rotate the character 180°, without affecting its parent [Player] node or being overwritten by its child [RootMotion] node
@onready var physical_bone_simulator: PhysicalBoneSimulator3D = $Pivot/RootMotion/PlayerModel/GeneralSkeleton/PhysicalBoneSimulator3D


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Ensure the player's [PhysicalBone3D]s do not collide with the [CollisionShape3D] required by the [CharacterBody3D]
	physical_bone_simulator.physical_bones_add_collision_exception(get_rid())


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Toggle mouse capture
	if event.is_action_pressed("start") or event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Check if the "focus" action was just pressed or released to toggle the "strafing" flag
	if event.is_action_pressed("focus"):
		is_strafing = true
	elif event.is_action_released("focus"):
		is_strafing = false


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Play forward animation with lateral movement for leaning
	var forward_vector := Vector2(0, input_vector.length())

	# Route input to "locomotion > crouch" blend while crouching so stance locomotion can move
	if is_crouching:
		animation_tree.set(locomotion_mode_path, 0.0)
		animation_tree.set(locomotion_crouch_blend_path, forward_vector)
		animation_tree.set(locomotion_forward_blend_path, Vector2.ZERO)
		return

	# Route input to "locomotion > strafe" blend while strafing so locomotion can move
	if is_strafing:
		animation_tree.set(locomotion_mode_path, 1.0)
		animation_tree.set(
			locomotion_strafe_blend_path, 
			Vector2(
				clamp(input_vector.x, -1, 1),
				-clamp(input_vector.y, -1, 1),
			)
		)
		animation_tree.set(locomotion_forward_blend_path, Vector2.ZERO)
		return

	# Route input to "locomotion > forward" blend so locomotion can move
	animation_tree.set(locomotion_mode_path, 0.0)
	if is_sprinting:
		animation_tree.set(locomotion_forward_blend_path, forward_vector * Vector2(1, 1.5))
	else:
		animation_tree.set(locomotion_forward_blend_path, forward_vector)


## Called once on each physics tick, and allows Nodes to synchronize their logic with physics ticks.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Cache if the player is "crouching"
	is_crouching = playback_stance_state in [state_name_standing_to_crouching, state_name_crouching, state_name_crouching_to_standing]

	# Cache if the player is "jumping"
	is_jumping = playback_locomotion_state in [state_name_running_jump, state_name_standing_jump]

	# Cache if the player is "sliding"
	is_sliding = playback_locomotion_state == state_name_running_slide

	if Input.is_action_pressed("sprint")\
	and is_on_floor() \
	and (abs(velocity.x) > 0.2 or abs(velocity.z) > 0.2)\
	and not is_crouching \
	and not is_sliding \
	and not is_strafing:
		is_sprinting = true
	else:
		is_sprinting = false

	# Check if the player released the "crouch" action and is still flagged as "crouching"
	if not Input.is_action_pressed("crouch") \
	and is_crouching:
		# Transition to the "crouching to standing" state in the animation tree
		playback_stance.travel(state_name_crouching_to_standing)

	# Check if the player is on a floor
	if is_on_floor():
		# [Re]set the "is_falling" flag
		is_falling = false
		# Check if the action "crouch" was just pressed
		if Input.is_action_pressed("crouch") \
		and not is_crouching \
		and not is_sliding:
			# Check if the player has some velocity
			if (abs(velocity.x) > 0.2 or abs(velocity.z) > 0.2) \
			and is_sprinting:
				# Transition to the "sliding" state in the animation tree
				begin_running_slide()
			# The player must be standing still
			else:
				# Transition to the "crouching" state in the animation tree
				begin_crouching()
		# Check if the action "jump" was just pressed
		if Input.is_action_just_pressed("jump"):
			# Backflip when strafing and backpedaling.
			if is_strafing and input_vector.y > 0.2:
				begin_backflip()
			# Check if the player has some velocity
			elif (abs(velocity.x) > 0.2 or abs(velocity.z) > 0.2):
				# Transition to the "running jump" state in the animation tree
				begin_running_jump()
			# The player must be standing still
			else:
				# Transition to the "standing jump" state in the animation tree
				begin_standing_jump()
	# The player must not be on a floor
	else:
		# Check if the "below" raycast is not colliding and the player is not already flagged as "falling"
		if not raycast_below.is_colliding() \
		and not is_falling \
		and not is_jumping \
		and not is_paragliding:
			# Travel to the "falling" state in the animation tree
			playback_locomotion.travel(state_name_falling)
		# Check if "jump" if pressed while in the air
		if Input.is_action_just_pressed("jump"):
			# Transition to the "paragliding" state in the animation tree
			begin_paragliding()

	# Cache the player input vector
	input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.2)

	# Determine the movement direction in 3D space by multiplying the input vector with the [Camera3D]'s [SpringArm3D] global transform basis, while ignoring the y component and normalizing the result
	var direction := camera_sprint_arm.global_transform.basis * Vector3(input_vector.x, 0, input_vector.y)
	# Zero out the y component of the direction to prevent vertical movement, and normalize the result to maintain consistent movement speed in all directions, including diagonally
	direction.y = 0
	# Normalize the direction vector to maintain consistent movement speed in all directions, including diagonally, and check if the resulting vector is not zero to prevent errors when applying movement
	direction = direction.normalized()
	# Check if there is movement input
	if direction.length() > 0.01 and not is_strafing:
		# Rotate the player to face the movement direction
		#pivot.rotation.y = lerp_angle(pivot.rotation.y, atan2(direction.x, direction.z), TURN_SPEED * delta)
		pivot.rotation.y = atan2(direction.x, direction.z)

	var current_rotation = pivot.transform.basis.get_rotation_quaternion()
	var root_motion_velocity = current_rotation * animation_tree.get_root_motion_position() / delta;

	velocity = Vector3(root_motion_velocity.x, velocity.y, root_motion_velocity.z);

	# Check if the player is not on a floor
	if not is_on_floor():
		# Apply gravity, opposite to the player's up direction
		velocity -= up_direction * gravity * delta

	# Move the body based on velocity
	move_and_slide()


## Called when the "jump" (while strafing and backpedaling) action is first executed. Transitions to the [backflip_state_name] state in the animation tree.
func begin_backflip():
	# Transition to the "backflip" state in the animation tree
	playback_locomotion.travel(state_name_backflip)


## Called when the "crouch" (while standing) action is first executed. Transitions to the [standing_to_crouched_state_name] state in the animation tree.
func begin_crouching() -> void:
	# Transition to the "standing to crouching" state in the animation tree
	playback_stance.travel(state_name_standing_to_crouching)


## Called when the "paraglide" (while in the air) action is first executed. Transitions to the [paragliding_state_name] state in the animation tree.
func begin_paragliding() -> void:
	# Transition to the "paragliding" state in the animation tree
	playback_locomotion.travel(state_name_paragliding)
	# Flag the player as "paragliding"
	is_paragliding = true
	# Reduce gravity while paragliding for better control and longer airtime
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity") / 4


## Called when the "jump" (while running) action is first executed. Transitions to the [running_jump_state_name] state in the animation tree.
func begin_running_jump():
	# Transition to the "running jump" state in the animation tree
	playback_locomotion.travel(state_name_running_jump)


## Called when the "slide" (while running) action is first executed. Transitions to the [running_slide_state_name] state in the animation tree.
func begin_running_slide():
	# Transition to the "running slide" state in the animation tree
	playback_locomotion.travel(state_name_running_slide)


## Called when the "jump" (while standing) action is first executed. Transitions to the [jumping_state_name] state in the animation tree.
func begin_standing_jump():
	# Transition to the "standing jump" state in the animation tree
	playback_locomotion.travel(state_name_standing_jump)


## Called by the "jump start/mixamo_com" animation to execute the jump velocity at the correct time (0.5s) in the animation.
func execute_jump_velocity():
	# Apply jump velocity, opposite to the player's up direction
	velocity += up_direction * JUMP_VELOCITY
