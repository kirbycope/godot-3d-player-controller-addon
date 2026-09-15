extends DemoScene
## The flight style: the Player's flying state ([member Player.enable_flying]) over a downtown skyline, a course
## of rings that light up one at a time ([RingCourse]) with the run timed, and a tower to set down on at the far
## end. Jump, then jump again in the air to take off; the stick flies, Jump climbs, Action dives, Sprint goes fast,
## and a double tap of Action lands.

const QUEST: Quest = preload("res://addons/3d_player_controller/resources/quests/flight_rings.tres")

@export var course: RingCourse
@export var landing: Area3D

var best_seconds: float = -1.0
var landed: bool = false


func setup_player(target: Player) -> void:
	target.enable_flying = true
	target.enable_stamina = false
	target.lethal_fall_speed = 1000.0 # a fall from the course is a respawn at the pad, not a ragdoll on the street
	course.ring_passed.connect(_on_ring_passed)
	course.course_finished.connect(_on_course_finished)
	if target.quest_log:
		target.quest_log.start(QUEST)


func _on_ring_passed(_index: int, _total: int) -> void:
	if player and player.quest_log:
		player.quest_log.progress(&"pass_ring")


func _on_course_finished(seconds: float) -> void:
	if best_seconds < 0.0 or seconds < best_seconds:
		best_seconds = seconds


func _on_landing_body_entered(body: Node3D) -> void:
	if body is Player and not landed and course.finished:
		landed = true
		if player and player.quest_log:
			player.quest_log.progress(&"land")


## The recording: take off from the pad, the eight rings in turn (the stick aimed at each, Jump and Action for
## the height), and the tower at the end.
func build_autopilot(pilot: DemoAutopilot) -> void:
	var flying: Callable = func() -> bool: return player.is_flying
	pilot.wait(1.0).tap(&"jump").wait(0.35).tap(&"jump").wait_until(flying, 2.0).wait(0.3) # off the pad
	pilot.hold(&"jump", 0.8)
	for i: int in course.total():
		var ring: Area3D = course.get_child(i)
		pilot.fly_to(ring, 16.0, 2.0, true)
	pilot.fly_to($Landing/LandingTrigger, 14.0, 2.5, true).wait(0.3).tap(&"action").wait(0.15).tap(&"action").wait(3.0) # and down
