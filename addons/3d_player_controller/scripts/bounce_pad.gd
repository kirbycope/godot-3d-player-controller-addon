class_name BouncePad
extends Area3D
## A spring, a mushroom cap, a trampoline: a [Player] landing in this area is thrown up at [member bounce_speed].
## [signal bounced] is for the scene, a squash on the cap or a sound.

signal bounced(player: Player)

@export var bounce_speed: float = 12.0


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or not player.is_multiplayer_authority():
		return
	player.bounce(bounce_speed)
	bounced.emit(player)
