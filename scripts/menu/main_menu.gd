extends Control

const SERVERS := [
	{"name": "Nekrovia - serwer glowny", "address": "46.151.138.13", "port": 8910, "token": "nW1gF3JsEfMfO0aVRNr1YBQQ"},
]

# Placeholders only - the real tools (and what "clicking" one should even do)
# are a separate conversation still to happen. This just gives the gallery
# layout something to show.
const TOOLS := [
	"World Builder",
	"Asset Builder",
	"Block Editor",
	"Item Builder",
]

@onready var btn_join: Button = $TopBar/HBox/BtnJoin
@onready var btn_profile: Button = $TopBar/HBox/BtnProfile
@onready var btn_settings: Button = $TopBar/HBox/BtnSettings
@onready var btn_tools: Button = $TopBar/HBox/BtnTools
@onready var btn_update: Button = $TopBar/HBox/BtnUpdate
@onready var update_status_label: Label = $TopBar/HBox/UpdateStatusLabel

@onready var join_panel: VBoxContainer = $ContentArea/JoinPanel
@onready var search_box: LineEdit = $ContentArea/JoinPanel/SearchBox
@onready var server_list: VBoxContainer = $ContentArea/JoinPanel/ServerScroll/ServerList
@onready var status_label: Label = $ContentArea/JoinPanel/StatusLabel
@onready var placeholder_panel: Label = $ContentArea/PlaceholderPanel
@onready var profile_panel: VBoxContainer = $ContentArea/ProfilePanel
@onready var profile_name_edit: LineEdit = $ContentArea/ProfilePanel/NameEdit
@onready var profile_status_label: Label = $ContentArea/ProfilePanel/ProfileStatusLabel
@onready var profile_id_label: Label = $ContentArea/ProfilePanel/IdLabel
@onready var tools_panel: VBoxContainer = $ContentArea/ToolsPanel
@onready var tool_grid: GridContainer = $ContentArea/ToolsPanel/ToolGrid
@onready var tools_status_label: Label = $ContentArea/ToolsPanel/ToolsStatusLabel

var _server_rows: Array = [] # [{node, name}]

func _ready() -> void:
	for server in SERVERS:
		_add_server_row(server)

	Net.connected_to_server.connect(_on_connected)
	Net.world_state_received.connect(_on_world_state_received)
	Net.connection_failed.connect(_on_connection_failed)
	Net.disconnected_from_server.connect(_on_connection_failed)

	btn_join.pressed.connect(_show_join_panel)
	btn_profile.pressed.connect(_show_profile_panel)
	btn_settings.pressed.connect(_show_placeholder.bind("Ustawienia - wkrotce"))
	btn_tools.pressed.connect(_show_tools_panel)
	btn_update.pressed.connect(_on_update_pressed)

	search_box.text_changed.connect(_on_search_text_changed)
	for tool_name in TOOLS:
		_add_tool_card(tool_name)

	profile_name_edit.text = Profile.player_name
	profile_name_edit.text_submitted.connect(_on_profile_name_submitted)
	profile_id_label.text = "ID klienta: %s" % Profile.client_id

	UpdateChecker.update_available.connect(_on_update_available)
	UpdateChecker.up_to_date.connect(_on_up_to_date)
	UpdateChecker.check_failed.connect(_on_check_failed)
	UpdateChecker.update_applied.connect(_on_update_applied)
	UpdateChecker.update_failed.connect(_on_update_failed)

	if Profile.has_valid_name():
		_show_join_panel()
	_update_name_gate()
	UpdateChecker.check_for_update()

func _update_name_gate() -> void:
	var valid := Profile.has_valid_name()
	btn_join.disabled = not valid
	btn_settings.disabled = not valid
	btn_tools.disabled = not valid
	if not valid:
		profile_status_label.text = "Ustaw nazwe gracza (min. 3 litery, bez cyfr), zeby grac."
		_show_profile_panel()

func _show_only(panel: Control) -> void:
	for p in [join_panel, placeholder_panel, profile_panel, tools_panel]:
		p.visible = (p == panel)

func _show_join_panel() -> void:
	_show_only(join_panel)

func _show_placeholder(text: String) -> void:
	placeholder_panel.text = text
	_show_only(placeholder_panel)

func _show_profile_panel() -> void:
	_show_only(profile_panel)

func _show_tools_panel() -> void:
	tools_status_label.text = ""
	_show_only(tools_panel)

func _on_profile_name_submitted(new_name: String) -> void:
	if Profile.set_player_name(new_name):
		profile_status_label.text = "Zapisano: %s" % Profile.player_name
		_update_name_gate()
	else:
		profile_status_label.text = "Nazwa: min. 3 litery, tylko litery (bez cyfr/symboli)."

static func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.13, 0.15)
	style.border_width_left = 3
	style.border_color = Color(0.55, 0.15, 0.12)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _add_server_row(server: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style())

	var hbox := HBoxContainer.new()
	card.add_child(hbox)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_box)

	var name_label := Label.new()
	name_label.text = server["name"]
	text_box.add_child(name_label)

	var address_label := Label.new()
	address_label.text = "%s:%d" % [server["address"], server["port"]]
	address_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	address_label.add_theme_font_size_override("font_size", 12)
	text_box.add_child(address_label)

	var join_button := Button.new()
	join_button.text = "Dolacz"
	join_button.focus_mode = Control.FOCUS_NONE
	join_button.pressed.connect(_on_join_pressed.bind(server))
	hbox.add_child(join_button)

	server_list.add_child(card)
	_server_rows.append({"node": card, "name": server["name"] as String})

func _on_search_text_changed(query: String) -> void:
	query = query.to_lower()
	for entry in _server_rows:
		var row_name: String = entry["name"]
		entry["node"].visible = query == "" or row_name.to_lower().contains(query)

func _add_tool_card(tool_name: String) -> void:
	var button := Button.new()
	button.text = tool_name
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(200, 80)
	button.pressed.connect(_on_tool_card_pressed.bind(tool_name))
	tool_grid.add_child(button)

func _on_tool_card_pressed(tool_name: String) -> void:
	tools_status_label.text = "%s - wkrotce" % tool_name

func _on_join_pressed(server: Dictionary) -> void:
	status_label.text = "Laczenie z %s..." % server["address"]
	Net.join(server["address"], server["port"], Profile.player_name, "player", server.get("token", ""), Profile.client_id)

func _on_connected() -> void:
	status_label.text = "Polaczono, wczytuje swiat..."

func _on_world_state_received() -> void:
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
