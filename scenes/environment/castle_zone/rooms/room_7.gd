extends Node2D

@onready var switch2 = $Switch2
@onready var switch3 = $Switch3

func _ready():
    switch2.activated.connect(switch3._on_platform_running)
    switch3.deactivated.connect(switch2._on_platform_disabled)
    $Switch.activated.connect($Blocker._on_platform_running)
