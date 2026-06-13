class_name Player
extends CharacterBody3D

const EMOTE_STATE_PLAYBACK_PATH: String = "parameters/EmoteStateMachine/playback"
const LOCOMOTION_STATE_PLAYBACK_PATH: String = "parameters/LocomotionStateMachine/playback"
const ARCHERY_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/ArcheryLocomotion/blend_position"
const BOW_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/BowLocomotion/blend_position"
const BRACED_HANG_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/BracedHangLocomotion/blend_position"
const CLIMBING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/ClimbingLocomotion/blend_position"
const CROUCHING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/CrouchingLocomotion/blend_position"
const FREE_HANGING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/FreeHangLocomotion/blend_position"
const GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/GreatSwordLocomotion/blend_position"
const PISTOL_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/PistolLocomotion/blend_position"
const RIFLE_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/RifleLocomotion/blend_position"
const SHIELD_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/ShieldLocomotion/blend_position"
const STANDING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/StandingLocomotion/blend_position"

@export var animation_tree: AnimationTree
@export var current_animation: int
@export var motion_interpolate_speed: float = 10.0
@export var rotation_interpolate_speed: float = 10.0

var equipment: Array = []
var equipped_axe_1h: bool = false
var equipped_axe_2h: bool = false
var equipped_bow: bool = false
var equipped_dagger: bool = false
var equipped_pistol: bool = false
var equipped_rifle: bool = false
var equipped_shield: bool = false
var equipped_staff: bool = false
var equipped_sword_1h: bool = false
var equipped_sword_2h: bool = false

var is_aiming_bow: bool = false
var is_drawing_arrow: bool = false
var is_firing_arrow: bool = false
var is_climbing: bool = false
var is_crouching: bool = false
var is_emoting: bool = false
var is_hanging_braced: bool = false
var is_hanging_free: bool = false
var is_hopping_left: bool = false
var is_hopping_right: bool = false
var is_hopping_up: bool = false
var is_falling: bool = false
var is_focusing: bool = false
var is_jumping: bool = false
var is_jump_queued: bool = false
var is_shooting: bool = false
var is_sliding: bool = false
var is_sprinting: bool = false

var orientation := Transform3D()
var root_motion := Transform3D()

var locomotion_state: ## Gets the [StateMachine] "LocomotionStateMachine"
	get:
		return animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH)

@onready var controls: CanvasLayer = $Controls
@onready var debug: CanvasLayer = $Debug
@onready var initial_position: Vector3 = transform.origin
@onready var ledge_detection_horizontal: RayCast3D = $PlayerModel/Armature/LedgeDetectionHorizontal
@onready var ledge_detection_vertical: RayCast3D = $PlayerModel/Armature/LedgeDetectionHorizontal/LedgeDetectionVertical
@onready var ledge_detection_marker: MeshInstance3D = $PlayerModel/Armature/LedgeDetectionHorizontal/LedgeDetectionVertical/LedgeDetectionMarker
@onready var look_at_modifier = $PlayerModel/Armature/GeneralSkeleton/LookAtModifier3D
@onready var look_at_target: Marker3D = $SpringArm3D/ProjectileRaycast/LookAtTarget
@onready var player_input: InputSynchronizer = $InputSynchronizer
@onready var player_model: Node3D = $PlayerModel
@onready var projectile_raycast: RayCast3D = $SpringArm3D/ProjectileRaycast
@onready var skeleton: Skeleton3D = $PlayerModel/Armature/GeneralSkeleton
@onready var spring_arm: SpringArm3D = $SpringArm3D


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Pre-initialize orientation transform.
	orientation = player_model.global_transform
	orientation.origin = Vector3()

	# Ensure the AnimationTree is active so that root motion is applied in the first frame.
	animation_tree.active = true

	# Ensure the projectile RayCast3D doesn't collide with the player.
	projectile_raycast.add_exception(self)


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		# Check if the mouse is currently captured
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# Set the mouse mode to visible to show the mouse cursor
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# The mouse must not be currently captured
		else:
			# Set the mouse mode to captured to hide the mouse cursor
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Stop "climbing" and start "falling" when the player manually cancels climbing with the "crouch" button.
	if event.is_action_pressed("crouch") and is_climbing:
		is_climbing = false
		locomotion_state.travel("Falling")
		is_falling = true


