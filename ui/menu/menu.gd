extends CanvasLayer

enum State { MAIN, PAUSE, SETTINGS }

@export_file("*.tscn") var start_level_path: String = "res://scenes/environment/castle_zone/rooms/room1.tscn"
@export var start_level_portal_name: String = "portal_1"
@export var start_possessed_char: String = "main_char"

const SETTINGS_PATH = "user://settings.cfg"
const MUSIC_BUS = "music"   # defined in audio/default_bus_layout.tres

@onready var bg: ColorRect      = $Bg
@onready var title: Label       = $Center/VBox/Title
@onready var items: VBoxContainer = $Center/VBox/Items
@onready var settings_panel: VBoxContainer = $Center/VBox/Settings
@onready var music_slider: HSlider = $Center/VBox/Settings/MusicRow/Slider
@onready var music_label: Label = $Center/VBox/Settings/MusicRow/Value
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var settings_back: Label = $Center/VBox/Settings/Back
@onready var bg_image: TextureRect = $BgImage
@onready var font_option: OptionButton = $Center/VBox/Settings/FontRow/Option
@onready var size_slider: HSlider = $Center/VBox/Settings/SizeRow/Slider
@onready var size_value: Label = $Center/VBox/Settings/SizeRow/Value

var state = State.MAIN
var _return_state = State.MAIN  # where Settings goes Back to
var _selection: int = 0
var _has_save: bool = false
var _settings_sel: int = 0   # 0=music, 1=font, 2=size, 3=back
const SETTINGS_ROWS = 4

const FONT_OPTIONS = [
	["Default",        "default"],
	["Open Sans",      "open_sans"],
	["Press Start 2P", "press_start_2p"],
]

func _ready():
	Global.menu = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.bus = MUSIC_BUS
	music_slider.value_changed.connect(_on_music_slider_changed)
	for opt in FONT_OPTIONS:
		font_option.add_item(opt[0])
	font_option.item_selected.connect(_on_font_selected)
	size_slider.value_changed.connect(_on_size_slider_changed)
	_load_settings()
	Global.ui_text_settings_changed.connect(_apply_own_fonts)
	_apply_own_fonts()
	open_main()

func _apply_own_fonts():
	Global.apply_to_label(title, 16)
	Global.apply_to_label(settings_back, 10)
	for c in items.get_children():
		Global.apply_to_label(c, 10)

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
	_settings_sel = 0
	_update_settings_highlight()
	show()

func _settings_row_label(row: int) -> Label:
	match row:
		0: return $Center/VBox/Settings/MusicRow/Label
		1: return $Center/VBox/Settings/FontRow/Label
		2: return $Center/VBox/Settings/SizeRow/Label
		3: return settings_back
	return null

func _update_settings_highlight():
	for r in SETTINGS_ROWS:
		var lbl = _settings_row_label(r)
		if lbl == null: continue
		var base = Color(1, 1, 1) if r < 3 else Color(0.7, 0.7, 0.7)
		lbl.modulate = Color(1, 1, 0) if r == _settings_sel else base

func close():
	hide()
	music_player.stop()

# ── Items rendering ───────────────────────────────────────────────

func _rebuild_items(entries: Array):
	# Detach before freeing: queue_free() alone leaves the old labels as children
	# for the rest of the frame, so _update_highlight() would index into stale
	# entries and light up a dying label.
	for c in items.get_children():
		items.remove_child(c)
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
		Global.apply_to_label(lbl, 10)

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
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_step(-1, live)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("use"):
		_activate(live)
		get_viewport().set_input_as_handled()
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
	if event.is_action_pressed("ui_down"):
		_settings_sel = (_settings_sel + 1) % SETTINGS_ROWS
		_update_settings_highlight()
		return
	if event.is_action_pressed("ui_up"):
		_settings_sel = (_settings_sel - 1 + SETTINGS_ROWS) % SETTINGS_ROWS
		_update_settings_highlight()
		return
	if event.is_action_pressed("ui_left"):
		_settings_adjust(-1)
		return
	if event.is_action_pressed("ui_right"):
		_settings_adjust(+1)
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("use"):
		if _settings_sel == 3:
			_act_settings_back()
		return
	# Mouse hover/click for back label
	if event is InputEventMouseMotion:
		for r in SETTINGS_ROWS:
			var lbl = _settings_row_label(r)
			if lbl and lbl.get_global_rect().has_point(event.global_position):
				if _settings_sel != r:
					_settings_sel = r
					_update_settings_highlight()
				break
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if settings_back.get_global_rect().has_point(event.global_position):
			_act_settings_back()
			get_viewport().set_input_as_handled()

