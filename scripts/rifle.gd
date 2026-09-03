class_name Rifle
extends Firearm
## A [Firearm] that also loops the "RifleFiringStanding" spine emote while the Player holds shoot.

const FIRING_EMOTE: StringName = &"RifleFiringStanding"


func _physics_process(delta: float) -> void:
	super(delta)
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
