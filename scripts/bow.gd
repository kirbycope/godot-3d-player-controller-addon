class_name Bow
extends Equipment
## Fires arrows and plays draw/fire feedback from the Player's archery locomotion nodes.
##
## Expects a template [Arrow] child named "Arrow" and optional "BowDrawArrow"/"BowFireArrow"
## audio players. Only the equipped copy (with [member player] set) reacts.

const RAY_MISS_DISTANCE: float = 40.0 ## Aim point distance when the projectile ray hits nothing.

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
	var rumble: bool = player.controls.current_input_type not in [player.controls.InputType.KEYBOARD_MOUSE, player.controls.InputType.TOUCH]
	match state_path:
		"Bow/BowDrawArrow":
			if draw_sfx:
				draw_sfx.play()
			if rumble:
				Input.start_joy_vibration(0, 0.0, 0.2, 0.5)
		"Bow/BowFireArrow":
			fire_arrow()
			if fire_sfx:
				fire_sfx.play()
			if rumble:
				Input.start_joy_vibration(0, 0.4, 0.0, 0.5)


## Spawns a copy of the template arrow and launches it at the projectile ray's hit point.
func fire_arrow() -> void:
	if arrow_node == null:
		return
	var arrow: Arrow = arrow_node.duplicate() as Arrow
	arrow.is_template = false
	arrow.shooter = player
	var world: Node = get_tree().current_scene if get_tree().current_scene else player.get_parent()
	world.add_child(arrow)
	arrow.global_transform = arrow_node.global_transform
	arrow.show()

	player.projectile_raycast.force_raycast_update()
	var target_position: Vector3 = player.projectile_raycast.get_collision_point() if player.projectile_raycast.is_colliding() \
			else player.projectile_raycast.global_position - player.projectile_raycast.global_basis.z * RAY_MISS_DISTANCE
	if arrow.global_position.distance_to(target_position) > 0.1:
		arrow.look_at(target_position, player.up_direction)
		arrow.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
	arrow.linear_velocity = (target_position - arrow.global_position).normalized() * projectile_speed
	var swish: AudioStreamPlayer3D = arrow.get_node_or_null("Swish") as AudioStreamPlayer3D
	if swish:
		swish.play()
