extends CharacterBody3D

const SPEED := 5.0
const SPRINT_MULT := 1.8
const FLY_SPEED := 20.0
const FLY_SPEED_MULT_MIN := 0.2
const FLY_SPEED_MULT_MAX := 20.0
const FLY_SPEED_MULT_STEP := 1.2
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003
const WORLD_LIMIT := 5000.0
const POSITION_SEND_INTERVAL := 3 # physics frames between position updates

@onready var head: Node3D = $Head
@onready var camera_first_person: Camera3D = $Head/Camera3D
@onready var camera_third_person: Camera3D = $Head/ThirdPersonPivot/ThirdPersonArm/ThirdPersonCamera

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _flying := false
var _fly_speed_mult := 1.0
var _position_send_counter := 0
var _third_person := false
var _menu_open := false

func set_menu_open(open: bool) -> void:
	_menu_open = open

func _ready() -> void:
	# No per-peer player spawning/replication exists yet (each client's Player
	# node is local-only, not shared) so there is no real multiplayer
	# authority to gate on here. Once server-side spawning with proper
	# authority assignment exists, this needs to check is_multiplayer_authority()
	# again so remote players' avatars don't process local input.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if _menu_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -1.5, 1.5)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BACKSPACE:
		_toggle_fly()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		_toggle_camera()
	elif _flying and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_fly_speed_mult = clampf(_fly_speed_mult * FLY_SPEED_MULT_STEP, FLY_SPEED_MULT_MIN, FLY_SPEED_MULT_MAX)
	elif _flying and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_fly_speed_mult = clampf(_fly_speed_mult / FLY_SPEED_MULT_STEP, FLY_SPEED_MULT_MIN, FLY_SPEED_MULT_MAX)

func _toggle_fly() -> void:
	_flying = not _flying
	velocity = Vector3.ZERO
	$CollisionShape3D.disabled = _flying

func _toggle_camera() -> void:
	_third_person = not _third_person
	camera_first_person.current = not _third_person
	camera_third_person.current = _third_person

func _physics_process(delta: float) -> void:
	if _menu_open:
		return
	if _flying:
		_process_fly(delta)
		_clamp_to_world_bounds()
		_send_position()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var move_speed := SPEED * SPRINT_MULT if Input.is_key_pressed(KEY_SHIFT) else SPEED
	var input_dir := _get_input_dir()
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)

	move_and_slide()
	_clamp_to_world_bounds()
	_send_position()

func _send_position() -> void:
	_position_send_counter += 1
	if _position_send_counter < POSITION_SEND_INTERVAL:
		return
	_position_send_counter = 0
	Net.send_position(global_position, rotation.y, head.rotation.x)

func _clamp_to_world_bounds() -> void:
	var clamped_x := clampf(global_position.x, -WORLD_LIMIT, WORLD_LIMIT)
	var clamped_z := clampf(global_position.z, -WORLD_LIMIT, WORLD_LIMIT)
	if is_equal_approx(clamped_x, global_position.x) and is_equal_approx(clamped_z, global_position.z):
		return
	global_position.x = clamped_x
	global_position.z = clamped_z
	velocity.x = 0.0
	velocity.z = 0.0

func _process_fly(delta: float) -> void:
	var move_dir := Vector3.ZERO
	var look_basis := head.global_transform.basis

	if Input.is_key_pressed(KEY_W):
		move_dir -= look_basis.z
	if Input.is_key_pressed(KEY_S):
		move_dir += look_basis.z
	if Input.is_key_pressed(KEY_A):
		move_dir -= look_basis.x
	if Input.is_key_pressed(KEY_D):
		move_dir += look_basis.x
	if Input.is_key_pressed(KEY_SPACE):
		move_dir += Vector3.UP
	if Input.is_key_pressed(KEY_CTRL):
		move_dir += Vector3.DOWN

	if move_dir.length() > 0.0:
		move_dir = move_dir.normalized()

	global_position += move_dir * FLY_SPEED * _fly_speed_mult * delta

func _get_input_dir() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		dir.y += 1
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		dir.x += 1
	return dir.normalized()
