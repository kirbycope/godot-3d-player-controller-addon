extends SceneTree
func _init() -> void:
	for path: String in OS.get_cmdline_user_args():
		if not path.begins_with("res://"): continue
		var node: Node = (load(path) as PackedScene).instantiate()
		_dump(node, 0)
		node.free()
	quit()
func _dump(node: Node, depth: int) -> void:
	var extra: String = ""
	if node is Node3D: extra = " pos=%s" % (node as Node3D).position
	print("  ".repeat(depth) + node.name + " (" + node.get_class() + ")" + extra)
	for child: Node in node.get_children(): _dump(child, depth + 1)
