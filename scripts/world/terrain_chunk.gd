class_name TerrainChunk
extends StaticBody3D

# One square patch of the continuous world terrain. Sampled in WORLD-space
# coordinates so adjacent chunks share identical height values along their
# border - no visible seams, no manual chunk placement by hand. This is a
# streaming/performance detail only; from the outside it should read as one
# seamless surface, not a grid the player or future tools have to think about.

const CHUNK_SIZE := 100.0
const RESOLUTION := 24 # quads per side

var chunk_x: int
var chunk_z: int

func build(terrain_noise: TerrainNoise, cx: int, cz: int) -> void:
	chunk_x = cx
	chunk_z = cz
	var origin_x := cx * CHUNK_SIZE
	var origin_z := cz * CHUNK_SIZE
	position = Vector3(origin_x, 0.0, origin_z)

	var step := CHUNK_SIZE / RESOLUTION
	var heights := []
	heights.resize(RESOLUTION + 1)
	for iz in range(RESOLUTION + 1):
		var row := PackedFloat32Array()
		row.resize(RESOLUTION + 1)
		for ix in range(RESOLUTION + 1):
			var wx := origin_x + ix * step
			var wz := origin_z + iz * step
			row[ix] = terrain_noise.height_at(wx, wz)
		heights[iz] = row

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for iz in range(RESOLUTION):
		for ix in range(RESOLUTION):
			var x0 := ix * step
			var x1 := (ix + 1) * step
			var z0 := iz * step
			var z1 := (iz + 1) * step
			var h00: float = heights[iz][ix]
			var h10: float = heights[iz][ix + 1]
			var h01: float = heights[iz + 1][ix]
			var h11: float = heights[iz + 1][ix + 1]

			var p00 := Vector3(x0, h00, z0)
			var p10 := Vector3(x1, h10, z0)
			var p01 := Vector3(x0, h01, z1)
			var p11 := Vector3(x1, h11, z1)

			st.add_vertex(p00)
			st.add_vertex(p10)
			st.add_vertex(p11)

			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p01)

	st.generate_normals()
	var mesh := st.commit()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.42, 0.28)
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
