# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

extends Node3D

## Interactive Demo scene for 3D Player Controller.
## Provides quick-teleport navigation across the sandbox arena
## (Courtyard, Glider Tower, Water Pool, Climbing Wall).
## Detailed player telemetry and toggleable features are available via F3 (Debug HUD).

@onready var player: Player = $Player
@onready var water_pool: Area3D = $Structures/PoolBasin/WaterPool


func _ready() -> void:
	if is_instance_valid(player):
		player.enable_paraglider = true
		player.enable_stamina = true
		player.state_changed.connect(_on_player_state_changed)


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


## Opens one of the gameplay-style demos bound in the scene's button connection.
func _on_demo_pressed(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
