extends Node3D

@export var player: Player

@onready var footsteps: AudioStreamPlayer3D = $Footsteps
@onready var voice_male_effort_grunt: AudioStreamPlayer3D = $VoiceMaleEffortGrunt
@onready var voice_male_breathing_jog: AudioStreamPlayer3D = $VoiceMaleBreathingJog
@onready var voice_male_breathing_run: AudioStreamPlayer3D = $VoiceMaleBreathingRun
@onready var voice_male_grunt_pain: AudioStreamPlayer3D = $VoiceMaleGruntPain

var cached_velocity: Vector3
var was_on_the_floor: bool

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


## Called every frame. '_delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player.is_sprinting:
		if not voice_male_breathing_run.playing:
			voice_male_breathing_run.play()
	elif voice_male_breathing_run.playing:
		voice_male_breathing_run.stop()

	if not was_on_the_floor and player.is_on_floor():
		if not voice_male_grunt_pain.playing \
		and abs(cached_velocity.length()) > 10:
			voice_male_grunt_pain.play()

	was_on_the_floor = player.is_on_floor()
	cached_velocity = player.velocity
