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

var _nearby: Player = null
var _reader: Player = null
var _read_by: Array[Player] = []

@onready var action_prompt: ActionPrompt = $ActionPrompt


func _input(event: InputEvent) -> void:
	if _nearby == null or _reader != null or _nearby.is_paused or not event.is_action_pressed(&"action") or event.is_echo():
		return
	if open(_nearby):
		get_viewport().set_input_as_handled()


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
	if _nearby == who and not (once and _read_by.has(who)):
		action_prompt.show_for(who.controls, prompt_label)


## Wired to PlayerDetection.body_entered.
func _on_player_detection_body_entered(body: Node3D) -> void:
	if body is Player and body.is_multiplayer_authority() and not (once and _read_by.has(body)):
		_nearby = body
		action_prompt.show_for(_nearby.controls, prompt_label)


## Wired to PlayerDetection.body_exited.
func _on_player_detection_body_exited(body: Node3D) -> void:
	if body == _nearby:
		action_prompt.hide_for(_nearby.controls)
		_nearby = null
