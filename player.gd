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

var current_state: int = -1 ## The current state of the Player (from the Node/Code [NodeStateMachine], not the AnimationTree NodeStateMachine).
var locomotion_state: ## Gets the [NodeStateMachine] "LocomotionStateMachine"
	get:
		return animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH)

# Equipment
var equipment: Array = []
var equipment_by_type: Dictionary = {}
var can_player_attack: bool = false ## Does the currently equipped item allow the Player to attack?
var can_player_shoot: bool = false ## Does the currently equipped item allow the Player to shoot?

# Attack Sequence (while holding equipment)
var attack_sequence: int = 0
var is_attacking: bool = false
var is_attacking_1: bool = false # Attack Sequence: 1 of n
var is_attacking_2: bool = false # Attack Sequence: 2 of n
var is_attacking_3: bool = false # Attack Sequence: 3 of n
# Bow and Arrow
var is_aiming_bow: bool = false
var is_drawing_arrow: bool = false
var is_firing_arrow: bool = false
# Climbing
var is_climbing: bool = false ## Is the Player currently climbing?
var is_climbing_on: bool = false ## Is the Player currently climbing on to a ledge?
var climbing_on_target: Vector3  ## The target position the Player is climbing on to (from ledge detection).
var is_climbing_hopping_left: bool = false ## Is the Player currently hopping left while climbing?
var is_climbing_hopping_right: bool = false ## Is the Player currently hopping right while climbing?
var is_climbing_hopping_up: bool = false ## Is the Player currently hopping up while climbing?
var is_hopping_from_climbing: bool = false ## Is the Player currently hopping while climbing?
# Hanging
var is_hanging_braced: bool = false ## Is the Player currently hanging (braced)?
var is_hanging_free: bool = false ## Is the Player currently hanging (free)?

var is_crouching: bool = false ## Is the Player currently crouching?
var is_emoting: bool = false ## Is the Player currently emoting?
var is_exhausted: bool = false ## Is the Player currently exhausted?
var is_falling: bool = false ## Is the Player currently falling?
var is_focusing: bool = false ## Is the Player currently focusing (forward or on a target)?
var is_jumping: bool = false ## Is the Player currently jumping?
var is_jump_queued: bool = false ## Is the Player currently queued to jump?
var is_mining: bool = false ## Is the Player currently mining?
var is_logging: bool = false ## Is the Player currently logging?
var is_paragliding: bool = false ## Is the Player currently paragliding?
var is_shooting: bool = false ## Is the Player currently shooting?
var is_sliding: bool = false ## Is the Player currently sliding?
var is_sprinting: bool = false ## Is the Player currently sprinting?

var initial_collision_shape_height: float
var initial_collision_shape_position: Vector3
var orientation := Transform3D()
var root_motion := Transform3D()

@onready var attack_sequence_timer: Timer = $AttackSequenceTimer
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
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
@onready var state_machine: NodeStateMachine = $NodeStateMachine ## Enables/Disables the scripts that run when various States are entered/exited.
@onready var sfx_footsteps_grass: AudioStreamPlayer3D = $SFX_Footsteps_Grass
@onready var sfx_footsteps_slide: AudioStreamPlayer3D = $SFX_Footsteps_Slide
@onready var sfx_footsteps_wood: AudioStreamPlayer3D = $SFX_Footsteps_Wood


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Pre-initialize orientation transform.
	orientation = player_model.global_transform
	orientation.origin = Vector3()

	# Record the initial collision shape height and position for crouching and sliding.
	initial_collision_shape_height = collision_shape.shape.height
	initial_collision_shape_position = collision_shape.position

	# Ensure the AnimationTree is active so that root motion is applied in the first frame.
	animation_tree.active = true

	# Keep animation sampling in physics domain to match root-motion consumption in _physics_process.
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS

	# Ensure the projectile RayCast3D doesn't collide with the player
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


