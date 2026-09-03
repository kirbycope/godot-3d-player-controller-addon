class_name Inventory
extends CanvasLayer
## Tracks the [Equipment] attached to the Player's skeleton and the stowed "backpack" attachments.
##
## Each [BoneAttachment3D] holds exactly one [Equipment]; stowed attachments live hidden under
## this node until re-equipped. Tapping next/last weapon cycles; holding opens the [RadialMenu].

signal equipment_changed ## Emitted after the set of equipped items changes.

@export var player: Player

var equipment: Array[Equipment] = [] ## Items currently attached to the skeleton.
var equipment_by_type: Dictionary[Equipment.EquipmentType, Equipment] = {}
var can_player_attack: bool = true ## Does the currently equipped item allow the Player to attack?
var can_player_shoot: bool = false ## Does the currently equipped item allow the Player to shoot?
var custom_cycle_handler: Callable = Callable() ## Replaces weapon cycling (e.g. radio stations while driving).

@onready var radial_menu: RadialMenu = $RadialMenu
@onready var hold_timer: Timer = $HoldTimer ## Runs while next/last weapon is held; its timeout opens the radial menu.


func _ready() -> void:
	set_process_unhandled_input(is_multiplayer_authority())


func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.held_object.is_holding_object():
		hold_timer.stop()
		return

	if event.is_action_pressed("next_weapon") or event.is_action_pressed("last_weapon"):
		hold_timer.start()
	elif event.is_action_released("next_weapon") or event.is_action_released("last_weapon"):
		# A release while the timer still runs is a tap; a timeout already opened the radial menu.
		if hold_timer.is_stopped():
			return
		hold_timer.stop()
		cycle_weapon(1 if event.is_action_released("next_weapon") else -1)


## Equips the next (+1) or previous (-1) item; the slot before the first item is "unarmed".
func cycle_weapon(direction: int) -> void:
	if custom_cycle_handler.is_valid():
		custom_cycle_handler.call(direction)
		return

	var all_weapons: Array[Equipment] = get_all_weapons()
	if all_weapons.is_empty():
		return
	var current_index: int = -1
	for i: int in all_weapons.size():
		if equipment.has(all_weapons[i]):
			current_index = i
			break
	var new_index: int = posmod(current_index + 1 + direction, all_weapons.size() + 1) - 1
	if new_index == -1:
		unequip_all()
	else:
		equip_weapon(all_weapons[new_index])


func add_equipment(item: Equipment) -> void:
	if item == null or equipment.has(item):
		return
	equipment.append(item)
	rebuild_equipment_cache()


func remove_equipment(item: Equipment) -> void:
	if item == null or not equipment.has(item):
		return
	equipment.erase(item)
	rebuild_equipment_cache()


func rebuild_equipment_cache() -> void:
	equipment_by_type.clear()
	can_player_attack = equipment.is_empty()
	can_player_shoot = false
	for item: Equipment in equipment:
		equipment_by_type[item.equipment_type] = item
		can_player_attack = can_player_attack or item.can_attack
		can_player_shoot = can_player_shoot or item.can_shoot
	if player and player.controls:
		player.controls.reset_labels()
	equipment_changed.emit()


func set_equipment_visibility(is_visible: bool) -> void:
	for item: Equipment in equipment:
		item.visible = is_visible


func get_equipment_by_type(type: Equipment.EquipmentType) -> Equipment:
	return equipment_by_type.get(type)


func has_equipment(type: Equipment.EquipmentType) -> bool:
	return equipment_by_type.has(type)


## Returns true if the player has a firearm equipped (Pistol, Rifle).
func has_firearm_equipped() -> bool:
	return has_equipment(Equipment.EquipmentType.PISTOL) or has_equipment(Equipment.EquipmentType.RIFLE)


## Returns true if the player has a bow equipped.
func has_bow_equipped() -> bool:
	return has_equipment(Equipment.EquipmentType.BOW)


## True if an item of this type on this bone is already equipped or stowed.
func has_equipment_in_backpack(type: Equipment.EquipmentType, bone_name: String) -> bool:
	for item: Equipment in get_all_weapons():
		if item.equipment_type == type and item.bone_attachment_bone_name == bone_name:
			return true
	return false


func has_any_equipment(types: Array[Equipment.EquipmentType]) -> bool:
	for type: Equipment.EquipmentType in types:
		if equipment_by_type.has(type):
			return true
	return false


## True if any equipped item has the given boolean capability (e.g. &"can_log").
func has_equipment_with_capability(capability: StringName) -> bool:
	for item: Equipment in equipment:
		if item.get(capability):
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


## Equipped and stowed items, sorted by type then bone.
func get_all_weapons() -> Array[Equipment]:
	var all_weapons: Array[Equipment] = []
	all_weapons.assign(equipment)
	for child: Node in get_children():
		if child is BoneAttachment3D:
			all_weapons.append(child.get_child(0) as Equipment)
	all_weapons.sort_custom(func(a: Equipment, b: Equipment) -> bool:
		if a.equipment_type != b.equipment_type:
			return a.equipment_type < b.equipment_type
		return a.bone_attachment_bone_name < b.bone_attachment_bone_name
	)
	return all_weapons


func equip_weapon(target_item: Equipment) -> void:
	if equipment.has(target_item):
		return
	var attachment: BoneAttachment3D = target_item.get_parent() as BoneAttachment3D
	if attachment:
		equip_from_backpack(attachment)


## Moves a stowed attachment back onto the skeleton, stowing whatever conflicts with it.
func equip_from_backpack(attachment: BoneAttachment3D) -> void:
	var item: Equipment = attachment.get_child(0) as Equipment
	stow_conflicting(item.bone_attachment_bone_name, item.is_exclusive)
	attachment.reparent(player.skeleton, false)
	attachment.show()
	add_equipment(item)


## Stows every equipped item that conflicts with an incoming one: same bone, or either side exclusive.
func stow_conflicting(bone_name: String, is_exclusive: bool) -> void:
	for item: Equipment in equipment.duplicate():
		if item.bone_attachment_bone_name == bone_name or is_exclusive or item.is_exclusive:
			_stow_attachment(item.get_parent() as BoneAttachment3D)


func unequip_all() -> void:
	stow_conflicting("", true)


## Moves an equipped attachment (and its item) off the skeleton into the hidden backpack.
func _stow_attachment(attachment: BoneAttachment3D) -> void:
	remove_equipment(attachment.get_child(0) as Equipment)
	attachment.reparent(self, false)
	attachment.hide()
