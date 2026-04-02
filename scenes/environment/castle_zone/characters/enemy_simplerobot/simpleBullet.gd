extends Area2D

var SPEED = 100
var direction = Vector2()

func _physics_process(delta):
	position += direction * SPEED * delta

func _on_body_entered(body):
	queue_free()
	if "health" in body:
		body.health -= 10
