extends Node3D

@export var player: Player

@onready var opening: AudioStreamPlayer3D = $Opening
@onready var cloth_ruffling: AudioStreamPlayer3D = $ClothRuffling


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if not visible:
		if (player.is_falling) or (player.is_jumping and not player.is_jump_queued) \
		and Input.is_action_just_pressed("jump") \
		and not player.paraglider_raycast.is_colliding():
			# Stop "falling"/"jumping"
			player.is_falling = false
			player.is_jumping = false
			# Start "paragliding"
			player.state_machine.travel(NodeStateMachine.States.PARAGLIDING)
			# Start "paragliding" audio and visuals
			if not opening.playing:
				opening.play()
				await get_tree().create_timer(0.2).timeout
				show()
				if not cloth_ruffling.playing: 
					cloth_ruffling.play()
				await get_tree().create_timer(0.3).timeout
				$LeftWing.visible = true
				$RightWing.visible = true
	if visible and not player.is_paragliding:
		hide()
		if opening.playing:
			opening.stop()
		if cloth_ruffling.playing:
			cloth_ruffling.stop()
		$LeftWing.visible = false
		$RightWing.visible = false
