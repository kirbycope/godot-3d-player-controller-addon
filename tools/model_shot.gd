extends SceneTree
## Renders one still of each scene given after "--" to a PNG beside the scene's file name in the output folder,
## from a three-quarter view with an axis gizmo (red +X, green +Y, blue +Z), to see which way a model faces
## before it goes into a scene. Needs a window, not --headless.
##   godot --path . -s tools/model_shot.gd -- /tmp/shots res://path/to/model.gltf ...

var _paths: PackedStringArray = []
var _out_dir: String = ""
var _index: int = -1
var _frames: int = 0
var _camera: Camera3D
var _holder: Node3D


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out_dir = args[0]
	for path: String in args.slice(1):
		if path.begins_with("res://"):
			_paths.append(path)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	root.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	root.add_child(sun)
	_camera = Camera3D.new()
	root.add_child(_camera)
	_holder = Node3D.new()
	root.add_child(_holder)


func _process(_delta: float) -> bool:
	_frames += 1
	if _index >= 0 and _frames == 4:
		var image: Image = root.get_viewport().get_texture().get_image()
		image.save_png(_out_dir.path_join(_paths[_index].get_file().get_basename() + ".png"))
	if _frames >= 4 or _index < 0:
		_index += 1
		_frames = 0
		if _index >= _paths.size():
			quit()
			return true
		_show(_paths[_index])
	return false


func _show(path: String) -> void:
	for child: Node in _holder.get_children():
		child.free()
	var scene: PackedScene = load(path) as PackedScene
	var node: Node3D = scene.instantiate() as Node3D
	_holder.add_child(node)
	var aabb: AABB = AABB()
	var first: bool = true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	var extent: float = maxf(aabb.size.length(), 0.1)
	for axis: int in 3:
		var bar: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		var size: Vector3 = Vector3.ONE * extent * 0.02
		size[axis] = extent * 0.6
		mesh.size = size
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = [Color.RED, Color.GREEN, Color.BLUE][axis]
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material = material
		bar.mesh = mesh
		var offset: Vector3 = Vector3.ZERO
		offset[axis] = extent * 0.3
		bar.position = offset
		_holder.add_child(bar)
	var centre: Vector3 = aabb.get_center()
	_camera.position = centre + Vector3(1.0, 0.8, 1.6).normalized() * extent * 1.6
	_camera.look_at(centre)
	print("%s: size=%s position=%s" % [path.get_file(), aabb.size, aabb.position])
