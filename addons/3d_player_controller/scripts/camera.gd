extends Camera3D
class_name Camera

signal looking_at_changed(previous: Node3D, current: Node3D) ## Emitted when the interactable under the camera ray changes (either may be null).
signal interaction_target_changed(previous: Node3D, current: Node3D) ## Emitted when the one thing the action button would act on changes (either may be null).

enum Perspective {
	FIRST_PERSON, ## Rendered from the viewpoint of the player character
	THIRD_PERSON, ## Rendered from a fixed distance behind and slightly above the player character.
}

const FOCUS_AIM_WORLD_RADIUS: float = 0.5 ## World-space radius in units/meters that the aim can deviate from the target center.

@export var camera_mount: Node3D
@export var camera_spring_arm: SpringArm3D
@export var first_person_offset: Vector3 = Vector3(0.0, 0.0, -0.3) ## The offset of the camera from the player's head when in first-person perspective.
@export var first_person_item_spring_length: float = 0.7 ## Held-item spring length in first-person.
@export var held_pitch_min: float = -0.35 ## Radians: in third person the item arm never dips below this when the camera looks down, so a held object stays out of the ground and the Player's legs.
@export var held_pitch_max: float = 0.6 ## Radians: and never rises above this when the camera looks up.
@export var third_person_item_spring_length: float = 2.0 ## Held-item spring length in third-person.
@export var interaction_distance: float = 3.0 ## The maximum distance the player can reach to interact with objects.
@export var joypad_sensitivity: float = 100.0
@export var held_joypad_look_multiplier: float = 0.45
@export var mouse_sensitivity: float = 0.1
@export var default_fov: float = 75.0 ## Base third-person FOV.
@export var aim_fov: float = 58.0 ## Narrowed FOV when aiming/shooting (over-the-shoulder).
@export var default_h_offset: float = 0.0 ## Base horizontal offset.
@export var aim_h_offset: float = 0.25 ## Over-the-right-shoulder offset when aiming/shooting.
@export var perspective: Perspective = Perspective.THIRD_PERSON ## What perspective should the Camera use?
@export_group("Locked View", "locked_")
@export var locked_view: bool = false ## Holds the third-person camera at [member locked_pitch_degrees] and [member locked_yaw_degrees], [member locked_distance] out, and ignores the look stick and the mouse: an action RPG's view from above.
@export var locked_pitch_degrees: float = -55.0
@export var locked_yaw_degrees: float = 0.0
@export var locked_distance: float = 12.0
@export_group("")
@export var player: Player

var focus_aim_offset: Vector2 = Vector2.ZERO ## Current aim offset applied on top of the focused lock-on target.
var is_temporarily_captured: bool = false ## Cursor captured only while right-click rotating; released back to visible.
var looking_at: Node3D = null: ## The nearest ancestor of the camera ray's collider that has a `display_menu` method, if any.
	set(value):
		if value == looking_at:
			return
		var previous: Node3D = looking_at
		looking_at = value
		looking_at_changed.emit(previous, value)
var in_reach: Array[Node3D] = [] ## Everything whose [InteractionReach] the Player is standing in right now.
var interaction_target: Node3D = null: ## The one thing the action button acts on, and the only one showing a prompt.
	set(value):
		if value == interaction_target:
			return
		var previous: Node3D = interaction_target
		interaction_target = value
		interaction_target_changed.emit(previous, value)

@onready var camera_initial_transform: Transform3D = transform
@onready var camera_ray_cast: RayCast3D = $CameraRayCast
@onready var camera_follow_timer: Timer = $CameraFollowTimer ## Running while the camera holds its manual rotation instead of following the player.
@onready var first_person_bone_attachment: BoneAttachment3D = %FirstPersonCameraBoneAttachment
@onready var item_spring_arm: SpringArm3D = %ItemSpringArm
@onready var item_spring_arm_initial_transform: Transform3D = item_spring_arm.transform


