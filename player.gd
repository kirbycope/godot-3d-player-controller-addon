class_name Player
extends CharacterBody3D


const EMOTE_STATE_PLAYBACK_PATH: String = "parameters/EmoteStateMachine/playback"
const LOCOMOTION_STATE_PLAYBACK_PATH: String = "parameters/LocomotionStateMachine/playback"
const ARCHERY_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/ArcheryLocomotion/blend_position"
const BOW_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/BowLocomotion/blend_position"
const BOXING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/BoxingLocomotion/blend_position"
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
@export var motion_interpolate_speed: float = 10.0
@export var rotation_interpolate_speed: float = 10.0
@export var swimming_root_motion_multiplier: float = 2.0

@export_category("Optional Gadgets & Gear")
@export var paraglider_scene: PackedScene
@export var skateboard_scene: PackedScene
@export_category("Optional Interaction")
@export var held_object_throw_force: float = 5.0
@export var push_force: float = 1.0
@export var mass: float = 80.0

@export_category("Debug Settings")
@export var debug_left_hand_hit_color: Color = Color.ORANGE
@export var debug_right_hand_hit_color: Color = Color.BLUE

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
var is_boxing: bool = false

# Attack Sequence
var attack_sequence: int = 0
var is_attacking: bool = false
var is_attacking_1: bool: # Attack Sequence: 1 of n
	get: return String(locomotion_state.get_current_node()) in ["GreatSwordDownwardSlash", "ShieldDownwardSlash", "ShortHeadJab"] if is_multiplayer_authority() and animation_tree else false
var is_attacking_2: bool: # Attack Sequence: 2 of n
	get: return String(locomotion_state.get_current_node()) in ["GreatSwordLowSlash", "ShieldCrossSlash", "BackHandCross"] if is_multiplayer_authority() and animation_tree else false
var is_attacking_3: bool: # Attack Sequence: 3 of n
	get: return String(locomotion_state.get_current_node()) in ["GreatSwordPowerSlash", "ShieldPowerSlash"] if is_multiplayer_authority() and animation_tree else false
# Bow and Arrow
var is_aiming_bow: bool:
	get: return String(locomotion_state.get_current_node()) == "ArcheryLocomotion" if is_multiplayer_authority() and equipped_bow else false
var is_drawing_arrow: bool:
	get: return String(locomotion_state.get_current_node()) == "BowDrawArrow" if is_multiplayer_authority() and equipped_bow else false
var is_firing_arrow: bool:
	get: return String(locomotion_state.get_current_node()) == "BowFireArrow" if is_multiplayer_authority() and equipped_bow else false
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
var has_started_emoting: bool = false ## Has the player's emote animation transitioned away from Idle yet?
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
var is_front_flipping: bool = false ## Is the Player currently front flipping?
var is_back_flipping: bool = false ## Is the Player currently back flipping?
var is_flipping: bool: ## Is the Player currently front or back flipping?
	get:
		if not is_multiplayer_authority() or animation_tree == null:
			return false
		return is_front_flipping or is_back_flipping \
				or String(locomotion_state.get_current_node()) in ["Backflip", "FowardFlip"]
var is_throw_queued: bool = false ## Is the Player currently queued to throw a held object?
var is_throwing: bool = false ## Is the Player currently throwing?
var is_charging_throw: bool = false ## Is the Player currently charging a throw?
var throw_charge_time: float = 0.0 ## Current elapsed charge duration for throw.
var throw_power: float = 1.0 ## Throw power multiplier (0.25 to 1.0).
var queued_throw_direction: Vector3 = Vector3.ZERO ## The direction to apply when executing a queued throw.
var throw_charge_bar: ProgressBar
var held_rigidbody: RigidBody3D = null
var held_rigidbody_original_collision_layer: int = 0
var held_rigidbody_original_collision_mask: int = 0
var held_rigidbody_original_freeze: bool = false
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
var is_ragdolling: bool = false ## Is the Player currently ragdolling?
var is_shooting: bool: ## Is the Player currently shooting?
	get:
		if not is_multiplayer_authority() or is_driving or inventory == null:
			return false
		return Input.is_action_pressed("shoot") and inventory.can_player_shoot
