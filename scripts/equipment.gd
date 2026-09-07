class_name Equipment
extends Node3D
## A pick-up-able item attached to a Player skeleton bone when equipped.
##
## In the world it is a GTA-style pickup: a child [Area3D] named "PlayerDetection" (its body_entered wired to
## [method _on_player_detection_body_entered] in the scene) equips a copy on the first Player to walk over it and
## then stops monitoring, so each pickup is taken once with no prompt or button.
##
## Melee weapons that should register hits need a child [Area3D] named "Hitbox"; [HitDetection]
## enables its monitoring during attack swings.

enum EquipmentType {
	AXE_1H,
	AXE_2H,
	BOW,
	DAGGER,
	FISHING_ROD,
	PISTOL,
	RIFLE,
	STAFF,
	SWORD_1H,
	SWORD_2H,
	SWORD_AND_SHIELD,
}

@export var bone_attachment_bone_name: String ## The name of the bone on the player's skeleton to which this equipment will be attached when equipped. (e.g. "RightHand", "LeftHand", etc.)
@export var can_attack: bool = false ## Does this equipment have an attack/melee action that the player can perform?
@export var can_log: bool = false ## Can this equipment chop down trees? (See [Choppable].)
@export var can_mine: bool = false ## Can this equipment mine ore? (See [Mineable].)
@export var can_shoot: bool = false ## Does this equipment have a shooting/ranged action that the player can perform?
@export var display_name: String = "" ## Name displayed in the UI. If empty, falls back to equipment type name.
@export_multiline var description: String = "" ## Flavour text under the name in the inventory.
@export var model_scene: PackedScene ## A 3D model the inventory shows turning in place of the icon; empty keeps the icon.
@export var equipment_type: EquipmentType ## The type of equipment (e.g. AXE_1H, BOW, RIFLE, etc.)
@export var icon: Texture2D ## Icon to display in the UI for this equipment
@export var is_exclusive: bool = false ## Is this equipment exclusive, meaning it cannot be equipped with other equipment types simultaneously?
@export var is_throwable: bool = false ## Can this equipment be thrown?
@export var projectile_speed: float = 50.0 ## meters/second (Arrows, Bullets, etc.)
@export var accuracy: Accuracy ## Spread cone for ranged equipment, shrinking with the Player's [code]skill_level[/code]; empty fires dead straight.
@export var position_offset: Vector3: ## Positional offset applied to the equipment when attached to the player.
	set(val):
		position_offset = val
		_update_attachment_offsets()
@export var rotation_offset_degrees: Vector3: ## Rotational offset in degrees applied to the equipment when attached to the player.
	set(val):
		rotation_offset_degrees = val
		_update_attachment_offsets()
@export var scale_offset: Vector3 = Vector3.ONE: ## Scale offset applied to the equipment when attached to the player.
	set(val):
		scale_offset = val
		_update_attachment_offsets()

var equipment_instance: Equipment ## The equipped copy of this item, once [method equip] has run.
var player: Player

@onready var player_detection: Area3D = get_node_or_null("PlayerDetection") as Area3D ## The walk-over pickup volume, on world copies.


## Extra lines the inventory prints under [member description]; a rod says what bait is on the line. Empty by default.
func get_details() -> String:
	return ""


func _update_attachment_offsets() -> void:
	if not is_inside_tree() or equipment_instance == null:
		return
	equipment_instance.position = position_offset
	equipment_instance.rotation_degrees = rotation_offset_degrees
	equipment_instance.scale = scale_offset


## Wired to PlayerDetection.body_entered: the Player that walked over the pickup takes it, and the pickup is spent.
## A Player who just dropped it (the inventory marks the pickup "dropped_by") has to step away first.
func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is Player and body.is_multiplayer_authority() and not (has_meta("dropped_by") and get_meta("dropped_by") == body) and equip(body):
		player_detection.set_deferred(&"monitoring", false)


## Equips this item on [param target_player]: the inventory duplicates it onto a new [BoneAttachment3D] on the
## skeleton ([method Inventory.equip_pickup]) and this pickup remembers the copy as [member equipment_instance].
## False when the Player already carries one of this type on this bone, or the item cannot be worn.
func equip(target_player: Player) -> bool:
	if target_player == null:
		return false
	var copy: Equipment = target_player.inventory.equip_pickup(self)
	if copy == null:
		return false
	equipment_instance = copy
	return true


## [param direction] pushed off its line by [member accuracy] for the Player's skill; straight without one.
func scatter(direction: Vector3) -> Vector3:
	return accuracy.scatter(direction, player.skill_level) if accuracy and player else direction.normalized()
