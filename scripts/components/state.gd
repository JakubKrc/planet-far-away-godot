class_name State extends Node

@onready var label_test_status = $"../TestStatus"

var state : Global.States :
	set (setting_state):
		if (state != setting_state):
			state = setting_state
			label_test_status.text = Global.states_names[state]
	get:
		return state
