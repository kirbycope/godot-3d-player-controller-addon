extends GutTest

## Purpose: A Dialogue opens on the first line whose condition holds, types it out, goes on with Action, offers
## choices as focused buttons, and applies what lines and choices do to the quest log. A TalkingNpc offers Talk
## while looked at, opens its dialogue on Action, faces the talker and lets go when it ends. The demo guide's
## conversation walks the demo errand from greeting to reward.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const NPC_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/talking_npc.tscn")
const DEMO_DIALOGUE: Dialogue = preload("res://addons/3d_player_controller/resources/dialogues/demo_guide.tres")
const DEMO_QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/demo_errand.tres")
const APPLE: Item = preload("res://addons/3d_player_controller/inventory/resources/items/apple.tres")

var root: Node3D
var player: Player
var screen: DialogueScreen


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(40.0, 1.0, 40.0)
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	screen = player.dialogue_screen
	screen.characters_per_second = 0.0
	await wait_physics_frames(2)


func _line(text: String, ends: bool = false) -> DialogueLine:
	var line: DialogueLine = DialogueLine.new()
	line.text = text
	line.ends_dialogue = ends
	return line


func _dialogue(lines: Array[DialogueLine]) -> Dialogue:
	var dialogue: Dialogue = Dialogue.new()
	dialogue.lines = lines
	return dialogue


func test_a_dialogue_shows_its_lines_in_turn_and_pauses_the_player() -> void:
	var dialogue: Dialogue = _dialogue([_line("One"), _line("Two"), _line("Three")])
	watch_signals(screen)
	assert_true(screen.start(dialogue, null, "Tester"))
	assert_true(screen.visible)
	assert_true(player.is_paused, "The Player stands still while talking")
	assert_signal_emitted(screen, "dialogue_started")
	assert_eq(screen.speaker_label.text, "Tester")
	assert_eq(screen.text_label.text, "One")
	assert_eq(player.controls.prompt_action_label, "Continue", "The bottom button reads Continue")
	screen.advance()
	assert_eq(screen.text_label.text, "Two")
	screen.advance()
	assert_eq(screen.text_label.text, "Three")
	screen.advance()
	assert_false(screen.visible)
	assert_false(player.is_paused)
	assert_signal_emitted(screen, "dialogue_ended")
	assert_eq(player.controls.prompt_action_label, "", "The label is given back")


func test_a_line_types_out_and_action_reveals_it_first() -> void:
	screen.characters_per_second = 10.0
	var dialogue: Dialogue = _dialogue([_line("A fairly long sentence to type out."), _line("Two")])
	screen.start(dialogue)
	assert_eq(screen.text_label.visible_characters, 0)
	assert_false(screen.is_line_revealed())
	await wait_seconds(0.25)
	assert_gt(screen.text_label.visible_characters, 0, "It types")
	assert_false(screen.is_line_revealed())
	screen.advance()
	assert_true(screen.is_line_revealed(), "The first Action shows the whole line")
	assert_eq(screen.text_label.text, "A fairly long sentence to type out.")
	screen.advance()
	assert_eq(screen.text_label.text, "Two", "The next Action goes on")
	screen.end()


func test_choices_are_buttons_that_steer_the_conversation() -> void:
	var yes: DialogueChoice = DialogueChoice.new()
	yes.text = "Yes"
	yes.next = 2
	var no: DialogueChoice = DialogueChoice.new()
	no.text = "No"
	no.next = -1
	var ask: DialogueLine = _line("Coming?")
	ask.choices = [yes, no]
	var dialogue: Dialogue = _dialogue([ask, _line("Never shown"), _line("Good", true)])
	watch_signals(screen)
	screen.start(dialogue)
	await wait_process_frames(1)
	assert_eq(screen._choice_buttons.size(), 2)
	assert_eq(screen._choice_buttons[0].text, "Yes")
	assert_true(screen._choice_buttons[0].has_focus(), "The first choice is focused for the pad")
	assert_eq(player.controls.prompt_action_label, "Choose")
	screen.advance()
	assert_eq(screen.text_label.text, "Coming?", "Action does not skip past a choice")
	screen._choice_buttons[1].grab_focus()
	screen._choice_buttons[0].grab_focus()
	var confirm: InputEventAction = InputEventAction.new()
	confirm.action = &"action"
	confirm.pressed = true
	screen._input(confirm)
	assert_signal_emitted(screen, "choice_made")
	assert_eq(screen.text_label.text, "Good", "Action picks the focused choice: Yes jumps where it points")
	screen.advance()
	assert_false(screen.visible)
	screen.start(dialogue)
	await wait_process_frames(1)
	screen._choice_buttons[1].pressed.emit()
	assert_false(screen.visible, "No ends the conversation")


