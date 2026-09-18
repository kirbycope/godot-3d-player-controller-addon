class_name LockedDoor
extends StaticBody3D
## A door that opens for a walk-up Action once the Player carries [member key] (a key card, a dungeon key), and
## reads "Locked" until they do. [member panel] is the part that moves: it slides by [member open_offset] and turns
## by [member open_degrees] about its Y over [member open_seconds], and the door's collision goes with it. With no
## key set, any Action opens it. [signal opened] and [signal refused] are for the scene: a buzz, a light, a quest.

signal opened(by: Player)
signal refused(by: Player) ## Action without the key.

@export var key: Item ## What the Player has to carry; empty needs nothing.
@export var sealed: bool = false ## Shut by the scene rather than a key (a gate until the waves are done): no press opens it until a script clears this.
@export var consumes_key: bool = false ## The key is spent on opening (a one-use card).
@export var panel: Node3D ## The moving part; the whole door when empty.
@export var open_offset: Vector3 = Vector3(0.0, 2.6, 0.0) ## Where the panel slides to, in its own space.
@export var open_degrees: float = 0.0 ## How far the panel turns about its Y as it opens.
@export var open_seconds: float = 0.8
@export var prompt_label: String = "Open"
@export var locked_label: String = "Locked"
@export var stays_open: bool = true ## Off, and it closes again once the Player has walked away.

var is_open: bool = false
var _panel_rest: Transform3D
var _tween: Tween

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	if panel == null:
		panel = self
	_panel_rest = panel.transform


## Whether [param who] carries [member key] and the door is not [member sealed].
func has_key(who: Player) -> bool:
	return not sealed and (key == null or (who.inventory and who.inventory.count_of(key) > 0))


## Opens for [param who]; false when the door is open already or the key is missing.
func open(who: Player) -> bool:
	if is_open or who == null or not has_key(who):
		return false
	if key and consumes_key:
		who.inventory.remove_item(key, 1)
	is_open = true
	collision_shape.disabled = true
	hide_menu()
	_move_panel(true)
	opened.emit(who)
	return true


func close() -> void:
	if not is_open:
		return
	is_open = false
	collision_shape.disabled = false
	_move_panel(false)


func _move_panel(opening: bool) -> void:
	if _tween:
		_tween.kill()
	var target: Transform3D = _panel_rest
	if opening:
		target = _panel_rest.translated_local(open_offset).rotated_local(Vector3.UP, deg_to_rad(open_degrees))
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(panel, "transform", target, open_seconds)


## Called by [Camera] when this is the one thing the action button would act on. An open door offers nothing,
## and a locked one says so rather than pretending it will open.
func display_menu(who: Player) -> void:
	if is_open:
		return
	action_prompt.show_for(who.controls, prompt_label if has_key(who) else locked_label)


## Called by [Camera] when it is not.
func hide_menu() -> void:
	for who: Node in get_tree().get_nodes_in_group(&"Player"):
		if who is Player and (who as Player).controls:
			action_prompt.hide_for((who as Player).controls)
	action_prompt.hide()


## The Camera's Action hook: open for whoever pressed it, or refuse when they have no key.
func equip(who: Player) -> void:
	if is_open or who == null:
		return
	if not has_key(who):
		refused.emit(who)
		return
	open(who)


## Wired to PlayerDetection.player_exited: a door that does not stay open swings shut once nobody is by it.
func _on_player_detection_player_exited(_player: Player) -> void:
	if is_open and not stays_open:
		close()
