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
var _nearby: Player = null
var _panel_rest: Transform3D
var _tween: Tween

@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	if panel == null:
		panel = self
	_panel_rest = panel.transform


func _input(event: InputEvent) -> void:
	if _nearby == null or is_open or _nearby.is_paused or not event.is_action_pressed(&"action") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if not has_key(_nearby):
		refused.emit(_nearby)
		return
	open(_nearby)


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
	if _nearby:
		action_prompt.hide_for(_nearby.controls)
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


## Wired to PlayerDetection.body_entered.
func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is Player and body.is_multiplayer_authority() and not is_open:
		_nearby = body
		action_prompt.show_for(_nearby.controls, prompt_label if has_key(_nearby) else locked_label)


## Wired to PlayerDetection.body_exited.
func _on_player_detection_body_exited(body: Node3D) -> void:
	if body == _nearby:
		action_prompt.hide_for(_nearby.controls)
		_nearby = null
		if is_open and not stays_open:
			close()