# https://github.com/godotengine/tps-demo/blob/master/player/gd#L54
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Start falling if the player is not on the floor and not already falling.
	if not is_on_floor() and not is_falling \
	and not is_climbing and not is_climbing_on \
	and not is_hanging_braced and not is_hanging_free \
	and not is_jumping and not is_jump_queued \
	and not is_paragliding:
		# Enable the "falling" state in the NodeStateMachine. The AnimationTree will automatically transition to the "Falling" animation state.
		state_machine.travel(NodeStateMachine.States.FALLING)

	# Apply player input to control the character and update the animation state.
	apply_input(delta)

	# Treat "jumping" as queued jump or upward airborne movement.
	is_jumping = (is_on_floor() and is_jump_queued) or (not is_on_floor() and locomotion_state.get_current_node().contains("Jump"))

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


# https://github.com/godotengine/tps-demo/blob/master/player/gd#L86
func apply_input(delta: float) -> void:
	# Get the target motion from the synchronized input.
	var target_motion: Vector2 = player_input.motion

	# Track if player is mining or logging.
	is_mining = locomotion_state.get_current_node() == "Mining" or "Mining" in locomotion_state.get_travel_path()
	is_logging = locomotion_state.get_current_node() == "Logging" or "Logging" in locomotion_state.get_travel_path()
	# If the player is mining or logging, block regular locomotion transitions by setting the `target_motion` to zero.
	if is_mining or is_logging:
		target_motion = Vector2.ZERO

	# Smoothly interpolate the target_motion for more gradual changes in animation blending and rotation.
	target_motion = target_motion.lerp(target_motion, motion_interpolate_speed * delta)

	# While paragliding, block regular locomotion. Paragliding.gd will handle movement.
	if is_paragliding:
		return

	# Attack { Microsoft: Ⓧ, Nintendo: Ⓨ, Sony: 🟗, Keyboard: [Alt] }
	if Input.is_action_just_pressed("attack") \
	and not is_attacking \
	and can_player_attack:
		# Enable the "attacking" state in the NodeStateMachine. The AnimationTree will automatically transition to the "Falling" animation state.
		state_machine.travel(NodeStateMachine.States.ATTACKING)

	# Climbing, Start { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if not is_on_floor() \
	and not is_climbing \
	and not is_hanging_braced \
	and not is_hanging_free \
	and Input.is_action_just_pressed("jump") \
	and ledge_detection_horizontal.is_colliding():
		# Stop "falling", start "climbing"
		if is_falling:
			state_machine.travel(NodeStateMachine.States.CLIMBING, NodeStateMachine.States.FALLING)
		# Stop "jumping", start "climbing"
		elif is_jumping:
			state_machine.travel(NodeStateMachine.States.CLIMBING, NodeStateMachine.States.JUMPING)
		# Start "climbing" from any other state
		else:
			state_machine.travel(NodeStateMachine.States.CLIMBING)

	# Crouch { Console: Left ⬤, Keyboard: [Control] }.
	if Input.is_action_pressed("crouch") \
	and not is_crouching \
	and is_on_floor() \
	and not is_sliding \
	and not is_sprinting:
		# Enable the "crouching" state in the NodeStateMachine. The AnimationTree will automatically transition to the "Falling" animation state.
		state_machine.travel(NodeStateMachine.States.CROUCHING)

	# Focus { Microsoft: 🄻T, Nintendo: Z🄻, Sony: 🄻2, Keyboard: [Right Mouse Button] }.
	is_focusing = Input.is_action_pressed("focus")

	# Shoot { Microsoft: 🅁T, Nintendo: 🅁L, Sony: 🅁2, Keyboard: [Left Mouse Button] } 
	is_shooting = Input.is_action_pressed("shoot") and can_player_shoot

	# Update locomotion state based on equipped items if not in special states
	if not is_climbing and not is_hanging_braced and not is_hanging_free and not is_falling and not is_jumping and not is_sliding and not is_mining and not is_logging:
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
			if not current_state.contains("Jump") and not is_shield_attack_state and current_state != "Mining" and current_state != "Logging":
				locomotion_state.travel(target_state)

	# Jump { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if is_on_floor() \
	and Input.is_action_just_pressed("jump") \
	and not is_climbing \
	and not is_hanging_braced \
	and not is_hanging_free \
	and not is_jump_queued \
	and not is_paragliding \
	and not is_sliding:
		# Enable the "jumping" state in the NodeStateMachine. The AnimationTree will automatically transition to the "Falling" animation state.
		state_machine.travel(NodeStateMachine.States.JUMPING)

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
		# Enable the "sliding" state in the NodeStateMachine. The AnimationTree will automatically transition to the "Falling" animation state.
		state_machine.travel(NodeStateMachine.States.SLIDING)

	# Handle movement is strafing
	if is_shooting or is_focusing:

		# Rotate to face the camera direction when focusing or shooting (unless is_focusing and not is_shooting)
		if (is_shooting or not is_focusing) and not is_firing_arrow and not is_hanging_braced and not is_hanging_free and not is_climbing:
			var camera_basis := spring_arm.global_transform.basis
			var camera_forward := -camera_basis.z
			camera_forward = camera_forward.slide(up_direction)
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
		target_dir = target_dir.slide(up_direction)
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
				wall_dir = wall_dir.slide(up_direction)
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
		target_dir = target_dir.slide(up_direction)
		
		var current_h_vel := velocity.slide(up_direction)
		var current_speed := current_h_vel.length()
		var air_speed_cap := max(current_speed, 5.0)
		var target_h_vel = target_dir * air_speed_cap
		
		# Slowly lerp to target air speed to preserve momentum
		h_velocity = current_h_vel.lerp(target_h_vel, 3.0 * delta)

	var vertical_speed := velocity.dot(up_direction)
	if is_climbing or is_climbing_on or is_climbing_hopping_left or is_climbing_hopping_right or is_climbing_hopping_up:
		vertical_speed = h_velocity.dot(up_direction)
	elif is_hanging_braced or is_hanging_free:
		vertical_speed = 0.0
	else:
		vertical_speed += get_gravity().dot(up_direction) * 1.5 * delta
	velocity = h_velocity.slide(up_direction) + (up_direction * vertical_speed)
	set_velocity(velocity)
	set_up_direction(up_direction)
	move_and_slide()

	orientation.origin = Vector3() # Clear accumulated root motion displacement (was applied to speed).
	orientation = orientation.orthonormalized() # Orthonormalize orientation.

	player_model.global_transform.basis = orientation.basis


