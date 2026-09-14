@icon("res://addons/3d_player_controller/inventory/assets/icons/materials.svg")
class_name Inventory
extends CanvasLayer
## Everything the Player carries.
##
## Equipment is the live [Equipment] attached to the Player's skeleton plus the stowed "backpack" attachments;
## each [BoneAttachment3D] holds exactly one [Equipment], stowed attachments live hidden under this node until
## re-equipped, tapping next/last weapon cycles and holding opens the [RadialMenu]. Everything else is stacks
## of [Item] in fixed-size tabs (materials, food, key items) that the [InventoryScreen] shows as a grid.
##
## Spells live here too: the child [Spellbook] holds the unlocked spells, the skill points and the wheel loadout,
## and is saved with the items. Equipment is capped at [member max_equipment] pieces, BOTW style.
##
## The inventory only signals when an item is used; the game applies the effect. With [member persist] on, the whole
## inventory is written to [member save_path] after every change and read back once the Player is ready.
##
## Over the network the equipment is the authority's alone; every other peer's copy of the Player rebuilds the same
## pieces from their scene paths ([method _sync_equipment]) so its stances read there, and a drop lands in every
## world under one name ([method _spawn_dropped]) so a later pickup vanishes everywhere. Items themselves never
## leave the owning peer.

signal equipment_changed ## Emitted after the set of equipped items changes.
signal items_changed ## Emitted after a stack is added, removed, moved, used or dropped.
signal item_used(item: Item, count: int) ## Use on a stack; consumables lose the count, the effect is the game's.
signal item_dropped(item: Item, count: int, pickup: Node3D) ## A stack (or part of one) is back in the world.

const ITEM_PICKUP_SCENE: PackedScene = preload("res://addons/3d_player_controller/inventory/scenes/item_pickup.tscn")
const ITEM_TABS: Array[Item.Category] = [Item.Category.MATERIALS, Item.Category.FOOD, Item.Category.KEY_ITEMS]

@export var player: Player
@export_range(1, 100) var slots_per_tab: int = 20 ## Slots on each item tab; the grid shows them all.
@export_range(1, 100) var max_equipment: int = 8 ## Weapons and tools carried at once, equipped and stowed together; more are refused.
@export var persist: bool = false ## Load [member save_path] on ready and write it after every change.
@export var save_path: String = "user://inventory.tres"
@export var next_weapon_action: StringName = &"next_weapon" ## Tap cycles forward; holding either opens the [RadialMenu].
@export var last_weapon_action: StringName = &"last_weapon" ## Tap cycles back.

static var persistence_enabled: bool = true ## Off, no inventory loads or saves whatever [member persist] says; the test suite's pre-run hook turns it off so tests never touch a real save.

var equipment: Array[Equipment] = [] ## Items currently attached to the skeleton.
var equipment_by_type: Dictionary[Equipment.EquipmentType, Equipment] = {}
var can_player_attack: bool = true ## Does the currently equipped item allow the Player to attack?
var can_player_shoot: bool = false ## Does the currently equipped item allow the Player to shoot?
var custom_cycle_handler: Callable = Callable() ## Replaces weapon cycling (e.g. radio stations while driving).
var _tabs: Dictionary[int, Array] = {} ## Category to its slots: [ItemSlot] or null per index.
var _loading: bool = false ## True while a save is applied, so the changes it makes are not written back.
var _save_queued: bool = false ## A write is waiting for the end of the frame, so a burst of changes costs one.
var _drop_counter: int = 0 ## Numbers this peer's drops, so every peer names the pickup the same.

@onready var radial_menu: RadialMenu = $RadialMenu
@onready var hold_timer: Timer = $HoldTimer ## Runs while next/last weapon is held; its timeout opens the radial menu.
@onready var spellbook: Spellbook = get_node_or_null("Spellbook") as Spellbook ## The spells; optional.


func _ready() -> void:
	set_process_unhandled_input(is_multiplayer_authority())
	for category: Item.Category in ITEM_TABS:
		_tabs[category] = _empty_tab()
	if not is_multiplayer_authority():
		return
	multiplayer.peer_connected.connect(_send_equipment)
	if persist and persistence_enabled:
		# The Player's skeleton and abilities are @onready, so a save applied before its ready has nowhere to go
		if player and not player.is_node_ready():
			player.ready.connect(load_save, CONNECT_ONE_SHOT)
		else:
			load_save()