func test_the_pause_button_ends_a_conversation() -> void:
	screen.start(_dialogue([_line("Hello")]))
	watch_signals(screen)
	var event: InputEventAction = InputEventAction.new()
	event.action = &"start"
	event.pressed = true
	screen._input(event)
	assert_false(screen.visible)
	assert_signal_emitted(screen, "dialogue_ended")
	assert_null(screen.dialogue)


func test_conditions_pick_the_line_and_effects_reach_the_quest_log() -> void:
	var quest: Quest = Quest.new()
	quest.id = &"q"
	var objective: QuestObjective = QuestObjective.new()
	objective.id = &"o"
	quest.objectives.append(objective)
	var before: DialogueLine = _line("Before", true)
	before.condition = DialogueLine.Condition.QUEST_NOT_STARTED
	before.condition_quest = quest
	before.starts_quest = quest
	var during: DialogueLine = _line("During", true)
	during.condition = DialogueLine.Condition.QUEST_ACTIVE
	during.condition_quest = quest
	during.progresses_objective = &"o"
	var after: DialogueLine = _line("After", true)
	after.condition = DialogueLine.Condition.QUEST_COMPLETE
	after.condition_quest = quest
	var dialogue: Dialogue = _dialogue([before, during, after])
	var log: QuestLog = player.quest_log
	screen.start(dialogue)
	assert_eq(screen.text_label.text, "Before")
	assert_true(log.is_active(quest), "Showing the line started the quest")
	screen.advance()
	screen.start(dialogue)
	assert_eq(screen.text_label.text, "During")
	assert_true(log.is_complete(quest), "Showing the line met the objective")
	screen.advance()
	screen.start(dialogue)
	assert_eq(screen.text_label.text, "After")
	screen.advance()
	var nothing: Dialogue = _dialogue([before])
	assert_false(screen.start(nothing), "No line applies, nothing opens")
	assert_false(screen.visible)


func test_a_talking_npc_offers_talk_and_opens_its_dialogue() -> void:
	var npc: TalkingNpc = NPC_SCENE.instantiate()
	npc.dialogue = _dialogue([_line("Hi there", true)])
	npc.display_name = "Bob"
	root.add_child(npc)
	npc.global_position = Vector3(0.0, 0.0, -2.0)
	await wait_physics_frames(2)
	watch_signals(npc)
	npc.display_menu(player)
	assert_true(npc.action_prompt.visible, "Looked at, the prompt shows")
	assert_eq(player.controls.prompt_action_label, "Talk")
	npc.hide_menu()
	assert_false(npc.action_prompt.visible)
	npc.equip(player)
	assert_signal_emitted(npc, "talked_to")
	assert_eq(npc.talker, player)
	assert_true(screen.visible)
	assert_eq(screen.speaker_label.text, "Bob")
	assert_eq(screen.speaker_node, npc)
	npc.display_menu(player)
	assert_false(npc.action_prompt.visible, "No prompt mid-conversation")
	screen.advance()
	assert_null(npc.talker, "Let go once the conversation ends")


func test_the_camera_ray_finds_the_talker() -> void:
	var npc: TalkingNpc = NPC_SCENE.instantiate()
	npc.dialogue = _dialogue([_line("Hi there", true)])
	root.add_child(npc)
	npc.global_position = player.global_position + Vector3(0.0, 0.0, -1.5)
	await wait_physics_frames(6)
	assert_eq(player.camera.looking_at, npc, "Standing in front of the NPC, the camera ray lands on them")
	assert_true(npc.action_prompt.visible)


func test_the_demo_guide_walks_the_errand_to_its_reward() -> void:
	var log: QuestLog = player.quest_log
	screen.start(DEMO_DIALOGUE, null, "Guide")
	await wait_process_frames(1)
	assert_true(screen.text_label.text.begins_with("Welcome"), "Before the errand: the greeting")
	assert_eq(screen._choice_buttons.size(), 2)
	screen._choice_buttons[1].pressed.emit()
	assert_false(screen.visible, "Declining ends it")
	assert_false(log.is_active(DEMO_QUEST))
	screen.start(DEMO_DIALOGUE, null, "Guide")
	await wait_process_frames(1)
	screen._choice_buttons[0].pressed.emit()
	assert_true(log.is_active(DEMO_QUEST), "Accepting starts the errand")
	assert_true(log.is_objective_done(DEMO_QUEST, &"talk_guide"))
	assert_true(screen.text_label.text.begins_with("Go for a swim"))
	screen.advance()
	assert_false(screen.visible)
	screen.start(DEMO_DIALOGUE, null, "Guide")
	assert_true(screen.text_label.text.begins_with("The pool"), "Mid-errand: the reminder, never the task line again")
	screen.advance()
	log.progress(&"swim")
	assert_true(log.is_complete(DEMO_QUEST))
	assert_eq(player.inventory.count_of(APPLE), 2)
	screen.start(DEMO_DIALOGUE, null, "Guide")
	assert_true(screen.text_label.text.begins_with("You are dripping"), "Done: the thanks")
	screen.advance()
