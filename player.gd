class_name Player
extends CharacterBody3D

const EMOTE_STATE_PLAYBACK_PATH: String = "parameters/EmoteStateMachine/playback"
const LOCOMOTION_STATE_PLAYBACK_PATH: String = "parameters/LocomotionStateMachine/playback"
const ARCHERY_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/ArcheryLocomotion/blend_position"
const BOW_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/BowLocomotion/blend_position"
const BRACED_HANG_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/BracedHangLocomotion/blend_position"
const CLIMBING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/ClimbingLocomotion/blend_position"
const CROUCHING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/CrouchingLocomotion/blend_position"
const FREE_HANGING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/FreeHangingLocomotion/blend_position"
const GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/GreatSwordLocomotion/blend_position"
const PISTOL_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/PistolLocomotion/blend_position"
const RIFLE_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/RifleLocomotion/blend_position"
const SHIELD_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/ShieldLocomotion/blend_position"
const STANDING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/StandingLocomotion/blend_position"

@export var animation_tree: AnimationTree
@export var current_animation: int
@export var motion_interpolate_speed: float = 10.0
@export var rotation_interpolate_speed: float = 10.0

var attack_sequence: int = 0
var climbing_on_target: Vector3

var equipment: Array = []
var equipment_by_type: Dictionary = {}
var can_player_attack: bool = false
var can_player_shoot: bool = false

var is_aiming_bow: bool = false
var is_attacking: bool = false
var is_attacking_1: bool = false # Attack Sequence: 1 of n
var is_attacking_2: bool = false # Attack Sequence: 2 of n
var is_attacking_3: bool = false # Attack Sequence: 3 of n
var is_drawing_arrow: bool = false
var is_firing_arrow: bool = false
var is_climbing: bool = false
var is_climbing_on: bool = false
var is_crouching: bool = false
var is_emoting: bool = false
var is_hanging_braced: bool = false
var is_hanging_free: bool = false
var is_climbing_hopping_left: bool = false
var is_climbing_hopping_right: bool = false
var is_climbing_hopping_up: bool = false
var is_hopping_from_climbing: bool = false
var is_falling: bool = false
var is_focusing: bool = false
var is_jumping: bool = false
var is_jump_queued: bool = false
var is_paragliding: bool = false
var is_shooting: bool = false
var is_sliding: bool = false
var is_sprinting: bool = false

var orientation := Transform3D()
var root_motion := Transform3D()

var locomotion_state: ## Gets the [StateMachine] "LocomotionStateMachine"
	get:
		return animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH)

