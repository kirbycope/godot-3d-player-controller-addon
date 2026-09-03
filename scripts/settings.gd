extends CanvasLayer

@export var player: Player

@onready var panel: Panel = $Panel
@onready var audio_button: Button = panel.get_node("VBoxContainer/Audio")
@onready var video_button: Button = panel.get_node("VBoxContainer/Video")
@onready var back_button: Button = panel.get_node("VBoxContainer/BACK")


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process_input(is_multiplayer_authority())


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	# Close settings menu
	if event.is_action_pressed("start") \
	and visible:
		hide_settings()
		get_viewport().set_input_as_handled()


func show_settings() -> void:
	show()
	player.is_paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	audio_button.grab_focus()


func hide_settings() -> void:
	hide()
	player.is_paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_audio_pressed() -> void:
	hide()
	if player and player.audio_settings:
		player.audio_settings.show_settings()


func _on_audio_touch_screen_button_pressed() -> void:
	_on_audio_pressed()


func _on_video_pressed() -> void:
	hide()
	if player and player.video_settings:
		player.video_settings.show_settings()


func _on_video_touch_screen_button_pressed() -> void:
	_on_video_pressed()


## Return to the pause menu.
func _on_back_pressed() -> void:
	hide()
	if player and player.pause:
		player.pause.show_menu()


func _on_back_touch_screen_button_pressed() -> void:
	_on_back_pressed()
