extends Node2D

@onready var switch1 = $Switch
@onready var platform1 = $Platform

@onready var switch2 = $Switch2
@onready var switch3 = $Switch3

func _ready():
	switch1.activated.connect(platform1.activate)
	switch1.deactivated.connect(platform1.deactivate)
	
	platform1.started_running.connect(switch1._on_platform_running)
	platform1.stopped_running.connect(switch1._on_platform_disabled)

	switch2.activated.connect(switch3._on_platform_running)
	switch3.deactivated.connect(switch2._on_platform_disabled)
