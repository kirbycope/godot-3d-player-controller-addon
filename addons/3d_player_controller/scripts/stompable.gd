class_name Stompable
extends Area3D
## A head that can be jumped on, platformer style: a [Player] landing on this area from above while falling deals
## [member damage] to [member enemy] and is bounced back up at [member bounce_speed]. Put it on an [EnemyNpc] at
## head height with a mask that sees the Player; walking into it from the side does nothing.

signal stomped(player: Player)

@export var enemy: EnemyNpc ## Who takes the hit; the parent when empty.
@export var damage: float = 100.0
@export var bounce_speed: float = 8.0
@export var falling_speed: float = 0.5 ## The Player has to be coming down at least this fast.


func _ready() -> void:
	if enemy == null:
		enemy = get_parent() as EnemyNpc
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or not player.is_multiplayer_authority() or enemy == null or enemy.is_dead:
		return
	var coming_down: float = -player.velocity.dot(player.up_direction)
	if coming_down < falling_speed:
		return
	enemy.take_hit(damage, player.global_position)
	player.bounce(bounce_speed)
	stomped.emit(player)
