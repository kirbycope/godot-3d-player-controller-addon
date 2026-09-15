class_name Flashlight
extends SpotLight3D
## A torch in the Player's hand, pointed where the camera looks: sit it under the CameraMount. [member action]
## turns it on and off, it runs on [member battery] (seconds of light) that drains while on and refills from a
## battery item (the game adds to [member battery] on use), and anything in [member freezes_group] caught in the
## beam stands still while lit ([member EnemyNpc.movement_scale] 0), the way a thing that only moves in the dark
## does. [signal toggled] and [signal battery_changed] are for the HUD.

signal toggled(on: bool)
signal battery_changed(seconds_left: float, capacity: float)
signal went_dark ## The battery ran out with the light on.

@export var player: Player ## Whose torch; the CameraMount's Player when empty.
@export var action: StringName = &"flashlight"
@export var capacity: float = 90.0 ## Seconds of light on a full battery.
@export var battery: float = 90.0: ## Seconds of light left.
	set(value):
		battery = clampf(value, 0.0, capacity)
		battery_changed.emit(battery, capacity)
@export var freezes_group: StringName = &"Stalkers" ## Enemies in this group stand still while the beam is on them.
@export var freeze_range: float = 14.0
@export var starts_on: bool = false

var is_on: bool = false:
	set(value):
		is_on = value and battery > 0.0
		visible = is_on
		toggled.emit(is_on)

var _frozen: Array[EnemyNpc] = []


func _ready() -> void:
	if player == null:
		player = get_parent().get_parent() as Player if get_parent() else null
	is_on = starts_on


func _input(event: InputEvent) -> void:
	if player and not player.is_paused and not player.is_typing and InputMap.has_action(action) and event.is_action_pressed(action) and not event.is_echo():
		is_on = not is_on
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if is_on:
		battery -= delta
		if battery <= 0.0:
			is_on = false
			went_dark.emit()
	_freeze_lit()


## Whether [param target] stands in the beam: within [member freeze_range], inside the cone, with nothing between.
func lights(target: Node3D) -> bool:
	if not is_on or not is_instance_valid(target):
		return false
	var to_target: Vector3 = Focus.get_focus_target_position(target) - global_position
	if to_target.length() > freeze_range:
		return false
	if (-global_basis.z).angle_to(to_target) > deg_to_rad(spot_angle):
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, global_position + to_target)
	if player:
		query.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == target or target.is_ancestor_of(hit["collider"])


func _freeze_lit() -> void:
	var lit: Array[EnemyNpc] = []
	if not freezes_group.is_empty():
		for node: Node in get_tree().get_nodes_in_group(freezes_group):
			if node is EnemyNpc and not (node as EnemyNpc).is_dead and lights(node):
				lit.append(node)
	for enemy: EnemyNpc in _frozen:
		if is_instance_valid(enemy) and not lit.has(enemy):
			enemy.movement_scale = 1.0
	for enemy: EnemyNpc in lit:
		enemy.movement_scale = 0.0
	_frozen = lit
