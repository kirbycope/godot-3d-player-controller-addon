class_name Equipment
extends Node3D

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

var equipment_instance: Node3D
var menu_displayed: bool = false
var player: Player

@onready var action_prompt: Node3D = get_node_or_null("ActionPrompt")


func _update_attachment_offsets() -> void:
	if not is_inside_tree():
		return
	if equipment_instance:
		equipment_instance.position = position_offset
		equipment_instance.rotation = Vector3(
			deg_to_rad(rotation_offset_degrees.x),
			deg_to_rad(rotation_offset_degrees.y),
			deg_to_rad(rotation_offset_degrees.z)
		)
		equipment_instance.scale = scale_offset


func display_menu(player: Player) -> void:
	if player.inventory and player.inventory.has_equipment_in_backpack(equipment_type, bone_attachment_bone_name):
		return

	if action_prompt:
		action_prompt.show()
		action_prompt.get_node("KeyboardMouse").hide()
		action_prompt.get_node("Microsoft").hide()
		action_prompt.get_node("Nintendo").hide()
		action_prompt.get_node("Sony").hide()
		if player.controls.current_input_type == player.controls.InputType.KEYBOARD_MOUSE:
			action_prompt.get_node("KeyboardMouse").show()
		elif player.controls.current_input_type == player.controls.InputType.MICROSOFT:
			action_prompt.get_node("Microsoft").show()
		elif player.controls.current_input_type == player.controls.InputType.NINTENDO:
			action_prompt.get_node("Nintendo").show()
		elif player.controls.current_input_type == player.controls.InputType.SONY:
			action_prompt.get_node("Sony").show()
	menu_displayed = true


func equip(player: Player) -> void:
	hide_menu()

	if not bone_attachment_bone_name or not player:
		return
	if not player.inventory:
		push_error("Inventory not found on player!")
		return

	if player.inventory.has_equipment_in_backpack(equipment_type, bone_attachment_bone_name):
		return

	# 1. Find the Skeleton3D on the player (adjust the node path if needed)
	var skeleton: Skeleton3D = player.get_node_or_null("PlayerModel/Armature/GeneralSkeleton")
	if not skeleton:
		push_error("Skeleton3D not found on player!")
		return

	# 2. Handle existing and conflicting attachments
	for child in skeleton.get_children():
		if child is BoneAttachment3D:
			var is_equipment_attachment: bool = false
			var is_exclusive_attachment: bool = false
			for sub_child in child.get_children():
				if "equipment_type" in sub_child:
					is_equipment_attachment = true
				if "is_exclusive" in sub_child and sub_child.is_exclusive:
					is_exclusive_attachment = true
					break

			# Ignore built-in bone attachments (e.g. paraglider/camera anchors)
			# that do not currently hold equipped items.
			if not is_equipment_attachment:
				continue

			# Remove any existing attachment on this specific bone,
			# OR unequip all other equipment types if equipping an exclusive/two-handed weapon,
			# OR unequip exclusive/two-handed weapons if equipping any new item.
			if child.bone_name == bone_attachment_bone_name or is_exclusive or is_exclusive_attachment:
				for sub_child in child.get_children():
					if "equipment_type" in sub_child:
						player.inventory.remove_equipment(sub_child)
				skeleton.remove_child(child)
				player.inventory.add_child(child)
				child.hide()

	# 3. Create a new BoneAttachment3D and configure it
	var new_attachment = BoneAttachment3D.new()
	new_attachment.bone_name = bone_attachment_bone_name
	skeleton.add_child(new_attachment)

	# 4. Duplicate this weapon and add it to the attachment
	equipment_instance = duplicate()
	equipment_instance.player = player
	new_attachment.add_child(equipment_instance)
	_disable_collisions(equipment_instance)
	_update_attachment_offsets()
	_configure_animation_trees(equipment_instance, equipment_instance)

	# 5. Add a reference to this equipment to the player
	player.inventory.add_equipment(equipment_instance)


func _disable_collisions(node: Node) -> void:
	if node is CollisionShape3D:
		node.disabled = true
	for child in node.get_children():
		_disable_collisions(child)


func _configure_animation_trees(node: Node, base_node: Node) -> void:
	if node is AnimationTree:
		node.active = true
		node.advance_expression_base_node = node.get_path_to(base_node)
	for child in node.get_children():
		_configure_animation_trees(child, base_node)


func hide_menu() -> void:
	if action_prompt:
		action_prompt.hide()
	menu_displayed = false