func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.is_paused or player.is_typing or player.held_object.is_holding_object():
		hold_timer.stop()
		return

	if event.is_action_pressed(next_weapon_action) or event.is_action_pressed(last_weapon_action):
		hold_timer.start()
	elif event.is_action_released(next_weapon_action) or event.is_action_released(last_weapon_action):
		# A release while the timer still runs is a tap; a timeout already opened the radial menu.
		if hold_timer.is_stopped():
			return
		hold_timer.stop()
		cycle_weapon(1 if event.is_action_released(next_weapon_action) else -1)


# --- Items -----------------------------------------------------------------------------------------------------

## The slots of an item tab: [ItemSlot] or null per index, [member slots_per_tab] long. Not for equipment, see
## [method get_all_weapons].
func get_slots(category: Item.Category) -> Array:
	return _tabs.get(category, [])


## The stack at [param index] of [param category], or null.
func get_slot(category: Item.Category, index: int) -> ItemSlot:
	var slots: Array = get_slots(category)
	if index < 0 or index >= slots.size():
		return null
	return slots[index]


## Adds [param count] of [param item]: onto stacks of the same item first, then into empty slots. Equipment items
## are picked up through their [member Item.equipment_scene] instead. Returns how many did not fit.
func add_item(item: Item, count: int = 1) -> int:
	if item == null or count <= 0:
		return count
	if item.category == Item.Category.EQUIPMENT:
		return count if not _add_equipment_item(item) else 0
	var slots: Array = get_slots(item.category)
	var left: int = count
	for slot: ItemSlot in slots:
		if left == 0:
			break
		if slot and slot.item.is_same(item) and slot.count < item.max_stack:
			var room: int = item.max_stack - slot.count
			var taken: int = mini(room, left)
			slot.count += taken
			left -= taken
	for i: int in slots.size():
		if left == 0:
			break
		if slots[i] == null:
			var taken: int = mini(item.max_stack, left)
			slots[i] = ItemSlot.make(item, taken)
			left -= taken
	if left != count:
		_items_changed()
	return left


## Takes [param count] of [param item] from the stacks that hold it. Returns how many were taken.
func remove_item(item: Item, count: int = 1) -> int:
	if item == null or count <= 0:
		return 0
	var slots: Array = get_slots(item.category)
	var left: int = count
	for i: int in range(slots.size() - 1, -1, -1):
		if left == 0:
			break
		var slot: ItemSlot = slots[i]
		if slot and slot.item.is_same(item):
			var taken: int = mini(slot.count, left)
			slot.count -= taken
			left -= taken
			if slot.count == 0:
				slots[i] = null
	if left != count:
		_items_changed()
	return count - left


## How many of [param item] are carried.
func count_of(item: Item) -> int:
	if item == null:
		return 0
	var total: int = 0
	for slot: ItemSlot in get_slots(item.category):
		if slot and slot.item.is_same(item):
			total += slot.count
	return total


func has_item(item: Item, count: int = 1) -> bool:
	return count_of(item) >= count


## Moves the stack at [param from_index] onto [param to_index] of the same tab: onto an empty slot it moves, onto
## the same item it merges up to the stack limit, onto anything else it swaps.
func move_slot(category: Item.Category, from_index: int, to_index: int) -> void:
	var slots: Array = get_slots(category)
	if from_index == to_index or from_index < 0 or to_index < 0 or from_index >= slots.size() or to_index >= slots.size():
		return
	var moving: ItemSlot = slots[from_index]
	if moving == null:
		return
	var target: ItemSlot = slots[to_index]
	if target and target.item.is_same(moving.item) and target.count < moving.item.max_stack:
		var taken: int = mini(moving.item.max_stack - target.count, moving.count)
		target.count += taken
		moving.count -= taken
		if moving.count == 0:
			slots[from_index] = null
	else:
		slots[to_index] = moving
		slots[from_index] = target
	_items_changed()


## Uses [param count] from the stack at [param index]: emits [signal item_used] and, for a consumable, takes them.
func use_slot(category: Item.Category, index: int, count: int = 1) -> void:
	var slot: ItemSlot = get_slot(category, index)
	if slot == null:
		return
	var used: int = mini(count, slot.count)
	var item: Item = slot.item
	if item.consumable:
		slot.count -= used
		if slot.count == 0:
			get_slots(category)[index] = null
		_items_changed()
	item_used.emit(item, used)


## Uses [param count] of [param item] from the first stack that holds it, as [method use_slot] does.
func use_item(item: Item, count: int = 1) -> void:
	if item == null:
		return
	var slots: Array = get_slots(item.category)
	for i: int in slots.size():
		if slots[i] and slots[i].item.is_same(item):
			use_slot(item.category, i, count)
			return


