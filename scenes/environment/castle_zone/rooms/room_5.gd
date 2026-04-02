extends Node2D

@onready var switch1 = $Switch
@onready var platform1 = $Platform

func _ready():
	switch1.activated.connect(platform1.activate)
	switch1.deactivated.connect(platform1.deactivate)
	
	platform1.started_running.connect(switch1._on_platform_running)
	platform1.stopped_running.connect(switch1._on_platform_disabled)