## Returns the maximum angular aim offset (in radians) based on distance to target.
## Uses atan2(FOCUS_AIM_WORLD_RADIUS, distance) so the angular window shrinks with distance.
func get_max_focus_aim_angle() -> float:
	var dist: float = 5.0
	if player:
		if is_instance_valid(player.current_focus_target):
			var target_pos: Vector3 = Focus.get_focus_target_position(player.current_focus_target)
			dist = maxf(camera_mount.global_position.distance_to(target_pos), 1.0)
		elif player.focus and player.focus.target_detection:
			var col: CollisionShape3D = player.focus.target_detection.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col and col.shape is SphereShape3D:
				dist = (col.shape as SphereShape3D).radius
	return atan2(FOCUS_AIM_WORLD_RADIUS, dist)


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	set_process_unhandled_input(is_multiplayer_authority())
	# The scene marks no camera current. A remote player's copy would otherwise take the view for the moment it
	# enters the tree, and clearing it afterwards hands the view to whichever camera entered before it. The
	# camera this peer controls claims the view itself, once, here.
	if is_multiplayer_authority():
		make_current()

	interaction_target_changed.connect(_on_interaction_target_changed)

	# Ensure the [RayCast3D] doesn't collide with the player
	camera_ray_cast.add_exception(player)

	# Water is looked through, never at: the ray has to reach the boat and the props floating in it
	for water: Node in get_tree().get_nodes_in_group(&"WATER"):
		if water is CollisionObject3D:
			camera_ray_cast.add_exception(water)

	# Ensure the Camera's [SpringArm3D] doesn't collide with the player
	camera_spring_arm.add_excluded_object(player.get_rid())
	# The item arm shortens against walls and the ground, never against the Player carrying the item
	item_spring_arm.add_excluded_object(player.get_rid())

	_update_raycast()


## Shows the interaction prompt of the one thing the button would act on, and hides the previous one. Only
## ever one prompt is up, which is what tells the player which of a crowd they are about to talk to.
func _on_interaction_target_changed(previous: Node3D, current: Node3D) -> void:
	if is_instance_valid(previous) and previous.has_method("hide_menu"):
		previous.hide_menu()
	if is_instance_valid(current):
		current.display_menu(player)


## Swaps first and third person, the way the perspective button does; public so a seat that has taken the
## Player's input (the retro computer while DOOM plays) can still answer that button.
func toggle_perspective() -> void:
	if perspective == Perspective.FIRST_PERSON:
		perspective = Perspective.THIRD_PERSON
		transform = camera_initial_transform
	else:
		perspective = Perspective.FIRST_PERSON
	_update_raycast()


