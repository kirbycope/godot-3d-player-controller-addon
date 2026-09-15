class_name VisionCone
extends Node3D
## What a guard can see: a cone [member range_metres] long and [member angle_degrees] wide from the eyes, checked
## against every Player each physics frame with a line-of-sight ray. A Player in it fills [member suspicion] over
## [member detect_seconds] (a crouched one only within [member crouch_range_factor] of the range, a stealthed one
## never); full, the [member enemy] hunts them and [signal spotted] fires, with every enemy in [member alert_group]
## set on them too. Out of sight for [member lose_seconds] the hunt is called off ([method EnemyNpc.lose_target])
## and [signal lost] fires. [member show_cone] draws the cone, clear to red with the suspicion, for the player to read.

signal spotted(player: Player)
signal lost(player: Player)
signal suspicion_changed(value: float)

@export var enemy: EnemyNpc ## Whose eyes these are; the parent when empty.
@export var range_metres: float = 12.0
@export var angle_degrees: float = 70.0 ## The whole cone, edge to edge.
@export var eye_height: float = 1.6
@export var detect_seconds: float = 1.0 ## Seconds in plain view before the hunt starts.
@export var lose_seconds: float = 4.0 ## Seconds out of sight before a hunt is called off.
@export var crouch_range_factor: float = 0.5 ## A crouched Player is seen only this fraction of the range away.
@export var alert_group: StringName = &"" ## Enemies in this group are set on the Player as well when spotted.
@export var show_cone: bool = true ## Draw the cone on the ground.

var suspicion: float = 0.0:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if value == suspicion: # an approximate test would stall a hair under full and never spot anyone
			return
		suspicion = value
		suspicion_changed.emit(suspicion)
		_tint()
var watching: Player = null ## The Player in view this frame, if any.

var _cone: MeshInstance3D
var _material: StandardMaterial3D
var _unseen: float = 0.0


func _ready() -> void:
	if enemy == null:
		enemy = get_parent() as EnemyNpc
	if show_cone:
		_build_cone()


func _physics_process(delta: float) -> void:
	if enemy == null or enemy.is_dead:
		if _cone:
			_cone.visible = false
		return
	watching = null
	for node: Node in get_tree().get_nodes_in_group(&"Player"):
		var player: Player = node as Player
		if player and can_see(player):
			watching = player
			break
	if watching:
		suspicion += delta / maxf(detect_seconds, 0.01)
		_unseen = 0.0
		if suspicion >= 1.0 and enemy.target != watching:
			enemy.aggro(watching)
			spotted.emit(watching)
			if not alert_group.is_empty():
				for other: Node in get_tree().get_nodes_in_group(alert_group):
					if other is EnemyNpc and other != enemy:
						(other as EnemyNpc).aggro(watching)
	else:
		suspicion -= delta / maxf(lose_seconds, 0.01)
		if enemy.target is Player:
			_unseen += delta
			if _unseen >= lose_seconds:
				var was: Player = enemy.target as Player
				enemy.lose_target()
				_unseen = 0.0
				lost.emit(was)
	_tint()


## Whether [param player] stands in the cone, in the open, with nothing between: crouched shortens the range,
## stealth hides outright.
func can_see(player: Player) -> bool:
	if player.is_stealthed or not player.health.is_alive():
		return false
	var eyes: Vector3 = enemy.global_position + enemy.up_direction * eye_height
	var to_player: Vector3 = Focus.get_focus_target_position(player) - eyes
	var reach: float = range_metres * (crouch_range_factor if player.is_crouching else 1.0)
	if to_player.length() > reach:
		return false
	var forward: Vector3 = -enemy.global_basis.z.slide(enemy.up_direction).normalized()
	if forward.angle_to(to_player.slide(enemy.up_direction)) > deg_to_rad(angle_degrees * 0.5):
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eyes, eyes + to_player)
	query.exclude = [enemy.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == player or player.is_ancestor_of(hit["collider"])


func _build_cone() -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = range_metres * tan(deg_to_rad(angle_degrees * 0.5))
	mesh.height = range_metres
	mesh.radial_segments = 24
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(1.0, 1.0, 1.0, 0.07)
	mesh.material = _material
	_cone = MeshInstance3D.new()
	_cone.mesh = mesh
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Apex at the eyes, the base out along the enemy's forward (-Z); the mesh's +Y end (the apex) turns to +Z
	_cone.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	_cone.position = Vector3(0.0, 0.06, -range_metres * 0.5)
	_cone.scale = Vector3(1.0, 1.0, 0.02) # flattened onto the ground: a fan, not a searchlight
	add_child(_cone)
	_tint()


func _tint() -> void:
	if _material == null:
		return
	var hunting: bool = enemy and enemy.target is Player
	var colour: Color = Color(1.0, 0.25, 0.1, 0.22) if hunting else Color(1.0, 1.0, 1.0, 0.07).lerp(Color(1.0, 0.8, 0.1, 0.2), suspicion)
	_material.albedo_color = colour
	if _cone:
		_cone.visible = show_cone
