class_name HitDetection
extends Node
## Applies knockback impulses to bodies overlapping the Player's active attack shapes.
##
## Unarmed attacks query spheres around the hand bones; armed attacks query the
## equipped weapon's "Hitbox" collision shapes.

const HAND_HIT_RADIUS: float = 0.15 ## Radius of the sphere queried around each hand bone.
const KNOCKBACK_MULTIPLIER: float = 10.0 ## Scales [member Player.push_force] for attack knockback.
const DEBUG_SPHERE_LIFETIME: float = 1.0 ## Seconds a debug hit sphere stays visible.
const RESOURCE_SWEEP_RADIUS: float = 0.9 ## Radius of the sphere swept in front of the player for resource nodes.

@export var player: Player

@export_category("Debug Settings")
@export var debug_left_hand_hit_color: Color = Color.ORANGE
@export var debug_right_hand_hit_color: Color = Color.BLUE
@export var debug_weapon_hit_color: Color = Color.RED

var _swing_hit_targets: Array[Node] = [] ## Targets already notified during the current swing.
var _last_swing_node: String = "" ## Locomotion node of the swing that populated [member _swing_hit_targets].
var _hand_sphere: SphereShape3D ## Reused so the physics server doesn't create/destroy a shape every frame.
var _sweep_sphere: SphereShape3D ## Reused so the physics server doesn't create/destroy a shape every frame.


var _left_hand_node: Node
var _right_hand_node: Node

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_physics_process(is_multiplayer_authority())
	_hand_sphere = SphereShape3D.new()
	_hand_sphere.radius = HAND_HIT_RADIUS
	_sweep_sphere = SphereShape3D.new()
	_sweep_sphere.radius = RESOURCE_SWEEP_RADIUS
	
	_left_hand_node = Node.new()
	_left_hand_node.name = "LeftHand"
	add_child(_left_hand_node)
	
	_right_hand_node = Node.new()
	_right_hand_node.name = "RightHand"
	add_child(_right_hand_node)

## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	if player == null or player.skeleton == null:
		return
	if not player.is_attacking:
		# Attack ended; the next swing is new even if it reuses the same animation node
		_last_swing_node = ""
		_swing_hit_targets.clear()
		return

	# A new attack animation node means a new swing; targets may be hit again
	var current_node: String = player.current_locomotion_node
	if current_node != _last_swing_node:
		_last_swing_node = current_node
		_swing_hit_targets.clear()

	var queries: Array[Dictionary] = []
	if player.inventory and player.inventory.is_unarmed():
		queries = _gather_hand_queries()
	elif player.inventory:
		queries = _gather_weapon_queries()

	_apply_first_hit_impulse(queries)
	_sweep_resource_targets()


## Registers weapon hits on resource nodes in front of the player.
func _sweep_resource_targets() -> void:
	if player.inventory == null or player.inventory.is_unarmed():
		return
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var forward: Vector3 = -player.orientation.basis.z
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _sweep_sphere
	query.transform = Transform3D(Basis(), player.global_position + player.up_direction * 0.5 + forward * RESOURCE_SWEEP_RADIUS)
	query.collision_mask = 0xFFFFFFFF
	for equip in player.inventory.equipment:
		if not equip.can_attack:
			continue
		if not ("can_log" in equip and equip.can_log) and not ("can_mine" in equip and equip.can_mine):
			continue
		for result in space_state.intersect_shape(query):
			var collider: Object = result.collider
			if collider is Node:
				_register_weapon_hit(collider, equip)


## Builds shape queries around the hand bones for unarmed attacks.
func _gather_hand_queries() -> Array[Dictionary]:
	var queries: Array[Dictionary] = []
	for hand_name in ["LeftHand", "RightHand"]:
		var bone_index: int = player.skeleton.find_bone(hand_name)
		if bone_index == -1:
			continue
		var bone_pose: Transform3D = player.skeleton.get_bone_global_pose(bone_index)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = _hand_sphere
		query.transform = player.skeleton.global_transform * bone_pose
		query.collision_mask = 0xFFFFFFFF
		var hit_color: Color = debug_left_hand_hit_color if hand_name == "LeftHand" else debug_right_hand_hit_color
		var equip_node: Node = _left_hand_node if hand_name == "LeftHand" else _right_hand_node
		queries.append({ "query": query, "color": hit_color, "equipment": equip_node })
	return queries


## Builds shape queries from the "Hitbox" shapes of equipped weapons that can attack.
func _gather_weapon_queries() -> Array[Dictionary]:
	var queries: Array[Dictionary] = []
	for equip in player.inventory.equipment:
		if not equip.can_attack:
			continue
		var hitbox: Node = equip.get_node_or_null("Hitbox")
		if hitbox == null or not hitbox is Area3D:
			continue
		for child in hitbox.get_children():
			if child is CollisionShape3D and child.shape:
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = child.shape
				query.transform = child.global_transform
				query.collision_mask = 0xFFFFFFFF
				queries.append({ "query": query, "color": debug_weapon_hit_color, "equipment": equip })
	return queries


## Applies one knockback impulse to the first hit body; marks every hit with a debug sphere.
func _apply_first_hit_impulse(queries: Array[Dictionary]) -> void:
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var impulse_applied: bool = false
	for entry in queries:
		var query: PhysicsShapeQueryParameters3D = entry["query"]
		var hit_color: Color = entry["color"]
		for result in space_state.intersect_shape(query):
			var collider: Object = result.collider
			if collider == player:
				continue
			if collider is Node and (collider as Node).get_parent() == player.physical_bone_simulator:
				continue

			if player.debug and player.debug.visible:
				_spawn_debug_hit_sphere(query.transform.origin, hit_color)

			var equipment: Node = entry.get("equipment") as Node
			if not equipment:
				equipment = player
			_register_weapon_hit(collider, equipment)

			if impulse_applied or not collider.has_method("apply_impulse"):
				continue
			if collider is Node and (collider as Node).has_meta("no_knockback_until") \
					and Time.get_ticks_msec() < (collider as Node).get_meta("no_knockback_until"):
				continue
			impulse_applied = true

			var push_dir: Vector3 = -player.global_transform.basis.z.normalized()
			push_dir = (push_dir + player.up_direction * 0.5).normalized()

			var collider_mass: float = 1.0
			if "mass" in collider:
				collider_mass = collider.mass
			elif collider.has_method("get_mass"):
				collider_mass = collider.call("get_mass")

			var effective_mass: float = (player.mass * collider_mass) / (player.mass + collider_mass)
			var impulse: Vector3 = push_dir * player.push_force * KNOCKBACK_MULTIPLIER * effective_mass
			var impulse_position: Vector3 = query.transform.origin - (collider as Node3D).global_position
			collider.call("apply_impulse", impulse, impulse_position)


## Notifies the nearest ancestor that handles weapon hits, once per target per swing.
func _register_weapon_hit(collider: Object, equipment: Node = null) -> void:
	var node: Node = collider as Node
	while node:
		if node.has_method("register_weapon_hit"):
			if node not in _swing_hit_targets:
				_swing_hit_targets.append(node)
				node.call("register_weapon_hit", equipment, collider)
			return
		node = node.get_parent()


## Spawns a short-lived unshaded sphere marking a detected hit.
func _spawn_debug_hit_sphere(hit_position: Vector3, hit_color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.05
	sphere_mesh.height = 0.1
	mesh_instance.mesh = sphere_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = hit_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	get_tree().root.add_child(mesh_instance)
	mesh_instance.global_position = hit_position
	get_tree().create_timer(DEBUG_SPHERE_LIFETIME).timeout.connect(mesh_instance.queue_free)
