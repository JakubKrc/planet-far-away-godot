class_name JumpControlled
extends Node

@onready var parent = get_parent()

@export var jump_velocity: float = -300

func jump():
	if 'wasOnFloor' in parent.get_component(Falling):
		if not true in parent.get_component(Falling).wasOnFloor:
			return
		
	parent.velocity.y = jump_velocity
			
func stop_jump():
	if parent.velocity.y < 0:
		parent.velocity.y = jump_velocity / 4
