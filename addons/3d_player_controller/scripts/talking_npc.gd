class_name TalkingNpc
extends FollowerNpc
## Somebody to talk to. Walk up to them (or look at them) and the prompt offers Talk; Action opens their [member dialogue] in the
## Player's [DialogueScreen], and they turn to face whoever is talking to them until it ends. Left with no
## [member FollowerNpc.player] they stand where they are; given one they follow, as any FollowerNpc does. The
## walk and run blend replicates like the enemy's. [signal talked_to] is for a game that wants to know.

signal talked_to(player: Player) ## A conversation with [param player] began.

const LOCOMOTION_BLEND_PATH: String = "parameters/blend_position"

@export var display_name: String = "Villager" ## Who the dialogue box says is speaking, for lines with no speaker of their own.
@export var dialogue: Dialogue
@export var prompt_label: String = "Talk" ## What the bottom-action button reads while the prompt is up.
@export var faces_talker: bool = true ## Turns on the spot to face whoever they are attending to, yaw only; the head modifier does the rest.
@export var head_tracks_player: bool = true ## Turns the head alone to the Player's own head, on top of whatever the body is doing.

var talker: Player ## Who is in conversation with this NPC, while one is.
var _attention: Player ## Who this NPC has noticed: the one being offered a prompt, or the one being talked to.
var _control_speed: float = 0.0
var locomotion_blend: float = 0.0: ## Replicated: 0 idle, 0.5 walk, 1 run.
	set(value):
		locomotion_blend = value
		if animation_tree:
			animation_tree.set(LOCOMOTION_BLEND_PATH, value)

@onready var mannequin: Node3D = $Mannequin_M
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var action_prompt: ActionPrompt = $ActionPrompt
@onready var head_look_at_modifier: LookAtModifier3D = $Mannequin_M/Armature/GeneralSkeleton/HeadLookAtModifier3D ## Turns the head alone; the body's yaw is [method _face].


func _ready() -> void:
	super()
	animation_tree.active = true


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
	var attending: Player = talker if talker else _attention
	if attending and is_instance_valid(attending) and faces_talker:
		# Yaw only. The body turns on the spot and the head modifier carries the pitch, so an NPC looking at a
		# Player on a step above them tips their head rather than leaning the whole torso back.
		_face(attending.global_position, delta)
	if talker:
		_stop_moving()
		_update_locomotion()
		return
	super(delta)
	_update_locomotion()


## Called by [Camera] when this NPC is the one thing the action button would act on. Being the chosen one is
## also when they notice you: they turn to face you and their head comes up, which is the clearest sign of
## which of a crowd is about to be talked to.
func display_menu(looking: Player) -> void:
	if talker or dialogue == null:
		return
	action_prompt.show_for(looking.controls, prompt_label)
	notice(looking)


## Turns this NPC's attention to [param who], or lets go when null: the body turns to face them and the head
## modifier tracks their head. Public so a scene can have somebody watch a Player without a prompt.
func notice(who: Player) -> void:
	_attention = who
	if head_look_at_modifier == null:
		return
	var head: Node3D = who.head_attachment if who and is_instance_valid(who) else null
	if head and head_tracks_player:
		head_look_at_modifier.target_node = head_look_at_modifier.get_path_to(head)
		head_look_at_modifier.active = true
	else:
		head_look_at_modifier.target_node = NodePath("")
		head_look_at_modifier.active = false


## Called by [Camera] when they are not.
func hide_menu() -> void:
	for looking: Node in get_tree().get_nodes_in_group(&"Player"):
		if looking is Player and (looking as Player).controls:
			action_prompt.hide_for((looking as Player).controls)
	action_prompt.hide()
	if talker == null:
		notice(null)


## The Camera's Action hook: talk to whoever pressed it.
func equip(who: Player) -> void:
	talk(who)


## Opens [member dialogue] with [param who]; false when there is nothing to say right now.
func talk(who: Player) -> bool:
	if talker or dialogue == null or who == null or who.dialogue_screen == null:
		return false
	hide_menu()
	if not who.dialogue_screen.start(dialogue, self, display_name):
		return false
	talker = who
	notice(who)
	who.dialogue_screen.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	talked_to.emit(who)
	return true


func _on_dialogue_ended(_dialogue: Dialogue) -> void:
	var was: Player = talker
	talker = null
	# The Camera holds the target across the conversation, so the prompt comes back for whoever was talking
	if was and is_instance_valid(was) and (was.camera as Camera) and (was.camera as Camera).interaction_target == self:
		display_menu(was)
	else:
		notice(null)


func _face(target: Vector3, delta: float) -> void:
	var to_target: Vector3 = (target - global_position).slide(up_direction)
	if to_target.length_squared() > 0.001:
		var wanted: Transform3D = global_transform.looking_at(global_position + to_target.normalized(), up_direction)
		global_transform = global_transform.interpolate_with(wanted, turn_speed * delta)


## Root motion moves the body, as it does the enemy: the navigation's wish picks the clip, the Root bone carries it.
func _move_with_control(control_velocity: Vector3) -> void:
	_control_speed = control_velocity.slide(up_direction).length()
	if is_on_floor() and not is_swimming:
		control_velocity = (mannequin.global_basis * animation_tree.get_root_motion_position() / get_physics_process_delta_time()).slide(up_direction)
	super(control_velocity)


func _update_locomotion() -> void:
	var wanted_blend: float = 0.0
	if _control_speed > 0.05:
		if walk_speed > 0.0 and _control_speed <= walk_speed:
			wanted_blend = _control_speed / walk_speed * 0.5
		else:
			wanted_blend = 0.5 + clampf((_control_speed - walk_speed) / maxf(move_speed - walk_speed, 0.001), 0.0, 1.0) * 0.5
	locomotion_blend = move_toward(locomotion_blend, wanted_blend, (8.0 if wanted_blend < locomotion_blend else 6.0) * get_physics_process_delta_time())


func sfx_footsteps_play() -> void:
	pass
