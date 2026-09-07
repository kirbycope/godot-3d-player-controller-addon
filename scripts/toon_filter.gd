class_name ToonFilter
extends MeshInstance3D
## Screen-space toon shading: a full-screen quad under the Player's camera that posterises the opaque scene into a
## few luminance bands and inks outlines where the depth buffer jumps. It reads only the screen and depth textures,
## so it runs in every renderer, and it is drawn in the 3D pass, so every CanvasLayer (the HUD, the menus) sits above
## it and only the current camera draws it. Purely local: a video setting kept in [PlayerSettingsResource], never
## replicated. Toggled by the "toggle_toon" action ([F6]) or the Video settings' "Toon shading" switch.

signal toggled(enabled: bool) ## The filter went on or off, by the key or the setting.

@export var enabled: bool = false: ## Shows or hides the filter; the saved setting overrides this at start.
	set(value):
		enabled = value
		visible = value
		toggled.emit(value)


func _ready() -> void:
	set_process_unhandled_input(is_multiplayer_authority())
	enabled = PlayerSettingsResource.load_or_create().toon_enabled


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_toon"):
		toggle()
		get_viewport().set_input_as_handled()


## Flips the filter and saves the choice with the other video settings.
func toggle() -> void:
	enabled = not enabled
	var settings: PlayerSettingsResource = PlayerSettingsResource.load_or_create()
	settings.toon_enabled = enabled
	settings.save()
