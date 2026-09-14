class_name SaveGame
extends Node
## Saves and loads the game. Drop one in the world: every node in the [code]Saveable[/code] group that implements
## [code]save_state() -> Dictionary[/code] and [code]load_state(state: Dictionary)[/code] is written to
## [member save_path] as a [SaveGameData] under its path, and read back into whichever of those nodes are still
## there. The Player saves itself (position, checkpoint, health, the whole inventory); a world adds its clock, its
## weather, its enemies, whatever else it wants kept, by joining the group.
##
## [method save_game] is the pause menu's Save, [member autosave_interval] writes on the AutosaveTimer, and with
## [member save_on_checkpoint] every [Checkpoint] writes as it is taken. A title screen's Continue sets
## [member load_requested] before the world loads; the SaveGame that finds it loads once the local Player is in
## (through [member player_spawner], or on ready without one). Over the network only what this peer owns is saved
## or loaded; the host's world state is the host's to save.

signal saved(path: String) ## The file was written.
signal loaded(path: String) ## The file was read and applied.
signal load_failed(path: String) ## There was no file, or it could not be read.

const GROUP: StringName = &"Saveable"
const DEFAULT_SAVE_PATH: String = "user://savegame.tres"

static var load_requested: bool = false ## Continue was picked: the next SaveGame to ready loads its file.

@export var save_path: String = DEFAULT_SAVE_PATH
@export var autosave_interval: float = 0.0: ## Seconds between automatic writes; zero turns them off.
	set(value):
		autosave_interval = maxf(value, 0.0)
		if is_node_ready():
			_update_timer()
@export var save_on_checkpoint: bool = true ## Write whenever a [Checkpoint] is taken.
@export var player_spawner: PlayerSpawner ## When set, a requested load waits for this peer's Player to spawn.

@onready var autosave_timer: Timer = $AutosaveTimer ## Its timeout is wired to [method save_game] in the scene.


func _ready() -> void:
	add_to_group(&"SaveGame")
	_update_timer()
	for checkpoint: Node in get_tree().get_nodes_in_group(&"Checkpoint"):
		if checkpoint is Checkpoint:
			watch_checkpoint(checkpoint as Checkpoint)
	if player_spawner:
		player_spawner.local_player_spawned.connect(_on_local_player_spawned)
	elif load_requested:
		load_requested = false
		load_game.call_deferred()


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


## Writes every Saveable's state to [member save_path].
func save_game() -> Error:
	var data: SaveGameData = SaveGameData.new()
	data.saved_at = Time.get_datetime_string_from_system(true)
	var scene: Node = get_tree().current_scene
	data.scene_path = scene.scene_file_path if scene else ""
	data.states = collect_states()
	var error: Error = ResourceSaver.save(data, save_path)
	if error == OK:
		saved.emit(save_path)
	else:
		push_error("SaveGame: could not write %s (%s)" % [save_path, error_string(error)])
	return error


## Reads [member save_path] back into the Saveables that are there; false when there is nothing to read.
func load_game() -> bool:
	if not has_save():
		load_failed.emit(save_path)
		return false
	var data: SaveGameData = ResourceLoader.load(save_path, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGameData
	if data == null:
		push_error("SaveGame: %s is not a SaveGameData" % save_path)
		load_failed.emit(save_path)
		return false
	apply_states(data.states)
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


func _on_local_player_spawned(_player: Player) -> void:
	if load_requested:
		load_requested = false
		load_game.call_deferred()


func _update_timer() -> void:
	if autosave_timer == null:
		return
	if autosave_interval > 0.0:
		autosave_timer.start(autosave_interval)
	else:
		autosave_timer.stop()