var is_sitting: bool = false ## Is the Player currently sitting?
var is_skateboarding: bool = false ## Is the Player currently skateboarding?
var is_sliding: bool = false ## Is the Player currently sliding?
var is_sprinting: bool = false ## Is the Player currently sprinting?
var is_standing: bool = false ## Is the Player currently standing?
var is_swimming: bool = false ## Is the Player currently swimming?
var last_fall_speed: float = 0.0 ## The downward vertical fall speed right before movement update.
var initial_collision_shape_height: float
var initial_collision_shape_position: Vector3
var initial_parent: Node3D
var orientation := Transform3D()
var root_motion := Transform3D()
var smoothed_motion: Vector2 = Vector2.ZERO
var paraglider: Node3D
var skateboard: Node3D

@onready var attack_sequence_timer: Timer = $AttackSequenceTimer
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var initial_collision_shape_transform: Transform3D = collision_shape.transform
@onready var separation_ray_shape: CollisionShape3D = $SeparationRayShape3D
@onready var initial_separation_ray_transform: Transform3D = separation_ray_shape.transform
@onready var controls: CanvasLayer = $Controls
@onready var crosshair: TextureRect = $Crosshair
@onready var debug: CanvasLayer = $Debug
@onready var inventory: Inventory = $Inventory
@onready var radial_menu: RadialMenu = $Inventory/RadialMenu
@onready var pause: CanvasLayer = $Pause
@onready var settings: CanvasLayer = $Settings
@onready var initial_transform: Transform3D = global_transform
@onready var falling_raycast: RayCast3D = $FallingRaycast
@onready var player_model: Node3D = $PlayerModel
@onready var ledge_detection_horizontal: RayCast3D = $PlayerModel/LedgeDetectionHorizontal
@onready var ledge_detection_vertical: RayCast3D = $PlayerModel/LedgeDetectionHorizontal/LedgeDetectionVertical
@onready var ledge_detection_marker: MeshInstance3D = $PlayerModel/LedgeDetectionHorizontal/LedgeDetectionVertical/LedgeDetectionMarker
@onready var hanging_braced_detection: RayCast3D = $PlayerModel/HangingBracedDetection
@onready var look_at_target: Marker3D = $CameraMount/ProjectileRaycast/LookAtTarget
@onready var camera_mount: Node3D = $CameraMount
@onready var item_spring_arm: SpringArm3D = $CameraMount/ItemSpringArm
@onready var player_input: InputSynchronizer = $InputSynchronizer
@onready var target_detection: Area3D = $TargetDetection
@onready var focus_target_marker: Marker3D = $FocusTargetMarker

var current_focus_target: Node3D = null
var current_focus_marker: Marker3D = null

@onready var initial_player_model_transform: Transform3D = player_model.transform
@onready var paraglider_raycast: RayCast3D = $ParagliderRaycast
@onready var projectile_raycast: RayCast3D = $CameraMount/ProjectileRaycast
@onready var skeleton: Skeleton3D = $PlayerModel/Armature/GeneralSkeleton
@onready var look_at_modifier = $PlayerModel/Armature/GeneralSkeleton/LookAtModifier3D
@onready var physical_bone_simulator: PhysicalBoneSimulator3D = $PlayerModel/Armature/GeneralSkeleton/PhysicalBoneSimulator3D
@onready var spring_arm: SpringArm3D = $CameraMount/CameraSpringArm
@onready var camera: Camera3D = $CameraMount/CameraSpringArm/Camera3D
@onready var state_machine: NodeStateMachine = $NodeStateMachine ## Enables/Disables the scripts that run when various States are entered/exited.
@onready var sfx_footsteps_grass: AudioStreamPlayer3D = $SFX_Footsteps_Grass
@onready var sfx_footsteps_slide: AudioStreamPlayer3D = $SFX_Footsteps_Slide
@onready var sfx_footsteps_stone: AudioStreamPlayer3D = $SFX_Footsteps_Stone
@onready var sfx_footsteps_wood: AudioStreamPlayer3D = $SFX_Footsteps_Wood


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		return

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

	# Improve traction on spheres/slopes
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(60.0)
	floor_constant_speed = true

	# Keep animation sampling in physics domainD to match root-motion consumption in _physics_process.
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS

	# Ensure the projectile RayCast3D doesn't collide with the player
	projectile_raycast.add_exception(self)

	# Ensure PhysicalBone3D nodes never collide with the player CharacterBody3D
	if physical_bone_simulator:
		for child in physical_bone_simulator.get_children():
			if child is PhysicalBone3D:
				child.add_collision_exception_with(self)
				add_collision_exception_with(child)

	_setup_throw_charge_bar()

	# Set the Player's initial state
	if state_machine:
		state_machine.travel(-1, NodeStateMachine.States.STANDING)
	else:
		current_state = NodeStateMachine.States.STANDING

	# Initialize optional gadget scenes if assigned
	if not paraglider:
		paraglider = get_node_or_null("PlayerModel/Armature/GeneralSkeleton/ParagliderBoneAttachment/Paraglider")
	if paraglider_scene and not paraglider:
		var bone_attachment = get_node_or_null("PlayerModel/Armature/GeneralSkeleton/ParagliderBoneAttachment")
		var paraglider_instance = paraglider_scene.instantiate() as Node3D
		if paraglider_instance:
			if bone_attachment:
				bone_attachment.add_child(paraglider_instance)
			else:
				player_model.add_child(paraglider_instance)
			paraglider = paraglider_instance
			if "player" in paraglider:
				paraglider.set("player", self)
			paraglider.hide()

	if not skateboard:
		skateboard = get_node_or_null("PlayerModel/Skateboard")
	if skateboard_scene and not skateboard:
		var skateboard_instance = skateboard_scene.instantiate() as Node3D
		if skateboard_instance:
			player_model.add_child(skateboard_instance)
			skateboard = skateboard_instance
			if "player" in skateboard:
				skateboard.set("player", self)
			skateboard.hide()

	if skateboard:
		for child in skateboard.find_children("*", "CollisionShape3D", true, false):
			if child is CollisionShape3D:
				child.disabled = true


