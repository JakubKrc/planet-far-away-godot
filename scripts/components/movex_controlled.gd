extends Node

@onready var parent = get_parent()

@export var speed: int

func move(params : Dictionary):
	parent.velocity.x = params['x_axis_input'] * speed
	if params['x_axis_input']==1:
		parent.animation_player.play("walk_right")
		direction = "right"
		parent.state.state = Global.States.MOVING_RIGHT
	if params['x_axis_input']==-1:
		parent.animation_player.play("walk_left")
		direction = "left"
		parent.state.state = Global.States.MOVING_LEFT
		
func stop_moving():
	if (parent.velocity.x != 0):
		parent.velocity.x = move_toward(parent.velocity.x, 0, speed/2)
		setDefaultSprite()

var direction = "right"
func setDefaultSprite():
	if (direction == 'right'):
			parent.animation_player.play("walk_right")
	else:
		parent.animation_player.play("walk_left")
					
	parent.animation_player.stop()
