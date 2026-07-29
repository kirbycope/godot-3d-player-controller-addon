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
const FLYING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/FlyingLocomotion/blend_position"
const GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/GreatSwordLocomotion/blend_position"
const PISTOL_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/PistolLocomotion/blend_position"
const RIFLE_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/RifleLocomotion/blend_position"
const SHIELD_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/ShieldLocomotion/blend_position"
const SKATEBOARDING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/SkateboardingLocomotion/blend_position"
const STANDING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/StandingLocomotion/blend_position"
const SWIMMING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/SwimmingLocomotion/blend_position"

@export var animation_tree: AnimationTree
@export var current_animation: int
@export var motion_interpolate_speed: float = 10.0
@export var rotation_interpolate_speed: float = 10.0
@export var swimming_root_motion_multiplier: float = 2.0

var current_state: int = -1 ## The current state of the Player (from the Node/Code [NodeStateMachine], not the AnimationTree NodeStateMachine).
var locomotion_state: ## Gets the [NodeStateMachine] "LocomotionStateMachine"
	get:
		return animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH)
var equipped_axe_1h: bool:
	get:
		return inventory != null and inventory.has_equipment(Equipment.EquipmentType.AXE_1H)
var equipped_axe_2h: bool:
	get:
		return inventory != null and inventory.has_equipment(Equipment.EquipmentType.AXE_2H)
var equipped_bow: bool:
	get:
		return inventory != null and inventory.has_equipment(Equipment.EquipmentType.BOW)
var equipped_dagger: bool:
	get:
		return inventory != null and inventory.has_equipment(Equipment.EquipmentType.DAGGER)
var equipped_fishing_rod: bool:
	get:
		return inventory != null and inventory.has_equipment(Equipment.EquipmentType.FISHING_ROD)
var equipped_pistol: bool:
	get:
		return inventory != null and inventory.has_equipment(Equipment.EquipmentType.PISTOL)
var equipped_rifle: bool:
	get:
		return inventory != null and inventory.has_equipment(Equipment.EquipmentType.RIFLE)
var equipped_shield: bool:
	get:
		return inventory != null and inventory.has_equipment(Equipment.EquipmentType.SWORD_AND_SHIELD)
var equipped_staff: bool:
	get:
		return inventory != null and inventory.has_equipment(Equipment.EquipmentType.STAFF)
var equipped_sword_1h: bool:
	get:
		return inventory != null and inventory.has_equipment(Equipment.EquipmentType.SWORD_1H)
var equipped_sword_2h: bool:
	get:
		return inventory != null and inventory.has_equipment(Equipment.EquipmentType.SWORD_2H)
var has_move_input: bool:
	get:
		return player_input != null and player_input.motion.length_squared() > 0.0
var uses_equipment_jump_variants: bool:
	get:
		return equipped_axe_1h \
			or equipped_axe_2h \
			or equipped_bow \
			or equipped_dagger \
			or equipped_fishing_rod \
			or equipped_pistol \
			or equipped_rifle \
			or equipped_shield \
			or equipped_staff \
			or equipped_sword_1h \
			or equipped_sword_2h
var is_hanging: bool:
	get:
		return is_hanging_braced or is_hanging_free

# Attack Sequence (while holding equipment)
var attack_sequence: int = 0
var is_attacking: bool = false
var is_attacking_1: bool: # Attack Sequence: 1 of n
	get:
		if not is_multiplayer_authority() or animation_tree == null:
			return false
		var current_node: String = String(locomotion_state.get_current_node())
		return current_node == "GreatSwordDownwardSlash" or current_node == "ShieldDownwardSlash"
var is_attacking_2: bool: # Attack Sequence: 2 of n
	get:
		if not is_multiplayer_authority() or animation_tree == null:
			return false
		var current_node: String = String(locomotion_state.get_current_node())
		return current_node == "GreatSwordLowSlash" or current_node == "ShieldCrossSlash"
var is_attacking_3: bool: # Attack Sequence: 3 of n
	get:
		if not is_multiplayer_authority() or animation_tree == null:
			return false
		var current_node: String = String(locomotion_state.get_current_node())
		return current_node == "GreatSwordPowerSlash" or current_node == "ShieldPowerSlash"
# Bow and Arrow
var is_aiming_bow: bool:
	get:
		if not is_multiplayer_authority() or not equipped_bow:
			return false
		var current_node: String = String(locomotion_state.get_current_node())
		return current_node == "ArcheryLocomotion"
