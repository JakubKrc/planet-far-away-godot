extends Area2D

var SPEED = 100
var direction = Vector2()

func _physics_process(delta):
	position += direction * SPEED * delta

func _on_body_entered(body):
	queue_free()
	if body.is_in_group('player'):
		body.health -= 10
