class_name JumpControlledFly
extends Node

@onready var parent = get_parent()

@export var jump_velocity: float = -100
@export var max_fuel: float = 75

var current_fuel:float = max_fuel-1

var is_flying : bool = false

func _physics_process(_delta):
	if current_fuel<=0:
		stop_jump()
	if is_flying && current_fuel>0:
		parent.velocity.y = jump_velocity
		current_fuel-=1
		parent.animation_player.play("fly")
		parent.components.get(State).state = Global.States.FLYING
	if 'wasOnFloor' in parent.components.get(Falling):
		if true in parent.components.get(Falling).wasOnFloor && current_fuel<max_fuel-1:
			current_fuel+=1.2

func jump():
	is_flying = true
			
func stop_jump():
	is_flying = false
	parent.components.get(MovexControlled).setDefaultSprite()