var is_drawing_arrow: bool:
	get:
		if not is_multiplayer_authority() or not equipped_bow:
			return false
		var current_node: String = String(locomotion_state.get_current_node())
		return current_node == "BowDrawArrow"
var is_firing_arrow: bool:
	get:
		if not is_multiplayer_authority() or not equipped_bow:
			return false
		var current_node: String = String(locomotion_state.get_current_node())
		return current_node == "BowFireArrow"
# Climbing
var is_climbing: bool = false ## Is the Player currently climbing?
var is_climbing_on: bool = false ## Is the Player currently climbing on to a ledge?
var climbing_on_target: Vector3 ## The target position the Player is climbing on to (from ledge detection).
var is_climbing_hopping_left: bool = false ## Is the Player currently hopping left while climbing?
var is_climbing_hopping_right: bool = false ## Is the Player currently hopping right while climbing?
var is_climbing_hopping_up: bool = false ## Is the Player currently hopping up while climbing?
var is_hopping_from_climbing: bool = false ## Is the Player currently hopping while climbing?
# Driving
var is_driving: bool = false ## Is the Player currently driving?
var is_driving_in: Node3D = null ## The VehicleBody3D the Player is currently driving, if any.
var is_entering_vehicle: bool = false ## Is the Player currently entering a vehicle?
var is_exiting_vehicle: bool = false ## Is the Player currently exiting a vehicle?
# Hanging
var is_hanging_braced: bool = false ## Is the Player currently hanging (braced)?
var is_hanging_free: bool = false ## Is the Player currently hanging (free)?

var is_crouching: bool = false ## Is the Player currently crouching?
var is_emoting: bool = false ## Is the Player currently emoting?
var is_exhausted: bool = false ## Is the Player currently exhausted?
var is_falling: bool = false ## Is the Player currently falling?
var is_fishing: bool = false ## Is the Player currently fishing (has a rod equipped)?
var is_casting_line: bool = false ## Is the Player currently casting a fishing line?
var is_reeling_line: bool = false ## Is the Player currently casting a fishing line?
var is_flying: bool = false ## Is the Player currently flying?
var is_focusing: bool: ## Is the Player currently focusing (forward or on a target)?
	get:
		if not is_multiplayer_authority() or is_driving:
			return false
		return Input.is_action_pressed("focus")
var is_jumping: bool = false ## Is the Player currently jumping?
var is_jump_queued: bool = false ## Is the Player currently queued to jump?
var is_mining: bool: ## Is the Player currently mining?
	get:
		if not is_multiplayer_authority() or animation_tree == null:
			return false
		var current_node: String = String(locomotion_state.get_current_node())
		var travel_path: Variant = locomotion_state.get_travel_path()
		return current_node == "Mining" or "Mining" in travel_path
var is_logging: bool: ## Is the Player currently logging?
	get:
		if not is_multiplayer_authority() or animation_tree == null:
			return false
		var current_node: String = String(locomotion_state.get_current_node())
		var travel_path: Variant = locomotion_state.get_travel_path()
		return current_node == "Logging" or "Logging" in travel_path
var is_paragliding: bool = false ## Is the Player currently paragliding?
var is_paused: bool = false ## Is the Player currently paused?
var is_shooting: bool: ## Is the Player currently shooting?
	get:
		if not is_multiplayer_authority() or is_driving or inventory == null:
			return false
		return Input.is_action_pressed("shoot") and inventory.can_player_shoot
var is_on_half_pipe: bool = false ## Is the Player currently inside a half-pipe area?
var _half_pipe_count: int = 0
var is_skateboarding: bool = false ## Is the Player currently skateboarding?
var is_sliding: bool = false ## Is the Player currently sliding?
var is_sprinting: bool = false ## Is the Player currently sprinting?
var is_standing: bool = false ## Is the Player currently standing?
var is_swimming: bool = false ## Is the Player currently swimming?
var initial_collision_shape_height: float
var initial_collision_shape_position: Vector3
var initial_parent: Node3D
var orientation := Transform3D()
var root_motion := Transform3D()
var smoothed_motion: Vector2 = Vector2.ZERO


func set_on_half_pipe(on_pipe: bool) -> void:
	if on_pipe:
		_half_pipe_count += 1
	else:
		_half_pipe_count = max(0, _half_pipe_count - 1)
	is_on_half_pipe = _half_pipe_count > 0

