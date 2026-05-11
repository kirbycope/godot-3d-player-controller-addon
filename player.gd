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
@export var state_name_locomotion: String = "Locomotion"
@export var state_name_standing_jump: String = "Jumping"
@export var state_name_running_jump: String = "RunningJump"
@export var state_name_running_slide: String = "RunningSlide"
@export var state_name_standing: String = "Standing"
@export var state_name_standing_to_crouching: String = "StandingToCrouching"
@export var state_name_crouching: String = "Crouching"
@export var state_name_crouching_to_standing: String = "CrouchingToStanding"

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_crouching: bool = false ## Is the player "crouching"?
var is_falling: bool = false ## Is the player "falling"?
var is_jumping: bool = false ## Is the player "jumping"?
var is_sliding: bool = false ## Is the player "sliding"?
var is_sprinting: bool = false ## Is the player "sprinting"?
var is_strafing: bool = false ## Is the player "strafing"?
var playback: AnimationNodeStateMachinePlayback:
	get:
		return animation_tree.get(locomotion_state_playback_path) as AnimationNodeStateMachinePlayback

@onready var camera_sprint_arm: SpringArm3D = $CameraSpringArm
@onready var pivot: Node3D = $Pivot ## Rotates the character 180°, without affecting its parent [Player] node or being overwritten by its child [RootMotion] node
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
	if event.is_action_pressed("start"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Get the currently running animation state
	#var locomotion_state := playback.get_current_node()

	# Get the vector from the player input
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.2)

	# Play forward animation with lateral movement for leaning
	var forward_vector := Vector2(0, input_vector.length())

	# Check if the player is "sprinting"
	var is_sprinting = Input.is_action_pressed("sprint") and not is_crouching

	# Set the locomotion blend values in the [AnimationTree] using the player input vector
	if is_sprinting:
		animation_tree.set(locomotion_forward_blend_path, forward_vector * Vector2(1, 1.5))
	else:
		animation_tree.set(locomotion_forward_blend_path, forward_vector)


## Called once on each physics tick, and allows Nodes to synchronize their logic with physics ticks.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Check if the player is not on a floor
	if not is_on_floor():
		# Apply gravity, opposite to the player's up direction
		velocity -= up_direction * gravity * delta
	# The player must be on a floor
	else:
		# Check if the action "jump" was just pressed
		if Input.is_action_just_pressed("jump"):
			# Apply jump velocity, opposite to the player's up direction
			velocity += up_direction * JUMP_VELOCITY

	# Get a [Vector2] from the player input
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Determine the movement direction in 3D space by multiplying the input vector with the [Camera3D]'s [SpringArm3D] global transform basis, while ignoring the y component and normalizing the result
	var direction := camera_sprint_arm.global_transform.basis * Vector3(input_vector.x, 0, input_vector.y)
	# Zero out the y component of the direction to prevent vertical movement, and normalize the result to maintain consistent movement speed in all directions, including diagonally
	direction.y = 0
	# Normalize the direction vector to maintain consistent movement speed in all directions, including diagonally, and check if the resulting vector is not zero to prevent errors when applying movement
	direction = direction.normalized()
	# Check if there is movement input
	if direction:
		# Rotate the player to face the movement direction
		pivot.rotation.y = lerp_angle(pivot.rotation.y, atan2(direction.x, direction.z), TURN_SPEED * delta)

	# Drive horizontal movement from animation root motion to avoid double-driving X/Z.
	if animation_tree != null:
		var root_motion_delta := animation_tree.get_root_motion_position()
		var root_motion_world := pivot.global_transform.basis * root_motion_delta
		var safe_delta := max(delta, 0.00001)
		velocity.x = root_motion_world.x / safe_delta
		velocity.z = root_motion_world.z / safe_delta
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()
