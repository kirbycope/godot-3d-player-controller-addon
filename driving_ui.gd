extends CanvasLayer

@export var player: Player
@export var speedometer_max_speed: float = 120

@onready var speedometer_guage: TextureRect = $Speedometer/Guage
@onready var speedometer_needle: TextureRect = $Speedometer/Needle

## NOTES
# -132.5 is the rotation of the needle when linear velocity is near 0
# 132.5 is the max rotation of the needgle (when the speed gets so high the guage tops out)

func _process(delta: float) -> void:
	if player and player.is_driving_in and not player.is_entering_vehicle and not player.is_exiting_vehicle:
		if not visible:
			show()
		var speed_mps = player.is_driving_in.linear_velocity.length()
		var speed_mph = speed_mps * 2.23694
		speedometer_needle.rotation_degrees = clampf(speed_mph / speedometer_max_speed * 265.0 - 132.5, -132.5, 132.5)
	else:
		if visible:
			hide()
		speedometer_needle.rotation_degrees = -132.5