@onready var attack_sequence_timer: Timer = $AttackSequenceTimer
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var initial_collision_shape_transform: Transform3D = collision_shape.transform
@onready var separation_ray_shape: CollisionShape3D = $SeparationRayShape3D
@onready var initial_separation_ray_transform: Transform3D = separation_ray_shape.transform
@onready var controls: CanvasLayer = $Controls
@onready var crosshair: TextureRect = $Crosshair
@onready var debug: CanvasLayer = $Debug
@onready var inventory: Inventory = $Inventory
@onready var pause: CanvasLayer = $Pause
@onready var settings: CanvasLayer = $Settings
@onready var initial_transform: Transform3D = global_transform
@onready var falling_raycast: RayCast3D = $FallingRaycast
@onready var hanging_braced_detection: RayCast3D = $PlayerModel/HangingBracedDetection
@onready var ledge_detection_horizontal: RayCast3D = $PlayerModel/LedgeDetectionHorizontal
@onready var ledge_detection_vertical: RayCast3D = $PlayerModel/LedgeDetectionHorizontal/LedgeDetectionVertical
@onready var ledge_detection_marker: MeshInstance3D = $PlayerModel/LedgeDetectionHorizontal/LedgeDetectionVertical/LedgeDetectionMarker
@onready var look_at_target: Marker3D = $SpringArm3D/ProjectileRaycast/LookAtTarget
@onready var player_input: InputSynchronizer = $InputSynchronizer
@onready var player_model: Node3D = $PlayerModel
@onready var initial_player_model_transform: Transform3D = player_model.transform
@onready var paraglider_raycast: RayCast3D = $ParagliderRaycast
@onready var projectile_raycast: RayCast3D = $SpringArm3D/ProjectileRaycast
@onready var skateboard: Node3D = $PlayerModel/Skateboard
@onready var skeleton: Skeleton3D = $PlayerModel/Armature/GeneralSkeleton
@onready var look_at_modifier = $PlayerModel/Armature/GeneralSkeleton/LookAtModifier3D
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var state_machine: NodeStateMachine = $NodeStateMachine ## Enables/Disables the scripts that run when various States are entered/exited.
@onready var sfx_footsteps_grass: AudioStreamPlayer3D = $SFX_Footsteps_Grass
@onready var sfx_footsteps_slide: AudioStreamPlayer3D = $SFX_Footsteps_Slide
@onready var sfx_footsteps_stone: AudioStreamPlayer3D = $SFX_Footsteps_Stone
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

	# Record the initial parent for re-parenting after driving.
	initial_parent = get_parent()

	# Ensure the AnimationTree is active so that root motion is applied in the first frame.
	animation_tree.active = true

	# Keep animation sampling in physics domainD to match root-motion consumption in _physics_process.
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS

	# Ensure the projectile RayCast3D doesn't collide with the player
	projectile_raycast.add_exception(self)

	# Set the Player's iniitial state
	current_state = NodeStateMachine.States.STANDING


## Called when there is an unhandled input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Toggle mouse capture
	if event.is_action_pressed("ui_cancel") and not pause.visible and not settings.visible:
		# Check if the mouse is currently captured
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# Set the mouse mode to visible to show the mouse cursor
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# The mouse must not be currently captured
		else:
			# Set the mouse mode to captured to hide the mouse cursor
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# https://github.com/godotengine/tps-demo/blob/master/player/gd#L54
## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	# Reset up_direction smoothly back to world UP when not skateboarding on a half-pipe
	if not (is_skateboarding and is_on_half_pipe) and not up_direction.is_equal_approx(Vector3.UP):
		if up_direction.angle_to(Vector3.UP) < 0.01:
			up_direction = Vector3.UP
		else:
			up_direction = up_direction.slerp(Vector3.UP, delta * 10.0).normalized()

	# Start falling if the player is not on the floor and not already falling.
	if not is_on_floor() and not is_falling \
	and not falling_raycast.is_colliding() \
	and not is_climbing and not is_climbing_on \
	and not is_driving \
	and not is_flying \
	and not is_hanging_braced and not is_hanging_free \
	and not is_jumping and not is_jump_queued \
	and not is_paragliding \
	and not is_skateboarding \
	and not is_swimming:
		# Enable the "falling" state in the NodeStateMachine. The AnimationTree will automatically transition to the "Falling" animation state.
		state_machine.travel(current_state, NodeStateMachine.States.FALLING)

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
		inventory.debug_unequip_all()


