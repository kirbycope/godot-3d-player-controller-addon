class_name HeldObject
extends Node
## Picks up, carries, charges, and throws [RigidBody3D] objects targeted by the crosshair.
##
## The "action" input picks up or drops the crosshair target; holding "shoot" charges a
## throw. Throw animations fire [method Player.execute_throw] via a "Call Method Track".

const CHARGE_START_DELAY: float = 0.2 ## Seconds "shoot" must be held before a charged throw starts.
const CHARGE_DURATION: float = 0.6 ## Seconds from charge start to full throw power.
const MIN_THROW_POWER: float = 0.25 ## Throw power multiplier for a quick tap.
const MAX_THROW_POWER: float = 1.0 ## Throw power multiplier at full charge.
const HOLD_EMOTE: StringName = &"ReadyToCastSpell" ## Emote pose played while carrying.

@export_file("*.tscn") var connector_scene: String ## Scene stretched from [member connector_origin] to the held object; loaded once.
@export var player: Player
@export var connector_origin: Node3D
@export var throw_charge_bar: ProgressBar ## Charge indicator; hidden whenever a charge ends.
@export var throw_force: float = 5.0 ## Impulse strength applied to thrown [RigidBody3D] objects.
@export var connector_origin_height: float = 1.0 ## Fallback height when connector_origin is unset.
@export_group("Held Object Controls")
@export var held_move_speed: float = 1.5
@export var held_joypad_move_multiplier: float = 0.65
@export var held_depth_speed: float = 1.5
@export var held_rotation_speed: float = 90.0
@export var held_min_distance: float = 0.5
@export var held_max_distance: float = 5.0
@export var held_max_offset: Vector2 = Vector2(1.5, 1.0)
@export var rotation_snap_angle: float = 45.0 ## Degrees to rotate per discrete D-pad press in rotation mode.
@export var use_discrete_rotation_snap: bool = true ## When true, D-pad presses snap rotation in discrete 45-degree increments.

var is_throw_queued: bool = false ## Is a throw waiting on the animation call track or charge timeout?
var is_throwing: bool = false ## Is the throw wind-up currently active?
var is_charging_throw: bool = false: ## Is the Player currently charging a throw?
	set(value):
		is_charging_throw = value
		if not value and throw_charge_bar:
			throw_charge_bar.hide()
var throw_charge_time: float = 0.0 ## Elapsed charge duration for the current throw.
var throw_power: float = 1.0 ## Throw power multiplier (MIN_THROW_POWER to MAX_THROW_POWER).
var queued_throw_direction: Vector3 = Vector3.ZERO ## Direction applied when executing a queued throw.
var held_rigidbody: RigidBody3D = null
var _original_collision_layer: int = 0
var _original_freeze: bool = false
var _connector_node: Node3D
var _held_distance: float = 2.0
var _held_offset: Vector2 = Vector2.ZERO
var _is_held_rotation_mode: bool = false


func _ready() -> void:
	set_physics_process(is_multiplayer_authority())
	set_process_input(is_multiplayer_authority())
	if connector_scene.is_empty():
		return
	var scene: PackedScene = load(connector_scene) as PackedScene
	if scene:
		_connector_node = scene.instantiate() as Node3D
		_connector_node.hide()
		add_child(_connector_node)


