extends SceneTree
## Prints the world AABB of each scene given after "--" on the command line, for placing and offsetting models.
##   godot --headless --path . -s tools/model_bounds.gd -- res://path/to/model.gltf ...

func _init() -> void:
	for path: String in OS.get_cmdline_user_args():
		if not path.begins_with("res://"):
			continue
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			print("%s: cannot load" % path)
			continue
		var node: Node3D = scene.instantiate() as Node3D
		root.add_child(node)
		var aabb: AABB = AABB()
		var first: bool = true
		var names: PackedStringArray = []
		for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			names.append(mesh.name)
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			aabb = box if first else aabb.merge(box)
			first = false
		print("%s: size=%s position=%s meshes=%s" % [path.get_file(), aabb.size, aabb.position, ", ".join(names)])
		node.free()
	quit()
