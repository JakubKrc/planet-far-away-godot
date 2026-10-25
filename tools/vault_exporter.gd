# Turns Obsidian notes tagged #in_game into game data: notes in dialogue/ become
# dialogues, all others encyclopedia entries. Format guide: vault "_how to write for the game".
class_name VaultExporter
extends RefCounted

const GAME_TAG = "in_game"
const START_TAG = "known_at_start"   # encyclopedia entries the player knows from New Game
const DIALOGUE_FOLDER = "dialogue"
const SKIPPED_FOLDERS = [".obsidian", ".trash", ".git"]
const ITEMS_FOLDER = "res://items/"
const ITEM_KEYS = ["requires", "requires_not", "gives", "removes"]
const FLAG_KEYS = ["sets_flag", "requires_flag", "requires_not_flag"]
const REVEAL_KEY = "reveals"   # encyclopedia entries a choice discovers

var errors: Array = []
var warnings: Array = []
var dialogue_count: int = 0
var entry_count: int = 0
var _entry_notes: Dictionary = {}   # entry id -> note, for checking `reveals`

var _link_pattern := RegEx.create_from_string("(!?)\\[\\[([^\\]|#]+)(#[^\\]|]*)?(?:\\|([^\\]]+))?\\]\\]")
var _tag_pattern := RegEx.create_from_string("(?<![\\w&#])#[A-Za-z_][\\w/-]*")
var _game_tag_pattern := RegEx.create_from_string("(?<![\\w&#])#" + GAME_TAG + "(?![\\w/-])")
var _start_tag_pattern := RegEx.create_from_string("(?<![\\w&#])#" + START_TAG + "(?![\\w/-])")
var _bold_pattern := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
var _italic_pattern := RegEx.create_from_string("(?<![\\*\\w])\\*(?!\\s)(.+?)(?<!\\s)\\*(?![\\*\\w])")
var _speaker_pattern := RegEx.create_from_string("^([^\\[\\]:]{1,40}):\\s+(.*)$")
var _choice_pattern := RegEx.create_from_string("^(.*?)\\s*(?:→|->)\\s*(.*)$")
var _item_pattern := RegEx.create_from_string("^([a-z0-9_]+)(?:\\s+x(\\d+))?$")
var _file_name_pattern := RegEx.create_from_string("^[a-z0-9_-]+$")

# Exports vault_dir into out_dir (dialogue/*.json and encyclopedia.json).
# Returns false and writes nothing when any note has an error.
func export_vault(vault_dir: String, out_dir: String) -> bool:
	errors.clear()
	warnings.clear()
	if not DirAccess.dir_exists_absolute(vault_dir):
		errors.append("Vault folder not found: " + vault_dir)
		return false

	var dialogue_notes = []
	var entry_notes = {}
	for note in _read_tagged_notes(vault_dir):
		if note["folder"] == DIALOGUE_FOLDER:
			dialogue_notes.append(note)
		else:
			entry_notes[_entry_id(note["title"])] = note

	_entry_notes = entry_notes
	var encyclopedia = {}
	for entry_id in entry_notes:
		var note = entry_notes[entry_id]
		encyclopedia[entry_id] = {
			"title": note["title"],
			"text": _note_body_to_bbcode(note["body"], entry_notes, note["path"]),
			"known_at_start": note["known_at_start"],
		}

	var dialogues = {}
	for note in dialogue_notes:
		var file_name = note["title"].to_lower().replace(" ", "_")
		if _file_name_pattern.search(file_name) == null:
			errors.append("%s: dialogue note names may only use letters, digits, spaces, _ and -" % note["path"])
			continue
		var steps = _parse_dialogue(note, entry_notes)
		if not steps.is_empty():
			dialogues[file_name] = steps

	if not errors.is_empty():
		return false
	_write_output(out_dir, dialogues, encyclopedia)
	dialogue_count = dialogues.size()
	entry_count = encyclopedia.size()
	return true

# ── Reading the vault ─────────────────────────────────────────────

