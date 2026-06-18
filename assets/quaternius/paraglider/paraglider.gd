extends Node3D

@export var player: Player
@export var paragliding_state_name: String = "Paragliding"

@onready var opening: AudioStreamPlayer3D = $Opening
@onready var cloth_ruffling: AudioStreamPlayer3D = $ClothRuffling


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if not visible:
		if player.is_jumping and Input.is_action_just_pressed("jump"):
			player.locomotion_state.travel("Paragliding")
			player.is_jumping = false
			player.velocity.y = min(player.velocity.y, 0.0)
			player.is_paragliding = true
			if not opening.playing:
				opening.play()
				await get_tree().create_timer(0.2).timeout
				show()
				if not cloth_ruffling.playing: 
					cloth_ruffling.play()
				await get_tree().create_timer(0.3).timeout
				$LeftWing.visible = true
				$RightWing.visible = true
	if visible and player.is_on_floor():
		player.is_paragliding = false
		hide()
		if opening.playing:
			opening.stop()
		if cloth_ruffling.playing:
			cloth_ruffling.stop()
		$LeftWing.visible = false
		$RightWing.visible = false
