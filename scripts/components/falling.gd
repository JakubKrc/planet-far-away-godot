extends Node

@onready var parent = get_parent()

var wasOnFloor = []
@export var frames_to_remember_ground: int = 6

func gravity_for_falling(velocity_player: Vector2):
	if velocity_player.y<=0:
		parent.state.state = Global.States.JUMPING
		return ProjectSettings.get_setting("physics/2d/default_gravity")
	else:
		parent.state.state = Global.States.FALLING
		return ProjectSettings.get_setting("physics/2d/default_gravity") * 1.5
		
func add_to_was_on_floor(whatToAdd):
	if wasOnFloor.size() >= frames_to_remember_ground:
		wasOnFloor.pop_front()
	wasOnFloor.append(whatToAdd)
	
func falling_and_floor_memory(params : Dictionary):
	if not parent.is_on_floor():
		parent.velocity.y += gravity_for_falling(parent.velocity) * params['delta']
		add_to_was_on_floor(false)
	else:
		parent.state.state = Global.States.IDLE
		add_to_was_on_floor(true)