## Detect if the player is in front of a ledge and can hang from it and/or climb on to it.
func detect_ledge() -> bool:
	# Ledge detection [Raycast]
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
		climbing_on_target = ledge_detection_marker.global_position
		ledge_detection_horizontal.show()
		ledge_detection_marker.show()
	else:
		ledge_detection_vertical.position = Vector3(0, 0, -1) # Reset to default
		ledge_detection_horizontal.hide()
		ledge_detection_marker.hide()

	return ledge_detected


## Called by the animation(s) using "Call Method Track" to execute the jump logic at the right time. 
func execute_jump() -> void:
	velocity = velocity.slide(up_direction) + (up_direction * 5.0)
	is_jump_queued = false
	is_jumping = true



## Called by the animation(s) using "Call Method Track" to play footstep sound effects at the right time.
func sfx_footsteps_play():
	if is_on_floor() and paraglider_raycast.is_colliding():
		var collider := paraglider_raycast.get_collider() as Node3D
		if collider:
			if collider.is_in_group("GRASS"):
				sfx_footsteps_grass.play()
			elif collider.is_in_group("WOOD"):
				sfx_footsteps_wood.play()


## Called by the animation(s) using "Call Method Track" to play sliding footstep sound effects at the right time.
func sfx_footsteps_slide_play():
	if is_on_floor() and paraglider_raycast.is_colliding():
		var collider := paraglider_raycast.get_collider() as Node3D
		if collider:
			if collider.is_in_group("GRASS"):
				sfx_footsteps_slide.play()


## Reset the attack sequence when the attack sequence timer times out.
func _on_attack_sequence_timer_timeout() -> void:
	attack_sequence = 0
