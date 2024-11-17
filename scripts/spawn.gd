extends Node

@export_file var CHARACTER: String = ""

@onready var main = get_parent()

func spawn() -> void:
	var character = load(CHARACTER).instantiate()
	main.add_child(character)
