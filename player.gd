class_name Player
extends CharacterBody3D


const EMOTE_STATE_PLAYBACK_PATH: String = "parameters/EmoteStateMachine/playback"
const LOCOMOTION_STATE_PLAYBACK_PATH: String = "parameters/LocomotionStateMachine/playback"
const ARCHERY_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/Bow/ArcheryLocomotion/blend_position"
const BOW_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/Bow/BowLocomotion/blend_position"
const BOXING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/Boxing/BoxingLocomotion/blend_position"
const BRACED_HANG_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/BracedHangLocomotion/blend_position"
const CLIMBING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/ClimbingLocomotion/blend_position"
const CROUCHING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/CrouchingLocomotion/blend_position"
const FREE_HANGING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/FreeHangingLocomotion/blend_position"
const FLYING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/FlyingLocomotion/blend_position"
const GREATSWORD_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/GreatSword/GreatSwordLocomotion/blend_position"
const PISTOL_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/Pistol/PistolLocomotion/blend_position"
const RIFLE_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/Rifle/RifleLocomotion/blend_position"
const SHIELD_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/Shield/ShieldLocomotion/blend_position"
const SKATEBOARDING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/SkateboardingLocomotion/blend_position"
const STANDING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/StandingLocomotion/blend_position"
const SWIMMING_LOCOMOTION_BLEND_POSITION_PATH: String = "parameters/LocomotionStateMachine/SwimmingLocomotion/blend_position"
const LOCOMOTION_GROUPS: Array[String] = ["Bow", "Boxing", "GreatSword", "Pistol", "Rifle", "Shield"] ## Grouped sub-state machines inside the LocomotionStateMachine.

@export var animation_tree: AnimationTree
@export var motion_interpolate_speed: float = 10.0
@export var rotation_interpolate_speed: float = 10.0
@export var swimming_root_motion_multiplier: float = 2.0

@export_category("Enable Settings")
@export var enable_flying: bool = false
@export var enable_paraglider: bool = false
@export var enable_ragdoll: bool = false
@export var enable_stamina: bool = false
@export_category("Optional Gadgets & Gear")
@export var paraglider_scene: PackedScene
@export var skateboard_scene: PackedScene
@export_category("Optional Interaction")
@export var push_force: float = 1.0
@export var mass: float = 80.0

var current_state: int = -1 ## The current state of the Player (from the Node/Code [NodeStateMachine], not the AnimationTree NodeStateMachine).
var locomotion_state: ## Gets the [NodeStateMachine] "LocomotionStateMachine"
	get:
		return animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH)
var active_locomotion_playback: ## Playback of the active grouped locomotion machine, or the root LocomotionStateMachine playback.
	get:
		var root_playback: AnimationNodeStateMachinePlayback = animation_tree.get(LOCOMOTION_STATE_PLAYBACK_PATH)
		if root_playback == null:
			return null
		var root_node: String = String(root_playback.get_current_node())
		if root_node in LOCOMOTION_GROUPS:
			return animation_tree.get("parameters/LocomotionStateMachine/" + root_node + "/playback")
		return root_playback
var current_locomotion_node: String: ## The deepest current locomotion state name (resolves grouped state machines).
	get:
		if animation_tree == null:
			return ""
		var playback: AnimationNodeStateMachinePlayback = active_locomotion_playback
		if playback == null:
			return ""
		return String(playback.get_current_node())
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
	get: return current_locomotion_node in ["GreatSwordDownwardSlash", "ShieldDownwardSlash", "ShortHeadJab"] if is_multiplayer_authority() and animation_tree else false
var is_attacking_2: bool: # Attack Sequence: 2 of n
	get: return current_locomotion_node in ["GreatSwordLowSlash", "ShieldCrossSlash", "BackHandCross"] if is_multiplayer_authority() and animation_tree else false
var is_attacking_3: bool: # Attack Sequence: 3 of n
	get: return current_locomotion_node in ["GreatSwordPowerSlash", "ShieldPowerSlash"] if is_multiplayer_authority() and animation_tree else false
# Bow and Arrow
var is_aiming_bow: bool:
	get: return current_locomotion_node == "ArcheryLocomotion" if is_multiplayer_authority() and equipped_bow else false
var is_drawing_arrow: bool:
	get: return current_locomotion_node == "BowDrawArrow" if is_multiplayer_authority() and equipped_bow else false
