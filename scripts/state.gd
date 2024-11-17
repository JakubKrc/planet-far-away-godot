class_name State extends Node

var current_state : Global.States :
	set (setting_state):
		current_state = setting_state
		print(Global.states_names[current_state])
	get:
		return current_state