## Every carried [Item] with [member Item.throwable] set, in tab and slot order, each kind once.
func get_throwable_items() -> Array[Item]:
	var found: Array[Item] = []
	for category: Item.Category in ITEM_TABS:
		for slot: ItemSlot in get_slots(category):
			if slot and slot.item.throwable and not found.any(func(item: Item) -> bool: return item.is_same(slot.item)):
				found.append(slot.item)
	return found


## Drops [param count] from the stack at [param index] on the ground in front of the Player as an [ItemPickup].
func drop_slot(category: Item.Category, index: int, count: int = 1) -> Node3D:
	var slot: ItemSlot = get_slot(category, index)
	if slot == null or player == null:
		return null
	var dropped: int = mini(count, slot.count)
	var item: Item = slot.item
	slot.count -= dropped
	if slot.count == 0:
		get_slots(category)[index] = null
	var pickup: Node3D = _drop(ITEM_PICKUP_SCENE.resource_path, item.resource_path, dropped)
	_items_changed()
	item_dropped.emit(item, dropped, pickup)
	return pickup


## Drops an equipped or stowed [Equipment] back into the world (its scene, in front of the Player) and forgets it.
## Equipment that was not instanced from a scene cannot be dropped; it stays.
func drop_equipment(item: Equipment) -> Node3D:
	if player == null:
		return null
	var scene_path: String = forget_equipment(item)
	if scene_path.is_empty():
		return null
	return _drop(scene_path, "", 0)


## Forgets an equipped or stowed [Equipment] without putting anything in the world (it was thrown, it broke) and
## returns the scene path it can be re-created from. Empty, and nothing happens, for equipment that was not
## instanced from a scene.
func forget_equipment(item: Equipment) -> String:
	var scene_path: String = origin_of(item)
	if scene_path.is_empty():
		return ""
	var attachment: BoneAttachment3D = item.get_parent() as BoneAttachment3D
	if equipment.has(item):
		_stow(item)
	var gone: Node = attachment if attachment else item
	if gone.get_parent():
		gone.get_parent().remove_child(gone) # out of the backpack now, freed at the end of the frame
	gone.queue_free()
	_items_changed()
	_send_equipment()
	return scene_path


## Equips a fresh instance of [param scene] (an [Equipment] scene) as walking over it would; returns the copy on
## the skeleton, or null when the equip was refused. An equipment [Item] comes through here when it is added.
func add_equipment_scene(scene: PackedScene) -> Equipment:
	if scene == null or player == null:
		return null
	var pickup: Equipment = scene.instantiate() as Equipment
	if pickup == null:
		return null
	return _equip_instance(pickup)


## Puts [param item] back in the backpack without dropping it.
func stow_equipment(item: Equipment) -> void:
	if item == null or not equipment.has(item):
		return
	_stow(item)


# --- Saving ----------------------------------------------------------------------------------------------------

## Writes every stack and every piece of equipment to [member save_path].
func save() -> Error:
	_save_queued = false
	return ResourceSaver.save(make_save(), save_path)


## Every stack and every piece of equipment as an [InventorySave], for [method save] and for a [SaveGame] that
## keeps the inventory inside the game's own file.
func make_save() -> InventorySave:
	var data: InventorySave = InventorySave.new()
	for category: Item.Category in ITEM_TABS:
		var slots: Array = get_slots(category)
		for i: int in slots.size():
			var slot: ItemSlot = slots[i]
			if slot == null:
				continue
			var saved: ItemSlot = ItemSlot.make(slot.item, slot.count)
			saved.category = category
			saved.index = i
			data.slots.append(saved)
	for item: Equipment in get_all_weapons():
		if not _is_scene_path(item.scene_file_path):
			continue # placed inline in a level; it cannot be re-created, so it is not saved
		var entry: EquipmentEntry = EquipmentEntry.new()
		entry.scene_path = item.scene_file_path
		entry.equipped = equipment.has(item)
		data.equipment.append(entry)
	if spellbook:
		spellbook.write_save(data)
	return data


## Where this folder has lived, oldest first. A save names its scripts by path, so one written before a move
## fails to load and the player loses everything they were carrying.
const LEGACY_PATHS: PackedStringArray = [
	"res://addons/garp/",                        # its own addon, before it moved inside the player controller
	"res://addons/3d_player_controller/garp/",   # inside the player controller, before the folder was renamed
]
const SCRIPT_PATH: String = "res://addons/3d_player_controller/inventory/"