# https://github.com/godotengine/tps-demo/blob/master/player/player.gd#L54
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Apply player input to control the character and update the animation state.
	apply_input(delta)

	# If we're below -40, respawn (teleport to the initial position).
	if transform.origin.y < -40.0:
		transform.origin = initial_position

	# Ledge detection
	var forward_direction := -ledge_detection_horizontal.global_transform.basis.z.normalized()
	if ledge_detection_horizontal and ledge_detection_horizontal.is_colliding():
		ledge_detection_vertical.global_position = ledge_detection_horizontal.get_collision_point() + (forward_direction * 0.05) + up_direction
		ledge_detection_vertical.force_raycast_update()
		if ledge_detection_vertical.is_colliding():
			ledge_detection_marker.global_position = ledge_detection_vertical.get_collision_point() + (ledge_detection_vertical.get_collision_normal() * 0.02)
			ledge_detection_horizontal.show()
			ledge_detection_marker.show()
		else:
			ledge_detection_horizontal.hide()
			ledge_detection_marker.hide()
	else:
		ledge_detection_vertical.position = Vector3(0, 0, -1) # Reset to default
		ledge_detection_horizontal.hide()
		ledge_detection_marker.hide()

	# Track if the player is "falling"
	is_falling = locomotion_state.get_current_node() == "Falling"

	# Stop "jumping" if player is "falling".
	if is_jumping and is_falling:
		is_jumping = false

	# Stop "climbing", "falling", "hanging" (braced/free), and "jumping" when player lands on the floor under normal gravity.
	if is_on_floor() and not is_jump_queued and velocity.y <= 0.0:
		is_climbing = false
		is_falling = false
		is_hanging_braced = false
		is_hanging_free = false
		is_jumping = false

	# Stop "sliding" when the animation finishes.
	var was_sliding := is_sliding
	is_sliding = locomotion_state.get_current_node() == "RunningSlide"
	if was_sliding and not is_sliding:
		is_sliding = false

	# Stop emote state when the animation finishes and reset the blend amount.
	if is_emoting and animation_tree.get(EMOTE_STATE_PLAYBACK_PATH).get_current_node() == "Idle":
		animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 0.0)
		is_emoting = false

	## DEBUG: Toggle emote state for testing purposes.
	if Input.is_action_just_pressed("emote"):
		var emote_state = animation_tree.get(EMOTE_STATE_PLAYBACK_PATH)
		if emote_state.get_current_node() != "Waving":
			animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 1.0)
			emote_state.travel("Waving")
			is_emoting = true

	## DEBUG: Remove all equipment for testing purposes.
	if Input.is_action_just_pressed("unequip"):
		debug_unequip_all()


func debug_unequip_all() -> void:
	equipped_axe_1h = false
	equipped_axe_2h = false
	equipped_bow = false
	equipped_dagger = false
	equipped_pistol = false
	equipped_rifle = false
	equipped_shield = false
	equipped_staff = false
	equipped_sword_1h = false
	equipped_sword_2h = false
	equipment.clear()
	for child in skeleton.get_children():
		if child is BoneAttachment3D:
			child.queue_free()
	locomotion_state.travel("StandingLocomotion")


