extends CanvasLayer

enum State { MAIN, PAUSE, SETTINGS }

@export_file("*.tscn") var start_level_path: String = "res://scenes/environment/castle_zone/rooms/room1.tscn"
@export var start_level_portal_name: String = "portal_1"
@export var start_possessed_char: String = "main_char"

const SETTINGS_PATH = "user://settings.cfg"

@onready var bg: ColorRect      = $Bg
@onready var title: Label       = $Center/VBox/Title
@onready var items: VBoxContainer = $Center/VBox/Items
@onready var settings_panel: VBoxContainer = $Center/VBox/Settings
@onready var music_slider: HSlider = $Center/VBox/Settings/MusicRow/Slider
@onready var music_label: Label = $Center/VBox/Settings/MusicRow/Value
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var settings_back: Label = $Center/VBox/Settings/Back
@onready var bg_image: TextureRect = $BgImage

var state = State.MAIN
var _return_state = State.MAIN  # where Settings goes Back to
var _selection: int = 0
var _has_save: bool = false

func _ready():
	Global.menu = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_slider.value_changed.connect(_on_music_slider_changed)
	_load_settings()
	open_main()

# ── Public API ────────────────────────────────────────────────────

func open_main():
	state = State.MAIN
	_has_save = Global.has_save()
	title.text = ""
	bg.color = Color(0, 0, 0, 0.35)
	bg_image.visible = bg_image.texture != null
	settings_panel.hide()
	items.show()
	_rebuild_items([
		["Last checkpoint",  "_act_continue",  _has_save],
		["New Game",  "_act_new_game",  true],
		["Settings",  "_act_open_settings", true],
		["Quit",      "_act_quit", true],
	])
	_selection = 0 if _has_save else 1
	_update_highlight()
	show()
	if not music_player.playing:
		music_player.play()

func open_pause():
	state = State.PAUSE
	title.text = "Paused"
	bg.color = Color(0, 0, 0, 0.55)
	bg_image.hide()
	settings_panel.hide()
	items.show()
	_rebuild_items([
		["Resume",                 "_act_resume",     true],
		["Last checkpoint",    "_act_continue",   Global.has_save()],
		["Settings",               "_act_open_settings", true],
		["Main Menu",              "_act_main_menu",  true],
		["Quit",                   "_act_quit",       true],
	])
	_selection = 0
	_update_highlight()
	show()

func open_settings():
	_return_state = state
	state = State.SETTINGS
	title.text = "Settings"
	items.hide()
	settings_panel.show()
	show()

func close():
	hide()
	music_player.stop()

# ── Items rendering ───────────────────────────────────────────────

func _rebuild_items(entries: Array):
	for c in items.get_children():
		c.queue_free()
	for entry in entries:
		var lbl = Label.new()
		lbl.text = entry[0]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		if not entry[2]:
			lbl.modulate = Color(0.5, 0.5, 0.5)
		lbl.set_meta("action", entry[1])
		lbl.set_meta("enabled", entry[2])
		items.add_child(lbl)

func _update_highlight():
	var live = items.get_children()
	for i in live.size():
		var l: Label = live[i]
		if not l.get_meta("enabled"):
			continue
		l.modulate = Color(1, 1, 0) if i == _selection else Color(1, 1, 1)

# ── Input ─────────────────────────────────────────────────────────

func _input(event: InputEvent):
	if not visible:
		if Global.game_state == Global.GameState.PLAYING and (event.is_action_pressed("escape") or event.is_action_pressed("pause")):
			if Input.is_key_pressed(KEY_ESCAPE) and OS.get_name() == "Web":
				return
			Global.game_state = Global.GameState.PAUSE_MENU
			get_tree().paused = true
			open_pause()
			get_viewport().set_input_as_handled()
		return
	if state == State.SETTINGS:
		_settings_input(event)
		return
	var live = items.get_children()
	if live.is_empty():
		return
	if event is InputEventMouseMotion:
		for i in live.size():
			if live[i].get_global_rect().has_point(event.global_position) and live[i].get_meta("enabled"):
				if _selection != i:
					_selection = i
					_update_highlight()
				break
	if event.is_action_pressed("ui_down"):
		_step(1, live)
	elif event.is_action_pressed("ui_up"):
		_step(-1, live)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("use"):
		_activate(live)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in live.size():
			if live[i].get_global_rect().has_point(event.global_position) and live[i].get_meta("enabled"):
				_selection = i
				_activate(live)
				get_viewport().set_input_as_handled()
				return
	elif state == State.PAUSE and (event.is_action_pressed("escape") or event.is_action_pressed("pause")):
		_act_resume()

