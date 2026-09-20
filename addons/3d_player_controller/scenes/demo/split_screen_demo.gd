extends Node3D
## The demo arena for two on one screen: the demo scene without its own Player, and a SplitScreen over it with
## two Players, one on each pad.

const DEMO_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/demo/demo.tscn")

@onready var split_screen: SplitScreen = $SplitScreen


func _ready() -> void:
	var arena: Node3D = DEMO_SCENE.instantiate()
	# The arena's own Player and teleport panel make way for the two views
	arena.set_script(null)
	arena.get_node("Player").free()
	arena.get_node("HUD").free()
	add_child(arena)
	move_child(arena, 0)
	split_screen.spawn()
	for i: int in split_screen.players.size():
		split_screen.players[i].global_position = Vector3(-2.0 + 4.0 * i, 0.5, 4.0)
		split_screen.players[i].enable_paraglider = true
		split_screen.players[i].enable_stamina = true
		# Half a screen each is too little for the whole button set: only the contextual hints, whatever the
		# saved On-Screen setting says (this is a pads-only arena, so the buttons are known anyway)
		split_screen.players[i].hud_mode_override = PlayerSettingsResource.HudMode.AUTO
