extends Area2D

var SPEED = 100
var direction = Vector2()
const LIFETIME = 5.0   # seconds; a bullet that hits nothing would otherwise fly forever

func _ready():
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)

func _physics_process(delta):
	position += direction * SPEED * delta

func _on_body_entered(body):
	queue_free()
	if "health" in body:
		body.health -= 10
