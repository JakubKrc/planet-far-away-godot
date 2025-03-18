extends Node

@onready var parent = get_parent()

@export var idle_animation_time: float
@export var idle_animation_random: float
var time_since_last_action: float = 0.0
			
func idle(params : Dictionary ):
	if (parent.velocity.x == 0):
		time_since_last_action += params['delta']
		if time_since_last_action >= idle_animation_time:
			parent.animation_player.play("idle")
	else:
		time_since_last_action = 0
		
func _on_animation_player_animation_finished(anim_name):
	if(anim_name == "idle"):
		time_since_last_action = 0;
		idle_animation_time += randf() * idle_animation_random