# Every note tagged #in_game, as {path, folder, title, body}. `folder` is the
# top-level vault folder the note sits in, or "" for notes in the vault root.
func _read_tagged_notes(vault_dir: String) -> Array:
	var notes = []
	for file_path in _markdown_files(vault_dir):
		# Notes named _something are guides and templates, never game content.
		if file_path.get_file().begins_with("_"):
			continue
		var relative_path = file_path.trim_prefix(vault_dir).trim_prefix("/")
		var text = FileAccess.get_file_as_string(file_path).replace("\r\n", "\n")
		var frontmatter = ""
		var body = text
		if text.begins_with("---\n"):
			var end = text.find("\n---", 4)
			if end != -1:
				frontmatter = text.substr(4, end - 4)
				body = text.substr(end + 4).trim_prefix("\n")
		var tagged_in_body = _game_tag_pattern.search(body) != null
		var tagged_in_frontmatter = frontmatter.contains(GAME_TAG)
		var known_at_start = _start_tag_pattern.search(body) != null or frontmatter.contains(START_TAG)
		if not tagged_in_body and not tagged_in_frontmatter:
			if known_at_start:
				warnings.append("%s: tagged #%s but not #%s, so it is not exported" % [relative_path, START_TAG, GAME_TAG])
			continue
		var folder = ""
		if relative_path.contains("/"):
			folder = relative_path.get_slice("/", 0)
		notes.append({
			"path": relative_path,
			"folder": folder,
			"title": relative_path.get_file().get_basename(),
			"body": body,
			"known_at_start": known_at_start,
		})
	return notes

func _markdown_files(dir_path: String) -> Array:
	var found = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub_dir in dir.get_directories():
		if sub_dir in SKIPPED_FOLDERS:
			continue
		found.append_array(_markdown_files(dir_path.path_join(sub_dir)))
	for file_name in dir.get_files():
		if file_name.ends_with(".md"):
			found.append(dir_path.path_join(file_name))
	return found

# Obsidian matches links case-insensitively, so ids are lowercase titles.
func _entry_id(title: String) -> String:
	return title.strip_edges().to_lower()

# ── Dialogues ─────────────────────────────────────────────────────

# Parses one dialogue note into the step dictionary the game reads.
# Returns {} when the note has errors (they are added to `errors`).
func _parse_dialogue(note: Dictionary, entry_notes: Dictionary) -> Dictionary:
	var where = note["path"]
	var error_count_before = errors.size()
	var steps = {}
	var step_order = []
	var current_step = null
	var current_choice = null
	var line_number = 0

	for raw_line in note["body"].split("\n"):
		line_number += 1
		var line = raw_line.strip_edges()
		var place = "%s:%d" % [where, line_number]
		if line.begins_with("## "):
			var step_id = line.substr(3).strip_edges()
			if steps.has(step_id):
				errors.append("%s: step '%s' is defined twice" % [place, step_id])
			current_step = {"paragraphs": [[]], "choices": []}
			steps[step_id] = current_step
			step_order.append(step_id)
			current_choice = null
			continue
		# Anything above the first step (a title, the #in_game tag) is for the writer.
		if current_step == null:
			continue
		if line == "":
			if not current_step["paragraphs"][-1].is_empty():
				current_step["paragraphs"].append([])
			continue
		var is_list_item = line.begins_with("- ") or line.begins_with("* ")
		if is_list_item and not _is_indented(raw_line):
			current_choice = _parse_choice(line.substr(2).strip_edges())
			current_step["choices"].append(current_choice)
			continue
		if is_list_item:
			if current_choice == null:
				errors.append("%s: an indented setting needs a choice above it" % place)
				continue
			_parse_choice_setting(current_choice, line.substr(2).strip_edges(), place)
			continue
		if not current_step["choices"].is_empty():
			errors.append("%s: text after the choices; put it above the first choice" % place)
			continue
		current_step["paragraphs"][-1].append(line)

	if not steps.has("start"):
		errors.append("%s: no '## start' step; every dialogue begins there" % where)
	for step_id in step_order:
		for choice in steps[step_id]["choices"]:
			var next = choice["next"]
			if next != null and not steps.has(next):
				errors.append("%s: choice '%s' in step '%s' leads to '%s', which does not exist" % [where, choice["text"], step_id, next])

	if errors.size() > error_count_before:
		return {}
	var game_steps = {}
	for step_id in step_order:
		game_steps[step_id] = _step_for_game(steps[step_id], entry_notes, where)
	return game_steps