func _input(event: InputEvent) -> void:
	if player == null or player.is_paused or player.is_ragdolling:
		return

	if is_holding_rigidbody() and _is_held_object_control_event(event):
		if event.is_action_pressed("focus") and not event.is_echo():
			_lay_held_rigidbody_flat()
		if event.is_action_pressed("throw") and not event.is_echo():
			_is_held_rotation_mode = true
			refresh_contextual_controls()
		elif event.is_action_released("throw"):
			_is_held_rotation_mode = false
			refresh_contextual_controls()

		# Discrete 45-degree rotation snapping on D-pad press in rotation mode
		if _is_held_rotation_mode and use_discrete_rotation_snap and event.is_pressed() and not event.is_echo():
			if event.is_action("last_weapon"):
				held_rigidbody.rotate_object_local(Vector3.UP, deg_to_rad(rotation_snap_angle))
			elif event.is_action("next_weapon"):
				held_rigidbody.rotate_object_local(Vector3.UP, deg_to_rad(-rotation_snap_angle))
			elif event.is_action("seeker"):
				held_rigidbody.rotate_object_local(Vector3.RIGHT, deg_to_rad(-rotation_snap_angle))
			elif event.is_action("whistle"):
				held_rigidbody.rotate_object_local(Vector3.RIGHT, deg_to_rad(rotation_snap_angle))

		get_viewport().set_input_as_handled()

	if event.is_action_pressed("action") and not event.is_echo():
		if is_holding_rigidbody():
			drop_held_rigidbody()
			get_viewport().set_input_as_handled()
			return
		if _try_pickup_rigidbody_from_crosshair():
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("shoot") and not event.is_echo() and is_holding_rigidbody():
		start_charging_throw()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_released("shoot") and not event.is_echo() and is_holding_rigidbody():
		release_charging_throw()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if player == null:
		return

	# While the throw wind-up is active, keep aiming at the live crosshair direction.
	if is_throwing:
		queued_throw_direction = _get_crosshair_throw_direction()
		player.turn_model_toward_direction(queued_throw_direction, delta)

	if is_charging_throw:
		throw_charge_time += delta
		var throw_dir: Vector3 = _get_crosshair_throw_direction()
		player.turn_model_toward_direction(throw_dir, delta)

		if throw_charge_time >= CHARGE_START_DELAY:
			if not is_throw_queued:
				queue_throw(throw_dir)
			var charge_ratio: float = clampf((throw_charge_time - CHARGE_START_DELAY) / CHARGE_DURATION, 0.0, 1.0)
			throw_power = lerpf(MIN_THROW_POWER, MAX_THROW_POWER, charge_ratio)
			if throw_charge_bar:
				throw_charge_bar.show()
				throw_charge_bar.value = charge_ratio * 100.0

		if throw_charge_time >= CHARGE_START_DELAY + CHARGE_DURATION:
			throw_power = MAX_THROW_POWER
			execute_throw()

	if is_instance_valid(held_rigidbody) and not is_throwing:
		_update_held_object_transform(delta)
		_update_connector_node()


## True if the item spring arm currently holds a [RigidBody3D].
func is_holding_rigidbody() -> bool:
	return player != null and player.item_spring_arm.get_child_count() > 0 \
			and player.item_spring_arm.get_child(0) is RigidBody3D


## True while shared controls belong exclusively to the held object manipulator.
func is_holding_object() -> bool:
	return is_instance_valid(held_rigidbody) or (player != null and player.item_spring_arm.get_child_count() > 0)


## Returns the held-object spring length requested by held object controls.
func get_held_distance(fallback_distance: float) -> float:
	return _held_distance if is_holding_object() else fallback_distance


## Starts charging a throw when the shoot button is pressed.
func start_charging_throw() -> void:
	if not is_holding_object():
		return
	is_charging_throw = true
	throw_charge_time = 0.0
	throw_power = MIN_THROW_POWER
	player.requires_shoot_release_after_throw = true
	player.rotate_model_to_direction(_get_crosshair_throw_direction())


## Called when the shoot button is released while charging a throw.
func release_charging_throw() -> void:
	if not is_charging_throw:
		return

	var throw_dir: Vector3 = _get_crosshair_throw_direction()
	player.rotate_model_to_direction(throw_dir)

	if throw_charge_time < CHARGE_START_DELAY:
		# Quick tap: instant weak throw without animation wind-up.
		execute_instant_throw(throw_dir, MIN_THROW_POWER)
	else:
		# Long press release: execute the queued throw with charged power.
		var charge_ratio: float = clampf((throw_charge_time - CHARGE_START_DELAY) / CHARGE_DURATION, 0.0, 1.0)
		throw_power = lerpf(MIN_THROW_POWER, MAX_THROW_POWER, charge_ratio)
		execute_throw()
	is_charging_throw = false


