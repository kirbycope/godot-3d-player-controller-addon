class_name SaveGameData
extends Resource
## What [SaveGame] writes: every [code]Saveable[/code] node's state under its path from the scene root, plus when
## and where. A plain [code].tres[/code], so it can be read and edited by hand.

@export var version: int = 1 ## The format; a game that changes what it saves bumps it and migrates in [method SaveGame.load_game].
@export var saved_at: String = "" ## ISO 8601 system time of the write.
@export var scene_path: String = "" ## The scene file the save was taken in.
@export var states: Dictionary = {} ## Node path (a String, relative to the SaveGame's parent) to the Dictionary its save_state() returned.
