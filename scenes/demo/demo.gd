# Copyright (c) 2026 Antigravity Contributors
# SPDX-License-Identifier: MIT

extends Node3D

## Interactive Demo scene for 3D Player Controller.
## Provides quick-teleport navigation across the sandbox arena
## (Courtyard, Glider Tower, Water Pool, Climbing Wall).
## Detailed player telemetry and toggleable features are available via F3 (Debug HUD).

@onready var player: Player = $Player

# Teleport markers
@onready var marker_courtyard: Marker3D = $Markers/Courtyard
@onready var marker_tower: Marker3D = $Markers/Tower
@onready var marker_pool: Marker3D = $Markers/Pool
@onready var marker_wall: Marker3D = $Markers/ClimbingWall

@onready var water_pool: Area3D = $Structures/PoolBasin/WaterPool


func _ready() -> void:
	if is_instance_valid(player):
		player.enable_paraglider = true
		player.enable_stamina = true


func _on_water_pool_body_entered(body: Node3D) -> void:
	if body is Player:
		(body as Player).enter_water(water_pool)


func _on_water_pool_body_exited(body: Node3D) -> void:
	if body is Player:
		(body as Player).exit_water(water_pool)


func _on_teleport_courtyard_pressed() -> void:
	if is_instance_valid(%TeleportCourtyard):
		%TeleportCourtyard.release_focus()
	_teleport_player(marker_courtyard)


func _on_teleport_tower_pressed() -> void:
	if is_instance_valid(%TeleportTower):
		%TeleportTower.release_focus()
	_teleport_player(marker_tower)


func _on_teleport_pool_pressed() -> void:
	if is_instance_valid(%TeleportPool):
		%TeleportPool.release_focus()
	_teleport_player(marker_pool)


func _on_teleport_wall_pressed() -> void:
	if is_instance_valid(%TeleportWall):
		%TeleportWall.release_focus()
	_teleport_player(marker_wall)


func _teleport_player(marker: Marker3D) -> void:
	if not is_instance_valid(player) or not is_instance_valid(marker):
		return
	player.is_navigating = false
	if player.navigation_agent:
		player.navigation_agent.target_position = marker.global_position
	player.global_position = marker.global_position
	player.velocity = Vector3.ZERO

