class_name DemoScene
extends Node3D
## What every gameplay-style demo shares. It finds the Player (its own child, or the one a [SplitScreen] spawned),
## puts the whole HUD on screen ([member Player.hud_mode_override]), turns on the gear the style wants, and, when
## the game was started with [code]--autopilot[/code], plays the sequence [method build_autopilot] filled in, so
## [code]tools/record_demo.sh[/code] can film it. A demo overrides [method setup_player] and
## [method build_autopilot]; the base does the rest.

@export var player: Player ## The demo's Player; found by the group when left empty.
@export var control_scheme: PlayerControls.ControlScheme = PlayerControls.ControlScheme.ZELDA
@export var show_whole_hud: bool = true ## Every button on screen, whatever the player saved.

const NAVIGATION_BAKE_FRAMES: int = 8 ## Physics frames a demo waits before baking its navigation mesh.

var autopilot: DemoAutopilot


func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(&"Player") as Player
	if player:
		player.control_scheme = control_scheme
		if show_whole_hud:
			player.hud_mode_override = PlayerSettingsResource.HudMode.SHOWN
		setup_player(player)
	if DemoAutopilot.requested():
		# The chat window comes forward under the pointer, which a recording leaves wherever it was
		if player and player.chat:
			player.chat.hide()
		autopilot = DemoAutopilot.new()
		autopilot.name = "Autopilot"
		autopilot.player = player
		add_child(autopilot)
		build_autopilot(autopilot)
		# A frame for everything to settle, then the show
		await get_tree().physics_frame
		await get_tree().physics_frame
		autopilot.run()
		await autopilot.finished
		# A movie run has nothing more to show; a second on the last frame, then the recorder can stop
		if OS.has_feature("movie"):
			await get_tree().create_timer(1.0).timeout
			get_tree().quit()


## The gear and rules this style plays with; the base has already set the scheme and the HUD.
func setup_player(_target: Player) -> void:
	pass


## The moves the recording plays, in order; see [DemoAutopilot].
func build_autopilot(_pilot: DemoAutopilot) -> void:
	pass


## Plays a conversation with the [TalkingNpc] the Player stands beside: Action opens it, then [param presses] more
## presses each land once the line has typed out (a choice's default is taken by the same press), and the step
## ends when the box has closed, so a paced recording never opens a second conversation by accident.
func talk(pilot: DemoAutopilot, presses: int) -> DemoAutopilot:
	var revealed: Callable = func() -> bool: return player.dialogue_screen and player.dialogue_screen.is_line_revealed()
	var closed: Callable = func() -> bool: return player.dialogue_screen == null or not player.dialogue_screen.visible
	pilot.tap(&"action")
	for i: int in presses:
		pilot.wait_until(revealed, 10.0).wait(0.8).tap(&"action")
	return pilot.wait_until(closed, 3.0).wait(0.4)


## Bakes [param region]'s mesh from the scene's geometry once it has settled: CSG shapes build their meshes a
## frame after entering the tree, and a bake in the first frames lands on a navigation map that has not synced the
## region yet and is lost, so a child timer holds it [constant NAVIGATION_BAKE_FRAMES] physics frames (a scene
## freed before then, a test, takes the pending bake with it). The source geometry is gathered here rather than
## parsed by the server, which would pull the CSG meshes back off the GPU with a warning: every root CSG shape's
## faces and every box shape under a StaticBody3D go in, and the result is handed to the region as a new
## resource, which is what makes the map take it. Enemies spawned after that path around the walls.
func bake_navigation(region: NavigationRegion3D) -> void:
	if region == null or region.navigation_mesh == null:
		return
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = float(NAVIGATION_BAKE_FRAMES) / Engine.physics_ticks_per_second
	timer.timeout.connect(func() -> void:
		if is_instance_valid(region) and region.is_inside_tree():
			_bake_navigation_now(region)
		timer.queue_free())
	add_child(timer)
	timer.start()


func _bake_navigation_now(region: NavigationRegion3D) -> void:
	var source: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	var to_region: Transform3D = region.global_transform.affine_inverse()
	for csg: Node in region.find_children("*", "CSGShape3D", true, false):
		var shape: CSGShape3D = csg as CSGShape3D
		if not shape.is_root_shape() or not shape.use_collision:
			continue
		var meshes: Array = shape.get_meshes()
		if meshes.size() < 2 or not meshes[1] is Mesh:
			continue
		source.add_faces((meshes[1] as Mesh).get_faces(), to_region * shape.global_transform * (meshes[0] as Transform3D))
	for collider: Node in region.find_children("*", "CollisionShape3D", true, false):
		var collision: CollisionShape3D = collider as CollisionShape3D
		if collision.disabled or not collision.get_parent() is StaticBody3D:
			continue
		var box: BoxShape3D = collision.shape as BoxShape3D
		if box == null:
			continue
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = box.size
		source.add_faces(mesh.get_faces(), to_region * collision.global_transform)
	var baked: NavigationMesh = region.navigation_mesh.duplicate()
	NavigationServer3D.bake_from_source_geometry_data(baked, source)
	region.navigation_mesh = baked


## Back to the demo hub.
func return_to_hub() -> void:
	get_tree().change_scene_to_file("res://addons/3d_player_controller/scenes/demo/demo.tscn")
