extends Control

const SIZE := 6.0
const THICKNESS := 2.0
const GAP := 2.0
const COLOR := Color(1, 1, 1, 0.85)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var center := get_rect().size / 2.0
	draw_line(center - Vector2(SIZE, 0), center - Vector2(GAP, 0), COLOR, THICKNESS)
	draw_line(center + Vector2(GAP, 0), center + Vector2(SIZE, 0), COLOR, THICKNESS)
	draw_line(center - Vector2(0, SIZE), center - Vector2(0, GAP), COLOR, THICKNESS)
	draw_line(center + Vector2(0, GAP), center + Vector2(0, SIZE), COLOR, THICKNESS)
