extends Control

const SERVERS := [
	{"name": "Nekrovia - serwer glowny", "address": "46.151.138.13", "port": 8910, "token": "nW1gF3JsEfMfO0aVRNr1YBQQ"},
]

@onready var list: VBoxContainer = $Panel/VBoxContainer/ServerList
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var update_label: Label = $Panel/VBoxContainer/UpdateBar/UpdateLabel
@onready var update_button: Button = $Panel/VBoxContainer/UpdateBar/UpdateButton
@onready var update_bar: HBoxContainer = $Panel/VBoxContainer/UpdateBar

func _ready() -> void:
	for server in SERVERS:
		_add_server_row(server)
	Net.connected_to_server.connect(_on_connected)
	Net.connection_failed.connect(_on_connection_failed)
	Net.disconnected_from_server.connect(_on_connection_failed)

	update_bar.hide()
	update_button.focus_mode = Control.FOCUS_NONE
	update_button.pressed.connect(_on_update_button_pressed)
	UpdateChecker.update_available.connect(_on_update_available)
	UpdateChecker.update_applied.connect(_on_update_applied)
	UpdateChecker.update_failed.connect(_on_update_failed)
	UpdateChecker.check_for_update()

func _on_update_available(remote_sha: String) -> void:
	update_label.text = "Dostepna nowa wersja (%s)" % remote_sha.substr(0, 7)
	update_button.text = "Aktualizuj"
	update_button.disabled = false
	update_bar.show()

func _on_update_button_pressed() -> void:
	update_label.text = "Aktualizuje..."
	update_button.disabled = true
	UpdateChecker.pull_update()

func _on_update_applied() -> void:
	update_label.text = "Zaktualizowano! Zamknij i uruchom gre ponownie."
	update_button.hide()

func _on_update_failed(reason: String) -> void:
	update_label.text = "Aktualizacja nie powiodla sie: %s" % reason
	update_button.text = "Sprobuj ponownie"
	update_button.disabled = false

func _add_server_row(server: Dictionary) -> void:
	var row := HBoxContainer.new()

	var label := Label.new()
	label.text = "%s  (%s:%d)" % [server["name"], server["address"], server["port"]]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var join_button := Button.new()
	join_button.text = "Dolacz"
	join_button.focus_mode = Control.FOCUS_NONE
	join_button.pressed.connect(_on_join_pressed.bind(server))
	row.add_child(join_button)

	list.add_child(row)

func _on_join_pressed(server: Dictionary) -> void:
	status_label.text = "Laczenie z %s..." % server["address"]
	Net.join(server["address"], server["port"], "Gracz", "player", server.get("token", ""))

func _on_connected() -> void:
	status_label.text = "Polaczono!"
	get_tree().change_scene_to_file("res://scenes/world/test_world.tscn")

func _on_connection_failed() -> void:
	status_label.text = "Nie udalo sie polaczyc z serwerem."