var is_firing_arrow: bool:
	get: return current_locomotion_node == "BowFireArrow" if is_multiplayer_authority() and equipped_bow else false
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
		# While the cursor is visible, right-click is reserved for camera rotation.
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			return false
		# Also suppressed during the temporary right-click capture used for camera rotation.
		if camera is Camera and (camera as Camera).is_temporarily_captured:
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
				or current_locomotion_node in ["Backflip", "FowardFlip"]
var is_throwing: bool: ## Is the Player currently in a throw wind-up? (Delegates to [HeldObject].)
	get:
		return held_object != null and held_object.is_throwing
	set(value):
		if held_object:
			held_object.is_throwing = value
var held_rigidbody: RigidBody3D: ## The [RigidBody3D] currently carried, if any. (Delegates to [HeldObject].)
	get:
		return held_object.held_rigidbody if held_object else null
var current_focus_target: Node3D: ## The body currently locked on to, if any. (Delegates to [Focus].)
	get:
		return focus.current_focus_target if focus else null
var is_mining: bool: ## Is the Player currently mining?
	get:
		if not is_multiplayer_authority() or animation_tree == null:
			return false
		return is_locomotion_state_active_or_queued("Mining")
var is_logging: bool: ## Is the Player currently logging?
	get:
		if not is_multiplayer_authority() or animation_tree == null:
			return false
		return is_locomotion_state_active_or_queued("Logging")
var is_navigating: bool = false ## Is the Player currently navigating (click to move)?
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
var drawn_weapon_group: String = "" ## Locomotion group whose draw animation already played; its Start skips the redraw.
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
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var pause: CanvasLayer = $Pause
@onready var settings: CanvasLayer = $Settings
@onready var stamina: TextureProgressBar = $Stamina
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
@onready var focus: Focus = $Focus
@onready var held_object: HeldObject = $HeldObject
@onready var initial_player_model_transform: Transform3D = player_model.transform
@onready var paraglider_raycast: RayCast3D = $ParagliderRaycast
@onready var projectile_raycast: RayCast3D = $CameraMount/ProjectileRaycast
@onready var skeleton: Skeleton3D = $PlayerModel/Armature/GeneralSkeleton
@onready var look_at_modifier = $PlayerModel/Armature/GeneralSkeleton/LookAtModifier3D
@onready var right_hand_ik: TwoBoneIK3D = $PlayerModel/Armature/GeneralSkeleton/RightHandIK
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

	## DEBUG: [N] toggles the cursor visibility for testing click-to-move navigation.
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_N \
			and not pause.visible and not settings.visible:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# [Left Mouse Button] pressed while the cursor is visible -> Start "navigating"
	if event is InputEventMouse \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE \
			and not pause.visible and not settings.visible:
		# Find out where the click lands on the player's movement plane
		var mouse_event: InputEventMouse = event
		var from: Vector3 = camera.project_ray_origin(mouse_event.position)
		var to: Vector3 = from + camera.project_ray_normal(mouse_event.position) * 10000.0
		var movement_plane := Plane(up_direction, global_position.dot(up_direction))
		var cursor_position: Variant = movement_plane.intersects_ray(from, to)
		if cursor_position != null:
			navigation_agent.target_position = cursor_position
			is_navigating = true
			if debug.visible:
				debug.draw_navigation_marker(cursor_position)


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Track which weapon group has finished its draw so re-entering it skips the redraw.
	var root_locomotion_node: String = String(locomotion_state.get_current_node())
	if root_locomotion_node in LOCOMOTION_GROUPS:
		var inner_node: String = current_locomotion_node
		# Skip Start/End so the flag isn't set before the entry edge picks draw vs skip.
		if not inner_node.ends_with("Draw") and inner_node not in ["Start", "End", ""]:
			drawn_weapon_group = root_locomotion_node
	elif drawn_weapon_group != "" and not is_group_equipment_equipped(drawn_weapon_group):
		drawn_weapon_group = ""

	# Apply player input to control the character and update the animation state.
	apply_input(delta)

	# Treat "jumping" as queued jump or upward airborne movement.
	is_jumping = (is_on_floor() and is_jump_queued) or (not is_on_floor() and current_locomotion_node.contains("Jump"))

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
				look_dir = - camera_basis.z
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
			var arc_angle: float = - root_motion_position.x / orbit_radius
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


## Snaps the model orientation to face the given direction on the movement plane.
func rotate_model_to_direction(dir: Vector3) -> void:
	var horizontal_dir: Vector3 = dir.slide(up_direction)
	if horizontal_dir.length_squared() > 0.001:
		horizontal_dir = horizontal_dir.normalized()
		var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
		var q_to: Quaternion = Basis.looking_at(-horizontal_dir, up_direction).get_rotation_quaternion()
		orientation.basis = Basis(q_from.slerp(q_to, 1.0))
		player_model.global_transform.basis = orientation.basis


