extends Node

@onready var parent = get_parent()

@export var jump_velocity: int

func jump():
	if 'falling' in parent:
		if 'wasOnFloor' in parent.falling:
			if not true in parent.falling.wasOnFloor:
				return	
			
	parent.velocity.y = jump_velocity
			
func stop_jump():
	if parent.velocity.y < 0:
		parent.velocity.y = jump_velocity / 4
