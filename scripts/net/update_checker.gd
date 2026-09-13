extends Node

const REPO := "Nekrovia/nekrovia-client"
const API_URL := "https://api.github.com/repos/%s/commits/main" % REPO

signal update_available(remote_sha: String)
signal up_to_date()
signal check_failed(reason: String)
signal update_applied()
signal update_failed(reason: String)

var _http: HTTPRequest

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func check_for_update() -> void:
	var headers := ["Accept: application/vnd.github+json", "User-Agent: Nekrovia-Client"]
	var err := _http.request(API_URL, headers)
	if err != OK:
		check_failed.emit("request error %d" % err)

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		print("UpdateChecker: check failed (HTTP %d)" % response_code)
		check_failed.emit("HTTP %d" % response_code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("sha"):
		print("UpdateChecker: check failed (unexpected response)")
		check_failed.emit("unexpected response")
		return
	var remote_sha: String = parsed["sha"]
	var local_sha := _get_local_commit()
	if local_sha == "":
		print("UpdateChecker: could not read local git commit")
		check_failed.emit("could not read local git commit")
	elif local_sha == remote_sha:
		print("UpdateChecker: up to date (%s)" % local_sha.substr(0, 7))
		up_to_date.emit()
	else:
		print("UpdateChecker: update available, local=%s remote=%s" % [local_sha.substr(0, 7), remote_sha.substr(0, 7)])
		update_available.emit(remote_sha)

func pull_update() -> void:
	var output := []
	var exit_code := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "pull"], output)
	if exit_code == 0:
		print("UpdateChecker: pulled successfully")
		update_applied.emit()
	else:
		print("UpdateChecker: pull failed: %s" % String("\n").join(output))
		update_failed.emit(String("\n").join(output))

func _get_local_commit() -> String:
	var output := []
	var exit_code := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], output)
	if exit_code != 0 or output.is_empty():
		return ""
	return String(output[0]).strip_edges()