## Executes an instant throw without animation wind-up (for quick taps).
func execute_instant_throw(throw_dir: Vector3, power: float) -> void:
	if not is_holding_object():
		return
	player.rotate_model_to_direction(throw_dir)
	var held_node: Node = player.item_spring_arm.get_child(0)
	clear_throw_queue()
	is_charging_throw = false
	is_throwing = false
	_throw_held_node(held_node, throw_dir, power)


## Queues a held-object throw to be executed by the animation call track or charge timeout.
func queue_throw(throw_direction: Vector3) -> void:
	if throw_direction.length_squared() <= 0.001:
		throw_direction = _get_crosshair_throw_direction()

	is_throw_queued = true
	is_throwing = true
	queued_throw_direction = throw_direction.normalized()

	var emote_state: AnimationNodeStateMachinePlayback = player.animation_tree.get(Player.EMOTE_STATE_PLAYBACK_PATH)
	if emote_state:
		player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 1.0)
		emote_state.travel("Throw")
		player.is_emoting = true
		player.has_started_emoting = false


## Clears the queued throw state.
func clear_throw_queue() -> void:
	is_throw_queued = false
	queued_throw_direction = Vector3.ZERO


## Throws the held object at the right frame (fired by [method Player.execute_throw]).
func execute_throw() -> void:
	if not is_throw_queued and not is_charging_throw:
		return
	if not is_holding_object():
		clear_throw_queue()
		is_charging_throw = false
		is_throwing = false
		return

	var held_node: Node = player.item_spring_arm.get_child(0)
	var throw_dir: Vector3 = queued_throw_direction
	if throw_dir.length_squared() <= 0.001:
		throw_dir = _get_crosshair_throw_direction()

	player.rotate_model_to_direction(throw_dir)
	var power: float = throw_power
	clear_throw_queue()
	is_charging_throw = false
	if not player.is_emoting:
		is_throwing = false
	_throw_held_node(held_node, throw_dir, power)


## Drops the held [RigidBody3D] back into the world without applying an impulse.
func drop_held_rigidbody() -> void:
	if is_instance_valid(held_rigidbody):
		_release_held_rigidbody()
	else:
		held_rigidbody = null
		_end_hold()


## Pushes the held-object control labels; states call this on travel while an object is held.
func refresh_contextual_controls() -> void:
	# Connected here rather than in _ready: the Player's own @onready references resolve after its children are ready
	if not player.controls.input_type_changed.is_connected(_on_input_type_changed):
		player.controls.input_type_changed.connect(_on_input_type_changed)
	_on_input_type_changed(player.controls.current_input_type)


## The state handlers yield the labels while an object is held (see [method NodeStateMachine._on_input_type_changed]).
func _on_input_type_changed(input_type: int) -> void:
	if is_holding_object():
		player.controls.set_labels(get_contextual_controls(input_type))


func get_contextual_controls(input_type: int) -> Dictionary:
	var controls: Dictionary = {
		player.controls.joypad_button_0_label: "Drop",
		player.controls.joypad_button_4_label: "Perspective",
		player.controls.joypad_button_6_label: "Pause Menu",
		player.controls.joypad_button_10_label: "Rotate",
		player.controls.joypad_button_15_label: "Screenshot",
		player.controls.joypad_axis_4_plus_label: "Lay Flat",
		player.controls.joypad_axis_5_plus_label: "Throw",
		player.controls.left_joystick_label: "Move",
		player.controls.right_joystick_label: "Move Item",
	}
	if input_type == player.controls.InputType.KEYBOARD_MOUSE:
		if _is_held_rotation_mode:
			controls[player.controls.key_i_label] = "Rotate Up"
			controls[player.controls.key_j_label] = "Rotate Left"
			controls[player.controls.key_k_label] = "Rotate Down"
			controls[player.controls.key_l_label] = "Rotate Right"
		else:
			controls[player.controls.key_i_label] = "Farther"
			controls[player.controls.key_k_label] = "Closer"
	else:
		if _is_held_rotation_mode:
			controls[player.controls.joypad_button_11_label] = "Rotate Up"
			controls[player.controls.joypad_button_12_label] = "Rotate Down"
			controls[player.controls.joypad_button_13_label] = "Rotate Left"
			controls[player.controls.joypad_button_14_label] = "Rotate Right"
		else:
			controls[player.controls.joypad_button_11_label] = "Farther"
			controls[player.controls.joypad_button_12_label] = "Closer"
	return controls


