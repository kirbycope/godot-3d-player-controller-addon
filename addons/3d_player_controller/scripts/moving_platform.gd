class_name MovingPlatform
extends AnimatableBody3D
## A platform that slides back and forth between where it starts and [member travel] away, over [member seconds]
## each way with [member pause] at the ends; [code]sync_to_physics[/code] carries whoever stands on it.

@export var travel: Vector3 = Vector3(0.0, 0.0, -8.0) ## The far end, relative to the start.
@export var seconds: float = 3.0 ## One way.
@export var pause: float = 0.6 ## Held at each end.
@export var start_paused: bool = false ## Waits for [method run] instead of setting off on ready.

var _tween: Tween


func _ready() -> void:
	sync_to_physics = true
	if not start_paused:
		run()


## Sets off, and keeps going.
func run() -> void:
	if _tween:
		_tween.kill()
	var start: Vector3 = global_position
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "global_position", start + travel, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_interval(pause)
	_tween.tween_property(self, "global_position", start, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_interval(pause)