@onready var attack_sequence_timer: Timer = $AttackSequenceTimer
@onready var controls: CanvasLayer = $Controls
@onready var debug: CanvasLayer = $Debug
@onready var initial_position: Vector3 = transform.origin
@onready var hanging_braced_detection: RayCast3D = $PlayerModel/HangingBracedDetection
@onready var ledge_detection_horizontal: RayCast3D = $PlayerModel/LedgeDetectionHorizontal
@onready var ledge_detection_vertical: RayCast3D = $PlayerModel/LedgeDetectionHorizontal/LedgeDetectionVertical
@onready var ledge_detection_marker: MeshInstance3D = $PlayerModel/LedgeDetectionHorizontal/LedgeDetectionVertical/LedgeDetectionMarker
@onready var look_at_modifier = $PlayerModel/Armature/GeneralSkeleton/LookAtModifier3D
@onready var look_at_target: Marker3D = $SpringArm3D/ProjectileRaycast/LookAtTarget
@onready var player_input: InputSynchronizer = $InputSynchronizer
@onready var player_model: Node3D = $PlayerModel
@onready var paraglider_raycast: RayCast3D = $ParagliderRaycast
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

	# Keep animation sampling in physics domain to match root-motion consumption in _physics_process.
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS

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
	
	# Stop "climbing" and "hanging" and start "falling" when the player manually cancels with the "crouch" button.
	if event.is_action_pressed("crouch") and (is_climbing or is_hanging_braced or is_hanging_free):
		is_climbing = false
		is_hanging_braced = false
		is_hanging_free = false
		is_climbing_hopping_left = false
		is_climbing_hopping_right = false
		is_climbing_hopping_up = false
		is_hopping_from_climbing = false
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
	var ledge_detected := false
	if not is_on_floor() and ledge_detection_horizontal and ledge_detection_horizontal.is_colliding():
		var forward_direction := -ledge_detection_horizontal.global_transform.basis.z.normalized()
		ledge_detection_vertical.global_position = ledge_detection_horizontal.get_collision_point() + (forward_direction * 0.05) + up_direction
		ledge_detection_vertical.force_raycast_update()
		if ledge_detection_vertical.is_colliding():
			ledge_detection_marker.global_position = ledge_detection_vertical.get_collision_point() + (ledge_detection_vertical.get_collision_normal() * 0.02)
			ledge_detected = true

	# Show/hide ledge detection gizmos.
	if ledge_detected:
		ledge_detection_horizontal.show()
		ledge_detection_marker.show()
	else:
		ledge_detection_vertical.position = Vector3(0, 0, -1) # Reset to default
		ledge_detection_horizontal.hide()
		ledge_detection_marker.hide()

	# Check if "climbing" player has reached a ledge
	if ledge_detected and is_climbing and player_input.motion.length() > 0.1:
		var player_top_position = global_position.y + $CollisionShape3D.shape.height + 0.1
		if player_top_position >= ledge_detection_marker.global_position.y:
			locomotion_state.travel("BracedHangLocomotion")
			is_climbing = false
			is_hanging_braced = true
			is_hanging_free = false

	# Track if the player is "falling"
	is_falling = locomotion_state.get_current_node() == "Falling" and not is_paragliding

	# Stop "jumping" if player is "falling".
	if is_jumping and is_falling:
		is_jumping = false

	# Stop "climbing", "falling", "hanging" (braced/free), and "jumping" when player lands on the floor under normal gravity.
	var climbing_down := is_climbing and player_input.motion.y < -0.1
	if is_on_floor() and not is_jump_queued and velocity.y <= 0.0 and not is_hanging_braced and not is_hanging_free and (not is_climbing or climbing_down):
		is_climbing = false
		is_falling = false
		is_hanging_braced = false
		is_hanging_free = false
		is_jumping = false
		is_climbing_hopping_left = false
		is_climbing_hopping_right = false
		is_climbing_hopping_up = false
		is_hopping_from_climbing = false

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
	equipment.clear()
	equipment_by_type.clear()
	can_player_attack = false
	can_player_shoot = false
	for child in skeleton.get_children():
		if child is BoneAttachment3D:
			child.queue_free()
	locomotion_state.travel("StandingLocomotion")


func rebuild_equipment_cache() -> void:
	equipment_by_type.clear()
	can_player_attack = false
	can_player_shoot = false
	for item in equipment:
		if item == null:
			continue
		if "equipment_type" in item:
			equipment_by_type[item.equipment_type] = item
		if "can_attack" in item and item.can_attack:
			can_player_attack = true
		if "can_shoot" in item and item.can_shoot:
			can_player_shoot = true


func get_equipment_by_type(type: int) -> Node3D:
	return equipment_by_type.get(type, null)


func has_equipment(type: int) -> bool:
	return equipment_by_type.has(type)


func has_any_equipment(types: Array) -> bool:
	for type in types:
		if equipment_by_type.has(type):
			return true
	return false


func has_heavy_weapon_equipped() -> bool:
	return has_any_equipment([
		Equipment.EquipmentType.AXE_2H,
		Equipment.EquipmentType.STAFF,
		Equipment.EquipmentType.SWORD_2H,
	])


func has_one_handed_or_shield_equipped() -> bool:
	return has_any_equipment([
		Equipment.EquipmentType.AXE_1H,
		Equipment.EquipmentType.DAGGER,
		Equipment.EquipmentType.SWORD_1H,
		Equipment.EquipmentType.SWORD_AND_SHIELD,
	])