# Lines indented with a tab or at least two spaces are settings of the choice above.
func _is_indented(raw_line: String) -> bool:
	return raw_line.begins_with("\t") or raw_line.begins_with("  ")

func _parse_choice(item_text: String) -> Dictionary:
	var choice_text = item_text
	var next = null
	var found = _choice_pattern.search(item_text)
	if found != null:
		choice_text = found.get_string(1).strip_edges()
		var target = found.get_string(2).strip_edges()
		if target != "" and target.to_lower() != "end":
			next = target
	# Choice rows are plain labels, so links in them keep only their text.
	return {"text": _links_to_plain_text(choice_text), "next": next}

func _parse_choice_setting(choice: Dictionary, setting: String, place: String):
	var colon = setting.find(":")
	if colon == -1:
		errors.append("%s: expected 'key: value', got '%s'" % [place, setting])
		return
	var key = setting.substr(0, colon).strip_edges()
	var value = setting.substr(colon + 1).strip_edges()
	if key in ITEM_KEYS:
		choice[key] = _parse_item_list(value, place)
	elif key in FLAG_KEYS:
		choice[key] = _split_list(value)
	elif key == REVEAL_KEY:
		choice[key] = _parse_entry_list(value, place)
	else:
		var known_keys = ITEM_KEYS + FLAG_KEYS + [REVEAL_KEY]
		errors.append("%s: unknown setting '%s' (known: %s)" % [place, key, ", ".join(known_keys)])

# "Igor Kozlov, V4 city state" -> ["igor kozlov", "v4 city state"]
func _parse_entry_list(value: String, place: String) -> Array:
	var entry_ids = []
	for name in _split_list(value):
		var entry_id = _entry_id(name)
		if not _entry_notes.has(entry_id):
			errors.append("%s: reveals '%s', but no note by that name is tagged #%s" % [place, name, GAME_TAG])
			continue
		entry_ids.append(entry_id)
	return entry_ids

# "spare_part, potion x2" -> {"spare_part": 1, "potion": 2}
func _parse_item_list(value: String, place: String) -> Dictionary:
	var items = {}
	for part in _split_list(value):
		var found = _item_pattern.search(part)
		if found == null:
			errors.append("%s: '%s' is not an item id (write it like spare_part or spare_part x2)" % [place, part])
			continue
		var item_id = found.get_string(1)
		var amount = 1
		if found.get_string(2) != "":
			amount = int(found.get_string(2))
		if not ResourceLoader.exists(ITEMS_FOLDER + item_id + ".tres"):
			errors.append("%s: no item '%s' in %s" % [place, item_id, ITEMS_FOLDER])
			continue
		items[item_id] = amount
	return items

func _split_list(value: String) -> Array:
	var parts = []
	for part in value.split(","):
		if part.strip_edges() != "":
			parts.append(part.strip_edges())
	return parts

func _step_for_game(step: Dictionary, entry_notes: Dictionary, where: String) -> Dictionary:
	var paragraphs = []
	for paragraph in step["paragraphs"]:
		if not paragraph.is_empty():
			paragraphs.append(" ".join(paragraph))
	# "Troguon: Hey there." names the speaker at the start of the first paragraph.
	var speaker = ""
	if not paragraphs.is_empty():
		var found = _speaker_pattern.search(paragraphs[0])
		if found != null:
			speaker = found.get_string(1).strip_edges()
			paragraphs[0] = found.get_string(2)
	var text = "\n".join(paragraphs)
	return {
		"speaker": speaker,
		"text": _inline_to_bbcode(_strip_tags(text), entry_notes, where),
		"choices": step["choices"],
	}

