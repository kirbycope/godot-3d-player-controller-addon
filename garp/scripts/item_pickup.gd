@icon("res://addons/3d_player_controller/garp/assets/icons/materials.svg")
class_name ItemPickup
extends Node3D
## An [Item] lying in the world, Zelda style: walk up and the [ActionPrompt] appears with the Action button read
## as "Pick Up"; Action puts [member count] of [member item] in the Player's [Inventory] and the pickup is gone.
## An item with a [member Item.model_scene] (what the inventory preview turns) lies here as that model, turning
## on the spot with its base on the ground; without one, or a mesh child of your own, its icon floats over the spot.
## The prompt and the label are up only while the Player is in the detection area and go down when they leave,
## when the pickup is taken, or when it vanishes (another peer took it).

signal picked_up(player: Player, count: int) ## Emitted with how many the Player took.

const TURN_SECONDS: float = 6.0 ## One full turn of the model.

@export var item: Item:
	set(value):
		item = value
		_refresh()
@export_range(1, 999) var count: int = 1
@export var show_icon: bool = true ## Float the item's icon as a billboard; turn off when the pickup has its own mesh.

var player: Player ## The Player in range, shown the prompt.
var _turn: Tween

@onready var player_detection: Area3D = $PlayerDetection
@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var icon: Sprite3D = $Icon
@onready var model_pivot: Node3D = $ModelPivot ## Holds the item's model, turning.


func _ready() -> void:
	_refresh()


## Freed while a Player stands by it (someone else took it, the level changed): the prompt lets the label go.
func _exit_tree() -> void:
	if player:
		action_prompt.hide_for(player)
		player = null


func _input(event: InputEvent) -> void:
	if player == null or item == null or player.is_paused or not event.is_action_pressed("action"):
		return
	take()
	get_viewport().set_input_as_handled()


## Puts what fits in the Player's inventory; the pickup frees itself once it is empty.
func take() -> void:
	if player == null or item == null:
		return
	var left: int = player.inventory.add_item(item, count)
	var taken: int = count - left
	if taken <= 0:
		return
	count = left
	picked_up.emit(player, taken)
	if count == 0:
		action_prompt.hide_for(player)
		player = null
		queue_free()


## Wired to PlayerDetection.body_entered: the Player who walked up gets the prompt, with the Action button read as
## "Pick Up" (the scene sets the prompt's message_end; the prompt's own ready put it on the labels).
func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is Player and body.is_multiplayer_authority() and not (body as Player).is_riding:
		player = body
		action_prompt.show_for(player, "Pick Up")


## Wired to PlayerDetection.body_exited: walking away takes the prompt and the label with it.
func _on_player_detection_body_exited(body: Node3D) -> void:
	if body == player:
		action_prompt.hide_for(player)
		player = null


func _refresh() -> void:
	if not is_node_ready():
		return
	for child: Node in model_pivot.get_children():
		child.queue_free()
	if _turn:
		_turn.kill()
		_turn = null
	var scene: PackedScene = item.get_model_scene() if item else null
	icon.visible = show_icon and item != null and item.icon != null and scene == null
	icon.texture = item.icon if item else null
	if scene == null:
		return
	var model: Node3D = scene.instantiate() as Node3D
	if model == null:
		return
	_disable_collision(model)
	model_pivot.add_child(model)
	item.prepare_model(model) # once in the tree, so the model's own ready nodes exist
	# Stand the model on the ground under the prompt, wherever its scene put its origin
	var bounds: AABB = AABB()
	var first: bool = true
	var geometries: Array[Node] = model.find_children("*", "GeometryInstance3D", true, false)
	if model is GeometryInstance3D:
		geometries.push_front(model)
	for geometry: Node in geometries:
		var visual: GeometryInstance3D = geometry as GeometryInstance3D
		var box: AABB = (model_pivot.global_transform.affine_inverse() * visual.global_transform) * visual.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if not first:
		model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
	_turn = create_tween().set_loops()
	_turn.tween_property(model_pivot, "rotation:y", TAU, TURN_SECONDS).as_relative()


## Switches off every collision shape and area under [param node], so the model on show neither blocks nor detects.
static func _disable_collision(node: Node) -> void:
	for shape: Node in node.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = true
	for area: Node in node.find_children("*", "Area3D", true, false):
		(area as Area3D).monitoring = false
		(area as Area3D).monitorable = false
