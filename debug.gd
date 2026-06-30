extends CanvasLayer

@export var player: Player


## Called when there is an input event.
func _input(event: InputEvent) -> void:
	if player:
		if event.is_action_pressed("debug"):
			visible = !visible


## Called every frame. '_delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if player:
		$States/is_attacking.button_pressed = player.is_attacking
		$States/is_climbing.button_pressed = player.is_climbing
		$States/is_crouching.button_pressed = player.is_crouching
		$States/is_emoting.button_pressed = player.is_emoting
		$States/is_hanging_braced.button_pressed = player.is_hanging_braced
		$States/is_hanging_free.button_pressed = player.is_hanging_free
		$States/is_falling.button_pressed = player.is_falling
		$States/is_focusing.button_pressed = player.is_focusing
		$States/is_jumping.button_pressed = (player.is_jump_queued or player.is_jumping)
		$States/is_paragliding.button_pressed = player.is_paragliding
		$States/is_shooting.button_pressed = player.is_shooting
		$States/is_sliding.button_pressed = player.is_sliding
		$States/is_sprinting.button_pressed = player.is_sprinting

		$Equipment/equipped_axe_1h.button_pressed = player.has_equipment(Equipment.EquipmentType.AXE_1H)
		$Equipment/equipped_axe_2h.button_pressed = player.has_equipment(Equipment.EquipmentType.AXE_2H)
		$Equipment/equipped_bow.button_pressed = player.has_equipment(Equipment.EquipmentType.BOW)
		$Equipment/equipped_dagger.button_pressed = player.has_equipment(Equipment.EquipmentType.DAGGER)
		$Equipment/equipped_shield.button_pressed = player.has_equipment(Equipment.EquipmentType.SWORD_AND_SHIELD)
		$Equipment/equipped_staff.button_pressed = player.has_equipment(Equipment.EquipmentType.STAFF)
		$Equipment/equipped_sword_1h.button_pressed = player.has_equipment(Equipment.EquipmentType.SWORD_1H)
		$Equipment/equipped_sword_2h.button_pressed = player.has_equipment(Equipment.EquipmentType.SWORD_2H)

		$Bow.visible = player.has_equipment(Equipment.EquipmentType.BOW)
		$Bow/is_aiming_bow.button_pressed = player.is_aiming_bow
		$Bow/is_drawing_arrow.button_pressed = player.is_drawing_arrow
		$Bow/is_firing_arrow.button_pressed = player.is_firing_arrow

		$Climbing.visible = player.is_climbing
		$Climbing/is_climbing_on.button_pressed = player.is_climbing_on
		$Climbing/is_climbing_hopping_left.button_pressed = player.is_climbing_hopping_left
		$Climbing/is_climbing_hopping_right.button_pressed = player.is_climbing_hopping_right
		$Climbing/is_climbing_hopping_up.button_pressed = player.is_climbing_hopping_up
		$Climbing/is_hopping_from_climbing.button_pressed = player.is_hopping_from_climbing
