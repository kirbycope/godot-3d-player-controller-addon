extends Node3D

@export var player: Player

@onready var footstep_grass: AudioStreamPlayer3D = $FootstepGrass
@onready var footstep_metal: AudioStreamPlayer3D = $FootstepMetal
@onready var footstep_mud: AudioStreamPlayer3D = $FootstepMud
@onready var footstep_sand: AudioStreamPlayer3D = $FootstepSand
@onready var footstep_stone: AudioStreamPlayer3D = $FootstepStone
@onready var footstep_water: AudioStreamPlayer3D = $FootstepWater
@onready var footstep_wood: AudioStreamPlayer3D = $FootstepWood
@onready var sneak_step: AudioStreamPlayer3D = $SneakStep
@onready var voice_male_effort_grunt: AudioStreamPlayer3D = $VoiceMaleEffortGrunt
@onready var voice_male_breathing_jog: AudioStreamPlayer3D = $VoiceMaleBreathingJog
@onready var voice_male_breathing_run: AudioStreamPlayer3D = $VoiceMaleBreathingRun
@onready var voice_male_breathing_walk: AudioStreamPlayer3D = $VoiceMaleBreathingWalk
@onready var voice_male_grunt_pain: AudioStreamPlayer3D = $VoiceMaleGruntPain

var cached_velocity: Vector3
var was_on_the_floor: bool


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if player.is_exhausted:
		if abs(player.velocity.length()) > 0.2:
			if not voice_male_breathing_run.playing:
				voice_male_breathing_run.play()
			if voice_male_breathing_walk.playing:
				voice_male_breathing_walk.stop()
		else:
			if not voice_male_breathing_walk.playing:
				voice_male_breathing_walk.play()
			if voice_male_breathing_run.playing:
				voice_male_breathing_run.stop()
	else:
		if voice_male_breathing_run.playing:
			voice_male_breathing_run.stop()
		if voice_male_breathing_walk.playing:
			voice_male_breathing_walk.stop()

	if not was_on_the_floor and player.is_on_floor():
		if not voice_male_grunt_pain.playing \
		and abs(cached_velocity.length()) > 10:
			voice_male_grunt_pain.play()

	was_on_the_floor = player.is_on_floor()
	cached_velocity = player.velocity


func check_under_player():
	if was_on_the_floor and cached_velocity.length() > 0.2:
		if player.raycast_below_step.is_colliding():
			if player.is_crouching:
				stop_all_footstep_sounds()
				sneak_step.play()
			else:
				var stepping_on = player.raycast_below_step.get_collider()
				if stepping_on.has_meta("step_sound"):
					var step_sound = stepping_on.get_meta("step_sound")
					if step_sound:
						stop_all_footstep_sounds()
						if step_sound.to_lower() == "grass":
							footstep_grass.play()
						elif step_sound.to_lower() == "stone":
							footstep_stone.play()
				else:
					# Stop all footstep sounds if none is defined for the surface
					stop_all_footstep_sounds()


func stop_all_footstep_sounds():
	footstep_grass.stop()
	footstep_metal.stop()
	footstep_mud.stop()
	footstep_sand.stop()
	footstep_stone.stop()
	footstep_water.stop()
	footstep_wood.stop()
	sneak_step.stop()
