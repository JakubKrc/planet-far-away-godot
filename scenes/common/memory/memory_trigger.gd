# Walk in and Igor stops, thinks the lines, and drifts into a memory: another
# level, until something there ends it (Global.end_memory) and he is back here.
# From code, without a trigger: Global.remember(lines, memory_level, memory_door).
extends Area2D

@export_multiline var lines: Array[String] = ["Why do I even do this?"]
@export_file("*.tscn") var memory_level: String = ""
@export var memory_door: String = ""     # empty: the memory level's own spawn door

# Saved with the level, so the memory does not start again on the way back.
var was_used: bool = false

func _ready():
	add_to_group("save")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node):
	if body != Global.controlled_char:
		return
	if was_used or memory_level == "":
		return
	was_used = true
	Global.remember(lines, memory_level, memory_door)
