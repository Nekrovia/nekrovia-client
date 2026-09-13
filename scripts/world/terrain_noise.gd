class_name TerrainNoise
extends RefCounted

# Custom terrain height function - built entirely on Godot's own FastNoiseLite
# (engine built-in, not a third-party addon). Deterministic from a single
# seed so the server only needs to hand out that one integer for every
# client to generate an identical terrain.

const HEIGHT_SCALE := 60.0
const FREQUENCY := 0.0008

var _noise: FastNoiseLite

func _init(seed_value: int) -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = seed_value
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = FREQUENCY

func height_at(world_x: float, world_z: float) -> float:
	return _noise.get_noise_2d(world_x, world_z) * HEIGHT_SCALE
