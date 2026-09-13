extends Node

signal peer_joined(id: int, info: Dictionary)
signal peer_left(id: int)
signal connected_to_server()
signal connection_failed()
signal disconnected_from_server()
signal world_state_updated(key: String, value: Variant)
signal world_state_received()
signal peer_list_updated()
signal peer_position_updated(peer_id: int, pos: Vector3, rot_y: float, head_pitch: float)
signal chat_message_received(sender_name: String, text: String)

const DEFAULT_PORT := 8910
const SAVE_DIR := "world_data"
const SAVE_FILE := "world_state.json"

var is_server: bool = false
var my_name: String = ""
var my_role: String = ""
var my_token: String = ""
var my_client_id: String = ""

# Server-side: every identified peer. Client-side: mirrored copy the server
# broadcasts on every join/leave, so the client can look up e.g. names.
var peers: Dictionary = {} # peer_id (int) -> {name: String, role: String}
var world_state: Dictionary = {}
var server_token: String = ""

func _ready() -> void:
	randomize()

func host(port: int = DEFAULT_PORT, token: String = "") -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		push_error("Net: failed to host on port %d (err %d)" % [port, err])
		return
	multiplayer.multiplayer_peer = peer
	is_server = true
	peers.clear()
	_load_world_state()
	server_token = token if token != "" else _load_or_create_token()
	print("Net[server]: access token = %s" % server_token)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("Net[server]: listening on port %d" % port)

func join(address: String, port: int = DEFAULT_PORT, display_name: String = "player", role: String = "player", token: String = "", client_id: String = "") -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("Net: failed to connect to %s:%d (err %d)" % [address, port, err])
		return
	my_name = display_name
	my_role = role
	my_token = token
	my_client_id = client_id
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	print("Net[client]: connecting to %s:%d..." % [address, port])

# --- Server-side connection handling ---

func _on_peer_connected(id: int) -> void:
	print("Net[server]: peer connected: %d (awaiting identify)" % id)

func _on_peer_disconnected(id: int) -> void:
	if not peers.has(id):
		return
	print("Net[server]: peer left: %d (%s)" % [id, peers[id].get("name", "?")])
	peers.erase(id)
	peer_left.emit(id)
	_broadcast_peer_list()

@rpc("any_peer", "reliable")
func _identify(display_name: String, role: String, token: String, client_id: String) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if token != server_token:
		print("Net[server]: rejected peer %d (bad token)" % id)
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	peers[id] = {"name": display_name, "role": role, "client_id": client_id}
	print("Net[server]: identified peer %d as '%s' (%s, client_id=%s)" % [id, display_name, role, client_id])
	rpc_id(id, "_welcome", world_state)
	peer_joined.emit(id, peers[id])
	_broadcast_peer_list()

func _broadcast_peer_list() -> void:
	for id in peers.keys():
		rpc_id(id, "_peer_list", peers)

# --- Client-side connection handling ---

func _on_connected_to_server() -> void:
	print("Net[client]: connected to server")
	rpc_id(1, "_identify", my_name, my_role, my_token, my_client_id)
	connected_to_server.emit()

func _on_connection_failed() -> void:
	push_error("Net[client]: connection failed")
	connection_failed.emit()

func _on_server_disconnected() -> void:
	push_error("Net[client]: lost connection to server")
	disconnected_from_server.emit()

@rpc("authority", "reliable")
func _welcome(state: Dictionary) -> void:
	world_state = state
	print("Net[client]: received world state (%d keys)" % world_state.size())
	world_state_received.emit()

@rpc("authority", "reliable")
func _peer_list(list: Dictionary) -> void:
	peers = list
	print("Net[client]: peer list updated (%d connected)" % list.size())
	peer_list_updated.emit()

func get_world_data_dir() -> String:
	return _world_data_dir()

# --- Chat ---
# Reliable, server-relayed so everyone (including the sender) sees the same
# messages in the same order - the server is the source of truth here too,
# same as everything else.

func send_chat_message(text: String) -> void:
	text = text.strip_edges()
	if text == "":
		return
	if is_server:
		_broadcast_chat_message(my_name, text)
	elif multiplayer.get_unique_id() != 1:
		rpc_id(1, "_request_chat_message", text)

