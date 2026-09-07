class_name Bow
extends Equipment
## Fires arrows and plays draw/fire feedback from the Player's archery locomotion nodes.
##
## Every shot takes one arrow ([AmmoItem] for [constant Equipment.EquipmentType.BOW]) from the Player's inventory:
## the kind Use selected while any is carried, else regular arrows, and with none carried nothing flies. An arrow
## with its own [member AmmoItem.projectile_scene] flies as that scene, the rest as [member arrow_scene].
## Expects a template [Arrow] child named "Arrow" and optional "BowDrawArrow"/"BowFireArrow"
## audio players. Only the equipped copy on the Player's multiplayer authority (with [member player] set) reacts;
## peers get the arrow through the [ProjectileSpawner].

signal ammo_selected(ammo: AmmoItem) ## Emitted when Use on an [AmmoItem] for the bow picks the arrows it fires.

const RAY_MISS_DISTANCE: float = 40.0 ## Aim point distance when the projectile ray hits nothing.

@export var arrow_scene: PackedScene ## Fired arrow scene; falls back to duplicating the template "Arrow" child when empty.

var selected_ammo: AmmoItem ## The arrows Use picked; null fires the plain kind.

@onready var arrow_node: Arrow = get_node_or_null("Arrow") as Arrow ## Template duplicated for every shot.
@onready var draw_sfx: AudioStreamPlayer3D = get_node_or_null("BowDrawArrow") as AudioStreamPlayer3D
@onready var fire_sfx: AudioStreamPlayer3D = get_node_or_null("BowFireArrow") as AudioStreamPlayer3D


func _ready() -> void:
	if player and player.is_multiplayer_authority():
		player.locomotion_node_changed.connect(_on_locomotion_node_changed)
		player.inventory.item_used.connect(_on_item_used)


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
			if fire_arrow():
				if fire_sfx:
					fire_sfx.play()
				player.controls.rumble(0.4, 0.0, 0.5)


## Use on an [AmmoItem] for the bow selects it; the next shots take that kind while any is carried.
func _on_item_used(item: Item, _count: int) -> void:
	var ammo: AmmoItem = item as AmmoItem
	if ammo == null or ammo.weapon_type != equipment_type:
		return
	selected_ammo = ammo
	ammo_selected.emit(ammo)


## The arrows the next shot takes: [member selected_ammo] while some is carried, else regular arrows, else null.
func get_ammo() -> AmmoItem:
	return AmmoItem.pick(player.inventory, equipment_type, selected_ammo) if player else null


## Takes one arrow of the kind [method get_ammo] names from the inventory and fires it at the projectile ray's hit
## point: its own scene, else [member arrow_scene], through the world's [ProjectileSpawner] when present
## (multiplayer), otherwise a local copy. False, and nothing flies, with no arrows carried or off the authority.
func fire_arrow() -> bool:
	var ammo: AmmoItem = get_ammo()
	var scene: PackedScene = (ammo.projectile_scene if ammo.projectile_scene else arrow_scene) if ammo else null
	if ammo == null or (scene == null and arrow_node == null) or not player.is_multiplayer_authority() \
			or player.inventory.remove_item(ammo, 1) == 0:
		return false
	var origin: Node3D = arrow_node if arrow_node else self
	player.projectile_raycast.force_raycast_update()
	var target_position: Vector3 = player.projectile_raycast.get_collision_point() if player.projectile_raycast.is_colliding() \
			else player.projectile_raycast.global_position - player.projectile_raycast.global_basis.z * RAY_MISS_DISTANCE
	var direction: Vector3 = scatter(target_position - origin.global_position)
	var spawner: ProjectileSpawner = get_tree().get_first_node_in_group(&"ProjectileSpawner") as ProjectileSpawner
	if scene and spawner:
		spawner.fire(scene, origin.global_transform, direction, projectile_speed, player, self)
		return true
	var arrow: Projectile = scene.instantiate() as Projectile if scene else arrow_node.duplicate() as Projectile
	arrow.is_template = false
	var world: Node = get_tree().current_scene if get_tree().current_scene else player.get_parent()
	world.add_child(arrow)
	arrow.show()
	for shape: Node in arrow.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = false
	if not arrow.body_entered.is_connected(arrow._on_body_entered):
		arrow.body_entered.connect(arrow._on_body_entered)
	arrow.launch(origin.global_transform, direction, projectile_speed, player, self)
	if arrow is Arrow:
		arrow.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
	var swish: AudioStreamPlayer3D = arrow.get_node_or_null("Swish") as AudioStreamPlayer3D
	if swish:
		swish.play()
	return true
