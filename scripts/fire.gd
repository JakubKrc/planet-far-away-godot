extends Node

@onready var parent = get_parent()

var bullet = preload("res://sprites/characters/enemies/simpleBullet.tscn")
var bulletCount = 0
var bulletTimer = 0

func shoot():
	
	if not parent.is_robot_chase:
		return
	
	bulletTimer += 1
	
	if bulletTimer > 80:
		bulletTimer = 0
		bulletCount = 0
		
	if bulletTimer < 80 and bulletCount < 1:
		
		var b = bullet.instantiate()
		b.direction.x = parent.direction.x
		b.SPEED = b.SPEED * -abs(b.direction.x)/b.direction.x
		b.position = self.global_position
		b.position.x -= 10 * -abs(b.direction.x)/b.direction.x
		get_parent().add_child(b)
		
		bulletCount+=1
