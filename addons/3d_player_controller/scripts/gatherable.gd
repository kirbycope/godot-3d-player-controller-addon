class_name Gatherable
extends StaticBody3D
## A tree, a boulder, a berry bush: something in the world that gives [member item] when struck. A swing from a
## piece of [Equipment] that [member needs] what it needs (the axe's [member Equipment.can_log], the pickaxe's
## [member Equipment.can_mine], or nothing at all for a bush) counts a hit; every [member hits_per_yield] hits put
## [member yield_count] of the item straight in the striker's [Inventory], and after [member total_yields] the
## thing is spent: hidden, and back after [member regrow_seconds] when that is set. In the "Gatherable" group so
## a swing reaches it the way it reaches an enemy ([member HitDetection.strike_groups]).

signal harvested(by: Player, item: Item, count: int)
signal depleted

enum Needs { NOTHING, LOGGING, MINING }

@export var item: Item
@export var yield_count: int = 1
@export var hits_per_yield: int = 3
@export var total_yields: int = 3 ## Yields before it is spent; 0 never runs out.
@export var needs: Needs = Needs.NOTHING
@export var regrow_seconds: float = 0.0 ## Back after this long once spent; 0 stays gone.
@export var wrong_tool_label: String = "" ## Shown on the HUD's boss line? No: kept for the game to read on [signal refused].
@export var shake_node: Node3D ## Nudged on every hit, for the feel; the model itself when empty.

var hits: int = 0
var yields_given: int = 0
var is_spent: bool = false

var _regrow_timer: Timer


func _ready() -> void:
	add_to_group(&"Gatherable")
	if shake_node == null:
		for child: Node in get_children():
			if child is Node3D and not child is CollisionShape3D:
				shake_node = child
				break


## Called by [HitDetection] for a swing that reached this; [param equipment] is the piece or the Player unarmed.
func register_weapon_hit(equipment: Node = null, _hit_node: Node = null) -> void:
	if is_spent or item == null:
		return
	var player: Player = (equipment as Equipment).player if equipment is Equipment else equipment as Player
	if not can_harvest_with(equipment):
		return
	hits += 1
	_shake()
	if hits < hits_per_yield:
		return
	hits = 0
	if player and player.inventory:
		player.inventory.add_item(item, yield_count)
	yields_given += 1
	harvested.emit(player, item, yield_count)
	if total_yields > 0 and yields_given >= total_yields:
		_deplete()


## Whether [param equipment] (a piece, or the Player for bare hands) is the tool for the job.
func can_harvest_with(equipment: Node) -> bool:
	match needs:
		Needs.LOGGING:
			return equipment is Equipment and (equipment as Equipment).can_log
		Needs.MINING:
			return equipment is Equipment and (equipment as Equipment).can_mine
	return true


func _deplete() -> void:
	is_spent = true
	visible = false
	for shape: Node in find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).set_deferred(&"disabled", true)
	depleted.emit()
	if regrow_seconds > 0.0:
		_regrow_timer = Timer.new()
		_regrow_timer.one_shot = true
		_regrow_timer.timeout.connect(regrow)
		add_child(_regrow_timer)
		_regrow_timer.start(regrow_seconds)


## Back as it was.
func regrow() -> void:
	is_spent = false
	yields_given = 0
	hits = 0
	visible = true
	for shape: Node in find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).set_deferred(&"disabled", false)
	if _regrow_timer:
		_regrow_timer.queue_free()
		_regrow_timer = null


func _shake() -> void:
	if shake_node == null:
		return
	var tween: Tween = create_tween()
	var rest: Vector3 = shake_node.rotation_degrees
	tween.tween_property(shake_node, "rotation_degrees", rest + Vector3(0.0, 0.0, 3.0), 0.06)
	tween.tween_property(shake_node, "rotation_degrees", rest + Vector3(0.0, 0.0, -2.0), 0.08)
	tween.tween_property(shake_node, "rotation_degrees", rest, 0.08)
