class_name Bow
extends Equipment
## Fires arrows and plays draw/fire feedback from the Player's archery locomotion nodes.
##
## Expects a template [Arrow] child named "Arrow" and optional "BowDrawArrow"/"BowFireArrow"
## audio players. Only the equipped copy (with [member player] set) reacts.

const RAY_MISS_DISTANCE: float = 40.0 ## Aim point distance when the projectile ray hits nothing.

@export var arrow_scene: PackedScene ## Fired arrow scene; falls back to duplicating the template "Arrow" child when empty.

@onready var arrow_node: Arrow = get_node_or_null("Arrow") as Arrow ## Template duplicated for every shot.
@onready var draw_sfx: AudioStreamPlayer3D = get_node_or_null("BowDrawArrow") as AudioStreamPlayer3D
@onready var fire_sfx: AudioStreamPlayer3D = get_node_or_null("BowFireArrow") as AudioStreamPlayer3D


func _ready() -> void:
	if player and player.is_multiplayer_authority():
		player.locomotion_node_changed.connect(_on_locomotion_node_changed)


func _on_locomotion_node_changed(state_path: String) -> void:
	if not player.inventory.equipment.has(self) or player.held_object.is_holding_object() or player.is_throwing:
		return
	var is_aiming: bool = state_path == "Bow/ArcheryLocomotion"
	player.set_look_at_target(player.look_at_target if is_aiming else null)
	if arrow_node:
		arrow_node.visible = is_aiming
	match state_path:
		"Bow/BowDrawArrow":
			if draw_sfx:
				draw_sfx.play()
			player.controls.rumble(0.0, 0.2, 0.5)
		"Bow/BowFireArrow":
			fire_arrow()
			if fire_sfx:
				fire_sfx.play()
			player.controls.rumble(0.4, 0.0, 0.5)


## Fires an arrow at the projectile ray's hit point: [member arrow_scene] through the world's
## [ProjectileSpawner] when present (multiplayer), otherwise a local copy of the template arrow.
func fire_arrow() -> void:
	if arrow_node == null and arrow_scene == null:
		return
	var origin: Node3D = arrow_node if arrow_node else self
	player.projectile_raycast.force_raycast_update()
	var target_position: Vector3 = player.projectile_raycast.get_collision_point() if player.projectile_raycast.is_colliding() 			else player.projectile_raycast.global_position - player.projectile_raycast.global_basis.z * RAY_MISS_DISTANCE
	var direction: Vector3 = (target_position - origin.global_position).normalized()
	var spawner: ProjectileSpawner = get_tree().get_first_node_in_group(&"ProjectileSpawner") as ProjectileSpawner
	if arrow_scene and spawner:
		spawner.fire(arrow_scene, origin.global_transform, direction, projectile_speed, player, self)
		return
	var arrow: Arrow = arrow_scene.instantiate() if arrow_scene else arrow_node.duplicate() as Arrow
	arrow.is_template = false
	var world: Node = get_tree().current_scene if get_tree().current_scene else player.get_parent()
	world.add_child(arrow)
	arrow.show()
	for shape: Node in arrow.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = false
	if not arrow.body_entered.is_connected(arrow._on_body_entered):
		arrow.body_entered.connect(arrow._on_body_entered)
	arrow.launch(origin.global_transform, direction, projectile_speed, player, self)
	arrow.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
	var swish: AudioStreamPlayer3D = arrow.get_node_or_null("Swish") as AudioStreamPlayer3D
	if swish:
		swish.play()