## Rewrites the script paths in a save written under any of [constant LEGACY_PATHS], which repairs it in
## place rather than throwing it away. Only ever does the work once per save.
func _migrate_legacy_save() -> void:
	if not save_path.ends_with(".tres"): # a binary save is not ours to rewrite as text
		return
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	file.close()
	var repaired: String = text
	for legacy: String in LEGACY_PATHS:
		repaired = repaired.replace(legacy, SCRIPT_PATH)
	if repaired == text:
		return
	file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(repaired)
	file.close()


## Replaces the inventory with what [member save_path] holds; nothing happens when there is no file.
func load_save() -> bool:
	if not ResourceLoader.exists(save_path):
		return false
	_migrate_legacy_save()
	var data: InventorySave = ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as InventorySave
	if data == null:
		return false
	apply_save(data)
	return true


## Replaces the inventory with [param data].
func apply_save(data: InventorySave) -> void:
	_loading = true
	for category: Item.Category in ITEM_TABS:
		_tabs[category] = _empty_tab()
	for saved: ItemSlot in data.slots:
		if saved.item == null or saved.index < 0 or saved.index >= slots_per_tab:
			continue
		get_slots(saved.category)[saved.index] = ItemSlot.make(saved.item, saved.count)
	var scene_paths: PackedStringArray = []
	var equipped: PackedByteArray = []
	for entry: EquipmentEntry in data.equipment:
		scene_paths.append(entry.scene_path)
		equipped.append(1 if entry.equipped else 0)
	_rebuild_equipment(scene_paths, equipped)
	if spellbook:
		spellbook.read_save(data)
	_loading = false
	_items_changed()
	_send_equipment()


## Replaces every piece of equipment with fresh instances of [param scene_paths], equipping those flagged in
## [param equipped]. An entry whose scene is gone is skipped, and its flag with it.
func _rebuild_equipment(scene_paths: PackedStringArray, equipped: PackedByteArray) -> void:
	if player == null or player.skeleton == null:
		return
	for item: Equipment in get_all_weapons():
		var attachment: BoneAttachment3D = item.get_parent() as BoneAttachment3D
		if equipment.has(item):
			_stow(item)
		if attachment:
			attachment.free()
	var instances: Array[Array] = [] # [Equipment, equipped] pairs; only the entries that came back
	for i: int in scene_paths.size():
		var pickup: Equipment = _pickup_from(scene_paths[i])
		if pickup == null:
			continue
		var instance: Equipment = _equip_instance(pickup)
		if instance:
			instances.append([instance, i < equipped.size() and equipped[i] == 1])
	unequip_all()
	for pair: Array in instances:
		if pair[1]:
			equip_weapon(pair[0])


## Writes the save if [member persist] is on; the [Spellbook] calls it after its own changes.
func request_save() -> void:
	_autosave()


func _autosave() -> void:
	if persist and persistence_enabled and not _loading and not _save_queued and is_inside_tree() and is_multiplayer_authority():
		_save_queued = true
		save.call_deferred()


func _items_changed() -> void:
	items_changed.emit()
	_autosave()


# --- Equipment -------------------------------------------------------------------------------------------------

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
	_autosave()
	_send_equipment()


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


## Room for one more weapon or tool under [member max_equipment].
func can_carry_equipment() -> bool:
	return get_all_weapons().size() < max_equipment


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
		if child is BoneAttachment3D and child.get_child_count() > 0:
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


