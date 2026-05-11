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
			print_debug("Showing mouse")
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			print_debug("Hiding mouse")
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return


func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Add the gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := camera_sprint_arm.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	direction.y = 0
	direction = direction.normalized()
	if direction:
		pivot.rotation.y = lerp_angle(pivot.rotation.y, atan2(direction.x, direction.z), TURN_SPEED * delta)
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
