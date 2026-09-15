class_name DemoAutopilot
extends Node
## Plays a demo for the camera. A demo scene fills a sequence with the fluent helpers ([method move], [method hold],
## [method tap], [method look], [method wait], [method call], [method warp]) and calls [method run]; the steps then
## drive the Player through the same input the states listen to (polled actions through [method Input.action_press],
## presses through [method Input.parse_input_event]), so a recording shows the real controller at work. The demo
## scenes run their sequence only when the game was started with the user argument [code]--autopilot[/code]
## ([code]godot ... -- --autopilot[/code]), which is what [code]tools/record_demo.sh[/code] passes with
## [code]--write-movie[/code].

signal finished ## The sequence has run to its end.

const ARGUMENT: String = "--autopilot"

var player: Player ## Whose camera [method walk] reads, to turn a world direction into a stick direction.
var _steps: Array[Dictionary] = []
var _running: bool = false


## True when the game was started for a recording.
static func requested() -> bool:
	return OS.get_cmdline_user_args().has(ARGUMENT)


## Holds the move stick at [param direction] (x right, y forward, each -1 to 1) for [param seconds].
func move(direction: Vector2, seconds: float) -> DemoAutopilot:
	_steps.append({"kind": "move", "direction": direction, "seconds": seconds})
	return self


## Walks toward [param direction] in the world for [param seconds], whatever way the camera faces: the stick is
## re-aimed every physics frame from the Player's camera, the way [method Player.apply_input] reads it.
func walk(direction: Vector3, seconds: float, sprint: bool = false) -> DemoAutopilot:
	_steps.append({"kind": "walk", "direction": direction.normalized(), "seconds": seconds, "sprint": sprint})
	return self


## Walks toward [param target] (a Vector3, a Node3D, or a Callable returning either) until within
## [param tolerance] metres of it or [param timeout] seconds are up, sprinting when asked; a step that lands on a
## pickup or a prompt whatever the run speed was.
func walk_to(target: Variant, timeout: float = 6.0, tolerance: float = 0.5, sprint: bool = false) -> DemoAutopilot:
	_steps.append({"kind": "walk_to", "target": target, "timeout": timeout, "tolerance": tolerance, "sprint": sprint})
	return self


## Runs along [param direction] (a Vector3, or a Callable returning one, followed each frame) for [param seconds] with the stick held throughout (air control keeps the
## momentum), pressing Jump at each of the [param jump_times] seconds into the run: a running jump, a double
## jump, a chain of platforms.
func hop(direction: Variant, seconds: float, jump_times: Array[float], sprint: bool = false) -> DemoAutopilot:
	_steps.append({"kind": "hop", "direction": direction, "seconds": seconds, "jumps": jump_times, "sprint": sprint})
	return self


## Presses [param action] and leaves it down through the steps that follow, until [method release]: a crouch held
## in cover while the aim step fires.
func press(action: StringName) -> DemoAutopilot:
	_steps.append({"kind": "press", "action": action, "down": true})
	return self


## Lets go of an action [method press] left down.
func release(action: StringName) -> DemoAutopilot:
	_steps.append({"kind": "press", "action": action, "down": false})
	return self


## Holds the look stick at [param direction] (x right, y down) for [param seconds].
func look(direction: Vector2, seconds: float) -> DemoAutopilot:
	_steps.append({"kind": "look", "direction": direction, "seconds": seconds})
	return self


## Holds [param action] down for [param seconds] (a sprint, an aim, a throw charge).
func hold(action: StringName, seconds: float) -> DemoAutopilot:
	_steps.append({"kind": "hold", "action": action, "seconds": seconds})
	return self


## Presses and releases [param action] (a jump, an attack, the Action button).
func tap(action: StringName) -> DemoAutopilot:
	_steps.append({"kind": "tap", "action": action})
	return self


## Does nothing for [param seconds], for the camera to take something in.
func wait(seconds: float) -> DemoAutopilot:
	_steps.append({"kind": "wait", "seconds": seconds})
	return self


## Waits until [param condition] returns true (a breath caught, a door open), or [param timeout] seconds pass.
func wait_until(condition: Callable, timeout: float = 10.0) -> DemoAutopilot:
	_steps.append({"kind": "wait_until", "condition": condition, "timeout": timeout})
	return self


