class_name Audio
extends Node3D

@export var player: Player

@onready var sfx_footsteps_dirt: AudioStreamPlayer3D = $SFX_Footsteps_Dirt
@onready var sfx_footsteps_grass: AudioStreamPlayer3D = $SFX_Footsteps_Grass
@onready var sfx_footsteps_slide: AudioStreamPlayer3D = $SFX_Footsteps_Slide
@onready var sfx_footsteps_stone: AudioStreamPlayer3D = $SFX_Footsteps_Stone
@onready var sfx_footsteps_water: AudioStreamPlayer3D = $SFX_Footsteps_Water
@onready var sfx_footsteps_wood: AudioStreamPlayer3D = $SFX_Footsteps_Wood


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_process(is_multiplayer_authority())
	set_physics_process(is_multiplayer_authority())
	set_process_input(is_multiplayer_authority())


## Play surface-aware footstep audio based on collider groups or meta.
func play_footstep(collider: Node3D = null) -> void:
	if not collider and player and player.paraglider_raycast and player.paraglider_raycast.is_colliding():
		collider = player.paraglider_raycast.get_collider() as Node3D

	if collider:
		if collider.is_in_group("DIRT") or collider.is_in_group("GRASS"):
			sfx_footsteps_grass.play()
		elif collider.is_in_group("COBBLESTONE") or collider.is_in_group("CONCRETE") or collider.is_in_group("STONE"):
			sfx_footsteps_stone.play()
		elif collider.is_in_group("WOOD"):
			sfx_footsteps_wood.play()
		elif collider.is_in_group("WATER"):
			sfx_footsteps_water.play()
		else:
			sfx_footsteps_stone.play()
	else:
		sfx_footsteps_stone.play()


## Play slide footstep sound.
func play_slide(_collider: Node3D = null) -> void:
	sfx_footsteps_slide.play()


## Update volume on all footstep AudioStreamPlayer3D nodes and vehicles.
func set_sfx_volume(value: float) -> void:
	var db = linear_to_db(value / 100.0) if value > 0.0 else -80.0
	for child in get_children():
		if child is AudioStreamPlayer3D:
			child.volume_db = db

	if is_inside_tree():
		for vehicle in get_tree().get_nodes_in_group("vehicles"):
			if vehicle.has_method("set_sfx_volume"):
				vehicle.set_sfx_volume(value)
			else:
				for player_node in vehicle.find_children("*", "AudioStreamPlayer3D", true, false):
					if player_node is AudioStreamPlayer3D:
						player_node.volume_db = db


## Update volume on RadiOtPlayer3D node under player or in scene tree.
func set_music_volume(value: float) -> void:
	var linear_vol: float = clampf(value / 100.0, 0.0, 1.0)
	var db: float = linear_to_db(linear_vol) if linear_vol > 0.0 else -80.0

	var radio_nodes: Array[Node] = []
	if player:
		var radio = player.get_node_or_null("RadiOtPlayer3D")
		if not radio:
			radio = player.find_child("RadiOtPlayer3D", true, false)
		if radio:
			radio_nodes.append(radio)

	if is_inside_tree():
		for r in get_tree().root.find_children("*", "RadiOtPlayer3D", true, false):
			if not r in radio_nodes:
				radio_nodes.append(r)

	for radio in radio_nodes:
		if radio.has_method("set_volume"):
			radio.set_volume(linear_vol)
		else:
			if "volume_db" in radio:
				radio.volume_db = db
			var streamer = radio.get_node_or_null("RadiOtStreamer")
			if streamer and streamer.has_method("set_volume"):
				streamer.set_volume(linear_vol)
