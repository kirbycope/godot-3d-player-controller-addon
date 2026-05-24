class_name Player
extends CharacterBody3D

const JUMP_VELOCITY = 4.5
const TURN_SPEED = 8.0
const SPEED = 5.0
const FALL_AIR_CONTROL_MULTIPLIER = 0.5
const LANDING_SKIP_LATERAL_SPEED = 0.75

@export_group("Animation Tree")
@export var animation_tree: AnimationTree
@export var locomotion_forward_blend_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/Standing/ForwardBlend/blend_position"
@export var locomotion_strafe_blend_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/Standing/StrafeBlend/blend_position"
@export var locomotion_crouch_blend_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/Crouching/blend_position"
@export var locomotion_mode_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/Standing/LocomotionSwitch/blend_amount"
@export var locomotion_stance_playback_path: String = "parameters/LocomotionStateMachine/Locomotion/StanceStateMachine/playback"
@export var locomotion_state_playback_path: String = "parameters/LocomotionStateMachine/playback"
@export var climbing_move_blend_path: String = "parameters/LocomotionStateMachine/Climbing/blend_position"
@export var hanging_free_move_blend_path: String = "parameters/LocomotionStateMachine/Hanging/FreeMove/blend_position"
@export var hanging_braced_move_blend_path: String = "parameters/LocomotionStateMachine/Hanging/BracedMove/blend_position"
@export var hanging_blend_path: String = "parameters/LocomotionStateMachine/Hanging/HangingSwitch/blend_amount"

@export_group("Animation State Names")
@export var state_name_climbing: String = "Climbing"
@export var state_name_falling: String = "Falling"
@export var state_name_locomotion: String = "Locomotion"
@export var state_name_backflip: String = "Backflip"
@export var state_name_hanging: String = "Hanging"
@export var state_name_paragliding: String = "Paragliding"
@export var state_name_standing_jump: String = "Jumping"
@export var state_name_running_jump: String = "RunningJump"
@export var state_name_running_slide: String = "RunningSlide"
@export var state_name_standing: String = "Standing"
@export var state_name_standing_panting: String = "StandingPanting"
@export var state_name_standing_to_crouching: String = "StandingToCrouching"
@export var state_name_crouching: String = "Crouching"
@export var state_name_crouching_to_standing: String = "CrouchingToStanding"

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var input_vector: Vector2 = Vector2.ZERO ## The player's input vector (move_up, move_down, move_left, move_right)
var is_climbing: bool = false ## Is the player "climbing"?
var is_crouching: bool = false ## Is the player "crouching"?
var is_exhausted: bool = false ## Is the player "exhausted"?
var is_falling: bool = false ## Is the player "falling"?
var is_hanging: bool = false ## Is the player "hanging"?
var is_jumping: bool = false ## Is the player "jumping"?
var is_paragliding: bool = false ## Is the player "paragliding"?
var is_ragdolling: bool = false ## Is the player "ragdolling"?
var is_running: bool = false ## Is the player "running"?
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