## Calls [param callable] when the sequence reaches it.
func call_step(callable: Callable) -> DemoAutopilot:
	_steps.append({"kind": "call", "callable": callable})
	return self


## Holds focus for [param seconds] with the camera kept on whatever [param target] returns (a position, or a
## Node3D to follow), so a free-aim scheme shoots at it: the trigger is held the whole time when
## [param taps_per_second] is 0 (an automatic weapon sprays), else pulled that many times a second (a pistol).
## A [param done] that returns true ends the step early (the targets are down), and the trigger waits until a
## Node3D target is within [param fire_within] metres, so rounds are not wasted on someone still running in.
func aim(target: Callable, seconds: float, taps_per_second: float = 0.0, done: Callable = Callable(), fire_within: float = INF) -> DemoAutopilot:
	_steps.append({"kind": "aim", "target": target, "seconds": seconds, "taps": taps_per_second, "done": done, "fire_within": fire_within})
	return self


## Fights in melee for [param seconds] with Focus held (a lock-on scheme keeps the camera and the body on the
## target): the cycle is [param swings] taps of Attack, a beat, then a roll to the side (a tap of Sprint with the
## stick held to [param roll_direction], -1 left, 1 right, 0 a backstep) and a moment to recover. Ends early when
## [param done] returns true; [param between] is called once a cycle, for a flask when health is low.
func melee(seconds: float, done: Callable = Callable(), swings: int = 2, roll_direction: float = -1.0, between: Callable = Callable()) -> DemoAutopilot:
	_steps.append({"kind": "melee", "seconds": seconds, "done": done, "swings": swings, "roll": roll_direction, "between": between})
	return self


## Flies toward [param target] (a Vector3, a Node3D, or a Callable) in the flying state: the stick aimed at it each
## frame, Jump held while it is above and Action while below, sprinting when asked, until within [param tolerance]
## metres or [param timeout] seconds.
func fly_to(target: Variant, timeout: float = 10.0, tolerance: float = 2.0, sprint: bool = false) -> DemoAutopilot:
	_steps.append({"kind": "fly_to", "target": target, "timeout": timeout, "tolerance": tolerance, "sprint": sprint})
	return self


## Clicks the mouse on [param target] (a Vector3, a Node3D, or a Callable returning either) where the camera shows
## it: the click-to-move of an action RPG. The cursor is shown for it, as the Player's navigation needs.
func click(target: Variant) -> DemoAutopilot:
	_steps.append({"kind": "click", "target": target})
	return self


## Keeps the camera on [param target] (a Vector3, a Node3D, or a Callable returning either) for [param seconds],
## pressing nothing: a look at something coming.
func watch(target: Variant, seconds: float) -> DemoAutopilot:
	_steps.append({"kind": "watch", "target": target, "seconds": seconds})
	return self


## Keeps the camera on [param target] (as [method watch]) until [param condition] returns true or [param timeout]
## seconds pass: a look at the guard until he looks back.
func watch_until(target: Variant, condition: Callable, timeout: float = 10.0) -> DemoAutopilot:
	_steps.append({"kind": "watch_until", "target": target, "condition": condition, "timeout": timeout})
	return self


## Puts [param player] at [param transform] (a jump cut between two parts of the demo).
func warp(player: Player, transform: Transform3D) -> DemoAutopilot:
	_steps.append({"kind": "warp", "player": player, "transform": transform})
	return self


