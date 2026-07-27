class_name Inventory
extends CanvasLayer

var equipment: Array = []
var equipment_by_type: Dictionary = {}
var can_player_attack: bool = false ## Does the currently equipped item allow the Player to attack?
var can_player_shoot: bool = false ## Does the currently equipped item allow the Player to shoot?
@export var player: Player


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
	can_player_attack = false
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

	player.locomotion_state.travel("StandingLocomotion")


func rebuild_equipment_cache() -> void:
	equipment_by_type.clear()
	can_player_attack = false
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


func has_any_equipment(types: Array) -> bool:
	for type in types:
		if equipment_by_type.has(type):
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