## Called when there is an unhandled input event.
func _input(event: InputEvent) -> void:
	# Do nothing if not the authority
	if is_paused or is_ragdolling: return

	if event.is_action_pressed("action") and not event.is_echo():
		if _is_holding_rigidbody():
			_drop_held_rigidbody()
			get_viewport().set_input_as_handled()
			return
		if _try_pickup_rigidbody_from_crosshair():
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("shoot") and not event.is_echo() and _is_holding_rigidbody():
		start_charging_throw()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_released("shoot") and not event.is_echo() and _is_holding_rigidbody():
		release_charging_throw()
		get_viewport().set_input_as_handled()
		return

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


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Handle Focus Target Logic
	if is_focusing:
		if not is_instance_valid(current_focus_target):
			if is_instance_valid(current_focus_marker):
				current_focus_marker.queue_free()
			current_focus_target = null
			current_focus_marker = null
			
			for body in target_detection.get_overlapping_bodies():
				if body.is_in_group("Target") or body.is_in_group("Focusable") or "Guy" in body.name:
					current_focus_target = body
					current_focus_marker = focus_target_marker.duplicate()
					body.add_child(current_focus_marker)
					current_focus_marker.visible = true
					break
	else:
		if current_focus_target != null:
			if is_instance_valid(current_focus_marker):
				current_focus_marker.queue_free()
			current_focus_target = null
			current_focus_marker = null

	# Apply player input to control the character and update the animation state.
	apply_input(delta)

	# Treat "jumping" as queued jump or upward airborne movement.
	is_jumping = (is_on_floor() and is_jump_queued) or (not is_on_floor() and locomotion_state.get_current_node().contains("Jump"))

	# While throw windup is active, keep aiming at live crosshair direction.
	if is_throwing:
		var crosshair_throw_dir: Vector3 = _get_crosshair_throw_direction()
		if crosshair_throw_dir.length_squared() > 0.001:
			queued_throw_direction = crosshair_throw_dir.normalized()
			_turn_model_toward_direction(queued_throw_direction, delta)

	# Process throw charging if actively holding shoot action
	if is_charging_throw:
		throw_charge_time += delta
		var throw_dir: Vector3 = _get_crosshair_throw_direction()
		_turn_model_toward_direction(throw_dir, delta)

		if throw_charge_time >= 0.2:
			if not is_throw_queued:
				queue_throw(throw_dir)
			var charge_ratio: float = clamp((throw_charge_time - 0.2) / 0.6, 0.0, 1.0)
			if throw_charge_bar:
				throw_charge_bar.visible = true
				throw_charge_bar.value = charge_ratio * 100.0
				throw_power = lerp(0.25, 1.0, charge_ratio)
			else:
				throw_power = lerp(0.25, 1.0, charge_ratio)

		if throw_charge_time >= 0.8:
			throw_power = 1.0
			execute_throw()

	# Stop emote state when the animation finishes and reset the blend amount.
	if is_emoting:
		if animation_tree.get(EMOTE_STATE_PLAYBACK_PATH).get_current_node() != "Idle":
			has_started_emoting = true
		elif has_started_emoting:
			animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 0.0)
			is_emoting = false
			has_started_emoting = false
			is_throwing = false

	## DEBUG: Toggle emote state for testing purposes.
	if not is_paused and not is_ragdolling and Input.is_action_just_pressed("emote"):
		var emote_state = animation_tree.get(EMOTE_STATE_PLAYBACK_PATH)
		if emote_state.get_current_node() != "Waving":
			animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 1.0)
			emote_state.travel("Waving")
			is_emoting = true
			has_started_emoting = false

	## DEBUG: Remove all equipment for testing purposes.
	if not is_paused and not is_ragdolling and Input.is_action_just_pressed("unequip"):
		inventory.debug_unequip_all()


