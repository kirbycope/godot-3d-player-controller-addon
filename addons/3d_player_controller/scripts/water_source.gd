class_name WaterSource
extends Area3D
## A pond, a well, a stream: walk in and the Action button reads [member prompt_label]; Action puts
## [member drink_amount] on the Player's [Vitals] thirst. [signal drank] is for the scene.

signal drank(by: Player)

@export var drink_amount: float = 40.0
@export var prompt_label: String = "Drink"

@onready var action_prompt: ActionPrompt = $ActionPrompt


func _ready() -> void:
	# Its own reach, since the water you are standing in is the area itself rather than a volume hung on an object
	add_to_group(Camera.REACH_GROUP)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func drink(who: Player) -> void:
	var vitals: Vitals = who.get_node_or_null("Vitals") as Vitals
	if vitals:
		vitals.drink(drink_amount)
	drank.emit(who)


## Called by [Camera] when this is the one thing the action button would act on.
func display_menu(who: Player) -> void:
	action_prompt.show_for(who.controls, prompt_label)


## Called by [Camera] when it is not.
func hide_menu() -> void:
	for who: Node in get_tree().get_nodes_in_group(&"Player"):
		if who is Player and (who as Player).controls:
			action_prompt.hide_for((who as Player).controls)
	action_prompt.hide()


## The Camera's Action hook: drink for whoever pressed it.
func equip(who: Player) -> void:
	drink(who)


func _on_body_entered(body: Node3D) -> void:
	var camera: Camera = _camera_of(body)
	if camera:
		camera.reach_entered(self)


func _on_body_exited(body: Node3D) -> void:
	var camera: Camera = _camera_of(body)
	if camera:
		camera.reach_exited(self)


## The [Camera] arbitrating for [param body], when it is a Player this peer is driving.
func _camera_of(body: Node3D) -> Camera:
	if body is Player and (body as Player).is_multiplayer_authority():
		return (body as Player).camera as Camera
	return null
