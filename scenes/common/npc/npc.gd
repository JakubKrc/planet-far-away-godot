extends Area2D

@export_file("*.json") var dialogue_file: String = "":
	set(v):
		dialogue_file = v
		if has_node("DialogueTrigger"):
			$DialogueTrigger.dialogue_file = v