## Throws the held node, preferring its own throw methods over a raw impulse.
func _throw_held_node(held_node: Node, throw_dir: Vector3, power: float) -> void:
	if held_node.has_method("throw_with_direction"):
		held_node.call("throw_with_direction", throw_dir, power)
	elif held_node.has_method("throw"):
		held_node.call("throw", throw_dir)
	elif held_node == held_rigidbody:
		var body: RigidBody3D = _release_held_rigidbody()
		body.freeze = false
		body.apply_impulse(throw_dir * throw_force * power, Vector3.ZERO)


## Gets the throw direction from the camera crosshair, falling back to the facing direction.
func _get_crosshair_throw_direction() -> Vector3:
	if player.camera:
		return -player.camera.global_transform.basis.z.normalized()
	var facing_direction: Vector3 = player.get_facing_direction()
	if facing_direction.length_squared() > 0.001:
		return facing_direction
	return -player.global_transform.basis.z.normalized()


## Attempts to pick up the [RigidBody3D] under the crosshair. Returns true on success.
func _try_pickup_rigidbody_from_crosshair() -> bool:
	if not player.camera or not player.camera.camera_ray_cast.is_colliding() or is_holding_object():
		return false

	# Walk up from the collider to the owning body.
	var node: Node = player.camera.camera_ray_cast.get_collider() as Node
	while node and not node is RigidBody3D:
		node = node.get_parent()
	if node == null or node is VehicleBody3D:
		return false

	_pickup_rigidbody(node as RigidBody3D)
	return true


## Freezes the body, disables its world collision, and parents it to the item spring arm.
func _pickup_rigidbody(body: RigidBody3D) -> void:
	held_rigidbody = body
	_original_collision_layer = body.collision_layer
	_original_freeze = body.freeze

	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze = true
	body.set_collision_layer_value(1, false)
	body.set_collision_layer_value(2, true)
	body.add_collision_exception_with(player)
	player.add_collision_exception_with(body)

	body.reparent(player.item_spring_arm, true)
	body.transform = Transform3D()
	_held_distance = clampf(player.item_spring_arm.spring_length, held_min_distance, held_max_distance)
	_held_offset = Vector2.ZERO
	_is_held_rotation_mode = false

	var emote_state: AnimationNodeStateMachinePlayback = player.animation_tree.get(Player.EMOTE_STATE_PLAYBACK_PATH)
	if emote_state:
		player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 1.0)
		emote_state.start(HOLD_EMOTE)
		player.is_emoting = true
		player.has_started_emoting = false
	player.set_look_at_target(body)
	refresh_contextual_controls()


## Returns the held body to the world with the collision and freeze state recorded on pickup.
func _release_held_rigidbody() -> RigidBody3D:
	var body: RigidBody3D = held_rigidbody
	held_rigidbody = null
	body.collision_layer = _original_collision_layer
	body.freeze = _original_freeze
	body.remove_collision_exception_with(player)
	player.remove_collision_exception_with(body)
	var world: Node = player.get_parent() if player.get_parent() else get_tree().current_scene
	if world:
		body.reparent(world, true)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false
	_end_hold()
	return body


