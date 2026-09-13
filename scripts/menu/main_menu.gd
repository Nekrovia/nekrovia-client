extends Control

const SERVERS := [
	{"name": "Nekrovia - serwer glowny", "address": "46.151.138.13", "port": 8910, "token": "nW1gF3JsEfMfO0aVRNr1YBQQ"},
]

@onready var btn_join: Button = $TopBar/HBox/BtnJoin
@onready var btn_profile: Button = $TopBar/HBox/BtnProfile
@onready var btn_settings: Button = $TopBar/HBox/BtnSettings
@onready var btn_tools: Button = $TopBar/HBox/BtnTools
@onready var btn_update: Button = $TopBar/HBox/BtnUpdate
@onready var update_status_label: Label = $TopBar/HBox/UpdateStatusLabel

@onready var join_panel: VBoxContainer = $ContentArea/JoinPanel
@onready var server_list: VBoxContainer = $ContentArea/JoinPanel/ServerList
@onready var status_label: Label = $ContentArea/JoinPanel/StatusLabel
@onready var placeholder_panel: Label = $ContentArea/PlaceholderPanel

func _ready() -> void:
	for server in SERVERS:
		_add_server_row(server)

	Net.connected_to_server.connect(_on_connected)
	Net.connection_failed.connect(_on_connection_failed)
	Net.disconnected_from_server.connect(_on_connection_failed)

	btn_join.pressed.connect(_show_join_panel)
	btn_profile.pressed.connect(_show_placeholder.bind("Profil - wkrotce"))
	btn_settings.pressed.connect(_show_placeholder.bind("Ustawienia - wkrotce"))
	btn_tools.pressed.connect(_show_placeholder.bind("Nasze narzedzia - wkrotce"))
	btn_update.pressed.connect(_on_update_pressed)

	UpdateChecker.update_available.connect(_on_update_available)
	UpdateChecker.up_to_date.connect(_on_up_to_date)
	UpdateChecker.check_failed.connect(_on_check_failed)
	UpdateChecker.update_applied.connect(_on_update_applied)
	UpdateChecker.update_failed.connect(_on_update_failed)

	_show_join_panel()
	UpdateChecker.check_for_update()

func _show_join_panel() -> void:
	join_panel.show()
	placeholder_panel.hide()

func _show_placeholder(text: String) -> void:
	placeholder_panel.text = text
	placeholder_panel.show()
	join_panel.hide()

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

	server_list.add_child(row)

func _on_join_pressed(server: Dictionary) -> void:
	status_label.text = "Laczenie z %s..." % server["address"]
	Net.join(server["address"], server["port"], "Gracz", "player", server.get("token", ""))

func _on_connected() -> void:
	status_label.text = "Polaczono!"
	get_tree().change_scene_to_file("res://scenes/world/test_world.tscn")

func _on_connection_failed() -> void:
	status_label.text = "Nie udalo sie polaczyc z serwerem."

# --- Update button (top bar) - read-only against GitHub: only ever pulls,
# never pushes or resets anything. ---

func _on_update_pressed() -> void:
	update_status_label.text = "Sprawdzam..."
	btn_update.disabled = true
	UpdateChecker.check_for_update()

func _on_update_available(_remote_sha: String) -> void:
	update_status_label.text = "Pobieram aktualizacje..."
	UpdateChecker.pull_update()

func _on_up_to_date() -> void:
	update_status_label.text = "Wersja aktualna"
	btn_update.disabled = false

func _on_check_failed(_reason: String) -> void:
	update_status_label.text = "Nie udalo sie sprawdzic aktualizacji"
	btn_update.disabled = false

func _on_update_applied() -> void:
	update_status_label.text = "Zaktualizowano! Zrestartuj gre."

func _on_update_failed(_reason: String) -> void:
	update_status_label.text = "Aktualizacja nie powiodla sie"
	btn_update.disabled = false
