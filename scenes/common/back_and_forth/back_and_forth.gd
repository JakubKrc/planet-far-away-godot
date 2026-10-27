# Goes back and forth along `travel` from where it was placed, resting at each end:
# a lift capsule, someone crossing a bridge, a cleaning robot.
extends Sprite2D

@export var travel: Vector2 = Vector2(64, 0)
@export var speed: float = 12.0
@export var rest_seconds: float = 1.0
@export var frame_seconds: float = 0.25   # flips through hframes while moving

var _start: Vector2
var _distance: float = 0.0               # how far along `travel` it is now
var _going_out: bool = true
var _rest_left: float = 0.0
var _frame_time: float = 0.0

func _ready():
	_start = position

func _process(delta):
	if _rest_left > 0.0:
		_rest_left -= delta
		return
	var length = travel.length()
	if is_zero_approx(length):
		return

	if _going_out:
		_distance += speed * delta
	else:
		_distance -= speed * delta
	if _distance >= length:
		_distance = length
		_turn_around()
	elif _distance <= 0.0:
		_distance = 0.0
		_turn_around()
	position = _start + travel.normalized() * _distance

	var sideways_speed = travel.x if _going_out else -travel.x
	if not is_zero_approx(sideways_speed):
		flip_h = sideways_speed < 0.0
	_animate(delta)

func _turn_around():
	_going_out = not _going_out
	_rest_left = rest_seconds

func _animate(delta):
	if hframes < 2:
		return
	_frame_time += delta
	if _frame_time >= frame_seconds:
		_frame_time = 0.0
		frame = (frame + 1) % hframes
