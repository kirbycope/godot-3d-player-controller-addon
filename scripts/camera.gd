extends Camera3D
class_name Camera

enum Perspective {
	FIRST_PERSON, ## Rendered from the viewpoint of the player character
	THIRD_PERSON, ## Rendered from a fixed distance behind and slightly above the player character.
}

const CAMERA_FOLLOW_DELAY: float = 2.0

@export var camera_mount: Node3D
@export var camera_spring_arm: SpringArm3D
@export var first_person_offset: Vector3 = Vector3(0.0, 0.0, -0.3) ## The offset of the camera from the player's head when in first-person perspective.
@export var first_person_item_spring_length: float = 0.7 ## Held-item spring length in first-person.
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
@export var player: Player

var camera_follow_delay_remaining: float = 0.0
var first_person_bone_attachment: BoneAttachment3D
var is_temporarily_captured: bool = false ## Cursor captured only while right-click rotating; released back to visible.
var looking_at: Node3D = null

const FOCUS_AIM_WORLD_RADIUS: float = 0.5 ## World-space radius in units/meters that the aim can deviate from the target center.
var focus_aim_offset: Vector2 = Vector2.ZERO ## Current aim offset applied on top of the focused lock-on target.

@onready var camera_initial_transform: Transform3D = transform
@onready var camera_ray_cast: RayCast3D = $CameraRayCast
@onready var item_spring_arm: SpringArm3D = $"../../ItemSpringArm"
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
	default_fov = fov
	default_h_offset = h_offset

	set_process(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	set_process_input(is_multiplayer_authority())

	# Ensure the [RayCast3D] doesn't collide with the player
	camera_ray_cast.add_exception(player)

	# Ensure the Camera's [SpringArm3D] doesn't collide with the player
	camera_spring_arm.add_excluded_object(player.get_rid())

	# Match the [RayCast3D] offset to the starting perspective (scene offset is for third-person)
	if perspective == Perspective.FIRST_PERSON:
		camera_ray_cast.position = Vector3.ZERO

	_sync_item_spring_arm()


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Do nothing if the player is not set or is paused/ragdolling
	if not player or player.is_paused or player.is_ragdolling: return

	# Look at interactable objects under the mouse cursor while it is visible.
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		_update_raycast()

	# Check if the player is interacting with an equipment item and has pressed "action" to interact
	if looking_at and event.is_action_pressed("action") and looking_at.has_method("equip"):
		looking_at.equip(player)
		looking_at = null

	# Perspective { Microsoft: ⧉, Nintendo: ⊝, Sony: ⦀, Keyboard: [F5] }
	if event.is_action_pressed("perspective"):
		if perspective == Perspective.FIRST_PERSON:
			perspective = Perspective.THIRD_PERSON
			transform = camera_initial_transform
		else:
			perspective = Perspective.FIRST_PERSON
		_update_raycast()

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
	and (not player.is_driving or perspective == Perspective.THIRD_PERSON) \
	and not is_radial_menu_open():
		if player.is_focusing and not player.has_firearm_equipped:
			if player.is_shooting:
				var mouse_motion_input: Vector2 = event.relative
				focus_aim_offset.x += deg_to_rad(-mouse_motion_input.x * mouse_sensitivity)
				focus_aim_offset.y += deg_to_rad(-mouse_motion_input.y * mouse_sensitivity)
				focus_aim_offset = focus_aim_offset.limit_length(get_max_focus_aim_angle())
		else:
			rotate_camera_using_mouse_motion(event)
			if (player.is_driving or player.is_skateboarding) \
			and event.relative.length_squared() > 0.0:
				defer_camera_follow()

	# Only continue if the perspective is third-person
	if perspective == Perspective.THIRD_PERSON:
		# If Mouse scroll wheel up
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Shorten the camera spring arm, min 1.0
			camera_spring_arm.spring_length = max(camera_spring_arm.spring_length - 0.1, 1.0)
			# TODO: If the player tries to zoom in further, switch to first-person perspective instead?
			_update_raycast()

		# If Mouse scroll wheel down
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Lengthen the camera spring arm, max 6.0
			camera_spring_arm.spring_length = min(camera_spring_arm.spring_length + 0.1, 6.0)
			_update_raycast()


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Move camera to player's head if in first-person perspective
	if perspective == Perspective.FIRST_PERSON:
		move_camera_to_player_head()

	# Rotate the [Camera3D]'s [SpringArm3D] using the joypad motion input event
	var joypad_motion_input: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if joypad_motion_input != Vector2.ZERO \
	and player \
	and not player.is_paused \
	and not player.is_ragdolling \
	and (not player.is_driving or perspective == Perspective.THIRD_PERSON) \
	and not is_radial_menu_open():
		if player.is_focusing and not player.has_firearm_equipped:
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
			# Add a delay before the camera starts following the player again
			if player.is_skateboarding or player.is_driving:
				defer_camera_follow()

	# Decrement the camera follow delay
	if camera_follow_delay_remaining > 0.0:
		camera_follow_delay_remaining = max(
				camera_follow_delay_remaining - delta,
				0.0
		)

	# Smoothly interpolate FOV and shoulder offset when aiming/shooting (BotW/TotK over-the-shoulder framing)
	if perspective == Perspective.THIRD_PERSON:
		var is_aiming_now: bool = false
		if player != null:
			if player.has_firearm_equipped:
				is_aiming_now = player.is_focusing
			elif player.has_bow_equipped:
				is_aiming_now = player.is_shooting or player.is_drawing_arrow or player.is_aiming_bow
			else:
				is_aiming_now = player.is_shooting or player.is_drawing_arrow or player.is_aiming_bow
		var target_fov: float = aim_fov if is_aiming_now else default_fov
		var target_h_offset: float = aim_h_offset if is_aiming_now else default_h_offset
		fov = lerpf(fov, target_fov, delta * 10.0)
		h_offset = lerpf(h_offset, target_h_offset, delta * 10.0)

	# Lerp camera to face the player's direction when focusing, driving, or skateboarding (and the follow delay has expired).
	if perspective == Perspective.THIRD_PERSON:
		if player.is_focusing and not player.has_firearm_equipped:
			var max_angle: float = get_max_focus_aim_angle()
			focus_aim_offset = focus_aim_offset.limit_length(max_angle)
			if not player.is_shooting:
				focus_aim_offset = focus_aim_offset.move_toward(Vector2.ZERO, delta * 4.0)

			if is_instance_valid(player.current_focus_target):
				var target_pos: Vector3 = Focus.get_focus_target_position(player.current_focus_target)
				var to_target: Vector3 = target_pos - camera_mount.global_position
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
			if (player.is_driving and camera_follow_delay_remaining <= 0.0) \
			or (player.is_skateboarding and camera_follow_delay_remaining <= 0.0):
				camera_mount.rotation.y = lerp_angle(camera_mount.rotation.y, player.player_model.rotation.y + PI, delta * 8.0)

	_sync_item_spring_arm()


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	# Move camera to player's head if in first-person perspective
	if perspective == Perspective.FIRST_PERSON:
		move_camera_to_player_head()

	_sync_item_spring_arm()


## Rotates the [Camera3D]'s [SpringArm3D] using the input from a joypad motion event, while clamping the vertical rotation to prevent flipping.
func rotate_camera_using_joypad_motion(delta: float) -> void:
	# Get the input from the joypad motion event
	var joypad_motion_input: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	# Rotate the [Camera3D]'s [CameraMount] horizontally using the joypad motion input's x value
	if joypad_motion_input.x != 0:
		camera_mount.rotate_y(deg_to_rad(-joypad_motion_input.x * joypad_sensitivity * delta))
	# Rotate the [Camera3D]'s [CameraMount] vertically using the joypad motion input's y value
	if joypad_motion_input.y != 0:
		var new_rotation_x: float = camera_mount.rotation_degrees.x - joypad_motion_input.y * joypad_sensitivity * delta
		# Clamp the rotation to prevent flipping
		new_rotation_x = clamp(new_rotation_x, -89, 89)
		# Apply the new rotation to the [Camera3D]'s [CameraMount]
		camera_mount.rotation_degrees.x = new_rotation_x


## Rotates the [Camera3D]'s [SpringArm3D] using the input from a mouse motion event, while clamping the vertical rotation to prevent flipping.
func rotate_camera_using_mouse_motion(event: InputEventMouseMotion) -> void:
	# Get the input from the mouse motion event
	var mouse_motion_input: Vector2 = event.relative
	# Rotate the [Camera3D]'s [CameraMount] horizontally using the mouse motion input's x value
	camera_mount.rotate_y(deg_to_rad(-mouse_motion_input.x * mouse_sensitivity))
	# Rotate the [Camera3D]'s [CameraMount] vertically using the mouse motion input's y value
	var new_rotation_x: float = camera_mount.rotation_degrees.x - mouse_motion_input.y * mouse_sensitivity
	# Clamp the rotation to prevent flipping
	new_rotation_x = clamp(new_rotation_x, -89, 89)
	# Apply the new rotation to the [Camera3D]'s [CameraMount]
	camera_mount.rotation_degrees.x = new_rotation_x


## Adds a delay before the camera starts following the player again.
func defer_camera_follow() -> void:
	camera_follow_delay_remaining = CAMERA_FOLLOW_DELAY


## Update the camera to follow the character head's position (while in "first-person").
func move_camera_to_player_head() -> void:
	if first_person_bone_attachment == null:
		first_person_bone_attachment = player.skeleton.get_node("FirstPersonCameraBoneAttachment") as BoneAttachment3D

	global_position = first_person_bone_attachment.global_position
	global_rotation = camera_mount.global_rotation
	global_position += global_transform.basis.z * first_person_offset.z
	global_position += global_transform.basis.y * first_person_offset.y
	global_position += global_transform.basis.x * first_person_offset.x


## Keeps the held-item spring arm aligned with perspective/camera behavior.
func _sync_item_spring_arm() -> void:
	if not is_instance_valid(item_spring_arm):
		return

	if perspective == Perspective.FIRST_PERSON:
		# Preserve arm's authored local orientation (typically 180deg yaw)
		# so SpringArm extension remains in front of the first-person camera.
		item_spring_arm.global_basis = global_basis * item_spring_arm_initial_transform.basis
		item_spring_arm.global_position = global_position
		item_spring_arm.spring_length = player.held_object.get_held_distance(
			first_person_item_spring_length
		) if player.held_object else first_person_item_spring_length
	else:
		item_spring_arm.transform = item_spring_arm_initial_transform
		item_spring_arm.spring_length = player.held_object.get_held_distance(
			third_person_item_spring_length
		) if player.held_object else third_person_item_spring_length


## Updates the [RayCast3D] position and target_position based on current perspective/depth.
func _update_raycast() -> void:
	if not is_instance_valid(camera_ray_cast):
		return

	if perspective == Perspective.FIRST_PERSON:
		camera_ray_cast.position = Vector3.ZERO
		camera_ray_cast.target_position = Vector3(0, 0, -interaction_distance)
	else:
		camera_ray_cast.position = Vector3(0, 0, -1.0)
		var length := 2.0
		if is_instance_valid(camera_spring_arm):
			length = camera_spring_arm.spring_length
		camera_ray_cast.target_position = Vector3(0, 0, - (length + interaction_distance - 1.0))

	_sync_item_spring_arm()


## Returns whether the RadialMenu is currently open/visible.
func is_radial_menu_open() -> bool:
	if player and is_instance_valid(player.radial_menu):
		return player.radial_menu.is_open()
	return false
