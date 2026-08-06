class_name HitDetection
extends Node
## Applies knockback impulses to bodies overlapping the Player's active attack shapes.
##
## Unarmed attacks query spheres around the hand bones; armed attacks query the
## equipped weapon's "Hitbox" collision shapes.

const HAND_HIT_RADIUS: float = 0.15 ## Radius of the sphere queried around each hand bone.
const KNOCKBACK_MULTIPLIER: float = 10.0 ## Scales [member Player.push_force] for attack knockback.
const DEBUG_SPHERE_LIFETIME: float = 1.0 ## Seconds a debug hit sphere stays visible.

@export var player: Player

@export_category("Debug Settings")
@export var debug_left_hand_hit_color: Color = Color.ORANGE
@export var debug_right_hand_hit_color: Color = Color.BLUE
@export var debug_weapon_hit_color: Color = Color.RED


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_physics_process(is_multiplayer_authority())


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	if player == null or not player.is_attacking or player.skeleton == null:
		return

	var queries: Array[Dictionary] = []
	if player.inventory and player.inventory.is_unarmed():
		queries = _gather_hand_queries()
	elif player.inventory:
		queries = _gather_weapon_queries()

	_apply_first_hit_impulse(queries)


## Builds shape queries around the hand bones for unarmed attacks.
func _gather_hand_queries() -> Array[Dictionary]:
	var queries: Array[Dictionary] = []
	for hand_name in ["LeftHand", "RightHand"]:
		var bone_index: int = player.skeleton.find_bone(hand_name)
		if bone_index == -1:
			continue
		var bone_pose: Transform3D = player.skeleton.get_bone_global_pose(bone_index)
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = HAND_HIT_RADIUS
		query.shape = sphere
		query.transform = player.skeleton.global_transform * bone_pose
		query.collision_mask = 0xFFFFFFFF
		var hit_color: Color = debug_left_hand_hit_color if hand_name == "LeftHand" else debug_right_hand_hit_color
		queries.append({ "query": query, "color": hit_color })
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
				queries.append({ "query": query, "color": debug_weapon_hit_color })
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

			if impulse_applied or not collider.has_method("apply_impulse"):
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
