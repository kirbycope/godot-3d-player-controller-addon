class_name AbilityEntry
extends Node
## One ability in an [AbilityLibrary]: a child node carrying the [Ability] resource, so the library's contents are
## nodes a project can see and add to in the editor (instance the library scene, make its children editable, add
## an entry) rather than a list in a script.

@export var ability: Ability ## The ability this entry puts in the library; its [method Ability.get_id] is its name there.