# https://github.com/godotengine/tps-demo/blob/master/player/gd#L86
func apply_input(delta: float) -> void:
	# Get the target motion from the synchronized input.
	var target_motion: Vector2 = player_input.motion

	# If the player is mining or logging, block regular locomotion transitions by setting the `target_motion` to zero.
	if is_mining or is_logging:
		target_motion = Vector2.ZERO

	# Smoothly interpolate the target_motion for more gradual changes in animation blending and rotation.
	var motion_weight: float = clampf(motion_interpolate_speed * delta, 0.0, 1.0)
	smoothed_motion = smoothed_motion.lerp(target_motion, motion_weight)
	target_motion = smoothed_motion

	# While driving, paragliding, skateboarding, or flying, block regular locomotion.
	# Driving.gd / Paragliding.gd / Skateboarding.gd / Flying.gd will handle movement.
	if (is_driving and not is_entering_vehicle and not is_exiting_vehicle) or is_paragliding or is_skateboarding or is_flying:
		return

	# While swimming, keep SwimmingLocomotion active and feed its BlendSpace1D.
	if is_swimming and not is_driving:
		var current_swimming_node = locomotion_state.get_current_node()
		# Do not force SwimmingLocomotion while swimming to/at an edge or mantling out.
		if not current_swimming_node in ["BracedHangClimbingOn", "SwimmingAtEdge", "SwimmingToEdge"] \
		and current_swimming_node != "SwimmingLocomotion" \
		and not is_climbing_on:
			locomotion_state.travel("SwimmingLocomotion")
		# Feed the BlendSpace1D only while in normal swimming locomotion.
		if current_swimming_node == "SwimmingLocomotion":
			if is_focusing: # or is_shooting:
				animation_tree.set(SWIMMING_LOCOMOTION_BLEND_POSITION_PATH, target_motion.y)
			else:
				animation_tree.set(SWIMMING_LOCOMOTION_BLEND_POSITION_PATH, target_motion.length())

	# Attack { Microsoft: Ⓧ, Nintendo: Ⓨ, Sony: 🟗, Keyboard: [Alt] }
	if not is_driving \
	and Input.is_action_just_pressed("attack") \
	and not is_attacking \
	and inventory.can_player_attack:
		# Enable the "attacking" state in the NodeStateMachine. The AnimationTree will automatically transition to the "Falling" animation state.
		state_machine.travel(current_state, NodeStateMachine.States.ATTACKING)

	# Climbing, Start { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if not is_driving \
	and not is_on_floor() \
	and not is_climbing \
	and not is_hanging_braced \
	and not is_hanging_free \
	and not is_skateboarding \
	and not is_swimming \
	and not is_flying \
	and Input.is_action_just_pressed("jump") \
	and ledge_detection_horizontal.is_colliding():
		# Stop "falling", start "climbing"
		if is_falling:
			state_machine.travel(NodeStateMachine.States.FALLING, NodeStateMachine.States.CLIMBING)
		# Stop "jumping", start "climbing"
		elif is_jumping:
			state_machine.travel(NodeStateMachine.States.JUMPING, NodeStateMachine.States.CLIMBING)
		# Start "climbing" from any other state
		else:
			state_machine.travel(current_state, NodeStateMachine.States.CLIMBING)

	# Paragliding, Start { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if not is_driving \
	and not is_on_floor() \
	and Input.is_action_just_pressed("jump") \
	and (is_falling or is_jumping) \
	and not is_climbing \
	and not is_hanging_braced \
	and not is_hanging_free \
	and not is_paragliding \
	and not is_skateboarding \
	and not is_swimming \
	and not is_flying \
	and not paraglider_raycast.is_colliding():
		state_machine.travel(current_state, NodeStateMachine.States.PARAGLIDING)

	# Crouch { Console: Left ⬤, Keyboard: [Control] }.
	if not is_driving \
	and Input.is_action_pressed("crouch") \
	and not is_crouching \
	and is_on_floor() \
	and not is_sliding \
	and not is_sprinting:
		# Start "crouching"
		state_machine.travel(current_state, NodeStateMachine.States.CROUCHING)

	# Jump { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if not is_driving \
	and is_on_floor() \
	and Input.is_action_just_pressed("jump") \
	and not is_climbing \
	and not is_hanging_braced \
	and not is_hanging_free \
	and not is_jump_queued \
	and not is_paragliding \
	and not is_sliding:
		# Enable the "jumping" state in the NodeStateMachine. The AnimationTree will automatically transition to the "Falling" animation state.
		state_machine.travel(current_state, NodeStateMachine.States.JUMPING)

	# Flying, Start { Microsoft: Ⓨ, Nintendo: Ⓧ, Sony: 🟕, Keyboard: [Space] }
	if not is_flying \
	and (is_jumping or is_falling) \
	and not is_jump_queued \
	and paraglider_raycast.is_colliding() \
	and Input.is_action_just_pressed("jump"):
		state_machine.travel(current_state, NodeStateMachine.States.FLYING)

	# Sprint { Microsoft: Ⓑ, Nintendo: Ⓐ, Sony: Ⓞ, Keyboard: [Shift] }.
	if not is_driving \
	and is_on_floor() \
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
	if not is_driving \
	and is_sprinting \
	and Input.is_action_just_pressed("crouch") \
	and not is_sliding:
		# Enable the "sliding" state in the NodeStateMachine. The AnimationTree will automatically transition to the "Falling" animation state.
		state_machine.travel(current_state, NodeStateMachine.States.SLIDING)

	var is_first_person: bool = camera is Camera and (camera as Camera).perspective == Camera.Perspective.FIRST_PERSON
	# Handle movement is strafing
	if not is_driving and (is_shooting or is_focusing or is_first_person):
		# Rotate to face the camera direction when focusing, shooting, or in first person
		if (is_shooting or not is_focusing or is_first_person) and not is_firing_arrow and not is_hanging_braced and not is_hanging_free and not is_climbing:
			var camera_basis := spring_arm.global_transform.basis
			var camera_forward := -camera_basis.z
			camera_forward = camera_forward.slide(up_direction)
			if camera_forward.length_squared() > 0.001:
				camera_forward = camera_forward.normalized()
				var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
				var q_to: Quaternion = Basis.looking_at(-camera_forward, up_direction).get_rotation_quaternion()
				orientation.basis = Basis(q_from.slerp(q_to, delta * rotation_interpolate_speed))
		if is_crouching:
			animation_tree.set(CROUCHING_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
		else:
			if inventory.has_equipment(Equipment.EquipmentType.BOW):
				if is_shooting:
					animation_tree.set(ARCHERY_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
				else:
					animation_tree.set(BOW_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif inventory.has_any_equipment([
				Equipment.EquipmentType.AXE_1H,
				Equipment.EquipmentType.DAGGER,
				Equipment.EquipmentType.SWORD_1H,
			]):
				animation_tree.set(SHIELD_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif inventory.has_heavy_weapon_equipped():
				animation_tree.set(GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif inventory.has_equipment(Equipment.EquipmentType.PISTOL):
				animation_tree.set(PISTOL_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif inventory.has_equipment(Equipment.EquipmentType.RIFLE):
				animation_tree.set(RIFLE_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			else:
				animation_tree.set(STANDING_LOCOMOTION_BLEND_POSITION_PATH, target_motion)

	# Handle movement when not strafing
	elif not is_driving:
		# Use camera-relative direction for target_motion direction
		var camera_basis := spring_arm.global_transform.basis
		var target_dir := camera_basis * Vector3(target_motion.x, 0.0, -target_motion.y)
		target_dir = target_dir.slide(up_direction)
		if target_dir.length_squared() > 0.001 and not is_firing_arrow and not is_hanging_braced and not is_hanging_free and not is_climbing:
			target_dir = target_dir.normalized()
			var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
			var q_to: Quaternion = Basis.looking_at(-target_dir, up_direction).get_rotation_quaternion()
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
					var q_to: Quaternion = Basis.looking_at(-wall_dir, up_direction).get_rotation_quaternion()
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
			if inventory.has_equipment(Equipment.EquipmentType.BOW):
				if is_shooting:
					animation_tree.set(ARCHERY_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
				else:
					animation_tree.set(BOW_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif inventory.has_one_handed_or_shield_equipped():
				animation_tree.set(SHIELD_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif inventory.has_heavy_weapon_equipped():
				animation_tree.set(GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif inventory.has_equipment(Equipment.EquipmentType.PISTOL):
				animation_tree.set(PISTOL_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			elif inventory.has_equipment(Equipment.EquipmentType.RIFLE):
				animation_tree.set(RIFLE_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
			else:
				animation_tree.set(STANDING_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)

	var root_motion_position := animation_tree.get_root_motion_position()
	if is_swimming and not is_climbing_on:
		root_motion_position *= swimming_root_motion_multiplier

	root_motion = Transform3D(animation_tree.get_root_motion_rotation(), root_motion_position)

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
	elif is_driving:
		# While driving, vertical movement is driven by root motion/input, not gravity.
		vertical_speed = h_velocity.dot(up_direction)
	elif is_swimming:
		# While swimming, vertical movement is driven by root motion/input, not gravity.
		vertical_speed = h_velocity.dot(up_direction)
	else:
		vertical_speed += get_gravity().dot(up_direction) * 1.5 * delta
	velocity = h_velocity.slide(up_direction) + (up_direction * vertical_speed)
	update_movement_and_rotation(delta)


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
	if not is_jump_queued:
		return
	velocity = velocity.slide(up_direction) + (up_direction * 5.0)
	is_jump_queued = false
	is_jumping = true

## Gets the grounded locomotion state that matches the current equipment and intent.
func get_grounded_locomotion_state() -> StringName:
	if is_crouching:
		return &"CrouchingLocomotion"
	if equipped_axe_2h or equipped_fishing_rod or equipped_staff or equipped_sword_2h:
		return &"GreatSwordLocomotion"
	if equipped_bow:
		if is_shooting:
			return &"ArcheryLocomotion"
		return &"BowLocomotion"
	if equipped_axe_1h or equipped_dagger or equipped_shield or equipped_sword_1h:
		return &"ShieldLocomotion"
	if equipped_pistol:
		return &"PistolLocomotion"
	if equipped_rifle:
		return &"RifleLocomotion"
	return &"StandingLocomotion"


## Gets the player's forward direction projected onto the movement plane.
func get_facing_direction() -> Vector3:
	var facing_direction := -player_model.global_transform.basis.z
	facing_direction = facing_direction.slide(up_direction)
	if facing_direction.length_squared() <= 0.001:
		return Vector3.ZERO
	return facing_direction.normalized()


## Called by the animation(s) using "Call Method Track" to play footstep sound effects at the right time.
func sfx_footsteps_play():
	if is_on_floor() and paraglider_raycast.is_colliding():
		var collider := paraglider_raycast.get_collider() as Node3D
		if collider:
			if collider.is_in_group("GRASS"):
				sfx_footsteps_grass.play()
			elif collider.is_in_group("STONE"):
				sfx_footsteps_stone.play()
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


## Applies the current velocity, moves the player, and updates the orientation to match the up_direction.
func update_movement_and_rotation(delta: float) -> void:
	set_velocity(velocity)
	set_up_direction(up_direction)
	move_and_slide()

	orientation.origin = Vector3() # Clear accumulated root motion displacement (was applied to speed).
	orientation = orientation.orthonormalized() # Orthonormalize orientation.

	# Smoothly align character body and model orientation Y-axis with up_direction
	var current_up := orientation.basis.y
	if not current_up.is_equal_approx(up_direction):
		var next_up := current_up.slerp(up_direction, delta * 10.0).normalized()
		var q_align := Quaternion(current_up, next_up)
		orientation.basis = Basis(q_align) * orientation.basis

	var current_body_up := global_basis.y
	if not current_body_up.is_equal_approx(up_direction):
		var next_body_up := current_body_up.slerp(up_direction, delta * 10.0).normalized()
		var q_align_body := Quaternion(current_body_up, next_body_up)
		global_basis = Basis(q_align_body) * global_basis

	# Rotate the Player Model (unless entering/exiting a vehicle)
	if not (is_driving and (is_entering_vehicle or is_exiting_vehicle)):
		player_model.global_transform.basis = orientation.basis
		var model_facing_basis: Basis = orientation.basis.rotated(up_direction, PI)
		var rotated_basis: Basis = model_facing_basis * initial_separation_ray_transform.basis
		var rotated_origin: Vector3 = model_facing_basis * initial_separation_ray_transform.origin
		separation_ray_shape.transform = Transform3D(rotated_basis, rotated_origin)
