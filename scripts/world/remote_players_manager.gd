extends Node3D

# Spawns/moves/despawns a visual-only avatar for every OTHER connected peer.
# Not authoritative over anything - purely a rendering of what Net already
# knows (peers list + relayed position updates).

const REMOTE_PLAYER_SCENE := preload("res://scenes/player/remote_player.tscn")

var _avatars: Dictionary = {} # peer_id (int) -> RemotePlayer node

func _ready() -> void:
	Net.peer_list_updated.connect(_sync_avatars)
	Net.peer_left.connect(_on_peer_left)
	Net.peer_position_updated.connect(_on_position_updated)
	_sync_avatars()

func _sync_avatars() -> void:
	var my_id := multiplayer.get_unique_id()
	for id in Net.peers.keys():
		if id == my_id:
			continue
		if not _avatars.has(id):
			_spawn_avatar(id)
		else:
			_avatars[id].set_display_name(Net.peers[id].get("name", str(id)))

func _spawn_avatar(id: int) -> void:
	var avatar := REMOTE_PLAYER_SCENE.instantiate()
	add_child(avatar)
	avatar.set_display_name(Net.peers[id].get("name", str(id)))
	_avatars[id] = avatar
	print("RemotePlayersManager: spawned avatar for peer %d" % id)

func _on_peer_left(id: int) -> void:
	if _avatars.has(id):
		_avatars[id].queue_free()
		_avatars.erase(id)
		print("RemotePlayersManager: removed avatar for peer %d" % id)

func _on_position_updated(peer_id: int, pos: Vector3, rot_y: float, _head_pitch: float) -> void:
	if _avatars.has(peer_id):
		_avatars[peer_id].apply_transform(pos, rot_y)