## Runs the sequence; await it or listen for [signal finished].
func run() -> void:
	if _running:
		return
	_running = true
	var started: int = Time.get_ticks_msec()
	for step: Dictionary in _steps:
		if not is_inside_tree():
			break
		var described: Dictionary = step.duplicate()
		described.erase("player")
		print("[autopilot] %6.2fs %s" % [(Time.get_ticks_msec() - started) / 1000.0, described])
		match step["kind"]:
			"move":
				_stick(&"move_left", &"move_right", &"move_down", &"move_up", step["direction"])
				await get_tree().create_timer(step["seconds"]).timeout
				_stick(&"move_left", &"move_right", &"move_down", &"move_up", Vector2.ZERO)
			"walk":
				if step["sprint"]:
					_press(&"sprint", true)
				# Counted in physics frames, not wall-clock time: a movie run does not pass time at the clock's rate
				var frames: int = maxi(1, roundi(step["seconds"] * Engine.physics_ticks_per_second))
				while frames > 0 and is_inside_tree():
					frames -= 1
					if player and player.spring_arm:
						var local: Vector3 = player.spring_arm.global_transform.basis.inverse() * step["direction"]
						_stick(&"move_left", &"move_right", &"move_down", &"move_up", Vector2(local.x, -local.z).limit_length(1.0))
					await get_tree().physics_frame
				_stick(&"move_left", &"move_right", &"move_down", &"move_up", Vector2.ZERO)
				if step["sprint"]:
					_press(&"sprint", false)
			"hop":
				if step["sprint"]:
					_press(&"sprint", true)
				var total: int = maxi(1, roundi(step["seconds"] * Engine.physics_ticks_per_second))
				var presses: Array[int] = []
				for at: float in step["jumps"]:
					presses.append(roundi(at * Engine.physics_ticks_per_second))
				var release_at: int = -1
				for frame: int in total:
					if not is_inside_tree():
						break
					if player and player.spring_arm:
						var heading: Variant = step["direction"]
						if heading is Callable:
							heading = (heading as Callable).call()
						var local: Vector3 = player.spring_arm.global_transform.basis.inverse() * (heading as Vector3).normalized()
						_stick(&"move_left", &"move_right", &"move_down", &"move_up", Vector2(local.x, -local.z).limit_length(1.0))
					if presses.has(frame):
						_press(&"jump", true)
						release_at = frame + 4
					elif frame == release_at:
						_press(&"jump", false)
					await get_tree().physics_frame
				if release_at >= total:
					_press(&"jump", false)
				_stick(&"move_left", &"move_right", &"move_down", &"move_up", Vector2.ZERO)
				if step["sprint"]:
					_press(&"sprint", false)
			"walk_to":
				if step["sprint"]:
					_press(&"sprint", true)
				var frames: int = maxi(1, roundi(step["timeout"] * Engine.physics_ticks_per_second))
				while frames > 0 and is_inside_tree() and player and player.spring_arm:
					frames -= 1
					var point: Vector3 = _resolve_point(step["target"])
					var to_target: Vector3 = point - player.global_position
					to_target.y = 0.0
					if to_target.length() <= step["tolerance"]:
						break
					var local: Vector3 = player.spring_arm.global_transform.basis.inverse() * to_target.normalized()
					_stick(&"move_left", &"move_right", &"move_down", &"move_up", Vector2(local.x, -local.z).limit_length(1.0))
					await get_tree().physics_frame
				_stick(&"move_left", &"move_right", &"move_down", &"move_up", Vector2.ZERO)
				if step["sprint"]:
					_press(&"sprint", false)
			"look":
				_stick(&"look_left", &"look_right", &"look_up", &"look_down", step["direction"])
				await get_tree().create_timer(step["seconds"]).timeout
				_stick(&"look_left", &"look_right", &"look_up", &"look_down", Vector2.ZERO)
			"hold":
				_press(step["action"], true)
				await get_tree().create_timer(step["seconds"]).timeout
				_press(step["action"], false)
			"press":
				_press(step["action"], step["down"])
				await get_tree().process_frame
			"tap":
				_press(step["action"], true)
				await get_tree().process_frame
				await get_tree().process_frame
				_press(step["action"], false)
				await get_tree().process_frame
				await get_tree().process_frame
			"aim":
				var frames: int = maxi(1, roundi(step["seconds"] * Engine.physics_ticks_per_second))
				var taps: float = step["taps"]
				var tap_every: int = roundi(Engine.physics_ticks_per_second / taps) if taps > 0.0 else 0
				var trigger_down: bool = false
				_press(&"focus", true)
				var frame: int = 0
				var done: Callable = step["done"]
				while frames > 0 and is_inside_tree() and not (done.is_valid() and done.call()):
					frames -= 1
					frame += 1
					var target: Variant = (step["target"] as Callable).call()
					_point_camera_at(target)
					var in_range: bool = not (target is Node3D) or not player \
							or (target as Node3D).global_position.distance_to(player.global_position) <= step["fire_within"]
					if not in_range:
						if trigger_down:
							_press(&"shoot", false)
							trigger_down = false
					elif tap_every == 0:
						if not trigger_down:
							_press(&"shoot", true)
							trigger_down = true
					elif frame % tap_every == 1 and not trigger_down:
						_press(&"shoot", true)
						trigger_down = true
					elif trigger_down and frame % tap_every == 3:
						_press(&"shoot", false)
						trigger_down = false
					await get_tree().physics_frame
				if trigger_down:
					_press(&"shoot", false)
				_press(&"focus", false)
			"melee":
				_melee_left = maxi(1, roundi(step["seconds"] * Engine.physics_ticks_per_second))
				_melee_done = step["done"]
				_press(&"focus", true)
				await _melee_frames(6)
				while not _melee_over():
					# A lock that never took (the target was out of range) or was lost is asked for again
					if not player.is_focusing:
						_press(&"focus", false)
						await _melee_frames(2)
						_press(&"focus", true)
						await _melee_frames(4)
					for i: int in step["swings"]:
						if _melee_over():
							break
						_press(&"attack", true)
						await _melee_frames(4)
						_press(&"attack", false)
						await _melee_frames(32)
						_probe_melee()
					if _melee_over():
						break
					await _melee_frames(10)
					_stick(&"move_left", &"move_right", &"move_down", &"move_up", Vector2(step["roll"], 0.0))
					await _melee_frames(3)
					_press(&"sprint", true)
					await _melee_frames(3)
					_press(&"sprint", false)
					await _melee_frames(6)
					_stick(&"move_left", &"move_right", &"move_down", &"move_up", Vector2.ZERO)
					if (step["between"] as Callable).is_valid():
						(step["between"] as Callable).call()
					await _melee_frames(55)
				_press(&"focus", false)
			"fly_to":
				if step["sprint"]:
					_press(&"sprint", true)
				var frames: int = maxi(1, roundi(step["timeout"] * Engine.physics_ticks_per_second))
				var up_held: bool = false
				var down_held: bool = false
				while frames > 0 and is_inside_tree() and player and player.spring_arm:
					frames -= 1
					var point: Vector3 = _resolve_point(step["target"])
					var to_target: Vector3 = point - player.global_position
					if to_target.length() <= step["tolerance"]:
						break
					var flat: Vector3 = to_target.slide(Vector3.UP)
					var local: Vector3 = player.spring_arm.global_transform.basis.inverse() * flat.normalized()
					_stick(&"move_left", &"move_right", &"move_down", &"move_up", Vector2(local.x, -local.z).limit_length(1.0))
					var want_up: bool = to_target.y > 1.0
					var want_down: bool = to_target.y < -1.0
					if want_up != up_held:
						_press(&"jump", want_up)
						up_held = want_up
					if want_down != down_held:
						_press(&"action", want_down)
						down_held = want_down
					await get_tree().physics_frame
				if up_held:
					_press(&"jump", false)
				if down_held:
					_press(&"action", false)
				_stick(&"move_left", &"move_right", &"move_down", &"move_up", Vector2.ZERO)
				if step["sprint"]:
					_press(&"sprint", false)
			"click":
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				await get_tree().process_frame
				await get_tree().process_frame # the camera's transform is a frame behind the mount
				var camera: Camera3D = get_viewport().get_camera_3d()
				if camera:
					var point: Vector3 = _resolve_point(step["target"])
					# A parsed event carries a window position; the viewport scales it into its own space on the way in
					var screen: Vector2 = get_viewport().get_final_transform() * camera.unproject_position(point)
					for pressed: bool in [true, false]:
						var click: InputEventMouseButton = InputEventMouseButton.new()
						click.button_index = MOUSE_BUTTON_LEFT
						click.pressed = pressed
						click.position = screen
						click.global_position = screen
						Input.parse_input_event(click)
						await get_tree().process_frame
			"watch":
				var frames: int = maxi(1, roundi(step["seconds"] * Engine.physics_ticks_per_second))
				while frames > 0 and is_inside_tree():
					frames -= 1
					var target: Variant = step["target"]
					if target is Callable:
						target = (target as Callable).call()
					_point_camera_at(target)
					await get_tree().physics_frame
			"watch_until":
				var left: int = maxi(1, roundi(step["timeout"] * Engine.physics_ticks_per_second))
				while left > 0 and is_inside_tree() and not (step["condition"] as Callable).call():
					left -= 1
					var target: Variant = step["target"]
					if target is Callable:
						target = (target as Callable).call()
					_point_camera_at(target)
					await get_tree().physics_frame
			"wait":
				await get_tree().create_timer(step["seconds"]).timeout
			"wait_until":
				var left: int = maxi(1, roundi(step["timeout"] * Engine.physics_ticks_per_second))
				while left > 0 and is_inside_tree() and not (step["condition"] as Callable).call():
					left -= 1
					await get_tree().physics_frame
			"call":
				(step["callable"] as Callable).call()
				await get_tree().process_frame
			"warp":
				var warped: Player = step["player"] as Player
				warped.warp_to(step["transform"])
				# The camera settles behind the new facing, a little above, as a cut would frame it
				warped.camera_mount.rotation = Vector3(deg_to_rad(-10.0), 0.0, 0.0)
				await get_tree().process_frame
	_running = false
	finished.emit()


