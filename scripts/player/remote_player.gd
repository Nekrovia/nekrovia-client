extends Node3D

@onready var nametag: Label3D = $Nametag

func set_display_name(text: String) -> void:
	nametag.text = text

func apply_transform(pos: Vector3, rot_y: float) -> void:
	global_position = pos
	rotation.y = rot_y
