# A drone crossing the city: flies straight sideways at a steady speed and flips
# its rotor frames. It wraps around after `loop_width`, so on a repeating parallax
# layer it flies on forever without a seam.
extends Sprite2D

@export var speed: float = 20.0          # negative flies left
@export var loop_width: float = 640.0
@export var rotor_seconds: float = 0.08

var _rotor_time: float = 0.0

func _ready():
	flip_h = speed < 0

func _process(delta):
	position.x = fposmod(position.x + speed * delta, loop_width)
	if hframes > 1:
		_rotor_time += delta
		if _rotor_time >= rotor_seconds:
			_rotor_time = 0.0
			frame = (frame + 1) % hframes