## Called when an input event has not been consumed by the UI.
func _unhandled_input(event: InputEvent) -> void:
	# Do nothing if the player is not set or is paused/ragdolling
	if not player or player.is_paused or player.is_typing or player.is_ragdolling: return

	# Interactables that take "action" (the NPC, the chest, the skateboard); Equipment pickups are walk-over areas instead
	if interaction_target and event.is_action_pressed(&"action") and interaction_target.has_method("equip"):
		interaction_target.equip(player)
		interaction_target = null

	# Perspective { Microsoft: ⧉, Nintendo: ⊝, Sony: ⦀, Keyboard: [F5] }
	if event.is_action_pressed(&"perspective"):
		toggle_perspective()

	# The mouse is one local player's; a pad player's camera ignores it (see Player.uses_mouse)
	if event is InputEventMouse and (not player.uses_mouse or locked_view):
		return

	# With a visible cursor, holding right-click temporarily captures the mouse so rotation feels normal.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if player.held_object and player.held_object.is_holding_object():
			return
		if event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			is_temporarily_captured = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif not event.pressed and is_temporarily_captured:
			is_temporarily_captured = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Rotate the [Camera3D]'s [SpringArm3D] using the mouse motion input event
	if event is InputEventMouseMotion \
	and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) \
	and not (player.is_riding and not current) \
	and not is_radial_menu_open():
		if player.is_focusing and not player.has_firearm_equipped and player.lock_on_enabled():
			if player.is_shooting:
				var mouse_motion_input: Vector2 = event.relative
				focus_aim_offset.x += deg_to_rad(-mouse_motion_input.x * mouse_sensitivity)
				focus_aim_offset.y += deg_to_rad(-mouse_motion_input.y * mouse_sensitivity)
				focus_aim_offset = focus_aim_offset.limit_length(get_max_focus_aim_angle())
		else:
			rotate_camera_using_mouse_motion(event)

	# Only continue if the perspective is third-person
	if perspective == Perspective.THIRD_PERSON:
		# If Mouse scroll wheel up
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Shorten the camera spring arm, min 1.0
			camera_spring_arm.spring_length = maxf(camera_spring_arm.spring_length - 0.1, 1.0)
			# TODO: If the player tries to zoom in further, switch to first-person perspective instead?
			_update_raycast()

		# If Mouse scroll wheel down
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Lengthen the camera spring arm, max 6.0
			camera_spring_arm.spring_length = minf(camera_spring_arm.spring_length + 0.1, 6.0)
			_update_raycast()


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not player: return

	# A locked view holds its angle whatever the stick, the target or the mouse say
	if locked_view and perspective == Perspective.THIRD_PERSON:
		camera_mount.rotation = Vector3(deg_to_rad(locked_pitch_degrees), deg_to_rad(locked_yaw_degrees), 0.0)
		camera_spring_arm.spring_length = locked_distance
		focus_aim_offset = Vector2.ZERO
		fov = lerpf(fov, default_fov, delta * 10.0)
		h_offset = lerpf(h_offset, default_h_offset, delta * 10.0)
		return

	# Rotate the [Camera3D]'s [SpringArm3D] using the joypad motion input event
	var joypad_motion_input: Vector2 = player.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if joypad_motion_input != Vector2.ZERO \
	and not player.is_paused \
	and not player.is_typing \
	and not player.is_ragdolling \
	and not (player.is_riding and not current) \
	and not is_radial_menu_open():
		if player.is_focusing and not player.has_firearm_equipped and player.lock_on_enabled():
			if player.is_shooting:
				focus_aim_offset.x += deg_to_rad(-joypad_motion_input.x * joypad_sensitivity * delta)
				focus_aim_offset.y -= deg_to_rad(joypad_motion_input.y * joypad_sensitivity * delta)
				focus_aim_offset = focus_aim_offset.limit_length(get_max_focus_aim_angle())
		else:
			# Rotate the camera based on the joypad motion input event
			var look_multiplier: float = 1.0
			if player.held_object and player.held_object.is_holding_object():
				look_multiplier = held_joypad_look_multiplier
			rotate_camera_using_joypad_motion(delta * look_multiplier)

	# Only continue if the perspective is third-person
	if perspective != Perspective.THIRD_PERSON: return

	# Smoothly interpolate FOV and shoulder offset when aiming/shooting (BotW/TotK over-the-shoulder framing).
	# Free aim (a firearm, or the GTA scheme with anything in hand) is over the shoulder for as long as focus is held.
	var is_aiming_now: bool = player.is_focusing if player.has_firearm_equipped or not player.lock_on_enabled() \
			else player.is_shooting or player.is_drawing_arrow or player.is_aiming_bow
	fov = lerpf(fov, aim_fov if is_aiming_now else default_fov, delta * 10.0)
	h_offset = lerpf(h_offset, aim_h_offset if is_aiming_now else default_h_offset, delta * 10.0)

	# Lerp camera to face the player's direction when focusing, driving, or skateboarding (and the follow delay has expired).
	# Free aim leaves the camera where the stick put it: the Player turns to face it instead (Player.apply_input).
	if player.is_focusing and not player.has_firearm_equipped and player.lock_on_enabled():
		var max_angle: float = get_max_focus_aim_angle()
		focus_aim_offset = focus_aim_offset.limit_length(max_angle)
		if not player.is_shooting:
			focus_aim_offset = focus_aim_offset.move_toward(Vector2.ZERO, delta * 4.0)

		if is_instance_valid(player.current_focus_target):
			var target_pos: Vector3 = Focus.get_focus_target_position(player.current_focus_target)
			# CameraMount is a child of the Player body, so its rotation is local: put the target direction in the body frame first
			var to_target: Vector3 = player.global_basis.inverse() * (target_pos - camera_mount.global_position)
			var target_yaw: float = atan2(-to_target.x, -to_target.z) + focus_aim_offset.x
			var horiz_dist: float = Vector2(to_target.x, to_target.z).length()
			var target_pitch: float = clampf(atan2(to_target.y, horiz_dist) + focus_aim_offset.y, deg_to_rad(-80.0), deg_to_rad(80.0))
			camera_mount.rotation.y = lerp_angle(camera_mount.rotation.y, target_yaw, delta * 8.0)
			camera_mount.rotation.x = lerp_angle(camera_mount.rotation.x, target_pitch, delta * 8.0)
		else:
			camera_mount.rotation.y = lerp_angle(camera_mount.rotation.y, player.player_model.rotation.y + PI + focus_aim_offset.x, delta * 8.0)
			camera_mount.rotation.x = lerp_angle(camera_mount.rotation.x, deg_to_rad(-15.0) + focus_aim_offset.y, delta * 8.0)
	else:
		focus_aim_offset = Vector2.ZERO


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	if not player: return

	# Move camera to player's head if in first-person perspective
	if perspective == Perspective.FIRST_PERSON:
		move_camera_to_player_head()

	_sync_item_spring_arm()

	# Keep the projectile ray on the camera's centre line (shoulder offset, first-person head), so the crosshair is where rounds go
	var centre: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var normal: Vector3 = project_ray_normal(centre)
	player.projectile_raycast.global_transform = Transform3D(Basis.looking_at(normal, global_basis.y),
			project_ray_origin(centre) + normal * global_position.distance_to(camera_mount.global_position))

	# Resolve the nearest ancestor of the ray's collider that can display an interaction prompt
	var target: Node = camera_ray_cast.get_collider() as Node if camera_ray_cast.is_colliding() else null
	while target and not target.has_method("display_menu"):
		target = target.get_parent()
	looking_at = target as Node3D
	_resolve_interaction_target()