# ── Text conversion ───────────────────────────────────────────────

# A whole encyclopedia note: headings become bold lines, list items get a bullet.
func _note_body_to_bbcode(body: String, entry_notes: Dictionary, where: String) -> String:
	var lines = []
	for raw_line in _strip_tags(body).split("\n"):
		var line = raw_line.strip_edges()
		if line.begins_with("#"):
			var heading = line.lstrip("#").strip_edges()
			lines.append("[b]" + _inline_to_bbcode(heading, entry_notes, where) + "[/b]")
		elif line.begins_with("- ") or line.begins_with("* "):
			lines.append("• " + _inline_to_bbcode(line.substr(2), entry_notes, where))
		else:
			lines.append(_inline_to_bbcode(line, entry_notes, where))
	var text = "\n".join(lines).strip_edges()
	while text.contains("\n\n\n"):
		text = text.replace("\n\n\n", "\n\n")
	return text

# Converts links, **bold** and *italic*, and escapes stray brackets for BBCode.
func _inline_to_bbcode(text: String, entry_notes: Dictionary, where: String) -> String:
	var result = ""
	var position = 0
	for found in _link_pattern.search_all(text):
		result += _plain_to_bbcode(text.substr(position, found.get_start() - position))
		position = found.get_end()
		var is_embed = found.get_string(1) == "!"
		var target = found.get_string(2).strip_edges().get_file()
		var shown_text = found.get_string(4).strip_edges()
		if shown_text == "":
			shown_text = target
		if is_embed:
			warnings.append("%s: embedded note ![[%s]] is left out of the game" % [where, target])
			continue
		var entry_id = _entry_id(target)
		if entry_notes.has(entry_id):
			result += "[url=%s]%s[/url]" % [entry_id, _escape_brackets(shown_text)]
		else:
			warnings.append("%s: link to '%s' shown as plain text; that note is missing or not tagged #%s" % [where, target, GAME_TAG])
			result += _escape_brackets(shown_text)
	result += _plain_to_bbcode(text.substr(position))
	return result

func _plain_to_bbcode(text: String) -> String:
	var escaped = _escape_brackets(text)
	escaped = _bold_pattern.sub(escaped, "[b]$1[/b]", true)
	escaped = _italic_pattern.sub(escaped, "[i]$1[/i]", true)
	return escaped

func _escape_brackets(text: String) -> String:
	return text.replace("[", "[lb]")

func _links_to_plain_text(text: String) -> String:
	var result = ""
	var position = 0
	for found in _link_pattern.search_all(text):
		result += text.substr(position, found.get_start() - position)
		position = found.get_end()
		var shown_text = found.get_string(4).strip_edges()
		if shown_text == "":
			shown_text = found.get_string(2).strip_edges().get_file()
		result += shown_text
	return result + text.substr(position)

# Tags are for organising the vault, not for players.
func _strip_tags(text: String) -> String:
	var without_tags = _tag_pattern.sub(text, "", true)
	var lines = []
	for line in without_tags.split("\n"):
		lines.append(line.strip_edges(false, true))
	return "\n".join(lines)

# ── Writing ───────────────────────────────────────────────────────

func _write_output(out_dir: String, dialogues: Dictionary, encyclopedia: Dictionary):
	var dialogue_dir = out_dir.path_join("dialogue")
	DirAccess.make_dir_recursive_absolute(dialogue_dir)
	# The folder holds only generated files, so stale ones from deleted notes go.
	for old_file in DirAccess.get_files_at(dialogue_dir):
		if old_file.ends_with(".json"):
			DirAccess.remove_absolute(dialogue_dir.path_join(old_file))
	for file_name in dialogues:
		_write_json(dialogue_dir.path_join(file_name + ".json"), dialogues[file_name])
	_write_json(out_dir.path_join("encyclopedia.json"), encyclopedia)

func _write_json(path: String, data: Dictionary):
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		errors.append("Could not write %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data, "\t", false) + "\n")
	file.close()
