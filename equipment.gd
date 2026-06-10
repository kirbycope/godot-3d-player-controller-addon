extends Node3D

enum EquipmentType {
	AXE_1H,
	AXE_2H,
	BOW,
	DAGGER,
	PISTOL,
	RIFLE,
	STAFF,
	SWORD_1H,
	SWORD_2H,
	SWORD_AND_SHIELD,
}

@export var bone_attachment_bone_name: String
@export var can_shoot: bool = false
@export var equipment_type: EquipmentType
@export var is_exclusive: bool = false
@export var is_throwable: bool = false
@export var projectile_speed: float = 50.0 ## meters/second (Arrows, Bullets, etc.)
@export var position_offset: Vector3:
	set(val):
		position_offset = val
		_update_attachment_offsets()
@export var rotation_offset_degrees: Vector3:
	set(val):
		rotation_offset_degrees = val
		_update_attachment_offsets()
@export var scale_offset: Vector3 = Vector3.ONE:
	set(val):
		scale_offset = val
		_update_attachment_offsets()

var equipment_instance: Node3D
var menu_displayed: bool = false
var player: Player

@onready var action_prompt: Node3D = $ActionPrompt


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


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


func display_menu(_player: Player) -> void:
	if action_prompt:
		action_prompt.show()
	menu_displayed = true


func equip(player: Player) -> void:
	hide_menu()

	if not bone_attachment_bone_name or not player:
		return

	# 1. Find the Skeleton3D on the player (adjust the node path if needed)
	var skeleton: Skeleton3D = player.get_node_or_null("PlayerModel/Armature/GeneralSkeleton") 
	if not skeleton:
		push_error("Skeleton3D not found on player!")
		return

	# 2. Handle existing and conflicting attachments
	for child in skeleton.get_children():
		if child is BoneAttachment3D:
			var is_exclusive_attachment := false
			for sub_child in child.get_children():
				if "is_exclusive" in sub_child and sub_child.is_exclusive:
					is_exclusive_attachment = true
					break

			# Remove any existing attachment on this specific bone,
			# OR unequip all other equipment types if equipping an exclusive/two-handed weapon,
			# OR unequip exclusive/two-handed weapons if equipping any new item.
			if child.bone_name == bone_attachment_bone_name or is_exclusive or is_exclusive_attachment:
				for sub_child in child.get_children():
					if "equipment_type" in sub_child:
						_set_equipped_flag(player, sub_child.equipment_type, false)
						if player.equipment.has(sub_child):
							player.equipment.erase(sub_child)
				skeleton.remove_child(child)
				child.queue_free() # Clean it up from memory

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

	# 5. Flag the player as having equipped the item
	_set_equipped_flag(player, equipment_type, true)

	# 6. Add a reference to this equipment to the player
	if not player.equipment.has(equipment_instance):
		player.equipment.append(equipment_instance)


func _set_equipped_flag(player: Player, type: EquipmentType, state: bool) -> void:
	if type == EquipmentType.AXE_1H:
		player.equipped_axe_1h = state
	elif type == EquipmentType.AXE_2H:
		player.equipped_axe_2h = state
	elif type == EquipmentType.BOW:
		player.equipped_bow = state
	elif type == EquipmentType.DAGGER:
		player.equipped_dagger = state
	elif type == EquipmentType.PISTOL:
		player.equipped_pistol = state
	elif type == EquipmentType.RIFLE:
		player.equipped_rifle = state
	elif type == EquipmentType.STAFF:
		player.equipped_staff = state
	elif type == EquipmentType.SWORD_AND_SHIELD:
		player.equipped_shield = state
	elif type == EquipmentType.SWORD_1H:
		player.equipped_sword_1h = state
	elif type == EquipmentType.SWORD_2H:
		player.equipped_sword_2h = state


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
