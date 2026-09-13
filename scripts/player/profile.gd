extends Node

# Local player identity - purely client-side preference/ID, never touches
# GitHub or anything git-related. The server only ever sees whatever gets
# passed to Net.join() (name + client_id), it doesn't read this file.

const PROFILE_PATH := "user://profile.cfg"

const MIN_NAME_LENGTH := 2
const NAME_REGEX_PATTERN := "^[A-Za-zÀ-ÖØ-öø-ſ]+$" # letters only, no digits/symbols/spaces

var player_name: String = ""
var client_id: String = ""
var _name_regex: RegEx

func has_valid_name() -> bool:
	return is_valid_name(player_name)

func is_valid_name(name: String) -> bool:
	return name.length() > MIN_NAME_LENGTH and _name_regex.search(name) != null

func _ready() -> void:
	randomize()
	_name_regex = RegEx.new()
	_name_regex.compile(NAME_REGEX_PATTERN)
	_load()
	if client_id == "":
		client_id = _generate_client_id()
		_save()

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return
	player_name = cfg.get_value("profile", "player_name", player_name)
	client_id = cfg.get_value("profile", "client_id", "")

func set_player_name(new_name: String) -> bool:
	new_name = new_name.strip_edges()
	if not is_valid_name(new_name):
		return false
	player_name = new_name
	_save()
	return true

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "player_name", player_name)
	cfg.set_value("profile", "client_id", client_id)
	cfg.save(PROFILE_PATH)

func _generate_client_id() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	var result := ""
	for i in range(16):
		result += chars[randi() % chars.length()]
	return result
