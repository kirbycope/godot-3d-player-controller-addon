class_name SaveGame
extends Node
## Saves and loads the game. Drop one in the world: every node in the [code]Saveable[/code] group that implements
## [code]save_state() -> Dictionary[/code] and [code]load_state(state: Dictionary)[/code] is written to
## [member save_path] under its path, and read back into whichever of those nodes are still there. The Player saves
## itself (position, checkpoint, health, the whole inventory); a world adds its clock, its weather, its enemies,
## whatever else it wants kept, by joining the group.
##
## The file is plain JSON text: a [constant VERSION], when and where it was taken, and the states. Nothing in it is
## an object. A Resource a state holds is written as its [code]res://[/code] path, or, for one made at run time (an
## inventory's save), as its script's path and its stored properties, so reading a save back only ever loads the
## game's own files and never runs anything the file brought with it. A file of another version, or one that is not
## this format (the [code].tres[/code] saves of old), is refused rather than guessed at.
##
## [method save_game] is the pause menu's Save, [member autosave_interval] writes on the AutosaveTimer, and with
## [member save_on_checkpoint] every [Checkpoint] writes as it is taken. A title screen's Continue sets
## [member load_requested] before the world loads; the SaveGame loads once this peer's Player is in. A world that
## spawns its Players wires its [PlayerSpawner]'s local_player_spawned to [method load_for_player] in the scene; a
## Player standing in the scene is there already. Over the network only the host saves: a client is in the host's
## world, and its own Player is named after a peer id the next session will not have. Loading applies only to what
## this peer owns.

signal saved(path: String) ## The file was written.
signal loaded(path: String) ## The file was read and applied.
signal load_failed(path: String) ## There was no file, or it could not be read.

const GROUP: StringName = &"Saveable"
const VERSION: int = 2 ## The file format; 1 was the SaveGameData resource, which is no longer read.

static var DEFAULT_SAVE_PATH: String = "user://savegame.json" ## Where a SaveGame writes unless told otherwise; a test run points it elsewhere.
static var load_requested: bool = false ## Continue was picked: the next SaveGame loads its file once this peer's Player is in.

@export var save_path: String = DEFAULT_SAVE_PATH
@export var autosave_interval: float = 0.0: ## Seconds between automatic writes; zero turns them off.
	set(value):
		autosave_interval = maxf(value, 0.0)
		if is_node_ready():
			_update_timer()
@export var save_on_checkpoint: bool = true ## Write whenever a [Checkpoint] is taken.

@onready var autosave_timer: Timer = $AutosaveTimer ## Its timeout is wired to [method save_game] in the scene.


func _ready() -> void:
	add_to_group(&"SaveGame")
	_update_timer()
	for checkpoint: Node in get_tree().get_nodes_in_group(&"Checkpoint"):
		if checkpoint is Checkpoint:
			watch_checkpoint(checkpoint as Checkpoint)
	# A Player standing in the scene is in already; a spawned one arrives through load_for_player
	for player: Node in get_tree().get_nodes_in_group(&"Player"):
		if player.is_multiplayer_authority():
			load_for_player(player as Player)
			return


## True when a save exists at [param path].
static func has_save_at(path: String = DEFAULT_SAVE_PATH) -> bool:
	return FileAccess.file_exists(path)


## The SaveGame in [param tree], or null; the pause menu looks it up this way.
static func find_in(tree: SceneTree) -> SaveGame:
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"SaveGame") as SaveGame


func has_save() -> bool:
	return has_save_at(save_path)


## Wire a [PlayerSpawner]'s local_player_spawned here in the scene: a Continue waiting on [member load_requested]
## loads once this peer's Player is in. A connection made in the scene exists before any node readies, so it hears
## the spawn even when the spawner sits earlier in the tree and spawns in its own _ready, before this one's.
func load_for_player(_player: Player) -> void:
	if load_requested:
		load_requested = false
		load_game.call_deferred()


## Writes every Saveable's state to [member save_path]. A client in somebody else's session writes nothing
## (ERR_UNAVAILABLE): the world is the host's, and the client's own Player would go in under a peer id the next
## session will not have, over the single-player save at the same path.
func save_game() -> Error:
	if not multiplayer.is_server():
		return ERR_UNAVAILABLE
	var scene: Node = get_tree().current_scene
	var data: Dictionary = {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"scene_path": scene.scene_file_path if scene else "",
		"states": to_plain(collect_states()),
	}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	var error: Error = FileAccess.get_open_error() if file == null else OK
	if file:
		file.store_string(JSON.stringify(JSON.from_native(data), "\t"))
		error = file.get_error()
		file.close()
	if error == OK:
		saved.emit(save_path)
	else:
		push_error("SaveGame: could not write %s (%s)" % [save_path, error_string(error)])
	return error


