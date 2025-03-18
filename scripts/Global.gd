extends Node

enum GameState {MAIN_MENU, PLAYING, PAUSE_MENU, GAME_OVER}

enum States {
	IDLE,
	MOVING,
	JUMPING,
	FALLING,
	SHOOTING,
	CHASING
}

const states_names = ['IDLE','MOVING','JUMPING','FALLING','SHOOTING','CHASING']
	
var main
var game_state = GameState.MAIN_MENU;
var main_menu
var pause_menu
var death_menu
var camera

var controlled_char : Node

func _process(_delta):
	handle_ingame_input()

func handle_ingame_input():
	if (controlled_char == null):
		return
	
	if(is_method_on_target(controlled_char.components, 'jump')):
		if Input.is_action_just_pressed("jump"):
			call_method_on_target(controlled_char.components, 'jump')

		if Input.is_action_just_released("jump"):
			call_method_on_target(controlled_char.components, 'stop_jump')

	if(is_method_on_target(controlled_char.components, 'move')):
		var x_axis_input = Input.get_axis("left", "right")
		if x_axis_input!=0:
			call_method_on_target(controlled_char.components, 'move',{'x_axis_input':x_axis_input})
		else:	
			call_method_on_target(controlled_char.components, 'stop_moving')
	
func call_method_on_target(components, method_name, params: Dictionary = {}):
	var has_component:bool = false
	for component in components:
		if component.has_method(method_name):
			has_component = true
			if params.is_empty():
				component.call(method_name)
			else:
				component.call(method_name, params)
	if !has_component:
		push_error('Component dont have method %s' %method_name)
		get_tree().quit()

func is_method_on_target(components, method_name):
	for component in components:
		if component.has_method(method_name):
			return true
		
	return false
