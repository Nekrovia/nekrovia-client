extends Node3D

# Streams TerrainChunks in a square radius around the player. This is the
# only place the world is "chunked" - purely an implementation detail for
# performance, not something the player or future editing tools deal with
# directly (they see one continuous 10km x 10km surface).

const LOAD_RADIUS := 3

@export var player_path: NodePath

var terrain_noise: TerrainNoise
var _loaded_chunks: Dictionary = {} # Vector2i -> TerrainChunk
var _last_center: Vector2i = Vector2i(999999, 999999)

func _ready() -> void:
	var seed_value: int = Net.world_state.get("terrain_seed", 0)
	print("TerrainManager: building terrain with seed %d" % seed_value)
	terrain_noise = TerrainNoise.new(seed_value)
	_update_chunks(Vector3.ZERO)

func _process(_delta: float) -> void:
	var player := get_node_or_null(player_path)
	if player:
		_update_chunks(player.global_position)

func height_at(world_x: float, world_z: float) -> float:
	return terrain_noise.height_at(world_x, world_z)

func _update_chunks(player_pos: Vector3) -> void:
	var center := Vector2i(
		int(floor(player_pos.x / TerrainChunk.CHUNK_SIZE)),
		int(floor(player_pos.z / TerrainChunk.CHUNK_SIZE))
	)
	if center == _last_center and not _loaded_chunks.is_empty():
		return
	_last_center = center

	var needed: Dictionary = {}
	for dx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for dz in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			var key := Vector2i(center.x + dx, center.y + dz)
			needed[key] = true
			if not _loaded_chunks.has(key):
				_load_chunk(key)

	for key in _loaded_chunks.keys().duplicate():
		if not needed.has(key):
			_unload_chunk(key)

func _load_chunk(key: Vector2i) -> void:
	var chunk := TerrainChunk.new()
	add_child(chunk)
	chunk.build(terrain_noise, key.x, key.y)
	_loaded_chunks[key] = chunk

func _unload_chunk(key: Vector2i) -> void:
	_loaded_chunks[key].queue_free()
	_loaded_chunks.erase(key)
