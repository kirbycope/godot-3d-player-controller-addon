class_name DialogueScreen
extends PlayerMenuLayer
## The conversation box at the bottom of the screen: the speaker, the line typed out, and the choices when the
## line offers any. Action (or Confirm) reveals the rest of a line still typing, then goes on to the next; a choice
## is a focused button, so the sticks, the d-pad, the mouse and a finger all pick one. The Player is paused while
## it is up, the way the menus pause them, and the bottom-action label reads Continue. What a line or a choice
## does to the quests ([member DialogueLine.starts_quest] and the rest) happens here, through the Player's [QuestLog].

signal dialogue_started(dialogue: Dialogue)
signal dialogue_ended(dialogue: Dialogue)
signal line_shown(line: DialogueLine)
signal choice_made(choice: DialogueChoice)

@export var characters_per_second: float = 40.0 ## How fast a line types out; 0 shows it whole.
@export var continue_action: StringName = &"action" ## The action that reveals and advances a line.
@export var continue_label: String = "Continue" ## What the bottom-action button reads while a line is up.
@export var choose_label: String = "Choose" ## And while choices are up.

var dialogue: Dialogue ## The conversation up, if any.
var speaker_node: Node3D ## Who is talking, when a node started it.
var line_index: int = -1
var current_line: DialogueLine
var _default_speaker: String = ""
var _revealed: float = 0.0
var _choice_buttons: Array[Button] = []

@onready var speaker_label: Label = %Speaker
@onready var text_label: Label = %Text
@onready var choices_box: VBoxContainer = %Choices
@onready var continue_hint: Label = %ContinueHint


func _ready() -> void:
	super()
	hide()
	set_process(false)


## Opens on [param target]'s first applicable line; false when no line applies. [param talker] is who is speaking,
## [param speaker_name] what a line with no speaker of its own is labelled.
func start(target: Dialogue, talker: Node3D = null, speaker_name: String = "") -> bool:
	if target == null or player == null:
		return false
	var log: QuestLog = player.quest_log
	var first: int = target.first_line(log)
	if first < 0:
		return false
	dialogue = target
	speaker_node = talker
	_default_speaker = speaker_name
	show_menu()
	dialogue_started.emit(dialogue)
	_show_line(first)
	return true


## Reveals the rest of a line still typing, else goes on to the next line or ends; does nothing while choices wait.
func advance() -> void:
	if dialogue == null or current_line == null:
		return
	if not is_line_revealed():
		_reveal_all()
		return
	if not current_line.choices.is_empty():
		return
	var next: int = dialogue.next_line(line_index, player.quest_log)
	if next < 0:
		end()
	else:
		_show_line(next)


## Picks [param choice] of the current line.
func choose(choice: DialogueChoice) -> void:
	if dialogue == null or choice == null:
		return
	_apply(choice.starts_quest, choice.progresses_objective)
	choice_made.emit(choice)
	var next: int = dialogue.resolve(choice.next, player.quest_log) if choice.next >= 0 else -1
	if next < 0:
		end()
	else:
		_show_line(next)


## Closes the conversation.
func end() -> void:
	if dialogue == null:
		return
	var ended: Dialogue = dialogue
	dialogue = null
	current_line = null
	line_index = -1
	speaker_node = null
	_clear_choices()
	set_process(false)
	if visible:
		hide_menu()
	dialogue_ended.emit(ended)


func is_line_revealed() -> bool:
	return text_label.visible_characters < 0 or text_label.visible_characters >= text_label.text.length()


## The pause button ends the conversation, as it closes any menu.
func hide_menu() -> void:
	super()
	if player and player.controls:
		player.controls.release_action_label(self)
	if dialogue:
		end()


func _input(event: InputEvent) -> void:
	super(event)
	if not visible or dialogue == null or current_line == null:
		return
	if not current_line.choices.is_empty() and is_line_revealed():
		# Action or Confirm picks the focused choice here rather than through the GUI, so one press of the pad's A
		# (which is both) chooses once, and a scripted action press (a recording, a test) chooses the way it does.
		# The sticks and the d-pad still move the focus; with no focus (the window lost it) the first choice stands.
		if (event.is_action_pressed(continue_action) or event.is_action_pressed(&"ui_accept")) and not event.is_echo():
			var focus: Control = get_viewport().gui_get_focus_owner()
			var button: Button = focus as Button if focus is Button and _choice_buttons.has(focus as Button) else _choice_buttons[0]
			button.pressed.emit()
			get_viewport().set_input_as_handled()
		return
	if (event.is_action_pressed(continue_action) or event.is_action_pressed(&"ui_accept")) and not event.is_echo():
		advance()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if current_line == null or is_line_revealed():
		set_process(false)
		return
	_revealed += characters_per_second * delta
	text_label.visible_characters = int(_revealed)
	if is_line_revealed():
		_on_line_revealed()


func _show_line(index: int) -> void:
	line_index = index
	current_line = dialogue.lines[index]
	speaker_label.text = current_line.speaker if not current_line.speaker.is_empty() else _default_speaker
	speaker_label.visible = not speaker_label.text.is_empty()
	text_label.text = current_line.text
	_clear_choices()
	continue_hint.visible = false
	if player and player.controls:
		player.controls.claim_action_label(continue_label, self)
	_apply(current_line.starts_quest, current_line.progresses_objective)
	line_shown.emit(current_line)
	if characters_per_second <= 0.0:
		_reveal_all()
	else:
		_revealed = 0.0
		text_label.visible_characters = 0
		set_process(true)


func _reveal_all() -> void:
	text_label.visible_characters = -1
	set_process(false)
	_on_line_revealed()


## The whole line is readable: offer its choices, or say how to go on.
func _on_line_revealed() -> void:
	if current_line == null:
		return
	if current_line.choices.is_empty():
		continue_hint.visible = true
		return
	if player and player.controls:
		player.controls.claim_action_label(choose_label, self)
	for choice: DialogueChoice in current_line.choices:
		var button: Button = Button.new()
		button.text = choice.text
		button.custom_minimum_size.y = 32.0
		button.pressed.connect(choose.bind(choice))
		button.mouse_entered.connect(button.grab_focus)
		choices_box.add_child(button)
		_choice_buttons.append(button)
	_choice_buttons[0].grab_focus()


func _clear_choices() -> void:
	for button: Button in _choice_buttons:
		button.queue_free()
	_choice_buttons.clear()


func _apply(quest: Quest, objective: StringName) -> void:
	var log: QuestLog = player.quest_log if player else null
	if log == null:
		return
	if quest:
		log.start(quest)
	if not objective.is_empty():
		log.progress(objective)
