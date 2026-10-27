# Checks the vault converter against the small fixture vaults in tests/fixtures.
#   godot --headless --path . -s res://tests/vault_export.gd
extends SceneTree

const GOOD_VAULT = "res://tests/fixtures/vault"
const BROKEN_VAULT = "res://tests/fixtures/broken_vault"
const GOOD_OUT = "user://vault_export_test/good"
const BROKEN_OUT = "user://vault_export_test/broken"

var failures: int = 0
var checks: int = 0

func _initialize():
	_good_vault_exports_correctly()
	_broken_vault_writes_nothing()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _good_vault_exports_correctly():
	print("== good vault")
	_remove_folder(GOOD_OUT)
	var exporter = VaultExporter.new()
	var succeeded = exporter.export_vault(ProjectSettings.globalize_path(GOOD_VAULT), GOOD_OUT)
	_check("export succeeds", succeeded, str(exporter.errors))
	_check("one dialogue, four entries", exporter.dialogue_count == 1 and exporter.entry_count == 4, "%d / %d" % [exporter.dialogue_count, exporter.entry_count])
	_check("untagged dialogue skipped", not FileAccess.file_exists(GOOD_OUT + "/dialogue/draft.json"))
	_check("notes named _something skipped", not FileAccess.file_exists(GOOD_OUT + "/dialogue/_template.json"))

	var dialogue = _read_json(GOOD_OUT + "/dialogue/guard.json")
	var start = dialogue.get("start", {})
	_check("speaker read from the line", start.get("speaker") == "Guard", str(start.get("speaker")))
	var expected_start = "Stay away from [url=old tower]the tower[/url]. Ask me about the [b]captain[/b] or the Secret Note."
	_check("links and bold converted", start.get("text") == expected_start, str(start.get("text")))
	_check("untagged link warned about", _any_contains(exporter.warnings, "Secret Note"), str(exporter.warnings))

	var choices = start.get("choices", [])
	_check("three choices", choices.size() == 3, str(choices.size()))
	if choices.size() == 3:
		_check("arrow sets next step", choices[0]["next"] == "tower")
		_check("reveals lists entry ids", choices[0].get("reveals") == ["tower key"], str(choices[0].get("reveals")))
		_check("'-> end' ends the talk", choices[1]["next"] == null)
		_check("no arrow ends the talk", choices[2]["next"] == null)
		_check("ends_memory read as true", choices[2].get("ends_memory") == true, str(choices[2]))
		_check("other choices do not end a memory", not choices[0].has("ends_memory"))
		var gives = choices[1].get("gives", {})
		_check("item amount parsed", gives.keys() == ["test_potion"] and int(gives["test_potion"]) == 2, str(gives))
		_check("flag list parsed", choices[1].get("sets_flag") == ["guard_gave_potions", "met_guard"], str(choices[1].get("sets_flag")))

	var tower_text = dialogue.get("tower", {}).get("text")
	var expected_tower = "The [url=guard captain]Guard Captain[/url] guards it. It is very old.\nNobody goes there. Like everything in [url=world]this world[/url]."
	_check("lines joined, blank line starts a paragraph", tower_text == expected_tower, str(tower_text))

	var encyclopedia = _read_json(GOOD_OUT + "/encyclopedia.json")
	_check("frontmatter tag counts", encyclopedia.has("guard captain"))
	_check("untagged note left out", not encyclopedia.has("secret note"))
	_check("#known_at_start marks an entry", encyclopedia.get("world", {}).get("known_at_start") == true)
	_check("entries are not known at start by default", encyclopedia.get("old tower", {}).get("known_at_start") == false)
	_check("#known_at_start without #in_game warned about", _any_contains(exporter.warnings, "Lost Map.md: tagged #known_at_start but not #in_game"), str(exporter.warnings))
	_check("...and not exported", not encyclopedia.has("lost map"))
	var tower = encyclopedia.get("old tower", {})
	_check("entry keeps its title", tower.get("title") == "Old Tower", str(tower.get("title")))
	var expected_entry = "[b]The tower[/b]\nBuilt long ago. See [url=guard captain]Guard Captain[/url].\n• Tall\n• Old [lb]weird] bracket"
	_check("tags removed, headings, bullets, brackets", tower.get("text") == expected_entry, str(tower.get("text")))

func _broken_vault_writes_nothing():
	print("== broken vault")
	_remove_folder(BROKEN_OUT)
	var exporter = VaultExporter.new()
	var succeeded = exporter.export_vault(ProjectSettings.globalize_path(BROKEN_VAULT), BROKEN_OUT)
	_check("export fails", not succeeded)
	_check("missing step reported", _any_contains(exporter.errors, "'nowhere', which does not exist"), str(exporter.errors))
	_check("missing item reported", _any_contains(exporter.errors, "no item 'no_such_item'"), str(exporter.errors))
	_check("unknown setting reported", _any_contains(exporter.errors, "unknown setting 'colour'"), str(exporter.errors))
	_check("reveal of a missing entry reported", _any_contains(exporter.errors, "reveals 'Nobody'"), str(exporter.errors))
	_check("ends_memory other than yes reported", _any_contains(exporter.errors, "write 'ends_memory: yes'"), str(exporter.errors))
	_check("nothing written", not DirAccess.dir_exists_absolute(BROKEN_OUT))

# ── Helpers ───────────────────────────────────────────────────────

func _check(label: String, ok: bool, detail: String = ""):
	checks += 1
	if ok:
		print("  PASS ", label)
		return
	failures += 1
	print("  FAIL ", label, "  ", detail)

func _read_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}

func _any_contains(messages: Array, fragment: String) -> bool:
	for message in messages:
		if message.contains(fragment):
			return true
	return false

func _remove_folder(path: String):
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub_dir in DirAccess.get_directories_at(path):
		_remove_folder(path.path_join(sub_dir))
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)