## Smoothly turns the model orientation toward the given direction on the movement plane.
func turn_model_toward_direction(dir: Vector3, delta: float) -> void:
	var horizontal_dir: Vector3 = dir.slide(up_direction)
	if horizontal_dir.length_squared() > 0.001:
		horizontal_dir = horizontal_dir.normalized()
		var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
		var q_to: Quaternion = Basis.looking_at(-horizontal_dir, up_direction).get_rotation_quaternion()
		var rotate_weight: float = clampf(delta * rotation_interpolate_speed, 0.0, 1.0)
		orientation.basis = Basis(q_from.slerp(q_to, rotate_weight))
		player_model.global_transform.basis = orientation.basis


## Starts charging a throw when the shoot button is pressed. (Delegates to [HeldObject].)
func start_charging_throw() -> void:
	if held_object:
		held_object.start_charging_throw()


## Called when the shoot button is released while charging a throw. (Delegates to [HeldObject].)
func release_charging_throw() -> void:
	if held_object:
		held_object.release_charging_throw()


## Called by throw animation(s) using "Call Method Track" to throw the held object at the right frame.
func execute_throw() -> void:
	if held_object:
		held_object.execute_throw()


## Alias for animation call tracks that expect a throw-named method.
func throw_held_object() -> void:
	execute_throw()


## Gets the grounded locomotion state that matches the current equipment and intent.
## Grouped states use "Group/State" travel paths.
func get_grounded_locomotion_state() -> StringName:
	if is_exhausted and is_on_floor() and not has_move_input:
		return &"HeavyBreathing"
	if is_crouching:
		return &"CrouchingLocomotion"
	if equipped_axe_2h or equipped_fishing_rod or equipped_staff or equipped_sword_2h:
		return &"GreatSword/GreatSwordLocomotion"
	if equipped_bow:
		if is_shooting:
			return &"Bow/ArcheryLocomotion"
		return &"Bow/BowLocomotion"
	if equipped_axe_1h or equipped_dagger or equipped_shield or equipped_sword_1h:
		return &"Shield/ShieldLocomotion"
	if equipped_pistol:
		return &"Pistol/PistolLocomotion"
	if equipped_rifle:
		return &"Rifle/RifleLocomotion"
	if is_boxing:
		return &"Boxing/BoxingLocomotion"
	return &"StandingLocomotion"


## True if the state is the deepest current locomotion node or queued in a travel path.
func is_locomotion_state_active_or_queued(state_name: String) -> bool:
	var root_playback: AnimationNodeStateMachinePlayback = locomotion_state
	if root_playback == null:
		return false
	var playback: AnimationNodeStateMachinePlayback = active_locomotion_playback
	if String(playback.get_current_node()) == state_name:
		return true
	if StringName(state_name) in playback.get_travel_path():
		return true
	return StringName(state_name) in root_playback.get_travel_path()


## Travels the locomotion state machine; supports "Group/State" paths into nested machines.
func travel_locomotion(state_path: String) -> void:
	var root_playback: AnimationNodeStateMachinePlayback = locomotion_state
	if root_playback == null:
		return
	var parts: PackedStringArray = state_path.split("/")
	var entering_group: bool = parts[0] in LOCOMOTION_GROUPS \
			and String(root_playback.get_current_node()) != parts[0]
	root_playback.travel(parts[0])
	if parts.size() > 1:
		# On fresh entry of an undrawn group, let the Start edges route through the draw.
		if entering_group and drawn_weapon_group != parts[0] and parts[1].ends_with("Locomotion"):
			return
		var group_playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/LocomotionStateMachine/" + parts[0] + "/playback")
		if group_playback:
			group_playback.travel(parts[1])


## True if the equipment matching the given locomotion group is currently equipped.
func is_group_equipment_equipped(group_name: String) -> bool:
	match group_name:
		"Bow":
			return equipped_bow
		"Boxing":
			return is_boxing
		"GreatSword":
			return equipped_axe_2h or equipped_fishing_rod or equipped_staff or equipped_sword_2h
		"Pistol":
			return equipped_pistol
		"Rifle":
			return equipped_rifle
		"Shield":
			return equipped_axe_1h or equipped_dagger or equipped_shield or equipped_sword_1h
	return false


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