@onready var audio: Node3D = $Audio ## The audio controller
@onready var camera_spring_arm: SpringArm3D = $CameraSpringArm
@onready var raycast_top: RayCast3D = $Pivot/Top
@onready var raycast_head: RayCast3D = $Pivot/Head
@onready var raycast_chest: RayCast3D = $Pivot/Chest
@onready var raycast_below_paraglide: RayCast3D = $Pivot/BelowParaglide ## Used to detect if the player is high enough off the groud to paraglide
@onready var raycast_below_step: RayCast3D = $Pivot/BelowStep ## Used to detect if the player is close enough to the floor to step down and not fall.
@onready var skeleton: Skeleton3D = $Pivot/RootMotion/PlayerModel/GeneralSkeleton
@onready var pivot: Node3D = $Pivot ## Used to rotate the character 180°, without affecting its parent [Player] node or being overwritten by its child [RootMotion] node
@onready var physical_bone_simulator: PhysicalBoneSimulator3D = $Pivot/RootMotion/PlayerModel/GeneralSkeleton/PhysicalBoneSimulator3D
@onready var progress_bar_stamina: TextureProgressBar = $ProgressBarStamina
@onready var voice_male_effort_grunt: AudioStreamPlayer3D = $Audio/VoiceMaleEffortGrunt


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Ensure the [CameraSpringArm] doesn't collide with the player
	camera_spring_arm.add_excluded_object(self.get_rid())
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

	if event is InputEventKey \
	and event.is_pressed() \
	and event.keycode == Key.KEY_R:
		if is_ragdolling:
			print("Unragdolling player")
			# Disable the ragdoll simulation to return control to the player
			skeleton.get_node("PhysicalBoneSimulator3D").physical_bones_stop_simulation()
			# Set collision layer to 0
			skeleton.find_children("Physical Bone *","PhysicalBone3D", false)
			for physical_bone in skeleton.find_children("Physical Bone *","PhysicalBone3D", false):
				physical_bone.collision_layer[0] = true
				physical_bone.collision_layer[1] = false
			is_ragdolling = false
		else:
			print("Ragdolling player")
			# Set collision layer to 1
			skeleton.find_children("Physical Bone *","PhysicalBone3D", false)
			for physical_bone in skeleton.find_children("Physical Bone *","PhysicalBone3D", false):
				physical_bone.collision_layer[0] = false
				physical_bone.collision_layer[1] = true
			skeleton.get_node("PhysicalBoneSimulator3D").physical_bones_start_simulation()
			is_ragdolling = true


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

	# Blend between hanging free (0.0) and hanging braced (1.0)
	animation_tree.set(hanging_blend_path, 1.0 if raycast_chest.is_colliding() else 0.0)
	var climbing_blend := Vector2(clamp(input_vector.x, -1.0, 1.0), -clamp(input_vector.y, -1.0, 1.0)) if is_climbing else Vector2.ZERO
	animation_tree.set(climbing_move_blend_path, climbing_blend)
	var hanging_lateral_blend := clamp(input_vector.x, -1.0, 1.0) if is_hanging else 0.0
	animation_tree.set(hanging_free_move_blend_path, hanging_lateral_blend)
	animation_tree.set(hanging_braced_move_blend_path, hanging_lateral_blend)


