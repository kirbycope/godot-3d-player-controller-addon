# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

extends Node3D

## Interactive Demo scene for 3D Player Controller.
## Provides quick-teleport navigation across the sandbox arena
## (Courtyard, Glider Tower, Water Pool, Climbing Wall).
## Detailed player telemetry and toggleable features are available via F3 (Debug HUD).

const GUIDE_ERRAND: Quest = preload("res://addons/3d_player_controller/resources/quests/demo_errand.tres")

@onready var player: Player = $Player
@onready var guide: TalkingNpc = $Guide
@onready var water_pool: Area3D = $Structures/PoolBasin/WaterPool


func _ready() -> void:
	if is_instance_valid(player):
		player.enable_paraglider = true
		player.enable_stamina = true
		player.state_changed.connect(_on_player_state_changed)


## Talking to the Guide is the errand's first objective and, the first time, what starts it. The addon has no
## dialogue of its own (a game brings its own, Dialogic say), so the talk is over as soon as it begins.
func _on_guide_talked_to(who: Player) -> void:
	if who.quest_log:
		who.quest_log.start(GUIDE_ERRAND)
		who.quest_log.progress(&"talk_guide")
	guide.end_talk()


## The Guide's errand asks for a swim: entering the water reports it to the quest log.
func _on_player_state_changed(_from_state: int, to_state: int) -> void:
	if to_state == NodeStateMachine.States.SWIMMING and player.quest_log:
		player.quest_log.progress(&"swim")


func _on_water_pool_body_entered(body: Node3D) -> void:
	if body is Player:
		(body as Player).enter_water(water_pool)


func _on_water_pool_body_exited(body: Node3D) -> void:
	if body is Player:
		(body as Player).exit_water(water_pool)


## Teleports the player to the marker bound in the scene's button connection.
func _on_teleport_pressed(marker_path: NodePath) -> void:
	var marker: Marker3D = get_node(marker_path) as Marker3D
	if not is_instance_valid(player) or marker == null:
		return
	player.is_navigating = false
	player.navigation_agent.target_position = marker.global_position
	player.global_position = marker.global_position
	player.velocity = Vector3.ZERO
