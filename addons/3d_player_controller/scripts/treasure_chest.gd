class_name TreasureChest
extends StaticBody3D
## A chest the Player opens with Action: walk up to it (or look at it) and the prompt offers Open, the lid swings up
## ([member lid]), the [member items] go into the inventory (an equipment item is picked up as walking over it
## would) and [signal opened] fires. Once opened it stays open and offers nothing more; it saves with the game.
## Replicated: the server opens it and every peer's lid follows.

signal opened(by: Player)

@export var items: Dictionary[Item, int] = {} ## What is inside, by count.
@export var animation_player: AnimationPlayer ## A model with its own clips: [member open_animation] plays as it opens, the poses hold it after.
@export var open_animation: StringName = &"Chest_Open"
@export var opened_animation: StringName = &"Chest_Opened" ## The pose held once open (a load, a late joiner).
@export var closed_animation: StringName = &"Chest_Closed"
@export var lid: Node3D ## Without clips: this swings open about its X axis.
@export var lid_open_degrees: float = -110.0
@export var prompt_label: String = "Open"

var is_open: bool = false: ## Replicated; the setter swings the lid on every peer.
	set(value):
		if value == is_open:
			return
		is_open = value
		if is_node_ready():
			_show_lid(true)

var _nearby: Player ## The Player inside the detection area, whose prompt is up.

@onready var action_prompt: ActionPrompt = $ActionPrompt


func _ready() -> void:
	add_to_group(&"Saveable")
	_show_lid()


## The walk-up prompt: Action opens for whoever is standing by.
func _input(event: InputEvent) -> void:
	if _nearby and not is_open and not _nearby.is_paused and event.is_action_pressed(&"action") and not event.is_echo():
		if open(_nearby):
			get_viewport().set_input_as_handled()


## Wired to PlayerDetection.body_entered.
func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is Player and body.is_multiplayer_authority() and not is_open:
		_nearby = body
		display_menu(_nearby)


## Wired to PlayerDetection.body_exited.
func _on_player_detection_body_exited(body: Node3D) -> void:
	if body == _nearby:
		_nearby = null
		hide_menu()


## Called by [Camera] while the Player looks at the chest.
func display_menu(looking: Player) -> void:
	if not is_open:
		action_prompt.show_for(looking.controls, prompt_label)


## Called by [Camera] when the Player looks away.
func hide_menu() -> void:
	for looking: Node in get_tree().get_nodes_in_group(&"Player"):
		if looking is Player and (looking as Player).controls:
			action_prompt.hide_for((looking as Player).controls)
	action_prompt.hide()


## The Camera's Action hook.
func equip(who: Player) -> void:
	open(who)


## Opens for [param who]; the loot goes to them. False when already open.
func open(who: Player) -> bool:
	if is_open or who == null:
		return false
	hide_menu()
	if not multiplayer.is_server():
		_request_open.rpc_id(1, who.get_path())
		return true
	_open_for(who)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _request_open(player_path: NodePath) -> void:
	if multiplayer.is_server():
		_open_for(get_node_or_null(player_path) as Player)


func _open_for(who: Player) -> void:
	is_open = true
	_nearby = null
	if who and who.inventory:
		for item: Item in items:
			if item.category == Item.Category.EQUIPMENT and item.equipment_scene:
				var copy: Equipment = who.inventory.add_equipment_scene(item.equipment_scene)
				if copy:
					who.inventory.stow_equipment(copy)
			else:
				who.inventory.add_item(item, items[item])
	opened.emit(who)


## Puts the lid where [member is_open] says: the opening clip when it is happening now, else the held pose.
func _show_lid(animate: bool = false) -> void:
	if animation_player:
		if is_open and animate and animation_player.has_animation(open_animation):
			animation_player.play(open_animation)
		elif is_open and animation_player.has_animation(opened_animation):
			animation_player.play(opened_animation)
		elif not is_open and animation_player.has_animation(closed_animation):
			animation_player.play(closed_animation)
	if lid:
		lid.rotation_degrees.x = lid_open_degrees if is_open else 0.0


func save_state() -> Dictionary:
	return {"is_open": is_open}


func load_state(state: Dictionary) -> void:
	is_open = bool(state.get("is_open", false))
