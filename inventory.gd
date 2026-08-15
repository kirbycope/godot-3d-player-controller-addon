class_name Inventory
extends CanvasLayer

var equipment: Array = []
var equipment_by_type: Dictionary = {}
var can_player_attack: bool = true ## Does the currently equipped item allow the Player to attack?
var can_player_shoot: bool = false ## Does the currently equipped item allow the Player to shoot?
@export var player: Player


var _last_weapon_press_time: int = 0
var _last_weapon_press_pending: bool = false
var _next_weapon_press_time: int = 0
var _next_weapon_press_pending: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("next_weapon"):
		_next_weapon_press_time = Time.get_ticks_msec()
		_next_weapon_press_pending = true
	elif event.is_action_released("next_weapon"):
		if _next_weapon_press_pending:
			_next_weapon_press_pending = false
			var radial_menu = get_node_or_null("RadialMenu")
			if not radial_menu or not radial_menu.visible:
				cycle_weapon(1)
	elif event.is_action_pressed("last_weapon"):
		_last_weapon_press_time = Time.get_ticks_msec()
		_last_weapon_press_pending = true
	elif event.is_action_released("last_weapon"):
		if _last_weapon_press_pending:
			_last_weapon_press_pending = false
			var radial_menu = get_node_or_null("RadialMenu")
			if not radial_menu or not radial_menu.visible:
				cycle_weapon(-1)

func cycle_weapon(direction: int) -> void:
	var all_weapons = [null]
	all_weapons.append_array(get_all_weapons())
	if all_weapons.size() <= 1:
		return
	
	var current_index = 0
	for i in range(all_weapons.size()):
		var w = all_weapons[i]
		if w != null and equipment.has(w):
			current_index = i
			break
			
	var new_index = (current_index + direction + all_weapons.size()) % all_weapons.size()
	var new_weapon = all_weapons[new_index]
	if new_weapon == null:
		unequip_all()
	else:
		equip_weapon(new_weapon)

func add_equipment(item: Node3D) -> void:
	if item == null:
		return
	if not equipment.has(item):
		equipment.append(item)
	rebuild_equipment_cache()


func remove_equipment(item: Node) -> void:
	if item == null:
		return
	if equipment.has(item):
		equipment.erase(item)
	rebuild_equipment_cache()


func debug_unequip_all() -> void:
	equipment.clear()
	equipment_by_type.clear()
	can_player_attack = true
	can_player_shoot = false

	if not player:
		return

	for child in player.skeleton.get_children():
		if child is BoneAttachment3D:
			var has_equipment_child: bool = false
			for sub_child in child.get_children():
				if "equipment_type" in sub_child:
					has_equipment_child = true
					break
			if has_equipment_child:
				child.queue_free()

	player.locomotion_state.travel("StandingLocomotion") # Is this unnecessart? AnimationTree _should_ transition based on bool(s)


func rebuild_equipment_cache() -> void:
	equipment_by_type.clear()
	can_player_attack = is_unarmed()
	can_player_shoot = false

	for item in equipment:
		if item == null:
			continue
		if "equipment_type" in item:
			equipment_by_type[item.equipment_type] = item
		if "can_attack" in item and item.can_attack:
			can_player_attack = true
		if "can_shoot" in item and item.can_shoot:
			can_player_shoot = true


func set_equipment_visibility(is_visible: bool) -> void:
	for item in equipment:
		if item == null:
			continue
		if not is_instance_valid(item):
			continue
		if is_visible:
			item.show()
		else:
			item.hide()


func get_equipment_by_type(type: int) -> Node3D:
	return equipment_by_type.get(type, null)

func has_equipment(type: int) -> bool:
	return equipment_by_type.has(type)

func has_equipment_in_backpack(type: int, bone_name: String) -> bool:
	for item in get_all_weapons():
		if "equipment_type" in item and item.equipment_type == type:
			if "bone_attachment_bone_name" in item and item.bone_attachment_bone_name == bone_name:
				return true
	return false

func has_any_equipment(types: Array) -> bool:
	for type in types:
		if equipment_by_type.has(type):
			return true
	return false


func has_equipment_with_capability(capability: StringName) -> bool:
	for item in equipment:
		if is_instance_valid(item) and capability in item and item.get(capability):
			return true
	return false


func has_heavy_weapon_equipped() -> bool:
	return has_any_equipment([
		Equipment.EquipmentType.AXE_2H,
		Equipment.EquipmentType.FISHING_ROD,
		Equipment.EquipmentType.STAFF,
		Equipment.EquipmentType.SWORD_2H,
	])


func has_one_handed_or_shield_equipped() -> bool:
	return has_any_equipment([
		Equipment.EquipmentType.AXE_1H,
		Equipment.EquipmentType.DAGGER,
		Equipment.EquipmentType.SWORD_1H,
		Equipment.EquipmentType.SWORD_AND_SHIELD,
	])


func is_unarmed() -> bool:
	return equipment.is_empty()

func get_all_weapons() -> Array:
	var all = []
	for item in equipment:
		all.append(item)
	for child in get_children():
		if child is BoneAttachment3D:
			for sub_child in child.get_children():
				if "equipment_type" in sub_child:
					all.append(sub_child)
					break
					
	all.sort_custom(func(a, b):
		if a.equipment_type != b.equipment_type:
			return a.equipment_type < b.equipment_type
		return a.bone_attachment_bone_name < b.bone_attachment_bone_name
	)
	return all

func equip_weapon(target_item: Node3D) -> void:
	if equipment.has(target_item):
		return
	var attachment = target_item.get_parent()
	if attachment is BoneAttachment3D:
		equip_from_backpack(attachment)

func equip_from_backpack(attachment: BoneAttachment3D) -> void:
	var skeleton: Skeleton3D = player.get_node_or_null("PlayerModel/Armature/GeneralSkeleton")
	if not skeleton:
		return
	
	var is_new_exclusive = false
	var new_equipment = null
	for sub_child in attachment.get_children():
		if "equipment_type" in sub_child:
			new_equipment = sub_child
			if "is_exclusive" in sub_child and sub_child.is_exclusive:
				is_new_exclusive = true
			break
			
	for child in skeleton.get_children():
		if child is BoneAttachment3D:
			var is_equipment_attachment = false
			var is_exclusive_attachment = false
			for sub_child in child.get_children():
				if "equipment_type" in sub_child:
					is_equipment_attachment = true
				if "is_exclusive" in sub_child and sub_child.is_exclusive:
					is_exclusive_attachment = true
					break
			if not is_equipment_attachment:
				continue
				
			if child.bone_name == attachment.bone_name or is_new_exclusive or is_exclusive_attachment:
				for sub_child in child.get_children():
					if "equipment_type" in sub_child:
						remove_equipment(sub_child)
				skeleton.remove_child(child)
				add_child(child)
				child.hide()

	remove_child(attachment)
	skeleton.add_child(attachment)
	attachment.show()
	if new_equipment:
		add_equipment(new_equipment)

func unequip_all() -> void:
	var skeleton: Skeleton3D = player.get_node_or_null("PlayerModel/Armature/GeneralSkeleton")
	if not skeleton:
		return
		
	for child in skeleton.get_children():
		if child is BoneAttachment3D:
			var is_equipment_attachment = false
			for sub_child in child.get_children():
				if "equipment_type" in sub_child:
					is_equipment_attachment = true
					remove_equipment(sub_child)
			if is_equipment_attachment:
				skeleton.remove_child(child)
				add_child(child)
				child.hide()
