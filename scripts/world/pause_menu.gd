extends CanvasLayer

const HELP_TEXT := "STEROWANIE\n\nWASD - ruch\nSPACJA - skok\nSHIFT - bieg\nV - zmiana kamery (1/3 osoba)\nBACKSPACE - lot\nESC - to menu"

@export var player_path: NodePath

@onready var main_panel: VBoxContainer = $MainPanel
@onready var help_panel: VBoxContainer = $HelpPanel
@onready var help_label: Label = $HelpPanel/HelpLabel

var _open := false

func _ready() -> void:
	visible = false
	$MainPanel/ReturnButton.pressed.connect(_close)
	$MainPanel/HelpButton.pressed.connect(_show_help)
	$MainPanel/LeaveButton.pressed.connect(_leave_server)
	$HelpPanel/BackButton.pressed.connect(_show_main)
	help_label.text = HELP_TEXT

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _open:
			_close()
		else:
			_open_menu()

func _open_menu() -> void:
	_open = true
	visible = true
	_show_main()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_player_menu_open(true)

func _close() -> void:
	_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_player_menu_open(false)

func _set_player_menu_open(open: bool) -> void:
	var player := get_node_or_null(player_path)
	if player and player.has_method("set_menu_open"):
		player.set_menu_open(open)

func _show_main() -> void:
	main_panel.show()
	help_panel.hide()

func _show_help() -> void:
	main_panel.hide()
	help_panel.show()

func _leave_server() -> void:
	Net.leave_server()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
