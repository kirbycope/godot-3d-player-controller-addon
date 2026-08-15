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
const CONNECTOR_MATERIAL: Material = preload("res://assets/ultrahand.tres")
const CONNECTOR_RINGS: int = 16 ## Rings along the connector tube (more = smoother curve).
const CONNECTOR_RADIAL_SEGMENTS: int = 8 ## Vertices around each connector tube ring.

@export var player: Player
@export var throw_force: float = 5.0 ## Impulse strength applied to thrown [RigidBody3D] objects.
@export var connector_radius: float = 0.08 ## Connector tube radius at its widest (mid) point.
@export var connector_origin_height: float = 1.0 ## Connector start height above the Player origin.
@export var connector_lag: float = 6.0 ## Midpoint catch-up speed (lower = more bend when turning).
@export var connector_wave_amplitude: float = 0.06 ## Sideways wobble strength along the tube.
@export var connector_wave_frequency: float = 2.0 ## Wobble cycles along the tube length.
@export var connector_wave_speed: float = 1.5 ## Wobble scroll speed along the tube.

var is_throw_queued: bool = false ## Is a throw waiting on the animation call track or charge timeout?
var is_throwing: bool = false ## Is the throw wind-up currently active?
var is_charging_throw: bool = false ## Is the Player currently charging a throw?
var throw_charge_time: float = 0.0 ## Elapsed charge duration for the current throw.
var throw_power: float = 1.0 ## Throw power multiplier (MIN_THROW_POWER to MAX_THROW_POWER).
var queued_throw_direction: Vector3 = Vector3.ZERO ## Direction applied when executing a queued throw.
var throw_charge_bar: ProgressBar
var held_rigidbody: RigidBody3D = null
var _original_collision_layer: int = 0
var _original_collision_mask: int = 0
var _original_freeze: bool = false
var _connector_mesh: MeshInstance3D
var _connector_immediate_mesh: ImmediateMesh
var _connector_mid: Vector3 = Vector3.ZERO
var _is_connector_mid_initialized: bool = false
var _connector_wave_time: float = 0.0


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	set_process_input(is_multiplayer_authority())
	_create_connector_mesh()


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	if player == null or player.is_paused or player.is_ragdolling:
		return

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


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if player == null:
		return

	# While the throw wind-up is active, keep aiming at the live crosshair direction.
	if is_throwing:
		var crosshair_throw_dir: Vector3 = _get_crosshair_throw_direction()
		if crosshair_throw_dir.length_squared() > 0.001:
			queued_throw_direction = crosshair_throw_dir.normalized()
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
				throw_charge_bar.visible = true
				throw_charge_bar.value = charge_ratio * 100.0

		if throw_charge_time >= CHARGE_START_DELAY + CHARGE_DURATION:
			throw_power = MAX_THROW_POWER
			execute_throw()

	_update_connector_mesh(delta)


## True if the item spring arm currently holds a [RigidBody3D].
func is_holding_rigidbody() -> bool:
	if player.item_spring_arm.get_child_count() == 0:
		return false
	var held_node: Node = player.item_spring_arm.get_child(0)
	return held_node is RigidBody3D


## Starts charging a throw when the shoot button is pressed.
func start_charging_throw() -> void:
	if player.item_spring_arm.get_child_count() == 0:
		return

	_ensure_throw_charge_bar()
	is_charging_throw = true
	throw_charge_time = 0.0
	throw_power = MIN_THROW_POWER
	player.rotate_model_to_direction(_get_crosshair_throw_direction())


## Called when the shoot button is released while charging a throw.
func release_charging_throw() -> void:
	if not is_charging_throw:
		return

	var throw_dir: Vector3 = _get_crosshair_throw_direction()
	player.rotate_model_to_direction(throw_dir)

	if throw_charge_time < CHARGE_START_DELAY:
		# Quick tap: instant weak throw without animation wind-up.
		throw_power = MIN_THROW_POWER
		execute_instant_throw(throw_dir, throw_power)
	else:
		# Long press release: execute the queued throw with charged power.
		var charge_ratio: float = clampf((throw_charge_time - CHARGE_START_DELAY) / CHARGE_DURATION, 0.0, 1.0)
		throw_power = lerpf(MIN_THROW_POWER, MAX_THROW_POWER, charge_ratio)
		execute_throw()

	is_charging_throw = false
	if throw_charge_bar:
		throw_charge_bar.visible = false


## Executes an instant throw without animation wind-up (for quick taps).
func execute_instant_throw(throw_dir: Vector3, power: float) -> void:
	if player.item_spring_arm.get_child_count() == 0:
		return

	player.rotate_model_to_direction(throw_dir)
	var held_node: Node = player.item_spring_arm.get_child(0)
	clear_throw_queue()
	is_charging_throw = false
	if throw_charge_bar:
		throw_charge_bar.visible = false

	_throw_held_node(held_node, throw_dir, power)