@rpc("any_peer", "reliable")
func _request_chat_message(text: String) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id):
		return
	text = text.strip_edges()
	if text == "" or text.length() > 240:
		return
	_broadcast_chat_message(peers[id].get("name", str(id)), text)

func _broadcast_chat_message(sender_name: String, text: String) -> void:
	for id in peers.keys():
		rpc_id(id, "_receive_chat_message", sender_name, text)
	print("Net[chat] %s: %s" % [sender_name, text])

@rpc("authority", "reliable")
func _receive_chat_message(sender_name: String, text: String) -> void:
	chat_message_received.emit(sender_name, text)

# --- Player position sync ---
# Unreliable + frequent by design (a dropped position packet is superseded
# by the next one a fraction of a second later - reliability would only add
# latency here). Server relays after verifying the sender already passed
# identify, same guard as world-state writes.

func send_position(pos: Vector3, rot_y: float, head_pitch: float) -> void:
	# unique_id defaults to 1 both for the real server AND for a scene with
	# no multiplayer peer at all (e.g. running test_world.tscn directly,
	# bypassing Net.join()) - a real connected client is never 1, so this
	# also naturally skips sending when there's nothing to send to.
	if is_server or multiplayer.get_unique_id() == 1:
		return
	rpc_id(1, "_update_position", pos, rot_y, head_pitch)

@rpc("any_peer", "unreliable_ordered")
func _update_position(pos: Vector3, rot_y: float, head_pitch: float) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id):
		return
	for other_id in peers.keys():
		if other_id != id:
			rpc_id(other_id, "_peer_position_update", id, pos, rot_y, head_pitch)

@rpc("authority", "unreliable_ordered")
func _peer_position_update(peer_id: int, pos: Vector3, rot_y: float, head_pitch: float) -> void:
	peer_position_updated.emit(peer_id, pos, rot_y, head_pitch)

# --- World state: sandbox persistence + sync ---
# Generic key/value store for now (no asset schema decided yet) so the
# save -> broadcast -> reload loop can be proven end-to-end early.

func set_world_value(key: String, value: Variant) -> void:
	if is_server:
		_apply_world_value(key, value)
	elif multiplayer.get_unique_id() != 1:
		rpc_id(1, "_request_set_world_value", key, value)

@rpc("any_peer", "reliable")
func _request_set_world_value(key: String, value: Variant) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if not peers.has(id):
		print("Net[server]: ignoring set_world_value from unidentified peer %d" % id)
		return
	_apply_world_value(key, value)

func _apply_world_value(key: String, value: Variant) -> void:
	world_state[key] = value
	_save_world_state()
	for id in peers.keys():
		rpc_id(id, "_world_value_changed", key, value)
	world_state_updated.emit(key, value)

@rpc("authority", "reliable")
func _world_value_changed(key: String, value: Variant) -> void:
	world_state[key] = value
	world_state_updated.emit(key, value)
	print("Net[client]: world value changed: %s = %s" % [key, value])

func _world_data_dir() -> String:
	var base_dir: String = OS.get_executable_path().get_base_dir() if OS.has_feature("standalone") else ProjectSettings.globalize_path("res://")
	return base_dir.path_join(SAVE_DIR)

func _world_data_path() -> String:
	return _world_data_dir().path_join(SAVE_FILE)

func _save_world_state() -> void:
	DirAccess.make_dir_recursive_absolute(_world_data_dir())
	var path := _world_data_path()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(world_state))
	else:
		push_error("Net[server]: failed to save world state to %s" % path)

func _load_or_create_token() -> String:
	var dir := _world_data_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("server_secret.txt")
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var existing := f.get_as_text().strip_edges()
		if existing != "":
			return existing
	var generated := _generate_token()
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	if f2:
		f2.store_string(generated)
	return generated

func _generate_token() -> String:
	var chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var result := ""
	for i in range(24):
		result += chars[randi() % chars.length()]
	return result

func _load_world_state() -> void:
	var path := _world_data_path()
	if not FileAccess.file_exists(path):
		world_state = {}
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	world_state = parsed if parsed is Dictionary else {}
	print("Net[server]: loaded world state from disk (%d keys)" % world_state.size())
