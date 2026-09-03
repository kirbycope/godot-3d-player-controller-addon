extends CanvasLayer
## Speedometer shown while the Player is in the DRIVING state.

const NEEDLE_MIN_DEGREES: float = -132.5 ## Needle rotation at zero speed.
const NEEDLE_SWEEP_DEGREES: float = 265.0 ## Needle travel from zero to [member speedometer_max_speed].
const MPS_TO_MPH: float = 2.23694

@export var player: Player
@export var speedometer_max_speed: float = 120.0 ## Speed (mph) at which the needle tops out.

@onready var speedometer_needle: TextureRect = $Speedometer/Needle


func _ready() -> void:
	set_process(false)


## Wired to Player.state_changed in player.tscn.
func _on_player_state_changed(_from_state: int, to_state: int) -> void:
	visible = to_state == NodeStateMachine.States.DRIVING
	set_process(visible)
	speedometer_needle.rotation_degrees = NEEDLE_MIN_DEGREES


func _process(_delta: float) -> void:
	var car: RigidBody3D = player.is_driving_in as RigidBody3D
	if car == null:
		return
	var speed_mph: float = car.linear_velocity.length() * MPS_TO_MPH
	speedometer_needle.rotation_degrees = clampf(
		NEEDLE_MIN_DEGREES + speed_mph / speedometer_max_speed * NEEDLE_SWEEP_DEGREES,
		NEEDLE_MIN_DEGREES, -NEEDLE_MIN_DEGREES)