## Queues a held-object throw to be executed by the animation call track or charge timeout.
func queue_throw(throw_direction: Vector3) -> void:
	if throw_direction.length_squared() <= 0.001:
		throw_direction = _get_crosshair_throw_direction()
		if throw_direction.length_squared() <= 0.001:
			throw_direction = -player.global_transform.basis.z.normalized()

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
	if player.item_spring_arm.get_child_count() == 0:
		clear_throw_queue()
		is_charging_throw = false
		if throw_charge_bar:
			throw_charge_bar.visible = false
		return

	var held_node: Node = player.item_spring_arm.get_child(0)
	var throw_dir: Vector3 = queued_throw_direction
	if throw_dir.length_squared() <= 0.001:
		throw_dir = _get_crosshair_throw_direction()

	player.rotate_model_to_direction(throw_dir)
	var power: float = throw_power
	clear_throw_queue()
	is_charging_throw = false
	if throw_charge_bar:
		throw_charge_bar.visible = false

	_throw_held_node(held_node, throw_dir, power)


## Drops the held [RigidBody3D] back into the world without applying an impulse.
func drop_held_rigidbody() -> void:
	if not is_instance_valid(held_rigidbody):
		held_rigidbody = null
		return

	var drop_body: RigidBody3D = held_rigidbody

	if player.get_parent() != null:
		drop_body.reparent(player.get_parent(), true)
	else:
		var current_scene: Node = get_tree().current_scene
		if current_scene:
			drop_body.reparent(current_scene, true)

	_restore_held_rigidbody_state(drop_body)

	drop_body.linear_velocity = Vector3.ZERO
	drop_body.angular_velocity = Vector3.ZERO
	drop_body.sleeping = false


## Throws the held node, preferring its own throw methods over a raw impulse.
func _throw_held_node(held_node: Node, throw_dir: Vector3, power: float) -> void:
	if held_node.has_method("throw_with_direction"):
		held_node.call("throw_with_direction", throw_dir, power)
	elif held_node.has_method("throw"):
		held_node.call("throw", throw_dir)
	elif held_node is RigidBody3D:
		var throw_body: RigidBody3D = held_node as RigidBody3D
		_restore_held_rigidbody_state(throw_body)
		throw_body.freeze = false
		if player.get_parent() != null:
			throw_body.reparent(player.get_parent(), true)
		throw_body.sleeping = false
		throw_body.apply_impulse(throw_dir * throw_force * power, Vector3.ZERO)


## Gets the throw direction from the camera crosshair, falling back to the facing direction.
func _get_crosshair_throw_direction() -> Vector3:
	if player.camera:
		return -player.camera.global_transform.basis.z.normalized()

	var facing_direction: Vector3 = player.get_facing_direction()
	if facing_direction.length_squared() > 0.001:
		return facing_direction

	return -player.global_transform.basis.z.normalized()


## Walks up the tree from a collider to find the owning [RigidBody3D], if any.
func _find_rigidbody_from_node(start_node: Node) -> RigidBody3D:
	var current_node: Node = start_node
	while current_node:
		if current_node is RigidBody3D:
			return current_node as RigidBody3D
		current_node = current_node.get_parent()
	return null


## Attempts to pick up the [RigidBody3D] under the crosshair. Returns true on success.
func _try_pickup_rigidbody_from_crosshair() -> bool:
	if not player.camera or not is_instance_valid(player.camera.camera_ray_cast):
		return false
	if player.item_spring_arm.get_child_count() > 0:
		return false
	if not player.camera.camera_ray_cast.is_colliding():
		return false

	var collider: Object = player.camera.camera_ray_cast.get_collider()
	if collider == null or not (collider is Node):
		return false

	var target_body: RigidBody3D = _find_rigidbody_from_node(collider as Node)
	if not target_body:
		return false
	if target_body is VehicleBody3D:
		return false
	if target_body.get_parent() == player.item_spring_arm:
		return false

	_pickup_rigidbody(target_body)
	return true


## Freezes the body, disables its world collision, and parents it to the item spring arm.
func _pickup_rigidbody(body: RigidBody3D) -> void:
	held_rigidbody = body
	_original_collision_layer = body.collision_layer
	_original_collision_mask = body.collision_mask
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
	body.position = Vector3.ZERO


## Restores the collision and freeze state recorded when the body was picked up.
func _restore_held_rigidbody_state(body: RigidBody3D) -> void:
	body.collision_layer = _original_collision_layer
	body.collision_mask = _original_collision_mask
	body.freeze = _original_freeze
	body.remove_collision_exception_with(player)
	player.remove_collision_exception_with(body)
	held_rigidbody = null


