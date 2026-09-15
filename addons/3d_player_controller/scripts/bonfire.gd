class_name Bonfire
extends Node3D
## The Souls checkpoint: walk up and Rest. Resting takes the [member checkpoint] (the Player comes back here after
## dying, healed), tops the [member flask] up to [member flasks], and puts every dead [EnemyNpc] under [member revives]
## (the whole tree when empty) back on its feet at its post, the way a bonfire brings the level back. A [SaveGame]
## watching the checkpoint writes the game on it. [signal rested] is for the scene: a fire that grows, a message.

signal rested(player: Player)

@export var checkpoint: Checkpoint ## Taken on a rest; its respawn point is where the Player comes back.
@export var flask: Item ## The healing item topped up on a rest (a potion, an estus); empty tops nothing up.
@export var flasks: int = 3 ## How many of [member flask] a rest leaves the Player with.
@export var revives: Node ## The enemies a rest brings back: this node's [EnemyNpc] descendants, or every one in the tree when empty.
@export var prompt_label: String = "Rest" ## What the Action button reads beside the fire.

var _nearby: Player = null

@onready var action_prompt: ActionPrompt = $ActionPrompt


func _input(event: InputEvent) -> void:
	if _nearby and not _nearby.is_paused and event.is_action_pressed(&"action") and not event.is_echo():
		rest(_nearby)
		get_viewport().set_input_as_handled()


## Wired to PlayerDetection.body_entered.
func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is Player and body.is_multiplayer_authority():
		_nearby = body
		action_prompt.show_for(_nearby.controls, prompt_label)


## Wired to PlayerDetection.body_exited.
func _on_player_detection_body_exited(body: Node3D) -> void:
	if body == _nearby:
		action_prompt.hide_for(_nearby.controls)
		_nearby = null


## [param who] rests here: checkpoint, health, flasks, and the dead back at their posts.
func rest(who: Player) -> void:
	if who == null:
		return
	if checkpoint:
		checkpoint.take(who)
	else:
		who.set_checkpoint(global_transform)
		who.heal(who.health.max_health)
	refill_flasks(who)
	revive_enemies()
	rested.emit(who)


## Tops [member flask] up to [member flasks] in [param who]'s inventory.
func refill_flasks(who: Player) -> void:
	if flask == null or who.inventory == null:
		return
	var have: int = who.inventory.count_of(flask)
	if have < flasks:
		who.inventory.add_item(flask, flasks - have)


## Every dead enemy under [member revives] stands up again where it started.
func revive_enemies() -> void:
	var scope: Node = revives if revives else get_tree().root
	for enemy: Node in scope.find_children("*", "EnemyNpc", true, false):
		if (enemy as EnemyNpc).is_dead:
			(enemy as EnemyNpc).revive(true)