## Picks the single thing the action button acts on. What the camera ray lands on wins, so a crowd is settled
## by where the player is pointing; when the ray lands on nothing, the nearest thing in reach does, so walking
## up to something still offers it. Anything carrying an [InteractionReach] has to be in that reach to qualify,
## which is what stops a distant NPC answering across the road just because they are under the crosshair.
func _resolve_interaction_target() -> void:
	in_reach = in_reach.filter(func(node: Node3D) -> bool: return is_instance_valid(node))
	if looking_at and (not looking_at.is_in_group(InteractionReach.GROUP) or in_reach.has(looking_at)):
		interaction_target = looking_at
		return
	interaction_target = nearest_in_reach()


## The thing in reach closest to the Player, or null while nothing is.
func nearest_in_reach() -> Node3D:
	var best: Node3D = null
	var shortest: float = INF
	for node: Node3D in in_reach:
		var distance: float = player.global_position.distance_squared_to(node.global_position)
		if distance < shortest:
			shortest = distance
			best = node
	return best


## Called by an [InteractionReach] when the Player steps into it.
func reach_entered(host: Node3D) -> void:
	if is_instance_valid(host) and not in_reach.has(host):
		in_reach.append(host)


## Called by an [InteractionReach] when the Player steps out of it.
func reach_exited(host: Node3D) -> void:
	in_reach.erase(host)
	if interaction_target == host:
		_resolve_interaction_target()


## Rotates the [Camera3D]'s [SpringArm3D] using the input from a joypad motion event, while clamping the vertical rotation to prevent flipping.
func rotate_camera_using_joypad_motion(delta: float) -> void:
	# Get the input from the joypad motion event
	var joypad_motion_input: Vector2 = player.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	# Rotate the [Camera3D]'s [CameraMount] horizontally using the joypad motion input's x value
	if joypad_motion_input.x != 0:
		camera_mount.rotate_y(deg_to_rad(-joypad_motion_input.x * joypad_sensitivity * delta))
	# Rotate the [Camera3D]'s [CameraMount] vertically using the joypad motion input's y value
	if joypad_motion_input.y != 0:
		var new_rotation_x: float = camera_mount.rotation_degrees.x - joypad_motion_input.y * joypad_sensitivity * delta
		# Clamp the rotation to prevent flipping
		camera_mount.rotation_degrees.x = clampf(new_rotation_x, -89.0, 89.0)


