extends GutTest

## Purpose: The flight demo is a playable slice in the air: a second Jump in the air takes off into the flying
## state, the rings light in order and count for the quest only in order, the course times the run, and the far
## tower's pad ends it once the rings are done.

const DEMO_SCENE: PackedScene = preload("res://addons/3d_player_controller/scenes/demo/flight/flight_demo.tscn")
const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/flight_rings.tres")

var demo: Node3D
var player: Player
var course: RingCourse


func before_each() -> void:
	demo = DEMO_SCENE.instantiate()
	add_child_autofree(demo)
	await wait_physics_frames(3)
	player = demo.player
	course = demo.course


func after_each() -> void:
	_send(&"jump", false)


func _send(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func test_a_second_jump_in_the_air_takes_off() -> void:
	assert_true(player.enable_flying)
	assert_true(player.quest_log.is_active(QUEST))
	_send(&"jump", true)
	await wait_physics_frames(2)
	_send(&"jump", false)
	await wait_until(func() -> bool: return not player.is_on_floor(), 2.0)
	await wait_seconds(0.2)
	_send(&"jump", true)
	await wait_physics_frames(2)
	_send(&"jump", false)
	await wait_physics_frames(2)
	assert_true(player.is_flying, "Airborne, the second press is a take-off")
	assert_eq(player.current_state, NodeStateMachine.States.FLYING)


func test_rings_count_in_order_and_time_the_run() -> void:
	assert_eq(course.total(), 8)
	var second: Area3D = course.get_child(1)
	course._on_ring_body_entered(player, 1)
	assert_eq(course.next_index, 0, "The second ring first does nothing")
	for i: int in 8:
		course._on_ring_body_entered(player, i)
	assert_true(course.finished)
	assert_gte(demo.best_seconds, 0.0, "Timed")
	assert_eq(player.quest_log.get_count(QUEST, &"pass_ring"), 8)
	demo._on_landing_body_entered(player)
	assert_true(player.quest_log.is_complete(QUEST))
	assert_not_null(second)


func test_the_pad_counts_only_after_the_rings() -> void:
	demo._on_landing_body_entered(player)
	assert_false(demo.landed, "Landing first is no run")