# https://github.com/godotengine/tps-demo/blob/master/player/player.gd#L86
func apply_input(delta: float) -> void:
	# Get the target motion from the synchronized input.
	var target_motion: Vector2 = player_input.motion

	# Smoothly interpolate the target_motion for more gradual changes in animation blending and rotation.
	target_motion = target_motion.lerp(target_motion, motion_interpolate_speed * delta)

	# While paragliding, block regular locomotion transitions and drive movement directly.
	if is_paragliding:
		is_attacking = false
		is_attacking_1 = false
		is_attacking_2 = false
		is_attacking_3 = false
		is_shooting = false
		is_crouching = false
		is_focusing = false
		is_sprinting = false
		is_sliding = false
		is_climbing = false
		is_climbing_on = false
		is_hanging_braced = false
		is_hanging_free = false
		is_climbing_hopping_left = false
		is_climbing_hopping_right = false
		is_climbing_hopping_up = false
		is_hopping_from_climbing = false
		is_falling = false
		is_jump_queued = false

		if is_on_floor():
			is_paragliding = false
		else:
			if locomotion_state.get_current_node() != "Paragliding":
				locomotion_state.travel("Paragliding")

			var camera_basis := spring_arm.global_transform.basis
			var target_dir := camera_basis * Vector3(target_motion.x, 0.0, -target_motion.y)
			target_dir.y = 0.0
			if target_dir.length_squared() > 0.001 and not is_firing_arrow:
				target_dir = target_dir.normalized()
				var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
				var q_to: Quaternion = Basis.looking_at(-target_dir).get_rotation_quaternion()
				orientation.basis = Basis(q_from.slerp(q_to, delta * rotation_interpolate_speed))

			var current_h_vel := Vector3(velocity.x, 0.0, velocity.z)
			var glide_speed := max(current_h_vel.length(), 4.0)
			if target_dir.length_squared() > 0.001:
				current_h_vel = target_dir.normalized() * glide_speed

			velocity.x = current_h_vel.x
			velocity.z = current_h_vel.z
			velocity.y = min(velocity.y, 0.0)
			velocity += get_gravity() * 0.35 * delta
			velocity.y = max(velocity.y, -4.0)
			set_velocity(velocity)
			set_up_direction(Vector3.UP)
			move_and_slide()

			orientation.origin = Vector3()
			orientation = orientation.orthonormalized()
			player_model.global_transform.basis = orientation.basis
			return

	# Attack { Microsoft: X, Nintendo: Y, Sony: Square, Keyboard: [Alt] }.
	is_attacking = locomotion_state.get_current_node() in [
		"ShieldDownwardSlash",
		"ShieldCrossSlash",
		"ShieldPowerSlash",
		"GreatSwordDownwardSlash",
		"GreatSwordLowSlash",
		"GreatSwordPowerSlash",
	] or (Input.is_action_pressed("attack") and can_player_attack)

	# Attack { Microsoft: X, Nintendo: Y, Sony: Square, Keyboard: [Alt] }.
	var attack_pressed := Input.is_action_just_pressed("attack") and can_player_attack
	is_attacking_1 = attack_pressed and attack_sequence == 0
	is_attacking_2 = attack_pressed and attack_sequence == 1
	is_attacking_3 = attack_pressed and attack_sequence == 2

	# Attack Sequence: Sword and Shield
	if attack_pressed and has_one_handed_or_shield_equipped():
		attack_sequence_timer.start()
		if locomotion_state.get_current_node() == "ShieldDownwardSlash":
			attack_sequence = 1
		elif locomotion_state.get_current_node() == "ShieldCrossSlash":
			attack_sequence = 2
		elif locomotion_state.get_current_node() == "ShieldPowerSlash":
			attack_sequence = 0
			attack_sequence_timer.stop()
	
	# Attack Sequence: Greatsword
	elif attack_pressed and has_heavy_weapon_equipped():
		attack_sequence_timer.start()
		if locomotion_state.get_current_node() == "GreatSwordDownwardSlash":
			attack_sequence = 1
		elif locomotion_state.get_current_node() == "GreatSwordLowSlash":
			attack_sequence = 2
		elif locomotion_state.get_current_node() == "GreatSwordPowerSlash":
			attack_sequence = 0
			attack_sequence_timer.stop()

	# Shoot { Microsoft: 🅁T, Nintendo: 🅁L, Sony: 🅁2, Keyboard: [Left Mouse Button] } 
	is_shooting = Input.is_action_pressed("shoot") and can_player_shoot

	# Crouch { Console: Left ⬤, Keyboard: [Control] }.
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor() and not is_sliding and not is_sprinting

	# Focus { Microsoft: 🄻T, Nintendo: Z🄻, Sony: 🄻2, Keyboard: [Right Mouse Button] }.
	is_focusing = Input.is_action_pressed("focus")

	# Update locomotion state based on equipped items if not in special states
	if not is_climbing and not is_hanging_braced and not is_hanging_free and not is_falling and not is_jumping and not is_sliding:
		var current_state = locomotion_state.get_current_node()
		var target_state = "StandingLocomotion"
		var is_shield_attack_state: bool = current_state == "ShieldDownwardSlash" or current_state == "ShieldCrossSlash" or current_state == "ShieldPowerSlash"
		
		if is_crouching:
			target_state = "CrouchingLocomotion"
		elif has_heavy_weapon_equipped():
			target_state = "GreatSwordLocomotion"
		elif has_equipment(Equipment.EquipmentType.BOW):
			target_state = "BowLocomotion" if not is_shooting else "ArcheryLocomotion"
		elif has_one_handed_or_shield_equipped():
			target_state = "ShieldLocomotion"
		elif has_equipment(Equipment.EquipmentType.PISTOL):
			target_state = "PistolLocomotion"
		elif has_equipment(Equipment.EquipmentType.RIFLE):
			target_state = "RifleLocomotion"
		
		# Transition if target differs from current (skip Jump states but allow transition from any normal state)
		if current_state != target_state:
			if not current_state.contains("Jump") and not is_shield_attack_state:
				locomotion_state.travel(target_state)

	# Check if braced "hanging" player is [now] free
	if is_hanging_braced \
	and not hanging_braced_detection.is_colliding():
		locomotion_state.travel("FreeHangingLocomotion")
		is_hanging_braced = false
		is_hanging_free = true

	# Check if free "hanging" player is [now] braced
	if is_hanging_free \
	and hanging_braced_detection.is_colliding():
		locomotion_state.travel("BracedHangLocomotion")
		is_hanging_braced = true
		is_hanging_free = false

	# Jump { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if is_on_floor() \
	and Input.is_action_just_pressed("jump") \
	and not is_climbing \
	and not is_hanging_braced \
	and not is_hanging_free \
	and not is_jump_queued:
		if target_motion.length() > 0.0:
			if has_heavy_weapon_equipped():
				locomotion_state.travel("GreatSwordJumpForward")
			elif has_equipment(Equipment.EquipmentType.BOW):
				locomotion_state.travel("BowJumpForward")
			elif has_one_handed_or_shield_equipped():
				locomotion_state.travel("ShieldJumpForward")
			elif has_equipment(Equipment.EquipmentType.PISTOL):
				locomotion_state.travel("PistolJumpForward")
			elif has_equipment(Equipment.EquipmentType.RIFLE):
				locomotion_state.travel("RifleJumpForward")
			else:
				locomotion_state.travel("RunningJump")
		else:
			if has_heavy_weapon_equipped():
				locomotion_state.travel("GreatSwordJump")
			elif has_equipment(Equipment.EquipmentType.BOW):
				locomotion_state.travel("BowJump")
			elif has_one_handed_or_shield_equipped():
				locomotion_state.travel("ShieldJump")
			elif has_equipment(Equipment.EquipmentType.RIFLE):
				locomotion_state.travel("RifleJumpUp")
			elif has_equipment(Equipment.EquipmentType.PISTOL):
				locomotion_state.travel("PistolJump")
			else:
				locomotion_state.travel("JumpingUp")
		is_jump_queued = true

	# Climbing, Climbing On
	if is_climbing_on:
		var was_climbing_on := is_climbing_on
		is_climbing_on = animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH).get_current_node() == "BracedHangClimbingOn"
		if was_climbing_on and not is_climbing_on:
			global_position = climbing_on_target
			is_climbing_on = false

	# Climbing, Hopping
	if is_climbing or is_hanging_braced or is_climbing_hopping_left or is_climbing_hopping_right or is_climbing_hopping_up:
		var was_hopping := is_climbing_hopping_left or is_climbing_hopping_right or is_climbing_hopping_up
		var current_node = animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH).get_current_node()
		is_climbing_hopping_left = current_node == "BracedHangHopLeft"
		is_climbing_hopping_right = current_node == "BracedHangHopRight"
		is_climbing_hopping_up = current_node == "BracedHangHopUp"
		if was_hopping and not (is_climbing_hopping_left or is_climbing_hopping_right or is_climbing_hopping_up):
			is_climbing = is_hopping_from_climbing
			is_hanging_braced = not is_hopping_from_climbing
			is_hanging_free = false
			is_hopping_from_climbing = false

	# Climbing, Start { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if not is_on_floor() \
	and not is_climbing \
	and Input.is_action_just_pressed("jump") \
	and ledge_detection_horizontal.is_colliding():
		locomotion_state.travel("ClimbingLocomotion")
		is_climbing = true
		is_falling = false
		is_jumping = false

	# Climbing, Hop Up { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	elif not is_on_floor() \
	and (is_climbing or is_hanging_braced) \
	and Input.is_action_just_pressed("jump") \
	and (locomotion_state.get_current_node() == "ClimbingLocomotion" or locomotion_state.get_current_node() == "BracedHangLocomotion"):
		if is_hanging_braced and ledge_detection_vertical and ledge_detection_vertical.is_colliding():
			climbing_on_target = ledge_detection_vertical.get_collision_point()
			locomotion_state.travel("BracedHangClimbingOn")
			is_climbing = false
			is_climbing_on = true
			is_hanging_braced = false
			is_hanging_free = false
			is_climbing_hopping_left = false
			is_climbing_hopping_right = false
			is_climbing_hopping_up = false
		else:
			locomotion_state.travel("BracedHangHopUp")
			is_hopping_from_climbing = is_climbing
			is_climbing_hopping_left = false
			is_climbing_hopping_right = false
			is_climbing_hopping_up = true
	
	# Climbing, Speed Up { Microsoft: Ⓑ, Nintendo: Ⓐ, Sony: Ⓞ, Keyboard: [Shift] }.
	if is_climbing \
	and Input.is_action_pressed("sprint"):
		animation_tree.set("parameters/LocomotionTimeScale/scale", 1.5)
		is_sprinting = true
	else:
		is_sprinting = false
		animation_tree.set("parameters/LocomotionTimeScale/scale", 1.0)

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
	elif not is_climbing:
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
			if has_equipment(Equipment.EquipmentType.BOW):
				if is_shooting:
					animation_tree.set(ARCHERY_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
				else:
					animation_tree.set(BOW_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif has_any_equipment([
				Equipment.EquipmentType.AXE_1H,
				Equipment.EquipmentType.DAGGER,
				Equipment.EquipmentType.SWORD_1H,
			]):
				animation_tree.set(SHIELD_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif has_heavy_weapon_equipped():
				animation_tree.set(GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif has_equipment(Equipment.EquipmentType.PISTOL):
				animation_tree.set(PISTOL_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif has_equipment(Equipment.EquipmentType.RIFLE):
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
		# While climbing or hanging keep (rotate towards) facing the wall surface from the LedgeDetectionHorizontal raycast
		if is_climbing or is_hanging_braced or is_hanging_free:
			if ledge_detection_horizontal and ledge_detection_horizontal.is_colliding():
				var normal := ledge_detection_horizontal.get_collision_normal()
				var wall_dir := -normal
				wall_dir.y = 0.0
				if wall_dir.length_squared() > 0.001:
					wall_dir = wall_dir.normalized()
					var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
					var q_to: Quaternion = Basis.looking_at(-wall_dir).get_rotation_quaternion()
					orientation.basis = Basis(q_from.slerp(q_to, delta * rotation_interpolate_speed))
		if is_climbing:			
			animation_tree.set(CLIMBING_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
		elif is_hanging_braced:
			animation_tree.set(BRACED_HANG_LOCOMOTION_BLEND_POSITION_PATH, target_motion.x)
		elif is_hanging_free:
			animation_tree.set(FREE_HANGING_LOCOMOTION_BLEND_POSITION_PATH, target_motion.x)
		else:
			var anim_blend := Vector2(0.0, target_motion.length())
			if is_crouching:
				animation_tree.set(CROUCHING_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			if has_equipment(Equipment.EquipmentType.BOW):
				if is_shooting:
					animation_tree.set(ARCHERY_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
				else:
					animation_tree.set(BOW_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif has_one_handed_or_shield_equipped():
				animation_tree.set(SHIELD_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif has_heavy_weapon_equipped():
				animation_tree.set(GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif has_equipment(Equipment.EquipmentType.PISTOL):
				animation_tree.set(PISTOL_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif has_equipment(Equipment.EquipmentType.RIFLE):
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
	if is_climbing or is_climbing_on or is_climbing_hopping_left or is_climbing_hopping_right or is_climbing_hopping_up:
		velocity.y = h_velocity.y
	elif is_hanging_braced or is_hanging_free:
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


func _on_attack_sequence_timer_timeout() -> void:
	attack_sequence = 0