## Rotates the [Camera3D]'s [SpringArm3D] using the input from a mouse motion event, while clamping the vertical rotation to prevent flipping.
func rotate_camera_using_mouse_motion(event: InputEventMouseMotion) -> void:
	# Get the input from the mouse motion event
	var mouse_motion_input: Vector2 = event.relative
	# Rotate the [Camera3D]'s [CameraMount] horizontally using the mouse motion input's x value
	camera_mount.rotate_y(deg_to_rad(-mouse_motion_input.x * mouse_sensitivity))
	# Rotate the [Camera3D]'s [CameraMount] vertically using the mouse motion input's y value
	var new_rotation_x: float = camera_mount.rotation_degrees.x - mouse_motion_input.y * mouse_sensitivity
	# Clamp the rotation to prevent flipping
	camera_mount.rotation_degrees.x = clampf(new_rotation_x, -89.0, 89.0)


## Update the camera to follow the character head's position (while in "first-person").
func move_camera_to_player_head() -> void:
	global_position = first_person_bone_attachment.global_position
	global_rotation = camera_mount.global_rotation
	global_position += global_transform.basis.z * first_person_offset.z
	global_position += global_transform.basis.y * first_person_offset.y
	global_position += global_transform.basis.x * first_person_offset.x


## Keeps the held-item spring arm aligned with perspective/camera behavior. The arm is aimed at where the held object
## belongs, sideways and up offsets included ([method HeldObject.get_held_offset]), rather than straight ahead with the
## object hung off its axis: a SpringArm3D only sweeps along its own axis, so this way a wall beside the Player stops
## an object moved beside them the way one ahead stops it ahead, and it never ends up inside geometry.
func _sync_item_spring_arm() -> void:
	if not is_instance_valid(item_spring_arm):
		return
	var up: Vector3 = player.up_direction
	var origin: Vector3
	var forward: Vector3
	var fallback_length: float
	if perspective == Perspective.FIRST_PERSON:
		origin = global_position
		forward = -global_basis.z
		fallback_length = first_person_item_spring_length
	else:
		# Third person: the camera's yaw, but only so much of its pitch, so looking down never puts the object in the
		# ground or inside the Player, where releasing it would shove it out or leave it stuck
		var camera_forward: Vector3 = -camera_mount.global_basis.z
		var flat: Vector3 = camera_forward.slide(up)
		if flat.length_squared() < 0.0001:
			flat = (-player.global_basis.z).slide(up)
		flat = flat.normalized()
		var pitch: float = clampf(asin(clampf(camera_forward.dot(up), -1.0, 1.0)), held_pitch_min, held_pitch_max)
		forward = (flat * cos(pitch) + up * sin(pitch)).normalized()
		origin = camera_mount.global_position + camera_mount.global_basis * item_spring_arm_initial_transform.origin
		fallback_length = third_person_item_spring_length
	var offset: Vector3 = player.held_object.get_held_offset(fallback_length) if player.held_object else Vector3(0.0, 0.0, fallback_length)
	var right: Vector3 = forward.cross(up).normalized()
	var reach: Vector3 = forward * offset.z + right * offset.x + up * offset.y
	var direction: Vector3 = reach.normalized()
	var arm_up: Vector3 = up if absf(direction.dot(up)) < 0.99 else global_basis.y
	# The authored local orientation (a 180 degree yaw) keeps the arm extending along its +Z, in front of the view
	item_spring_arm.global_transform = Transform3D(Basis.looking_at(direction, arm_up) * item_spring_arm_initial_transform.basis, origin)
	item_spring_arm.spring_length = reach.length()


## Updates the [RayCast3D] position and target_position based on current perspective/depth.
func _update_raycast() -> void:
	if perspective == Perspective.FIRST_PERSON:
		camera_ray_cast.position = Vector3.ZERO
		camera_ray_cast.target_position = Vector3(0, 0, -interaction_distance)
	else:
		camera_ray_cast.position = Vector3(0, 0, -1.0)
		var length: float = camera_spring_arm.spring_length if is_instance_valid(camera_spring_arm) else 2.0
		camera_ray_cast.target_position = Vector3(0, 0, - (length + interaction_distance - 1.0))


## Returns whether the RadialMenu is currently open/visible.
func is_radial_menu_open() -> bool:
	if player and is_instance_valid(player.radial_menu):
		return player.radial_menu.is_open() or player.abilities.radial_menu.is_open()
	return false
