class_name DialogueChoice
extends Resource
## One answer the Player can give to a [DialogueLine]: what it says, where the conversation goes next and what
## it does to the quest log.

@export var text: String = ""
@export var next: int = -1 ## Index into [member Dialogue.lines] to go to; -1 ends the dialogue.
@export var starts_quest: Quest ## Picked, it starts this quest.
@export var progresses_objective: StringName = &"" ## Picked, it reports this objective once.