# https://github.com/godotengine/tps-demo/blob/master/player/gd#L86
func apply_input(delta: float) -> void:
	# Get the target motion from the synchronized input.
	var target_motion: Vector2 = player_input.motion

	# Block player movement control if paused or ragdolling.
	if is_paused or is_ragdolling:
		target_motion = Vector2.ZERO
		smoothed_motion = Vector2.ZERO
		is_sprinting = false

	# If the player is mining, logging, or flipping, block regular locomotion transitions by setting the `target_motion` to zero.
	if is_mining or is_logging or is_flipping:
		target_motion = Vector2.ZERO

	# Smoothly interpolate the target_motion for more gradual changes in animation blending and rotation.
	var motion_weight: float = clampf(motion_interpolate_speed * delta, 0.0, 1.0)
	smoothed_motion = smoothed_motion.lerp(target_motion, motion_weight)
	target_motion = smoothed_motion

	# While driving, paragliding, skateboarding, flying, or ragdolling, block regular locomotion.
	# Driving.gd / Paragliding.gd / Skateboarding.gd / Flying.gd / Ragdolling.gd will handle movement.
	if (is_driving and not is_entering_vehicle and not is_exiting_vehicle) or is_paragliding or is_skateboarding or is_flying or is_ragdolling or is_sitting:
		return

	# Sprint logic
	if is_sprinting:
		if is_focusing:
			var forward_amount: float = clampf(absf(target_motion.y), 0.0, 1.0)
			target_motion.y *= 1.5
			# Favor the forward blend only on diagonal sprints; pure strafing keeps full speed.
			target_motion.x *= lerpf(1.0, 0.5, forward_amount)
		else:
			target_motion *= 1.5

	var is_first_person: bool = camera is Camera and (camera as Camera).perspective == Camera.Perspective.FIRST_PERSON
	# Handle movement is strafing
	if not is_driving and (is_shooting or is_focusing or is_first_person):
		# Rotate to face the target, or the camera direction when shooting or in first person
		if not is_firing_arrow and not is_hanging_braced and not is_hanging_free and not is_climbing:
			var look_dir: Vector3 = Vector3.ZERO
			
			if is_focusing and is_instance_valid(current_focus_target):
				look_dir = (current_focus_target.global_position - global_position).slide(up_direction)
			elif is_shooting or not is_focusing or is_first_person:
				var camera_basis := spring_arm.global_transform.basis
				look_dir = -camera_basis.z
				look_dir = look_dir.slide(up_direction)
				
			if look_dir.length_squared() > 0.001:
				look_dir = look_dir.normalized()
				var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
				var q_to: Quaternion = Basis.looking_at(-look_dir, up_direction).get_rotation_quaternion()
				if is_focusing and is_instance_valid(current_focus_target):
					# Catch up quickly on lock-on, then track the target exactly (lag causes orbit wobble).
					var focus_weight: float = clampf(delta * rotation_interpolate_speed * 2.0, 0.0, 1.0)
					if q_from.angle_to(q_to) < 0.05:
						focus_weight = 1.0
					orientation.basis = Basis(q_from.slerp(q_to, focus_weight))
				else:
					var rotate_weight: float = clampf(delta * rotation_interpolate_speed, 0.0, 1.0)
					orientation.basis = Basis(q_from.slerp(q_to, rotate_weight))
		if is_crouching:
			animation_tree.set(CROUCHING_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
		else:
			if inventory.has_equipment(Equipment.EquipmentType.BOW):
				if is_shooting:
					animation_tree.set(ARCHERY_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
				else:
					animation_tree.set(BOW_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif inventory.has_one_handed_or_shield_equipped():
				animation_tree.set(SHIELD_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif inventory.has_heavy_weapon_equipped():
				animation_tree.set(GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif inventory.has_equipment(Equipment.EquipmentType.PISTOL):
				animation_tree.set(PISTOL_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif inventory.has_equipment(Equipment.EquipmentType.RIFLE):
				animation_tree.set(RIFLE_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
			elif inventory.is_unarmed() and is_boxing:
				animation_tree.set(BOXING_LOCOMOTION_BLEND_POSITION_PATH, target_motion)
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
		elif inventory.is_unarmed() and is_boxing:
			animation_tree.set(BOXING_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)
		else:
			animation_tree.set(STANDING_LOCOMOTION_BLEND_POSITION_PATH, anim_blend)

	var root_motion_position := animation_tree.get_root_motion_position()
	if is_swimming and not is_climbing_on:
		root_motion_position *= swimming_root_motion_multiplier

	root_motion = Transform3D(animation_tree.get_root_motion_rotation(), root_motion_position)

	orientation *= root_motion

	var h_velocity: Vector3 = orientation.origin / delta
	
	# Override h_velocity when targeting so tangential root motion follows an exact circular arc.
	if is_focusing and is_instance_valid(current_focus_target):
		var to_target: Vector3 = (current_focus_target.global_position - global_position).slide(up_direction)
		var orbit_radius: float = to_target.length()
		if orbit_radius > 0.1:
			var target_dir: Vector3 = to_target / orbit_radius
			# Strafe distance becomes rotation about the target; forward/back changes the radius.
			var arc_angle: float = -root_motion_position.x / orbit_radius
			var new_radius: float = maxf(orbit_radius - root_motion_position.z, 0.1)
			var new_offset: Vector3 = (-target_dir * new_radius).rotated(up_direction, arc_angle)
			h_velocity = (to_target + new_offset) / delta

	# Influence of root motion is removed when in the air, and movement is instead based on the input direction to allow for more player control while jumping and falling.
	# Flips stay root-motion driven so held move input doesn't push the player around.
	if (is_jumping or is_falling) and not is_flipping:
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
	last_fall_speed = - vertical_speed
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
	# Flip flags are only needed to enter the flip animation state, so clear them here.
	is_front_flipping = false
	is_back_flipping = false


func _setup_throw_charge_bar() -> void:
	if controls and not throw_charge_bar:
		throw_charge_bar = ProgressBar.new()
		throw_charge_bar.name = "ThrowChargeBar"
		throw_charge_bar.custom_minimum_size = Vector2(200, 24)
		throw_charge_bar.anchors_preset = Control.PRESET_CENTER_BOTTOM
		throw_charge_bar.anchor_left = 0.5
		throw_charge_bar.anchor_top = 0.8
		throw_charge_bar.anchor_right = 0.5
		throw_charge_bar.anchor_bottom = 0.8
		throw_charge_bar.offset_left = -100
		throw_charge_bar.offset_top = -60
		throw_charge_bar.offset_right = 100
		throw_charge_bar.offset_bottom = -36
		throw_charge_bar.show_percentage = true
		throw_charge_bar.min_value = 0.0
		throw_charge_bar.max_value = 100.0
		throw_charge_bar.value = 0.0
		throw_charge_bar.visible = false

		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
		bg_style.corner_radius_top_left = 6
		bg_style.corner_radius_top_right = 6
		bg_style.corner_radius_bottom_left = 6
		bg_style.corner_radius_bottom_right = 6

		var fg_style := StyleBoxFlat.new()
		fg_style.bg_color = Color(0.2, 0.8, 0.3, 0.9)
		fg_style.corner_radius_top_left = 6
		fg_style.corner_radius_top_right = 6
		fg_style.corner_radius_bottom_left = 6
		fg_style.corner_radius_bottom_right = 6

		throw_charge_bar.add_theme_stylebox_override("background", bg_style)
		throw_charge_bar.add_theme_stylebox_override("fill", fg_style)
		controls.add_child(throw_charge_bar)


func _rotate_model_to_direction(dir: Vector3) -> void:
	var horizontal_dir: Vector3 = dir.slide(up_direction)
	if horizontal_dir.length_squared() > 0.001:
		horizontal_dir = horizontal_dir.normalized()
		var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
		var q_to: Quaternion = Basis.looking_at(-horizontal_dir, up_direction).get_rotation_quaternion()
		orientation.basis = Basis(q_from.slerp(q_to, 1.0))
		player_model.global_transform.basis = orientation.basis


func _turn_model_toward_direction(dir: Vector3, delta: float) -> void:
	var horizontal_dir: Vector3 = dir.slide(up_direction)
	if horizontal_dir.length_squared() > 0.001:
		horizontal_dir = horizontal_dir.normalized()
		var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
		var q_to: Quaternion = Basis.looking_at(-horizontal_dir, up_direction).get_rotation_quaternion()
		var rotate_weight: float = clampf(delta * rotation_interpolate_speed, 0.0, 1.0)
		orientation.basis = Basis(q_from.slerp(q_to, rotate_weight))
		player_model.global_transform.basis = orientation.basis


func _get_crosshair_throw_direction() -> Vector3:
	if camera:
		return -camera.global_transform.basis.z.normalized()

	var facing_direction: Vector3 = get_facing_direction()
	if facing_direction.length_squared() > 0.001:
		return facing_direction

	return -global_transform.basis.z.normalized()


func _is_holding_rigidbody() -> bool:
	if item_spring_arm.get_child_count() == 0:
		return false
	var held_node: Node = item_spring_arm.get_child(0)
	return held_node is RigidBody3D


func _find_rigidbody_from_node(start_node: Node) -> RigidBody3D:
	var current_node: Node = start_node
	while current_node:
		if current_node is RigidBody3D:
			return current_node as RigidBody3D
		current_node = current_node.get_parent()
	return null


func _try_pickup_rigidbody_from_crosshair() -> bool:
	if not camera or not is_instance_valid(camera.camera_ray_cast):
		return false
	if item_spring_arm.get_child_count() > 0:
		return false
	if not camera.camera_ray_cast.is_colliding():
		return false

	var collider: Object = camera.camera_ray_cast.get_collider()
	if collider == null or not (collider is Node):
		return false

	var target_body: RigidBody3D = _find_rigidbody_from_node(collider as Node)
	if not target_body:
		return false
	if target_body is VehicleBody3D:
		return false
	if target_body.get_parent() == item_spring_arm:
		return false

	_pickup_rigidbody(target_body)
	return true


func _pickup_rigidbody(body: RigidBody3D) -> void:
	held_rigidbody = body
	held_rigidbody_original_collision_layer = body.collision_layer
	held_rigidbody_original_collision_mask = body.collision_mask
	held_rigidbody_original_freeze = body.freeze

	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze = true
	body.set_collision_layer_value(1, false)
	body.set_collision_layer_value(2, true)
	body.add_collision_exception_with(self)
	add_collision_exception_with(body)

	body.reparent(item_spring_arm, true)
	body.transform = Transform3D()
	body.position = Vector3.ZERO


func _drop_held_rigidbody() -> void:
	if not is_instance_valid(held_rigidbody):
		held_rigidbody = null
		return

	var drop_body: RigidBody3D = held_rigidbody

	if get_parent() != null:
		drop_body.reparent(get_parent(), true)
	else:
		var current_scene: Node = get_tree().current_scene
		if current_scene:
			drop_body.reparent(current_scene, true)

	_restore_held_rigidbody_state(drop_body)
	
	drop_body.linear_velocity = Vector3.ZERO
	drop_body.angular_velocity = Vector3.ZERO
	drop_body.sleeping = false


func _restore_held_rigidbody_state(body: RigidBody3D) -> void:
	body.collision_layer = held_rigidbody_original_collision_layer
	body.collision_mask = held_rigidbody_original_collision_mask
	body.freeze = held_rigidbody_original_freeze
	body.remove_collision_exception_with(self)
	remove_collision_exception_with(body)
	held_rigidbody = null


func _throw_rigidbody(body: RigidBody3D, throw_dir: Vector3, power: float) -> void:
	_restore_held_rigidbody_state(body)
	body.freeze = false
	if get_parent() != null:
		body.reparent(get_parent(), true)
	body.sleeping = false
	body.apply_impulse(throw_dir * held_object_throw_force * power, Vector3.ZERO)


## Starts charging a throw when shoot button is pressed.
func start_charging_throw() -> void:
	if item_spring_arm.get_child_count() == 0:
		return

	is_charging_throw = true
	throw_charge_time = 0.0
	throw_power = 0.25

	var throw_dir: Vector3
	if camera:
		throw_dir = - camera.global_transform.basis.z.normalized()
	else:
		throw_dir = get_facing_direction()
	_rotate_model_to_direction(throw_dir)


## Called when shoot button is released while charging a throw.
func release_charging_throw() -> void:
	if not is_charging_throw:
		return

	var throw_dir: Vector3
	if camera:
		throw_dir = - camera.global_transform.basis.z.normalized()
	else:
		throw_dir = get_facing_direction()
	_rotate_model_to_direction(throw_dir)

	if throw_charge_time < 0.2:
		# Quick tap (<0.2s): Instant weak throw (25% power)
		throw_power = 0.25
		execute_instant_throw(throw_dir, throw_power)
	else:
		# Long press release (>0.2s): execute queued throw with charged power
		var charge_ratio: float = clamp((throw_charge_time - 0.2) / 0.6, 0.0, 1.0)
		throw_power = lerp(0.25, 1.0, charge_ratio)
		execute_throw()

	is_charging_throw = false
	if throw_charge_bar:
		throw_charge_bar.visible = false


## Executes an instant throw without animation wind-up (for quick taps).
func execute_instant_throw(throw_dir: Vector3, power: float) -> void:
	if item_spring_arm.get_child_count() == 0:
		return

	_rotate_model_to_direction(throw_dir)
	var held_node: Node = item_spring_arm.get_child(0)
	clear_throw_queue()
	is_charging_throw = false
	if throw_charge_bar:
		throw_charge_bar.visible = false

	if held_node.has_method("throw_with_direction"):
		held_node.call("throw_with_direction", throw_dir, power)
	elif held_node.has_method("throw"):
		held_node.call("throw", throw_dir)
	elif held_node is RigidBody3D:
		var throw_body: RigidBody3D = held_node as RigidBody3D
		_throw_rigidbody(throw_body, throw_dir, power)


## Queues a held-object throw to be executed by animation call track or 0.8s timer.
func queue_throw(throw_direction: Vector3) -> void:
	if throw_direction.length_squared() <= 0.001:
		if camera:
			throw_direction = - camera.global_transform.basis.z.normalized()
		else:
			throw_direction = get_facing_direction()
		if throw_direction.length_squared() <= 0.001:
			throw_direction = - global_transform.basis.z.normalized()

	is_throw_queued = true
	is_throwing = true
	queued_throw_direction = throw_direction.normalized()

	var emote_state = animation_tree.get(EMOTE_STATE_PLAYBACK_PATH)
	if emote_state:
		animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 1.0)
		emote_state.travel("Throw")
		is_emoting = true
		has_started_emoting = false


## Clears the queued throw state.
func clear_throw_queue() -> void:
	is_throw_queued = false
	queued_throw_direction = Vector3.ZERO


## Called by throw animation(s) using "Call Method Track" or timer to throw held object at the right frame.
func execute_throw() -> void:
	if not is_throw_queued and not is_charging_throw:
		return
	if item_spring_arm.get_child_count() == 0:
		clear_throw_queue()
		if throw_charge_bar:
			throw_charge_bar.visible = false
		is_charging_throw = false
		return

	var held_node: Node = item_spring_arm.get_child(0)
	var throw_dir: Vector3 = queued_throw_direction
	if throw_dir.length_squared() <= 0.001:
		if camera:
			throw_dir = - camera.global_transform.basis.z.normalized()
		else:
			throw_dir = get_facing_direction()

	_rotate_model_to_direction(throw_dir)
	var power: float = throw_power
	clear_throw_queue()
	is_charging_throw = false
	if throw_charge_bar:
		throw_charge_bar.visible = false

	if held_node.has_method("throw_with_direction"):
		held_node.call("throw_with_direction", throw_dir, power)
	elif held_node.has_method("throw"):
		held_node.call("throw", throw_dir)
	elif held_node is RigidBody3D:
		var throw_body: RigidBody3D = held_node as RigidBody3D
		_throw_rigidbody(throw_body, throw_dir, power)


## Alias for animation call tracks that expect a throw-named method.
func throw_held_object() -> void:
	execute_throw()


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
	if is_boxing:
		return &"BoxingLocomotion"
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
	if is_on_floor() and paraglider_raycast.is_colliding() and not is_ragdolling:
		var collider := paraglider_raycast.get_collider() as Node3D
		if collider:
			if (collider.is_in_group("DIRT") or collider.is_in_group("GRASS")):
				sfx_footsteps_grass.play()
			elif (collider.is_in_group("COBBLESTONE") or collider.is_in_group("CONCRETE") or collider.is_in_group("STONE")):
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
	var current_body_up := global_basis.y
	if not current_body_up.is_equal_approx(up_direction):
		var q_align_body := Quaternion(current_body_up, up_direction)
		global_basis = Basis(q_align_body) * global_basis

	var pre_velocity := velocity
	move_and_slide()

	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_collider() is RigidBody3D:
			var rb := c.get_collider() as RigidBody3D
			if rb != held_rigidbody:
				var push_dir := -c.get_normal()
				var velocity_proj := pre_velocity.dot(push_dir)
				var rb_velocity_proj := rb.linear_velocity.dot(push_dir)
				var relative_velocity_proj := velocity_proj - rb_velocity_proj
				if relative_velocity_proj > 0.0:
					var effective_mass := (mass * rb.mass) / (mass + rb.mass)
					rb.apply_impulse(push_dir * relative_velocity_proj * effective_mass * push_force, c.get_position() - rb.global_position)


	orientation.origin = Vector3() # Clear accumulated root motion displacement (was applied to speed).
	orientation = orientation.orthonormalized() # Orthonormalize orientation.

	# Smoothly align character body and model orientation Y-axis with up_direction
	var current_up := orientation.basis.y
	if not current_up.is_equal_approx(up_direction):
		var next_up := current_up.slerp(up_direction, delta * 10.0).normalized()
		var q_align := Quaternion(current_up, next_up)
		orientation.basis = Basis(q_align) * orientation.basis


	# Rotate the Player Model (unless entering/exiting a vehicle or ragdolling)
	if not (is_driving and (is_entering_vehicle or is_exiting_vehicle)) and not is_ragdolling:
		player_model.global_transform.basis = orientation.basis
		var model_facing_basis: Basis = orientation.basis.rotated(up_direction, PI)
		var rotated_basis: Basis = model_facing_basis * initial_separation_ray_transform.basis
		var rotated_origin: Vector3 = global_position + (model_facing_basis * initial_separation_ray_transform.origin)
		separation_ray_shape.global_transform = Transform3D(rotated_basis, rotated_origin)

	# Debug: Check collisions against other objects using space state
	if is_attacking and skeleton:
		var space_state = get_world_3d().direct_space_state
		var collision_queries = []
		
		if inventory and inventory.is_unarmed():
			# Check hand collisions
			var hand_names = ["LeftHand", "RightHand"]
			for h_name in hand_names:
				var b_idx = skeleton.find_bone(h_name)
				if b_idx != -1:
					var bone_pose = skeleton.get_bone_global_pose(b_idx)
					var bone_global_trans = skeleton.global_transform * bone_pose
					
					var query = PhysicsShapeQueryParameters3D.new()
					var sphere = SphereShape3D.new()
					sphere.radius = 0.15
					query.shape = sphere
					query.transform = bone_global_trans
					query.collision_mask = 0xFFFFFFFF # Check all layers
					
					collision_queries.append({
						"query": query,
						"name": h_name,
						"color": debug_left_hand_hit_color if h_name == "LeftHand" else debug_right_hand_hit_color
					})
		elif inventory:
			# Check equipped weapon collisions
			for equip in inventory.equipment:
				if equip.can_attack:
					var hitbox = equip.get_node_or_null("Hitbox")
					if hitbox and hitbox is Area3D:
						for child in hitbox.get_children():
							if child is CollisionShape3D and child.shape:
								var query = PhysicsShapeQueryParameters3D.new()
								query.shape = child.shape
								query.transform = child.global_transform
								query.collision_mask = 0xFFFFFFFF
								collision_queries.append({
									"query": query,
									"name": equip.name,
									"color": Color.RED # Weapon debug color
								})
		
		# Execute all gathered queries
		var impulse_applied = false
		for cq in collision_queries:
			var query = cq["query"]
			var h_name = cq["name"]
			var hit_color = cq["color"]
			
			var results = space_state.intersect_shape(query)
			for res in results:
				var coll = res.collider
				# Exclude collisions with the player's own bodies
				if coll != self and coll.get_parent() != physical_bone_simulator:
					# Add a visual indicator for debugging (optional)
					#var mesh_inst = MeshInstance3D.new()
					#var sm = SphereMesh.new()
					#sm.radius = 0.05
					#sm.height = 0.1
					#mesh_inst.mesh = sm
					#var mat = StandardMaterial3D.new()
					#mat.albedo_color = hit_color
					#mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					#mesh_inst.material_override = mat
					#get_tree().root.add_child(mesh_inst)
					#mesh_inst.global_position = query.transform.origin
					#get_tree().create_timer(1.0).timeout.connect(mesh_inst.queue_free)
					# Apply impulse to the collider
					if not impulse_applied:
						impulse_applied = true
						if coll.has_method("apply_impulse"):
							var push_dir = - global_transform.basis.z.normalized()
							push_dir.y += 0.5 # Add a slight upward lift to the knockback
							push_dir = push_dir.normalized()
							
							var coll_mass = 1.0
							if "mass" in coll:
								coll_mass = coll.mass
							elif coll.has_method("get_mass"):
								coll_mass = coll.get_mass()
								
							var effective_mass = (mass * coll_mass) / (mass + coll_mass)
							coll.apply_impulse(push_dir * push_force * 10.0 * effective_mass, query.transform.origin - coll.global_position)