## Clears the carry pose, look-at, connector and control labels once nothing is held.
func _end_hold() -> void:
	_is_held_rotation_mode = false
	if is_instance_valid(_connector_node):
		_connector_node.hide()
	var emote_state: AnimationNodeStateMachinePlayback = player.animation_tree.get(Player.EMOTE_STATE_PLAYBACK_PATH)
	if emote_state and emote_state.get_current_node() == HOLD_EMOTE:
		emote_state.start("Idle")
		player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 0.0)
		player.is_emoting = false
		player.has_started_emoting = false
	player.set_look_at_target(null)
	# Hand the control labels back to the active state.
	player.controls.reset_labels()
	var state_node: NodeStateMachine = player.state_machine.get_node_or_null(NodePath(NodeStateMachine.get_state_name(player.current_state))) as NodeStateMachine
	if state_node:
		state_node._on_input_type_changed(player.controls.current_input_type)


func _update_held_object_transform(delta: float) -> void:
	var dpad_input: Vector2 = Input.get_vector("last_weapon", "next_weapon", "seeker", "whistle")
	if Input.is_action_pressed("throw"):
		var rotation_delta: Vector2 = dpad_input * held_rotation_speed * delta
		held_rigidbody.rotate_object_local(Vector3.RIGHT, deg_to_rad(rotation_delta.y))
		held_rigidbody.rotate_object_local(Vector3.UP, deg_to_rad(-rotation_delta.x))
	else:
		_held_distance = clampf(_held_distance - dpad_input.y * held_depth_speed * delta, held_min_distance, held_max_distance)

	var move_input: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var move_multiplier: float = 1.0
	if player.controls.current_input_type != player.controls.InputType.KEYBOARD_MOUSE:
		move_multiplier = held_joypad_move_multiplier
	_held_offset += move_input * held_move_speed * move_multiplier * delta
	_held_offset = _held_offset.clamp(-held_max_offset, held_max_offset)
	held_rigidbody.position.x = -_held_offset.x
	held_rigidbody.position.y = -_held_offset.y


func _lay_held_rigidbody_flat() -> void:
	var player_up: Vector3 = player.up_direction.normalized()
	var camera_forward: Vector3 = (-player.camera.global_transform.basis.z).slide(player_up).normalized()
	if camera_forward.length_squared() <= 0.001:
		camera_forward = player.global_transform.basis.z.slide(player_up).normalized()
	var flat_basis: Basis = Basis.looking_at(camera_forward, player_up)
	held_rigidbody.global_basis = flat_basis.rotated(flat_basis.x, -PI * 0.5)


func _is_held_object_control_event(event: InputEvent) -> bool:
	return event.is_action("seeker") \
		or event.is_action("whistle") \
		or event.is_action("last_weapon") \
		or event.is_action("next_weapon") \
		or event.is_action("look_left") \
		or event.is_action("look_right") \
		or event.is_action("look_up") \
		or event.is_action("look_down") \
		or event.is_action("throw") \
		or event.is_action("focus")


## Stretches the connector scene from the origin to the held body.
func _update_connector_node() -> void:
	if not is_instance_valid(_connector_node):
		return
	var player_up: Vector3 = player.up_direction.normalized()
	var start_position: Vector3 = connector_origin.global_position if is_instance_valid(connector_origin) \
			else player.global_position + player_up * connector_origin_height
	var connector_vector: Vector3 = held_rigidbody.global_position - start_position
	var connector_length: float = connector_vector.length()
	if connector_length <= 0.001:
		_connector_node.hide()
		return

	var up_vec: Vector3 = player_up
	if absf((connector_vector / connector_length).dot(up_vec)) > 0.99:
		up_vec = player.global_transform.basis.x
	_connector_node.global_position = start_position
	_connector_node.look_at(held_rigidbody.global_position, up_vec)
	_connector_node.scale = Vector3(1.0, 1.0, connector_length / 10.0)
	_connector_node.show()
