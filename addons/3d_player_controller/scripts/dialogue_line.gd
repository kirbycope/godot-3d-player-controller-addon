class_name DialogueLine
extends Resource
## One thing said in a [Dialogue]. A line is shown when its [member condition] holds; it then goes on to
## [member next] (the following line by default), ends the dialogue, or waits for one of its [member choices].
## Showing it can start a quest or report an objective, the way a choice can.

enum Condition {
	NONE, ## Always shown.
	QUEST_NOT_STARTED, ## Only before [member condition_quest] is started.
	QUEST_ACTIVE, ## Only while [member condition_quest] is active.
	QUEST_COMPLETE, ## Only once [member condition_quest] is complete.
	OBJECTIVE_DONE, ## Only once [member condition_objective] of [member condition_quest] is met.
}

@export var speaker: String = "" ## Who says it; empty takes the talker's display name.
@export_multiline var text: String = ""
@export var choices: Array[DialogueChoice] = [] ## Answers offered; empty and the line simply continues.
@export var next: int = -1 ## Index of the line after this one; -1 means the following line in order.
@export var ends_dialogue: bool = false ## The conversation ends after this line (when it offers no choices).
@export var entry: bool = true ## The dialogue may open on this line; off, it is only reached through next or a choice.
@export var condition: Condition = Condition.NONE
@export var condition_quest: Quest
@export var condition_objective: StringName = &""
@export var starts_quest: Quest ## Shown, it starts this quest.
@export var progresses_objective: StringName = &"" ## Shown, it reports this objective once.


## Whether [param log] lets this line show; a line with a condition and no log to ask is not shown.
func passes(log: QuestLog) -> bool:
	if condition == Condition.NONE:
		return true
	if log == null:
		return false
	match condition:
		Condition.QUEST_NOT_STARTED:
			return log.get_status(condition_quest) == QuestLog.Status.NOT_STARTED
		Condition.QUEST_ACTIVE:
			return log.is_active(condition_quest)
		Condition.QUEST_COMPLETE:
			return log.is_complete(condition_quest)
		Condition.OBJECTIVE_DONE:
			return log.is_objective_done(condition_quest, condition_objective)
	return true
