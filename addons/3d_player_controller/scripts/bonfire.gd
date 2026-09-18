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

@onready var action_prompt: ActionPrompt = $ActionPrompt


## Called by [Camera] when this is the one thing the action button would act on.
func display_menu(who: Player) -> void:
	action_prompt.show_for(who.controls, prompt_label)


## Called by [Camera] when it is not.
func hide_menu() -> void:
	for who: Node in get_tree().get_nodes_in_group(&"Player"):
		if who is Player and (who as Player).controls:
			action_prompt.hide_for((who as Player).controls)
	action_prompt.hide()


## The Camera's Action hook: rest for whoever pressed it.
func equip(who: Player) -> void:
	rest(who)


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
