extends Node

@onready var parent = get_parent()

func fall():
	if(parent.is_on_floor()):
		parent.position.y += 1
