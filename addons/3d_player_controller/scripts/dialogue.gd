class_name Dialogue
extends Resource
## A conversation: [DialogueLine]s in order. It opens on the first entry line whose condition holds, and each line
## goes on to the next line whose condition holds (or where its [member DialogueLine.next] or a choice points),
## so one resource covers a talker's greeting before, during and after a quest.

@export var lines: Array[DialogueLine] = []


## The line the dialogue opens on for [param log], or -1 when none applies.
func first_line(log: QuestLog) -> int:
	for i: int in lines.size():
		if lines[i].entry and lines[i].passes(log):
			return i
	return -1


## The line after [param index] for [param log]: the line it points at, or the next one in order that passes;
## -1 when the dialogue ends there.
func next_line(index: int, log: QuestLog) -> int:
	if index < 0 or index >= lines.size():
		return -1
	var line: DialogueLine = lines[index]
	if line.ends_dialogue:
		return -1
	if line.next >= 0:
		return resolve(line.next, log)
	return resolve(index + 1, log)


## [param index] if its line passes, else the next line in order that does; -1 past the end.
func resolve(index: int, log: QuestLog) -> int:
	for i: int in range(maxi(index, 0), lines.size()):
		if lines[i].passes(log):
			return i
	return -1
