class_name Readable
extends Node3D
## A note, a sign, a plaque: walk up and the Action button reads [member prompt_label]; Action opens
## [member dialogue] on the Player's [DialogueScreen] with [member title] as the speaker, the way a [TalkingNpc]
## talks. [signal read] fires when the box closes, once per Player when [member once] is on.

signal read(by: Player)

@export var dialogue: Dialogue
@export var title: String = "Note" ## The speaker line of the box.
@export var prompt_label: String = "Read"
@export var once: bool = false ## After the first reading the prompt no longer comes up.

var _reader: Player = null
var _read_by: Array[Player] = []

@onready var action_prompt: ActionPrompt = $ActionPrompt


## Opens the note for [param who]; false when it is open already or there is nothing to read.
func open(who: Player) -> bool:
	if who == null or dialogue == null or who.dialogue_screen == null or _reader != null:
		return false
	if once and _read_by.has(who):
		return false
	if not who.dialogue_screen.start(dialogue, self, title):
		return false
	_reader = who
	action_prompt.hide_for(who.controls)
	who.dialogue_screen.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	return true


func _on_dialogue_ended(_dialogue: Dialogue) -> void:
	var who: Player = _reader
	_reader = null
	if who and not _read_by.has(who):
		_read_by.append(who)
	read.emit(who)
	if who and not (once and _read_by.has(who)):
		display_menu(who)


## Called by [Camera] when this is the one thing the action button would act on. A note already read stays
## quiet while [member once] is on, so a read sign offers nothing.
func display_menu(who: Player) -> void:
	if _reader != null or (once and _read_by.has(who)):
		return
	action_prompt.show_for(who.controls, prompt_label)


## Called by [Camera] when it is not.
func hide_menu() -> void:
	for who: Node in get_tree().get_nodes_in_group(&"Player"):
		if who is Player and (who as Player).controls:
			action_prompt.hide_for((who as Player).controls)
	action_prompt.hide()


## The Camera's Action hook: open the note for whoever pressed it.
func equip(who: Player) -> void:
	open(who)
