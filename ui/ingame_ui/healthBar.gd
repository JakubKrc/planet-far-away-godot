extends ProgressBar

@onready var timer = $Timer
@onready var damage_bar = $DamageBar

enum which_value_enum {
	HEALTH,
	FLY_FUEL
}
@export var which_value : which_value_enum = which_value_enum.HEALTH
@export var use_timer: bool = true

var health = 0 : set = _set_health
var max_health: float : set = _set_max_health

func _set_max_health(new_max):
	max_health = new_max
	size = Vector2((max_health/2), 4) 
	max_value = max_health
	damage_bar.size = Vector2(max_health/2, 4)
	damage_bar.max_value = max_health

func _process(_delta):
	if which_value == which_value_enum.HEALTH:
		if (Global.controlled_char != null and health!=Global.controlled_char.health):
			health = Global.controlled_char.health
			max_health = Global.controlled_char.max_health
	if which_value == which_value_enum.FLY_FUEL && Global.controlled_char!=null:
		var fill_style := get_theme_stylebox("fill").duplicate()
		fill_style.bg_color = Color.DARK_BLUE
		add_theme_stylebox_override("fill", fill_style)
		if Global.controlled_char.components.get("JumpControlledFly") == null:
			visible = false
		else:
			visible = true
		if (Global.controlled_char.components.get("JumpControlledFly") != null and health!=Global.controlled_char.components["JumpControlledFly"].current_fuel):
			health = Global.controlled_char.components.get("JumpControlledFly").current_fuel
			max_health = Global.controlled_char.components.get("JumpControlledFly").max_fuel

func _set_health(new_health):
	var prev_health = health
	health = min(max_value, new_health)
	value = health
		
	if use_timer:
		if health < prev_health:
			timer.start()
		else:
			damage_bar.value = health
	else:
		damage_bar.value = health

func _on_timer_timeout():
	damage_bar.value = health
