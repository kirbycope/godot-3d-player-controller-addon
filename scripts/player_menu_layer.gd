class_name PlayerMenuLayer
extends CanvasLayer
## Base for the pause, settings and lobby menus: pauses the [Player] while shown and closes on the "start" action.

@export var player: Player
@export var focus_on_show: Control ## Control that receives focus when the menu opens.


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process_input(is_multiplayer_authority())


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("start") and visible:
		hide_menu()
		get_viewport().set_input_as_handled()


func show_menu() -> void:
	show()
	if player:
		player.is_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if focus_on_show:
		focus_on_show.grab_focus()


func hide_menu() -> void:
	hide()
	if player:
		player.is_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
