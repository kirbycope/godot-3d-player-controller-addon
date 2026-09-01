class_name WaterSplash
extends Node3D

## One-shot water entry splash: droplet burst plus expanding foam mist.
## Scales with impact_speed and frees itself once particles finish.

@export var impact_speed: float = 5.0 ## Downward entry speed (m/s); scales droplet count and velocity.
@export var max_lifetime: float = 1.6 ## Seconds before the node frees itself.


func _ready() -> void:
	var intensity: float = clampf(impact_speed / 8.0, 0.4, 1.6)
	for particles in find_children("*", "GPUParticles3D", true, false):
		var p: GPUParticles3D = particles as GPUParticles3D
		p.amount_ratio = clampf(intensity, 0.1, 1.0)
		if p.process_material is ParticleProcessMaterial:
			var mat: ParticleProcessMaterial = (p.process_material as ParticleProcessMaterial).duplicate()
			mat.initial_velocity_min *= intensity
			mat.initial_velocity_max *= intensity
			p.process_material = mat
		p.emitting = true
	var timer: SceneTreeTimer = get_tree().create_timer(max_lifetime)
	timer.timeout.connect(queue_free)