func _settings_adjust(dir: int):
	match _settings_sel:
		0:
			music_slider.value = clamp(music_slider.value + dir * music_slider.step, music_slider.min_value, music_slider.max_value)
		1:
			var n = font_option.item_count
			font_option.selected = (font_option.selected + dir + n) % n
			_on_font_selected(font_option.selected)
		2:
			size_slider.value = clamp(size_slider.value + dir * size_slider.step, size_slider.min_value, size_slider.max_value)

# ── Actions ───────────────────────────────────────────────────────

func _act_resume():
	close()
	Global.game_state = Global.GameState.PLAYING
	get_tree().paused = false
	Global.main.set_ingame_ui_visible(true)

func _close_dialogue_if_open():
	if Global.dialogue:
		if Global.dialogue.visible:
			Global.dialogue.hide()
		Global.dialogue._in_dialogue = false
		Global.dialogue.clear_log()
		Global.unblock_player_movement("dialogue")

func _act_new_game():
	Global.game_state = Global.GameState.PLAYING
	Global.per_level_save.clear()
	music_player.stop()
	close()
	_close_dialogue_if_open()
	# Anything that was holding movement belongs to the abandoned run.
	Global.clear_movement_blockers()
	# Both actions are reachable from the in-game pause menu, so a run may still be
	# live with its character parked under /root/main.
	_leave_current_run()
	Global.main.set_ingame_ui_visible(true)
	Global.main.load_level(start_level_path, start_level_portal_name, 10000, 0.1, start_possessed_char)

# Tears down whatever run is still in progress before another level is loaded.
func _leave_current_run():
	if Global.death_menu:
		Global.death_menu.hide()
	Global.main.clear_persistent_characters()

func _act_continue():
	var save = Global.load_game()
	if save.is_empty():
		return
	# Bail before closing the menu, so a damaged save leaves the player here
	# rather than in a running game with no level loaded.
	var target_level: String = str(save.get("current_level", ""))
	if target_level == "":
		push_error("Save has no current_level — cannot continue.")
		return
	Global.game_state = Global.GameState.PLAYING
	get_tree().paused = false
	var possessed = save.get("possessed_char_name", start_possessed_char)
	var spawn_pos = _saved_position(save.get("spawn_position", null))
	var home_level: String = str(save.get("possessed_char_home_level", ""))
	music_player.stop()
	close()
	_close_dialogue_if_open()
	Global.clear_movement_blockers()
	_leave_current_run()
	Global.main.set_ingame_ui_visible(true)
	if home_level != "" and home_level != target_level:
		await Global.main.load_level(home_level, "", 10000, 10000, possessed)
		await Global.main.load_level(target_level, "", 10000, 0.1, "", spawn_pos)
	else:
		await Global.main.load_level(target_level, "", 10000, 0.1, possessed, spawn_pos)

# Saved positions are [x, y] pairs. Anything else falls back to Vector2.ZERO,
# which load_level reads as "use the level's own spawn door".
func _saved_position(value) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(value[0], value[1])
	return Vector2.ZERO

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
	_close_dialogue_if_open()
	Global.clear_movement_blockers()
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

func _on_font_selected(idx: int):
	Global.ui_font_name = FONT_OPTIONS[idx][1]
	Global.ui_text_settings_changed.emit()
	_save_settings()

func _on_size_slider_changed(v: float):
	Global.ui_font_size_scale = v
	size_value.text = "%.1fx" % v
	Global.ui_text_settings_changed.emit()
	_save_settings()

func _apply_music_volume(v: float):
	# Must be the music bus, not Master — Master would take sound effects with it.
	var bus = AudioServer.get_bus_index(MUSIC_BUS)
	if bus < 0:
		push_warning("Audio bus '%s' not found; music volume not applied." % MUSIC_BUS)
		return
	if v <= 0.001:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(v))

func _load_settings():
	var cfg = ConfigFile.new()
	var vol: float = 1.0
	var font_name := "press_start_2p"
	var size_scale := 1.0
	if cfg.load(SETTINGS_PATH) == OK:
		vol        = float(cfg.get_value("audio", "music_volume", 1.0))
		font_name  = str(cfg.get_value("ui", "font_name", "press_start_2p"))
		size_scale = float(cfg.get_value("ui", "font_size_scale", 1.0))
	music_slider.value = vol
	music_label.text = "%d%%" % int(vol * 100)
	_apply_music_volume(vol)
	Global.ui_font_name = font_name
	Global.ui_font_size_scale = size_scale
	for i in FONT_OPTIONS.size():
		if FONT_OPTIONS[i][1] == font_name:
			font_option.selected = i
			break
	size_slider.value = size_scale
	size_value.text = "%.1fx" % size_scale

func _save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_slider.value)
	cfg.set_value("ui", "font_name", Global.ui_font_name)
	cfg.set_value("ui", "font_size_scale", Global.ui_font_size_scale)
	cfg.save(SETTINGS_PATH)
