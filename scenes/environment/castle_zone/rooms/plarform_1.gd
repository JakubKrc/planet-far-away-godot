extends Node2D

@export var activated = false
@export var repeat = true
@export var global_speed = 40
@export var waypoints: Array[Node2D]
@export var speeds: Array[float]

var current_index = 0
var targets: Array[Vector2] = []
var moves_first_time = true
var index_before = 0

signal started_running
signal stopped_running

func _ready() -> void:
	if activated:
		emit_signal("started_running")
	for wp in waypoints:
		targets.append(wp.global_position)

func activate():
	if(!activated):
		activated=true
		moves_first_time=true
		emit_signal("started_running")
	
func deactivate():
	if(activated):
		activated=false	
		emit_signal("stopped_running")

func _process(delta):
	if waypoints.size() == 0 || !activated:
		return
	
	if !repeat && !moves_first_time:
		deactivate()
	
	var target = waypoints[current_index].position
	var speed
	if global_speed==0:
		speed = speeds[current_index]
	else:
		speed = global_speed
	position = position.move_toward(target, speed * delta)
	
	if position.distance_to(target) < 0.1:
		if current_index == 0 && index_before == waypoints.size()-1:
			moves_first_time=false
			
		index_before = current_index

		current_index = (current_index + 1) % waypoints.size()
