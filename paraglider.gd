extends Node3D

@export var player: Player

@onready var opening: AudioStreamPlayer3D = $Opening
@onready var cloth_ruffling: AudioStreamPlayer3D = $ClothRuffling


## Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	# Do nothing if not the authority
	if not is_multiplayer_authority(): return

	if player.is_paragliding and not visible:
		# Show visual immediately once paragliding starts, then play effects if needed.
		show()
		$LeftWing.visible = true
		$RightWing.visible = true
		if not opening.playing:
			opening.play()
		if not cloth_ruffling.playing:
			cloth_ruffling.play()
	if visible and not player.is_paragliding:
		hide()
		if opening.playing:
			opening.stop()
		if cloth_ruffling.playing:
			cloth_ruffling.stop()
		$LeftWing.visible = false
		$RightWing.visible = false
