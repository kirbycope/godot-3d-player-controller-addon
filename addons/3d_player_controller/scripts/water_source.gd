class_name WaterSource
extends Area3D
## A pond, a well, a stream: walk in and the Action button reads [member prompt_label]; Action puts
## [member drink_amount] on the Player's [Vitals] thirst. [signal drank] is for the scene.

signal drank(by: Player)

@export var drink_amount: float = 40.0
@export var prompt_label: String = "Drink"

var _nearby: Player = null

@onready var action_prompt: ActionPrompt = $ActionPrompt


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func _input(event: InputEvent) -> void:
	if _nearby == null or _nearby.is_paused or not event.is_action_pressed(&"action") or event.is_echo():
		return
	drink(_nearby)
	get_viewport().set_input_as_handled()


func drink(who: Player) -> void:
	var vitals: Vitals = who.get_node_or_null("Vitals") as Vitals
	if vitals:
		vitals.drink(drink_amount)
	drank.emit(who)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and body.is_multiplayer_authority():
		_nearby = body
		action_prompt.show_for(_nearby.controls, prompt_label)


func _on_body_exited(body: Node3D) -> void:
	if body == _nearby:
		action_prompt.hide_for(_nearby.controls)
		_nearby = null
