extends Node
class_name Shoot

@onready var parent = get_parent()
@onready var timer = $ShootTimer

var bullet = preload("res://scenes/environment/castle_zone/characters/enemy_simplerobot/simpleBullet.tscn")

func attack():
	if !timer.is_stopped():
		return
	timer.start()
	var b = bullet.instantiate()
	b.direction = parent.direction.normalized()
	b.position = parent.global_position + Vector2(10 * b.direction.x, 0)
	parent.get_parent().add_child(b)
	
