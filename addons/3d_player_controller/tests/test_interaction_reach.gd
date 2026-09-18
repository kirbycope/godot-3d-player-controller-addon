extends GutTest

## Purpose: One thing at a time answers the action button. The camera ray picks it out of a crowd, the nearest
## thing in reach takes over when the ray finds nothing, an InteractionReach means the ray alone is not enough,
## and only the chosen one shows a prompt.

const PLAYER_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/player.tscn")
const NPC_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/talking_npc.tscn")

var root: Node3D
var player: Player
var camera: Camera


func before_each() -> void:
	root = Node3D.new()
	add_child_autofree(root)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	player = PLAYER_SCENE.instantiate()
	root.add_child(player)
	camera = player.camera as Camera
	# The idle animation's root motion walks the Player about 0.7m off its spawn, in a different direction each
	# run, and everything here is placed relative to where it stands. So let it settle, then hold it still: the
	# Camera keeps its own _physics_process and goes on resolving the ray either way.
	await wait_physics_frames(8)
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO


## An NPC with something to say, [param offset] from the Player.
func _npc(offset: Vector3) -> TalkingNpc:
	var npc: TalkingNpc = NPC_SCENE.instantiate()
	var line: DialogueLine = DialogueLine.new()
	line.text = "Hello"
	line.ends_dialogue = true
	var dialogue: Dialogue = Dialogue.new()
	dialogue.lines = [line]
	npc.dialogue = dialogue
	root.add_child(npc)
	npc.global_position = player.global_position + offset
	return npc


func _prompts_up(of: Array) -> int:
	var count: int = 0
	for node: Node in of:
		if (node as Node3D).get_node("ActionPrompt").visible:
			count += 1
	return count


func test_a_crowd_offers_one_prompt_and_it_is_the_one_under_the_ray() -> void:
	var left: TalkingNpc = _npc(Vector3(-0.9, 0.0, -1.2))
	var middle: TalkingNpc = _npc(Vector3(0.0, 0.0, -1.2))
	var right: TalkingNpc = _npc(Vector3(0.9, 0.0, -1.2))
	await wait_physics_frames(4)

	assert_eq(camera.interaction_target, middle, "The one being looked at is the one that answers")
	assert_eq(_prompts_up([left, middle, right]), 1, "Three NPCs shoulder to shoulder, one prompt")
	assert_true(middle.action_prompt.visible, "and it belongs to the one in the middle")


func test_the_action_talks_to_the_one_under_the_ray_and_not_its_neighbours() -> void:
	var left: TalkingNpc = _npc(Vector3(-0.9, 0.0, -1.2))
	var middle: TalkingNpc = _npc(Vector3(0.0, 0.0, -1.2))
	await wait_physics_frames(4)
	assert_eq(camera.interaction_target, middle, "Set up looking at the middle one")

	camera.interaction_target.equip(player)

	assert_eq(middle.talker, player, "The one being looked at is talked to")
	assert_null(left.talker, "The one beside them is not")


func test_the_nearest_in_reach_takes_over_when_the_ray_finds_nothing() -> void:
	var beside: TalkingNpc = _npc(Vector3(1.0, 0.0, 0.2))
	var further: TalkingNpc = _npc(Vector3(-1.4, 0.0, 0.2))
	await wait_physics_frames(4)

	assert_null(camera.looking_at, "Nobody is under the ray, they are off to the sides")
	assert_eq(camera.interaction_target, beside, "So the nearest one in reach is offered instead")
	assert_eq(_prompts_up([beside, further]), 1, "Still only one prompt")


func test_an_npc_under_the_ray_but_out_of_reach_is_not_offered() -> void:
	var far_off: TalkingNpc = _npc(Vector3(0.0, 0.0, -2.6))
	await wait_physics_frames(4)

	assert_eq(camera.looking_at, far_off, "The ray still reaches them at 2.6m")
	assert_null(camera.interaction_target, "but talking wants arm's length, so nothing is offered")
	assert_false(far_off.action_prompt.visible, "and no prompt floats over them")


func test_something_with_no_reach_is_still_offered_by_the_ray_alone() -> void:
	var board: RayOnly = RayOnly.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.0, 2.0, 1.0)
	shape.shape = box
	board.add_child(shape)
	root.add_child(board)
	board.global_position = player.global_position + Vector3(0.0, 1.0, -2.4)
	await wait_physics_frames(4)

	assert_eq(camera.interaction_target, board, "A computer or a skateboard has no reach volume, so the ray alone is enough")
	assert_eq(board.shown_for, player, "and it is the one asked to show a prompt")


func test_walking_out_of_reach_clears_the_offer() -> void:
	var npc: TalkingNpc = _npc(Vector3(0.0, 0.0, -1.2))
	await wait_physics_frames(4)
	assert_eq(camera.interaction_target, npc, "Offered while standing by them")

	npc.global_position = player.global_position + Vector3(0.0, 0.0, -20.0)
	await wait_physics_frames(4)

	assert_null(camera.interaction_target, "Walk away and nothing is offered")
	assert_false(npc.action_prompt.visible, "and the prompt goes with it")


## A stand-in for the things reachable by the camera ray alone, with no InteractionReach on them.
class RayOnly:
	extends StaticBody3D

	var shown_for: Player = null

	func display_menu(who: Player) -> void:
		shown_for = who

	func hide_menu() -> void:
		shown_for = null

	func equip(_who: Player) -> void:
		pass
