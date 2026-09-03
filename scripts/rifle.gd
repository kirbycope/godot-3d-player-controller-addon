class_name Rifle
extends Equipment
## Loops the "RifleFiringStanding" spine emote while the Player holds shoot.
##
## Shooting is a held input with no signal, so the equipped copy polls [member Player.is_shooting].

const FIRING_EMOTE: StringName = &"RifleFiringStanding"


func _ready() -> void:
	set_physics_process(false)
	if player and player.is_multiplayer_authority():
		player.inventory.equipment_changed.connect(_on_equipment_changed)


## Only the equipped rifle drives the emote.
func _on_equipment_changed() -> void:
	set_physics_process(player.inventory.equipment.has(self))


func _physics_process(_delta: float) -> void:
	var emote_state: AnimationNodeStateMachinePlayback = player.animation_tree.get(Player.EMOTE_STATE_PLAYBACK_PATH)
	var emote_node: StringName = emote_state.get_current_node()
	if player.is_shooting:
		player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 1.0)
		# The firing clip auto-advances to the aiming idle; restart it while shoot is held.
		if emote_node != FIRING_EMOTE:
			emote_state.start(FIRING_EMOTE)
	elif emote_node == FIRING_EMOTE or emote_node == &"RifleAimingStandingIdle":
		player.animation_tree.set("parameters/EmoteSpineBlend2/blend_amount", 0.0)
		emote_state.start("Idle")