## Called once on each physics tick, and allows Nodes to synchronize their logic with physics ticks.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Cache if the player is "crouching" 🧎
	is_crouching = playback_stance_state in [state_name_standing_to_crouching, state_name_crouching, state_name_crouching_to_standing]

	# Cache if the player is "jumping" 🤾
	is_jumping = playback_locomotion_state in [state_name_running_jump, state_name_standing_jump]

	# Cache if the player is "climbing"
	is_climbing = playback_locomotion_state == state_name_climbing

	# Cache if the player is "hanging"
	is_hanging = playback_locomotion_state == state_name_hanging

	# Cache if the player is "paragliding" 🪂
	#is_paragliding = playback_locomotion_state == state_name_paragliding

	# Cache if the player is "running" 🏃🏻‍♀️‍➡️
	is_running = playback_locomotion_state == state_name_locomotion and input_vector.length() >= 0.99

	# Cache if the player is "sliding" 🛝
	is_sliding = playback_locomotion_state == state_name_running_slide

	# ᯓ🏃🏻‍♀️‍➡️ [sprint]
	if Input.is_action_pressed("sprint")\
	and is_on_floor() \
	and (abs(velocity.x) > 0.2 or abs(velocity.z) > 0.2)\
	and not is_crouching \
	and not is_exhausted \
	and not is_sliding \
	and not is_strafing:
		if progress_bar_stamina.value <= 0.0:
			is_exhausted = true
		else:
			is_sprinting = true
	else:
		is_sprinting = false

	# 😮‍💨 [exhausted]
	if is_exhausted and velocity.length() < 0.2 and not is_crouching:
		playback_stance.travel(state_name_standing_panting)
	elif not is_exhausted and playback_stance_state == state_name_standing_panting:
		playback_stance.travel(state_name_standing)

	# 🧎 [crouch]
	if not Input.is_action_pressed("crouch") \
	and is_crouching:
		# Transition to the "crouching to standing" state in the animation tree
		playback_stance.travel(state_name_crouching_to_standing)

	# Check if the player is on a floor
	if is_on_floor():
		# Ignore landing animation when touching down from falling with enough lateral momentum.
		var lateral_velocity := velocity - up_direction * velocity.dot(up_direction)
		if playback_locomotion_state == state_name_falling and lateral_velocity.length() > LANDING_SKIP_LATERAL_SPEED:
			playback_locomotion.travel(state_name_locomotion)
			# Play "landing" sound
			play_footstep_sound()
		# [Re]set the "is_falling" flag
		is_falling = false
		# Stop climbing if the player has landed while climbing
		if is_climbing:
			end_climbing()
		# Stop hanging if the player has landed while hanging
		if is_hanging:
			end_hanging()
		# Stop paragliding if the player has landed while paragliding
		if is_paragliding:
			end_paragliding()
			# Unflag the player as "paragliding"
			is_paragliding = false

		# 🧎 [crouch] was just pressed
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

		# 🤾 [jump] was just pressed
		if Input.is_action_just_pressed("jump") and not is_ragdolling:
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
		var can_climb := raycast_top.is_colliding() and raycast_chest.is_colliding()
		var can_hang := raycast_top.is_colliding() and raycast_head.is_colliding()

		# 🤾 [jump] was just pressed
		if Input.is_action_just_pressed("jump") and not is_ragdolling:
			if not is_hanging \
			and not is_climbing \
			and can_hang:
				if can_climb:
					begin_climbing()
					is_climbing = true
				else:
					begin_hanging()
					is_hanging = true
				is_falling = false

		if can_climb and is_hanging:
			begin_climbing()
			is_hanging = false
			is_climbing = true
			is_falling = false
		elif is_climbing and can_hang and not can_climb:
			end_climbing_to_hanging()
			is_climbing = false
			is_hanging = true
			is_falling = false
		elif is_climbing and not can_hang:
			end_climbing_to_falling()
			is_climbing = false
			is_falling = true

		# Check if the player should stop hanging and start falling due to losing contact
		if is_hanging and not can_hang:
			end_hanging_to_falling()
			is_falling = true
			is_hanging = false

		# Check if the "below" raycast is not colliding and the player is not already flagged as "falling"
		if not raycast_below_step.is_colliding() \
		and not is_falling \
		and not is_jumping \
		and not is_climbing \
		and not is_hanging \
		and not is_paragliding:
			# Travel to the "falling" state in the animation tree
			playback_locomotion.travel(state_name_falling)
			is_falling = true
		# Check if "jump" if pressed while in the air
		if Input.is_action_just_pressed("jump") \
		and not raycast_below_paraglide.is_colliding() \
		and not is_climbing \
		and not is_hanging \
		and not is_paragliding:
			# Transition to the "paragliding" state in the animation tree
			begin_paragliding()
			# Flag the player as "paragliding"
			is_paragliding = true

	# Cache the player input vector
	input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.2)

	# Determine the movement direction in 3D space by multiplying the input vector with the [Camera3D]'s [SpringArm3D] global transform basis, while ignoring the y component and normalizing the result
	var direction := camera_spring_arm.global_transform.basis * Vector3(input_vector.x, 0, input_vector.y)
	# Zero out the y component of the direction to prevent vertical movement, and normalize the result to maintain consistent movement speed in all directions, including diagonally
	direction.y = 0
	# Normalize the direction vector to maintain consistent movement speed in all directions, including diagonally, and check if the resulting vector is not zero to prevent errors when applying movement
	direction = direction.normalized()
	# Check if there is movement input
	if direction.length() > 0.01 \
	and not is_strafing \
	and not is_climbing \
	and not is_hanging:
		# Rotate the player to face the movement direction
		#pivot.rotation.y = lerp_angle(pivot.rotation.y, atan2(direction.x, direction.z), TURN_SPEED * delta)
		pivot.rotation.y = atan2(direction.x, direction.z)

	# If airborne in fall/paraglide, use raw input direction for movement instead of root motion from the animation tree.
	if is_ragdolling:
		velocity = up_direction * velocity.dot(up_direction)
	elif is_climbing:
		var right_dir = pivot.global_transform.basis.x
		velocity = (right_dir * -input_vector.x + up_direction * -input_vector.y) * (SPEED * 0.25)
	elif is_hanging:
		var right_dir = pivot.global_transform.basis.x
		velocity = right_dir * -input_vector.x * (SPEED * 0.25)
	elif is_paragliding or is_falling:
		# Use raw input direction while airborne instead of animation root motion.
		var paraglide_velocity := camera_spring_arm.global_transform.basis * Vector3(input_vector.x, 0, input_vector.y)
		paraglide_velocity.y = 0
		if paraglide_velocity.length() > 0.01:
			var air_control_speed := SPEED if is_paragliding else SPEED * FALL_AIR_CONTROL_MULTIPLIER
			paraglide_velocity = paraglide_velocity.normalized() * air_control_speed
		velocity = Vector3(paraglide_velocity.x, velocity.y, paraglide_velocity.z)
	# Use root motion from the animation tree while grounded or jumping.
	else:
		var current_rotation = pivot.transform.basis.get_rotation_quaternion()
		var root_motion_velocity = current_rotation * animation_tree.get_root_motion_position() / delta;
		velocity = Vector3(root_motion_velocity.x, velocity.y, root_motion_velocity.z);

	# Check if the player is not on a floor
	if not is_on_floor() and not is_hanging and not is_climbing:
		# Apply gravity, opposite to the player's up direction
		velocity -= up_direction * gravity * delta

	# Move the body based on velocity
	move_and_slide()


