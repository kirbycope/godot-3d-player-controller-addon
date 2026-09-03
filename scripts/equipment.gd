class_name Equipment
extends Node3D
## A pick-up-able item attached to a Player skeleton bone when equipped.
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
@export var equipment_type: EquipmentType ## The type of equipment (e.g. AXE_1H, BOW, RIFLE, etc.)
@export var icon: Texture2D ## Icon to display in the UI for this equipment
@export var is_exclusive: bool = false ## Is this equipment exclusive, meaning it cannot be equipped with other equipment types simultaneously?
@export var is_throwable: bool = false ## Can this equipment be thrown?
@export var projectile_speed: float = 50.0 ## meters/second (Arrows, Bullets, etc.)
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
var menu_displayed: bool = false
var player: Player

@onready var action_prompt: Node3D = get_node_or_null("ActionPrompt") as Node3D


func _update_attachment_offsets() -> void:
	if not is_inside_tree() or equipment_instance == null:
		return
	equipment_instance.position = position_offset
	equipment_instance.rotation_degrees = rotation_offset_degrees
	equipment_instance.scale = scale_offset


func display_menu(target_player: Player) -> void:
	if target_player.inventory.has_equipment_in_backpack(equipment_type, bone_attachment_bone_name):
		return

	# The prompt scene is project-side (scenes/action_prompt.gd), so this stays duck typed.
	if action_prompt and action_prompt.has_method("show_for"):
		action_prompt.call("show_for", target_player)
	menu_displayed = true


## Duplicates this item onto a new [BoneAttachment3D] on the player's skeleton and registers it with the inventory.
func equip(target_player: Player) -> void:
	hide_menu()
	if target_player == null or bone_attachment_bone_name.is_empty() \
			or target_player.inventory.has_equipment_in_backpack(equipment_type, bone_attachment_bone_name):
		return

	target_player.inventory.stow_conflicting(bone_attachment_bone_name, is_exclusive)

	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.bone_name = bone_attachment_bone_name
	target_player.skeleton.add_child(attachment)

	equipment_instance = duplicate() as Equipment
	equipment_instance.player = target_player
	attachment.add_child(equipment_instance)
	# Disable world collision but keep the "Hitbox" shapes so HitDetection can monitor them.
	for shape: Node in equipment_instance.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = shape.get_parent().name != "Hitbox"
	for tree: Node in equipment_instance.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = true
		(tree as AnimationTree).advance_expression_base_node = tree.get_path_to(equipment_instance)
	_update_attachment_offsets()

	target_player.inventory.add_equipment(equipment_instance)


func hide_menu() -> void:
	if action_prompt:
		action_prompt.hide()
	menu_displayed = false