# https://github.com/godotengine/tps-demo/blob/master/player/player.gd#L86
func apply_input(delta: float) -> void:
	# Get the target motion from the synchronized input.
	var target_motion: Vector2 = player_input.motion

	# Smoothly interpolate the target_motion for more gradual changes in animation blending and rotation.
	target_motion = target_motion.lerp(target_motion, motion_interpolate_speed * delta)

	# Check if the player can shoot based on their equipped items.
	var can_player_shoot := false
	for item in equipment:
		if "can_shoot" in item and item.can_shoot:
			can_player_shoot = true
			break

	# Shoot { Microsoft: 🅁T, Nintendo: 🅁L, Sony: 🅁2, Keyboard: [Left Mouse Button] } 
	is_shooting = Input.is_action_pressed("shoot") and can_player_shoot

	# Crouch { Console: Left ⬤, Keyboard: [Control] }.
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor() and not is_sliding and not is_sprinting

	# Focus { Microsoft: 🄻T, Nintendo: Z🄻, Sony: 🄻2, Keyboard: [Right Mouse Button] }.
	is_focusing = Input.is_action_pressed("focus")

	# Jump { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if is_on_floor() \
	and Input.is_action_just_pressed("jump") \
	and not is_climbing \
	and not is_hanging_braced \
	and not is_hanging_free \
	and not is_jump_queued:
		if target_motion.length() > 0.0:
			if equipped_axe_2h or equipped_staff or equipped_sword_2h:
				locomotion_state.travel("GreatSwordJumpForward")
			elif equipped_bow:
				locomotion_state.travel("BowJumpForward")
			elif equipped_dagger or equipped_shield or equipped_sword_1h:
				locomotion_state.travel("ShieldJumpForward")
			elif equipped_pistol:
				locomotion_state.travel("PistolJumpForward")
			elif equipped_rifle:
				locomotion_state.travel("RifleJumpForward")
			else:
				locomotion_state.travel("RunningJump")
		else:
			if equipped_axe_2h or equipped_staff or equipped_sword_2h:
				locomotion_state.travel("GreatSwordJump")
			elif equipped_bow:
				locomotion_state.travel("BowJump")
			elif equipped_dagger or equipped_shield or equipped_sword_1h:
				locomotion_state.travel("ShieldJump")
			elif equipped_rifle:
				locomotion_state.travel("RifleJumpUp")
			elif equipped_pistol:
				locomotion_state.travel("PistolJump")
			else:
				locomotion_state.travel("JumpingUp")
		is_jump_queued = true

	# Climbing, Hopping Up
	if is_climbing or is_hanging_braced or is_hopping_up:
		is_hopping_up = animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH).get_current_node() == "BracedHangHopUp"

	# Climbing, Start { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if not is_on_floor() \
	and not is_climbing \
	and Input.is_action_just_pressed("jump") \
	and ledge_detection_horizontal.is_colliding():
		locomotion_state.travel("ClimbingLocomotion")
		is_climbing = true

	# Climbing, Hop Up { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	elif not is_on_floor() \
	and (is_climbing or is_hanging_braced) \
	and Input.is_action_just_pressed("jump") \
	and locomotion_state.get_current_node() == "ClimbingLocomotion":
		locomotion_state.travel("BracedHangHopUp")
		is_hopping_up = true

	# Sprint { Microsoft: Ⓑ, Nintendo: Ⓐ, Sony: Ⓞ, Keyboard: [Shift] }.
	if is_on_floor() \
	and Input.is_action_pressed("sprint") \
	and not is_crouching \
	and not is_jump_queued \
	and not is_jumping \
	and not is_sliding \
	and (target_motion.y > 0.0 if is_focusing else target_motion.length() > 0.0):
		if is_focusing:
			target_motion.y *= 1.5
			target_motion.x *= 0.5 # reduce strafe blend by 50% when sprinting so the blend favors the forward direction
		else:
			target_motion *= 1.5
		is_sprinting = true
	else:
		is_sprinting = false

	# Slide (Crouch while Sprinting)
	if is_sprinting \
	and Input.is_action_just_pressed("crouch") \
	and not is_sliding:
		locomotion_state.travel("RunningSlide")
		is_sliding = true

	# Handle movement is strafing
	if is_shooting or is_focusing:

		# Rotate to face the camera direction when focusing or shooting (unless is_focusing and not is_shooting)
		if (is_shooting or not is_focusing) and not is_firing_arrow and not is_hanging_braced and not is_hanging_free and not is_climbing:
			var camera_basis := spring_arm.global_transform.basis
			var camera_forward := -camera_basis.z
			camera_forward.y = 0.0
			if camera_forward.length_squared() > 0.001:
				camera_forward = camera_forward.normalized()
				var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
				var q_to: Quaternion = Basis.looking_at(-camera_forward).get_rotation_quaternion()
				orientation.basis = Basis(q_from.slerp(q_to, delta * rotation_interpolate_speed))
		if is_crouching:
			animation_tree.set(CROUCHING_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
		else:
			if equipped_bow:
				if is_shooting:
					animation_tree.set(ARCHERY_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
				else:
					animation_tree.set(BOW_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif equipped_axe_1h or equipped_dagger or equipped_sword_1h:
				animation_tree.set(SHIELD_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif equipped_axe_2h or equipped_staff or equipped_sword_2h:
				animation_tree.set(GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif equipped_pistol:
				animation_tree.set(PISTOL_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif equipped_rifle:
				animation_tree.set(RIFLE_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			else:
				animation_tree.set(STANDING_LOCOMOTION_BLEND_POSITION_PATH, target_motion)

	# Handle movement when not strafing
	else:
		# Use camera-relative direction for target_motion direction
		var camera_basis := spring_arm.global_transform.basis
		var target_dir := camera_basis * Vector3(target_motion.x, 0.0, -target_motion.y)
		target_dir.y = 0.0
		if target_dir.length_squared() > 0.001 and not is_firing_arrow and not is_hanging_braced and not is_hanging_free and not is_climbing:
			target_dir = target_dir.normalized()
			var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
			var q_to: Quaternion = Basis.looking_at(-target_dir).get_rotation_quaternion()
			orientation.basis = Basis(q_from.slerp(q_to, delta * rotation_interpolate_speed))
		if is_climbing:
			animation_tree.set(CLIMBING_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
		elif is_hanging_braced:
			animation_tree.set(BRACED_HANG_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
		elif is_hanging_free:
			animation_tree.set(FREE_HANGING_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
		else:
			var anim_blend := Vector2(0.0, target_motion.length())
			if is_crouching:
				animation_tree.set(CROUCHING_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			if equipped_bow:
				if is_shooting:
					animation_tree.set(ARCHERY_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
				else:
					animation_tree.set(BOW_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif equipped_axe_1h or equipped_dagger or equipped_shield or equipped_sword_1h:
				animation_tree.set(SHIELD_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif equipped_axe_2h or equipped_staff or equipped_sword_2h:
				animation_tree.set(GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif equipped_pistol:
				animation_tree.set(PISTOL_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif equipped_rifle:
				animation_tree.set(RIFLE_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			else:
				animation_tree.set(STANDING_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)

	root_motion = Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())

	orientation *= root_motion

	var h_velocity: Vector3 = orientation.origin / delta

	# Influence of root motion is removed when in the air, and movement is instead based on the input direction to allow for more player control while jumping and falling.
	if is_jumping or is_falling:
		var camera_basis := spring_arm.global_transform.basis
		var target_dir := camera_basis * Vector3(target_motion.x, 0.0, -target_motion.y)
		target_dir.y = 0.0
		
		var current_h_vel := Vector3(velocity.x, 0.0, velocity.z)
		var current_speed := current_h_vel.length()
		var air_speed_cap := max(current_speed, 5.0)
		var target_h_vel = target_dir * air_speed_cap
		
		# Slowly lerp to target air speed to preserve momentum
		h_velocity = current_h_vel.lerp(target_h_vel, 3.0 * delta)

	velocity.x = h_velocity.x
	velocity.z = h_velocity.z
	if is_climbing or is_hanging_braced or is_hanging_free or is_hopping_up:
		velocity.y = 0.0
	else:
		velocity += get_gravity() * 1.5 * delta
	set_velocity(velocity)
	set_up_direction(Vector3.UP)
	move_and_slide()

	orientation.origin = Vector3() # Clear accumulated root motion displacement (was applied to speed).
	orientation = orientation.orthonormalized() # Orthonormalize orientation.

	player_model.global_transform.basis = orientation.basis


## Called by the animation(s) using "Call Method Track" to execute the jump logic at the right time. 
func execute_jump() -> void:
	velocity.y = 5.0
	is_jump_queued = false
	is_jumping = true
