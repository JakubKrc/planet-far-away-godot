class_name MovexControlled
extends Node

@onready var parent = get_parent()

@export var speed: float = 100

func move(params : Dictionary):
	parent.velocity.x = params['x_axis_input'] * speed
	if params['x_axis_input']==1:
		parent.direction = Vector2.RIGHT
		if !parent.components.get(State).state == Global.States.FLYING:
			parent.animation_player.play("walk_right")
			parent.components.get(State).state = Global.States.MOVING_RIGHT
	if params['x_axis_input']==-1:
		parent.direction = Vector2.LEFT
		if !parent.components.get(State).state == Global.States.FLYING:
			parent.animation_player.play("walk_left")
			parent.components.get(State).state = Global.States.MOVING_LEFT
	if !parent.get_position_delta().length() > 0.1:
		parent.animation_player.stop()
	if parent.components.has(Sight) and parent.direction!=Vector2.ZERO:
		parent.components.get(Sight).set_raycast_direction()
		
func stop_moving():
	if (parent.velocity.x != 0):
		parent.velocity.x = move_toward(parent.velocity.x, 0, speed/2)
		if !parent.components.get(State).state == Global.States.FLYING:
			setDefaultSprite()

func setDefaultSprite():
	if (parent.direction == Vector2.RIGHT):
		parent.animation_player.play("stand_right")
	else:
		parent.animation_player.play("stand_left")
