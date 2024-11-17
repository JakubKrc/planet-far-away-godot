extends Node

@onready var parent = get_parent()
@onready var timer = $ShootTimer

var bullet = preload("res://scenes/environment/castle_zone/characters/enemy_simplerobot/simpleBullet.tscn")

func shoot():
	if not parent.is_robot_chase:
		if not timer.is_stopped():
			timer.stop()
		return
	elif timer.is_stopped():
		timer.start()
		oneShot()
		
func oneShot():
	var b = bullet.instantiate()
	b.direction = parent.direction.normalized()
	b.position = parent.global_position + Vector2(10 * b.direction.x, 0)
	parent.get_parent().add_child(b)

func _on_shoot_timer_timeout():
	oneShot()
