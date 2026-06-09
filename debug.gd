extends CanvasLayer

@export var player: Player


## Called every frame. '_delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if player:
		$States/is_crouching.button_pressed = player.is_crouching
		$States/is_falling.button_pressed = player.is_falling
		$States/is_focusing.button_pressed = player.is_focusing
		$States/is_jumping.button_pressed = (player.is_jump_queued or player.is_jumping)
		$States/is_shooting.button_pressed = player.is_shooting
		$States/is_sliding.button_pressed = player.is_sliding
		$States/is_sprinting.button_pressed = player.is_sprinting

		$Equipment/equipped_axe_1h.button_pressed = player.equipped_axe_1h
		$Equipment/equipped_axe_2h.button_pressed = player.equipped_axe_2h
		$Equipment/equipped_bow.button_pressed = player.equipped_bow
		$Equipment/equipped_dagger.button_pressed = player.equipped_dagger
		$Equipment/equipped_shield.button_pressed = player.equipped_shield
		$Equipment/equipped_staff.button_pressed = player.equipped_staff
		$Equipment/equipped_sword_1h.button_pressed = player.equipped_sword_1h
		$Equipment/equipped_sword_2h.button_pressed = player.equipped_sword_2h

		$Bow.visible = player.equipped_bow
		$Bow/is_aiming_bow.button_pressed = player.is_aiming_bow
		$Bow/is_drawing_arrow.button_pressed = player.is_drawing_arrow
		$Bow/is_firing_arrow.button_pressed = player.is_firing_arrow