## Equips [param pickup], an [Equipment] in the world, on the Player: a duplicate goes onto a new
## [BoneAttachment3D] on the skeleton, on the bone the item names and with the item's offsets, and joins
## [member equipment]; whatever conflicts with it is stowed first. Returns the copy on the skeleton, or null when
## the item names no bone, the Player already carries one of this type on this bone, or the backpack is full.
## [method Equipment.equip] and the walk-over pickups come through here.
func equip_pickup(pickup: Equipment) -> Equipment:
	if pickup == null or player == null or pickup.bone_attachment_bone_name.is_empty() \
			or has_equipment_in_backpack(pickup.equipment_type, pickup.bone_attachment_bone_name) \
			or not can_carry_equipment():
		return null

	stow_conflicting(pickup.bone_attachment_bone_name, pickup.is_exclusive)

	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.bone_name = pickup.bone_attachment_bone_name
	player.skeleton.add_child(attachment)

	var copy: Equipment = pickup.duplicate() as Equipment
	copy.player = player
	# A node added at runtime keeps the engine's default authority, the server's, whatever it hangs under; a piece
	# on a client's own skeleton has to answer to that client, or its own _ready takes it for a puppet's.
	attachment.set_multiplayer_authority(player.get_multiplayer_authority())
	copy.set_multiplayer_authority(player.get_multiplayer_authority())
	copy.scene_file_path = pickup.scene_file_path # so the inventory can save and drop it as its scene
	# Where a peer finds the same piece: the pickup itself when it stands in the world on every peer, else the
	# scene it came from. A model file alone carries no script, so a world pickup is named by its path.
	if pickup.is_inside_tree() and not player.is_ancestor_of(pickup):
		copy.set_meta("origin", String(pickup.get_path()))
	elif pickup.has_meta("origin"):
		copy.set_meta("origin", pickup.get_meta("origin"))
	attachment.add_child(copy)
	# Disable world collision but keep the "Hitbox" and "WeaponBody" shapes so HitDetection can use them.
	for shape: Node in copy.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = shape.get_parent().name not in ["Hitbox", "WeaponBody"]
	for tree: Node in copy.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = true
		(tree as AnimationTree).advance_expression_base_node = tree.get_path_to(copy)
	if pickup.is_inside_tree(): # The scene's hand offsets reach the copy from a pickup in the tree, as they always have
		copy.position = pickup.position_offset
		copy.rotation_degrees = pickup.rotation_offset_degrees
		copy.scale = pickup.scale_offset

	add_equipment(copy)
	return copy


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
			_stow(item)


## Takes [param item] off the skeleton into the backpack; one added without a bone attachment (a bare test fixture)
## just leaves the set.
func _stow(item: Equipment) -> void:
	var attachment: BoneAttachment3D = item.get_parent() as BoneAttachment3D
	if attachment:
		_stow_attachment(attachment)
	else:
		remove_equipment(item)


func unequip_all() -> void:
	stow_conflicting("", true)


## Moves an equipped attachment (and its item) off the skeleton into the hidden backpack. The move happens before
## [signal equipment_changed] fires, so listeners never see the item between the skeleton and the backpack.
func _stow_attachment(attachment: BoneAttachment3D) -> void:
	var item: Equipment = attachment.get_child(0) as Equipment
	attachment.reparent(self, false)
	attachment.hide()
	remove_equipment(item)


# --- Helpers ---------------------------------------------------------------------------------------------------

func _empty_tab() -> Array:
	var tab: Array = []
	tab.resize(slots_per_tab)
	return tab


## An equipment item is picked up by instancing its scene and equipping it, as a walk-over pickup would.
func _add_equipment_item(item: Item) -> bool:
	return add_equipment_scene(item.equipment_scene) != null


## Equips a freshly instanced [param pickup] the way walking over it would: on the Player for the moment it
## equips, since [method equip_pickup] applies the scene's hand offsets only while the pickup is in the tree,
## then freed. Returns the copy on the skeleton, or null when the equip was refused.
func _equip_instance(pickup: Equipment) -> Equipment:
	player.add_child(pickup)
	var instance: Equipment = equip_pickup(pickup)
	player.remove_child(pickup)
	pickup.free()
	return instance


## Puts [param scene_path] on the ground a metre in front of the Player, on every peer under one name so a later
## take vanishes it everywhere; an [ItemPickup] carries [param item_path] and [param count]. An item with no
## resource path cannot travel, so that drop is this peer's alone. Returns the copy in this world.
func _drop(scene_path: String, item_path: String, count: int) -> Node3D:
	var facing: Vector3 = player.get_facing_direction()
	if facing == Vector3.ZERO:
		facing = Vector3.FORWARD
	var at: Transform3D = Transform3D(Basis(), player.global_position + facing.normalized() * 1.0 + player.up_direction * 0.2)
	_drop_counter += 1
	var node_name: String = "Dropped_%d_%d" % [multiplayer.get_unique_id(), _drop_counter]
	if scene_path == ITEM_PICKUP_SCENE.resource_path and item_path.is_empty():
		_spawn_dropped(scene_path, at, node_name, item_path, count)
	else:
		_spawn_dropped.rpc(scene_path, at, node_name, item_path, count)
	return player.get_parent().get_node_or_null(node_name)