func _step(dir: int, live: Array):
	var n = live.size()
	for _i in n:
		_selection = (_selection + dir + n) % n
		if live[_selection].get_meta("enabled"):
			break
	_update_highlight()

func _activate(live: Array):
	var l: Label = live[_selection]
	if not l.get_meta("enabled"):
		return
	call(l.get_meta("action"))

func _settings_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("escape"):
		_act_settings_back()
		return
	if event.is_action_pressed("ui_left"):
		music_slider.value = clamp(music_slider.value - music_slider.step, music_slider.min_value, music_slider.max_value)
		return
	if event.is_action_pressed("ui_right"):
		music_slider.value = clamp(music_slider.value + music_slider.step, music_slider.min_value, music_slider.max_value)
		return
	if event is InputEventMouseMotion:
		var over = settings_back.get_global_rect().has_point(event.global_position)
		settings_back.modulate = Color(1, 1, 0) if over else Color(0.7, 0.7, 0.7)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if settings_back.get_global_rect().has_point(event.global_position):
			_act_settings_back()
			get_viewport().set_input_as_handled()

# ── Actions ───────────────────────────────────────────────────────

func _act_resume():
	close()
	Global.game_state = Global.GameState.PLAYING
	get_tree().paused = false
	Global.main.set_ingame_ui_visible(true)

func _act_new_game():
	Global.game_state = Global.GameState.PLAYING
	Global.per_level_save.clear()
	music_player.stop()
	close()
	Global.main.set_ingame_ui_visible(true)
	Global.main.load_level(start_level_path, start_level_portal_name, 10000, 0.1, start_possessed_char)

func _act_continue():
	var save = Global.load_game()
	if save.is_empty():
		return
	Global.game_state = Global.GameState.PLAYING
	get_tree().paused = false
	var possessed = save.get("possessed_char_name", start_possessed_char)
	var sp = save.get("spawn_position", [0.0, 0.0])
	var spawn_pos = Vector2(sp[0], sp[1])
	var target_level: String = save["current_level"]
	var home_level: String = save.get("possessed_char_home_level", "")
	music_player.stop()
	close()
	Global.main.set_ingame_ui_visible(true)
	if home_level != "" and home_level != target_level:
		await Global.main.load_level(home_level, "", 10000, 10000, possessed)
		await Global.main.load_level(target_level, "", 10000, 0.1, "", spawn_pos)
	else:
		await Global.main.load_level(target_level, "", 10000, 0.1, possessed, spawn_pos)

func _act_main_menu():
	var player = get_tree().get_first_node_in_group("player")
	if player: player.queue_free()
	var mc = get_tree().get_first_node_in_group("main_char")
	if mc: mc.queue_free()
	Global.main.unload_level()
	Global.game_state = Global.GameState.MAIN_MENU
	get_tree().paused = false
	Global.main.backgroundMusicPlayer.playMusic(null, 0)
	Global.main.set_ingame_ui_visible(false)
	open_main()

func _act_open_settings():
	open_settings()

func _act_quit():
	get_tree().quit()

func _act_settings_back():
	if _return_state == State.PAUSE:
		open_pause()
	else:
		open_main()

# ── Settings ──────────────────────────────────────────────────────

func _on_music_slider_changed(v: float):
	music_label.text = "%d%%" % int(v * 100)
	_apply_music_volume(v)
	_save_settings()

func _apply_music_volume(v: float):
	var bus = AudioServer.get_bus_index("Master")
	if bus < 0: bus = 0
	if v <= 0.001:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(v))

func _load_settings():
	var cfg = ConfigFile.new()
	var vol: float = 1.0
	if cfg.load(SETTINGS_PATH) == OK:
		vol = float(cfg.get_value("audio", "music_volume", 1.0))
	music_slider.value = vol
	music_label.text = "%d%%" % int(vol * 100)
	_apply_music_volume(vol)

func _save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_slider.value)
	cfg.save(SETTINGS_PATH)