## What [member save_path] holds (version, saved_at, scene_path and states), or an empty Dictionary when there is no
## file, it is not this format, or it is another version.
func read_save() -> Dictionary:
	if not has_save():
		return {}
	var json: JSON = JSON.new()
	var parsed: bool = json.parse(FileAccess.get_file_as_string(save_path)) == OK
	var data: Variant = JSON.to_native(json.data) if parsed else null # objects stay out: allow_objects is off
	if not data is Dictionary or int((data as Dictionary).get("version", 0)) != VERSION or not (data as Dictionary).get("states") is Dictionary:
		push_warning("SaveGame: %s is not a version %d save; it is left alone" % [save_path, VERSION])
		return {}
	data["states"] = from_plain(data["states"])
	return data


## Reads [member save_path] back into the Saveables that are there; false when there is nothing to read.
func load_game() -> bool:
	var data: Dictionary = read_save()
	if data.is_empty():
		load_failed.emit(save_path)
		return false
	apply_states(data["states"])
	loaded.emit(save_path)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(save_path)


## Every Saveable this peer owns, keyed by its path from this node's parent.
func collect_states() -> Dictionary:
	var states: Dictionary = {}
	var base: Node = get_parent() if get_parent() else self
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		if not node.has_method("save_state") or not node.is_multiplayer_authority():
			continue
		states[String(base.get_path_to(node))] = node.save_state()
	return states


## Hands each state to the Saveable at its path, if it is still there and this peer owns it.
func apply_states(states: Dictionary) -> void:
	var base: Node = get_parent() if get_parent() else self
	for path: String in states:
		var node: Node = base.get_node_or_null(NodePath(path))
		if node == null or not node.is_in_group(GROUP) or not node.has_method("load_state") or not node.is_multiplayer_authority():
			continue
		node.load_state(states[path])


## Saves when [param checkpoint] is taken, if [member save_on_checkpoint] asks for it.
func watch_checkpoint(checkpoint: Checkpoint) -> void:
	if not checkpoint.activated.is_connected(_on_checkpoint_activated):
		checkpoint.activated.connect(_on_checkpoint_activated)


func _on_checkpoint_activated(_player: Player) -> void:
	if save_on_checkpoint:
		save_game()


func _update_timer() -> void:
	if autosave_timer == null:
		return
	if autosave_interval > 0.0:
		autosave_timer.start(autosave_interval)
	else:
		autosave_timer.stop()


## [param value] with every Resource in it made plain: one saved under res:// becomes {"@path": its path}, one made
## at run time {"@script": its script's res:// path} plus its stored properties. Any other object is dropped.
static func to_plain(value: Variant) -> Variant:
	if value is Resource:
		var resource: Resource = value
		if resource.resource_path.begins_with("res://") and not resource.resource_path.contains("::"):
			return {"@path": resource.resource_path}
		var script: Script = resource.get_script() as Script
		if script == null or not script.resource_path.begins_with("res://"):
			return null
		var plain: Dictionary = {"@script": script.resource_path}
		for property: Dictionary in resource.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE:
				plain[property.name] = to_plain(resource.get(property.name))
		return plain
	if value is Object:
		return null
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(to_plain(item))
		return items
	if value is Dictionary:
		var entries: Dictionary = {}
		for key: Variant in value:
			entries[key] = to_plain(value[key])
		return entries
	return value


## Undoes [method to_plain]. Only res:// files are loaded, and only Resource scripts from res:// are instanced, so a
## save can name nothing but the game's own content.
static func from_plain(value: Variant) -> Variant:
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(from_plain(item))
		return items
	if not value is Dictionary:
		return value
	var plain: Dictionary = value
	if plain.has("@path"):
		var path: String = str(plain["@path"])
		return load(path) if path.begins_with("res://") and ResourceLoader.exists(path) else null
	if plain.has("@script"):
		var script_path: String = str(plain["@script"])
		var script: Script = load(script_path) as Script if script_path.begins_with("res://") and ResourceLoader.exists(script_path) else null
		if script == null or not script.can_instantiate() or not ClassDB.is_parent_class(script.get_instance_base_type(), &"Resource"):
			return null
		var resource: Resource = script.new()
		for key: Variant in plain:
			if key == "@script":
				continue
			var restored: Variant = from_plain(plain[key])
			var current: Variant = resource.get(key)
			if current is Array and restored is Array:
				(current as Array).assign(restored) # a typed array property takes the elements, not a plain Array
			else:
				resource.set(key, restored)
		return resource
	var entries: Dictionary = {}
	for key: Variant in plain:
		entries[key] = from_plain(plain[key])
	return entries