## Every peer puts the dropped [param scene_path] in its world as [param node_name] at [param at]; see [method _drop].
@rpc("any_peer", "call_local", "reliable")
func _spawn_dropped(scene_path: String, at: Transform3D, node_name: String, item_path: String, count: int) -> void:
	var pickup: Node3D = _pickup_from(scene_path) if scene_path.begins_with("/") else (load(scene_path) as PackedScene).instantiate() as Node3D
	if pickup == null:
		return
	pickup.name = node_name
	if not item_path.is_empty():
		pickup.set("item", load(item_path))
		pickup.set("count", count)
	player.get_parent().add_child(pickup)
	pickup.global_transform = at
	# A walk-over pickup lands inside its own reach; it ignores the Player who dropped it until they step away
	pickup.set_meta("dropped_by", player)
	var detection: Area3D = pickup.get_node_or_null("PlayerDetection") as Area3D
	if detection:
		detection.body_exited.connect(_on_dropped_equipment_body_exited.bind(pickup))


## The authority tells [param peer] (0 is everyone) what it carries; wired to peer_connected for late joiners and
## called after every change. A puppet has no save to draw on, so this is how its skeleton gets the same pieces.
func _send_equipment(peer: int = 0) -> void:
	if _loading or not is_inside_tree() or not is_multiplayer_authority() or multiplayer.get_peers().is_empty():
		return
	var scene_paths: PackedStringArray = []
	var equipped: PackedByteArray = []
	for item: Equipment in get_all_weapons():
		var origin: String = origin_of(item)
		if origin.is_empty():
			continue # placed inline in a level and never a pickup; a peer cannot re-create it
		scene_paths.append(origin)
		equipped.append(1 if equipment.has(item) else 0)
	_sync_equipment.rpc_id(peer, scene_paths, equipped)


## A peer's copy of the Player rebuilds the authority's equipment from its scene paths: visual only, it registers
## no actions and writes no save ([method _autosave] is the authority's alone).
@rpc("authority", "call_local", "reliable")
func _sync_equipment(scene_paths: PackedStringArray, equipped: PackedByteArray) -> void:
	if is_multiplayer_authority():
		return
	_loading = true
	_rebuild_equipment(scene_paths, equipped)
	_loading = false


## The Player who dropped a piece of equipment has walked off it; it can be picked up again.
func _on_dropped_equipment_body_exited(body: Node3D, pickup: Node3D) -> void:
	if is_instance_valid(pickup) and pickup.has_meta("dropped_by") and body == pickup.get_meta("dropped_by"):
		pickup.remove_meta("dropped_by")


## Whether a peer can re-create a piece from [param path]: any scene the loader knows, which is a .tscn as much
## as an imported .fbx or .glb, since a project's weapons are often the model file itself. A node placed inline
## in a level has no path and stays where it is.
## What names [param item] to a peer: the scene it was instanced from when that scene is its own (a .tscn
## carries the script and the settings), else the world pickup it came from, by path, which is what a model
## file with the script put on in the level needs. Empty for a piece placed inline that was never a pickup.
func origin_of(item: Equipment) -> String:
	if item == null:
		return ""
	if has_own_scene(item):
		return item.scene_file_path
	return item.get_meta("origin") if item.has_meta("origin") else ""


## Whether [param item] can be re-created from its scene alone: a .tscn or .scn, which carries its script and
## settings, unlike an imported model that only gets them in the level. A throw needs this, since what lands
## is an instance of that scene.
static func has_own_scene(item: Equipment) -> bool:
	return item != null and (item.scene_file_path.ends_with(".tscn") or item.scene_file_path.ends_with(".scn"))


## A fresh pickup for [param origin]: a copy of the world pickup at that path, or an instance of that scene.
## Null when neither is there. A copy of a spent pickup is made whole again, so it can be worn or walked over.
func _pickup_from(origin: String) -> Equipment:
	if origin.begins_with("/"):
		var source: Equipment = get_node_or_null(origin) as Equipment
		if source == null:
			return null
		var pickup: Equipment = source.duplicate() as Equipment
		pickup.equipment_instance = null
		pickup.visible = true
		var detection: Area3D = pickup.get_node_or_null("PlayerDetection") as Area3D
		if detection:
			detection.monitoring = true
		pickup.set_meta("origin", origin)
		return pickup
	var scene: PackedScene = load(origin) as PackedScene if _is_scene_path(origin) else null
	return scene.instantiate() as Equipment if scene else null


static func _is_scene_path(path: String) -> bool:
	return ResourceLoader.exists(path) and ResourceLoader.get_resource_type(path) == "PackedScene"
