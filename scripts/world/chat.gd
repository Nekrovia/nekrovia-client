extends CanvasLayer

const MAX_VISIBLE_MESSAGES := 8

@export var player_path: NodePath

@onready var log_container: VBoxContainer = $LogContainer
@onready var input_box: LineEdit = $InputBox

var _open := false

func _ready() -> void:
	input_box.hide()
	input_box.text_submitted.connect(_on_submit)
	Net.chat_message_received.connect(_on_message_received)

func _unhandled_input(event: InputEvent) -> void:
	if _open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		_open_chat()

func _open_chat() -> void:
	_open = true
	input_box.text = ""
	input_box.show()
	input_box.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_player_input_enabled(false)

func _close_chat() -> void:
	_open = false
	input_box.hide()
	input_box.release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_set_player_input_enabled(true)

func _set_player_input_enabled(enabled: bool) -> void:
	var player := get_node_or_null(player_path)
	if player and player.has_method("set_menu_open"):
		player.set_menu_open(not enabled)

func _on_submit(text: String) -> void:
	Net.send_chat_message(text)
	_close_chat()

func _on_message_received(sender_name: String, text: String) -> void:
	print("Chat: %s: %s" % [sender_name, text])
	var label := Label.new()
	label.text = "%s: %s" % [sender_name, text]
	log_container.add_child(label)
	if log_container.get_child_count() > MAX_VISIBLE_MESSAGES:
		log_container.get_child(0).queue_free()