## Called when the "jump" (while strafing and backpedaling) action is first executed. Transitions to the [backflip_state_name] state in the animation tree.
func begin_backflip():
	# Transition to the "backflip" state in the animation tree
	playback_locomotion.travel(state_name_backflip)


## Called when the "climb" action is first executed. Transitions to the [climbing_state_name] state in the animation tree.
func begin_climbing() -> void:
	if is_paragliding:
		gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
		is_paragliding = false
	# Transition to the "climbing" state in the animation tree.
	playback_locomotion.travel(state_name_climbing)
	gravity = 0
	velocity = Vector3.ZERO


## Called when the "crouch" (while standing) action is first executed. Transitions to the [standing_to_crouched_state_name] state in the animation tree.
func begin_crouching() -> void:
	# Transition to the "standing to crouching" state in the animation tree
	playback_stance.travel(state_name_standing_to_crouching)


## Called when the "paraglide" (while in the air) action is first executed. Transitions to the [paragliding_state_name] state in the animation tree.
func begin_paragliding() -> void:
	# Transition to the "paragliding" state in the animation tree
	playback_locomotion.travel(state_name_paragliding)
	# Reduce gravity while paragliding for better control and longer airtime
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity") / 4


func begin_hanging() -> void:
	# Stop paragliding if currently paragliding
	if is_paragliding:
		# Reset gravity to the default value
		gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
		is_paragliding = false
	# Determine if the player should enter the "hanging braced" state based on if there is a wall to the player's front to brace against, by checking if the "head" or "chest" raycasts are colliding with a wall while the "top" raycast is colliding with a ceiling.
	var hanging_braced := raycast_chest.is_colliding()
	# Set the "hanging" blend parameter to 1.0 to transition to the hanging state in the animation tree, and set the "hanging braced move" blend parameter to 1.0 if the player should be hanging
	playback_locomotion.set("parameters/hanging_blend", 1.0)
	if hanging_braced:
		playback_locomotion.set("parameters/hanging_braced_move", 1.0)
	else:
		playback_locomotion.set("parameters/hanging_braced_move", 0.0)
	# Transition to the "hanging" state in the animation tree.
	playback_locomotion.travel(state_name_hanging)
	# Disable gravity while hanging
	gravity = 0
	velocity = Vector3.ZERO


func end_hanging() -> void:
	# Return to locomotion when grounded.
	playback_locomotion.travel(state_name_locomotion)
	# Reset gravity to the default value
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func end_hanging_to_falling() -> void:
	# Return to falling when ledge contact is lost.
	playback_locomotion.travel(state_name_falling)
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func end_climbing() -> void:
	playback_locomotion.travel(state_name_locomotion)
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func end_climbing_to_hanging() -> void:
	playback_locomotion.travel(state_name_hanging)
	gravity = 0
	velocity = Vector3.ZERO


func end_climbing_to_falling() -> void:
	playback_locomotion.travel(state_name_falling)
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func end_paragliding() -> void:
	# Transition to the "locomotion" state in the animation tree
	playback_locomotion.travel(state_name_locomotion)
	# Reset gravity to the default value
	gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


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
	# Play a random [short] effort grunt
	voice_male_effort_grunt.play()


## Called by an animation to play footstep sounds based on the meta-data of the object the player is stepping on.
func play_footstep_sound():
	$Audio.check_under_player()