## Creates the throw charge bar lazily the first time a charge starts.
func _ensure_throw_charge_bar() -> void:
	if throw_charge_bar or player.controls == null:
		return

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
	player.controls.add_child(throw_charge_bar)


func _create_connector_mesh() -> void:
	_connector_immediate_mesh = ImmediateMesh.new()
	_connector_mesh = MeshInstance3D.new()
	_connector_mesh.name = "HeldObjectConnector"
	_connector_mesh.mesh = _connector_immediate_mesh
	_connector_mesh.material_override = CONNECTOR_MATERIAL
	_connector_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_connector_mesh.visible = false
	add_child(_connector_mesh)


func _update_connector_mesh(delta: float) -> void:
	if not is_instance_valid(_connector_mesh):
		return
	if player == null or not is_instance_valid(held_rigidbody):
		_connector_mesh.visible = false
		_is_connector_mid_initialized = false
		return

	_connector_wave_time += delta
	var player_up: Vector3 = player.up_direction.normalized()
	var start_position: Vector3 = player.global_position + player_up * connector_origin_height
	var end_position: Vector3 = held_rigidbody.global_position
	var connector_vector: Vector3 = end_position - start_position
	var connector_length: float = connector_vector.length()
	if connector_length <= 0.001:
		_connector_mesh.visible = false
		return

	# The midpoint lags behind the true center, bending the tube while the Player turns.
	var target_mid: Vector3 = start_position + connector_vector * 0.5
	if not _is_connector_mid_initialized:
		_connector_mid = target_mid
		_is_connector_mid_initialized = true
	var smoothing_weight: float = 1.0 - exp(-connector_lag * delta)
	_connector_mid = _connector_mid.lerp(target_mid, smoothing_weight)

	_rebuild_connector_tube(start_position, _connector_mid, end_position)
	_connector_mesh.global_transform = Transform3D.IDENTITY
	_connector_mesh.visible = true


## Rebuilds the connector tube mesh along a quadratic bezier through the lagged midpoint.
func _rebuild_connector_tube(p0: Vector3, p1: Vector3, p2: Vector3) -> void:
	var reference_axis: Vector3 = player.global_transform.basis.x
	var chord_direction: Vector3 = (p2 - p0).normalized()
	if absf(reference_axis.dot(chord_direction)) > 0.99:
		reference_axis = player.global_transform.basis.z

	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var uvs: Array[Vector2] = []

	for ring_index in CONNECTOR_RINGS + 1:
		var t: float = float(ring_index) / float(CONNECTOR_RINGS)
		var one_minus_t: float = 1.0 - t
		var ring_center: Vector3 = p0 * (one_minus_t * one_minus_t) \
				+ p1 * (2.0 * one_minus_t * t) \
				+ p2 * (t * t)
		var tangent: Vector3 = ((p1 - p0) * one_minus_t + (p2 - p1) * t).normalized()
		var ring_normal: Vector3 = reference_axis.cross(tangent).normalized()
		var ring_binormal: Vector3 = tangent.cross(ring_normal).normalized()

		# Anchor factor pins both ends while the middle wobbles and bulges.
		var anchor: float = sin(PI * t)
		var wave_phase: float = TAU * (t * connector_wave_frequency \
				- _connector_wave_time * connector_wave_speed)
		var wave_offset: Vector3 = (ring_normal * sin(wave_phase) \
				+ ring_binormal * cos(wave_phase)) * connector_wave_amplitude * anchor
		ring_center += wave_offset
		var ring_radius: float = connector_radius * (0.35 + 0.65 * anchor)

		for radial_index in CONNECTOR_RADIAL_SEGMENTS + 1:
			var angle: float = TAU * float(radial_index) / float(CONNECTOR_RADIAL_SEGMENTS)
			var radial_direction: Vector3 = ring_normal * cos(angle) + ring_binormal * sin(angle)
			vertices.append(ring_center + radial_direction * ring_radius)
			normals.append(radial_direction)
			uvs.append(Vector2(float(radial_index) / float(CONNECTOR_RADIAL_SEGMENTS), t))

	_connector_immediate_mesh.clear_surfaces()
	_connector_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_stride: int = CONNECTOR_RADIAL_SEGMENTS + 1
	for ring_index in CONNECTOR_RINGS:
		for radial_index in CONNECTOR_RADIAL_SEGMENTS:
			var index_a: int = ring_index * ring_stride + radial_index
			var index_b: int = index_a + 1
			var index_c: int = index_a + ring_stride
			var index_d: int = index_c + 1
			for vertex_index: int in [index_a, index_c, index_b, index_b, index_c, index_d]:
				_connector_immediate_mesh.surface_set_normal(normals[vertex_index])
				_connector_immediate_mesh.surface_set_uv(uvs[vertex_index])
				_connector_immediate_mesh.surface_add_vertex(vertices[vertex_index])
	_connector_immediate_mesh.surface_end()
