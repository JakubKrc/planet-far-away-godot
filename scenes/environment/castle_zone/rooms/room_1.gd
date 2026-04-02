extends Node2D

@onready var switch_a = $MovingPlatform_2/Switch3
@onready var switch_b = $Switch4
@onready var platform1 = $MovingPlatform_2
func _ready():
	switch_a.activated.connect(platform1.activate)
	switch_b.activated.connect(platform1.activate)
	
	switch_a.deactivated.connect(platform1.deactivate)
	switch_b.deactivated.connect(platform1.deactivate)
	
	platform1.started_running.connect(switch_a._on_platform_running)
	platform1.stopped_running.connect(switch_a._on_platform_disabled)
	platform1.started_running.connect(switch_b._on_platform_running)
	platform1.stopped_running.connect(switch_b._on_platform_disabled)