## The states listen for presses in _input and poll holds, so both the event and the polled state are set.
func _press(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _stick(negative_x: StringName, positive_x: StringName, negative_y: StringName, positive_y: StringName, direction: Vector2) -> void:
	_axis(negative_x, maxf(-direction.x, 0.0))
	_axis(positive_x, maxf(direction.x, 0.0))
	_axis(negative_y, maxf(-direction.y, 0.0))
	_axis(positive_y, maxf(direction.y, 0.0))


func _axis(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


## Turns the camera mount so its forward runs through [param target] (a Vector3, or a Node3D whose focus point is
## taken), the way the look stick would have; a free-aim shot then goes there.
func _point_camera_at(target: Variant) -> void:
	if player == null or player.camera_mount == null:
		return
	var point: Vector3
	if target is Node3D:
		if not is_instance_valid(target):
			return
		point = Focus.get_focus_target_position(target)
	elif target is Vector3:
		point = target
	else:
		return
	var local: Vector3 = player.global_basis.inverse() * (point - player.camera_mount.global_position)
	var flat: float = Vector2(local.x, local.z).length()
	player.camera_mount.rotation = Vector3(atan2(local.y, flat), atan2(-local.x, -local.z), 0.0)


## The point a step's target stands for: a Vector3 as is, a Node3D's position, a Callable's answer.
func _resolve_point(target: Variant) -> Vector3:
	if target is Callable:
		target = (target as Callable).call()
	if typeof(target) == TYPE_OBJECT:
		# A pickup already taken is gone (and a freed reference answers no "is"); the step ends where the Player stands
		if is_instance_valid(target) and target is Node3D:
			return (target as Node3D).global_position
		return player.global_position if player else Vector3.ZERO
	if target is Vector3:
		return target
	return player.global_position if player else Vector3.ZERO


## The melee step's frame budget and early-out; a lambda would copy the counter, so they live here.
var _melee_left: int = 0
var _melee_done: Callable = Callable()


func _melee_over() -> bool:
	return _melee_left <= 0 or not is_inside_tree() or (_melee_done.is_valid() and _melee_done.call())


## Waits [param count] physics frames off the melee budget.
func _melee_frames(count: int) -> void:
	for i: int in count:
		if not is_inside_tree():
			break
		await get_tree().physics_frame
		_melee_left -= 1


func _probe_melee() -> void:
	var nearest: Node3D = null
	var best: float = INF
	for enemy: Node in get_tree().get_nodes_in_group(&"Focusable"):
		if enemy is EnemyNpc and enemy.global_position.distance_to(player.global_position) < best:
			best = enemy.global_position.distance_to(player.global_position)
			nearest = enemy
	var facing: float = player.get_facing_direction().dot(player.global_position.direction_to(nearest.global_position)) if nearest else 0.0
	print("[probe] focusing=%s target=%s nearest=%s hp=%s dist=%.2f facing=%.2f state=%s node=%s exhausted=%s stamina=%.0f" % [player.is_focusing, player.current_focus_target, nearest.name if nearest else "", nearest.health.health if nearest else -1, best, facing, NodeStateMachine.get_state_name(player.current_state), player.current_locomotion_node, player.is_exhausted, player.stamina.stamina])
