extends CharacterBody3D

const SPEED := 5.0
const FLY_SPEED := 20.0
const FLY_SPEED_MULT_MIN := 0.2
const FLY_SPEED_MULT_MAX := 20.0
const FLY_SPEED_MULT_STEP := 1.2
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003
const WORLD_LIMIT := 48.0

@onready var head: Node3D = $Head

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _flying := false
var _fly_speed_mult := 1.0

func _ready() -> void:
	if not is_multiplayer_authority():
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, -1.5, 1.5)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BACKSPACE:
		_toggle_fly()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif _flying and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_fly_speed_mult = clampf(_fly_speed_mult * FLY_SPEED_MULT_STEP, FLY_SPEED_MULT_MIN, FLY_SPEED_MULT_MAX)
	elif _flying and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_fly_speed_mult = clampf(_fly_speed_mult / FLY_SPEED_MULT_STEP, FLY_SPEED_MULT_MIN, FLY_SPEED_MULT_MAX)

func _toggle_fly() -> void:
	_flying = not _flying
	velocity = Vector3.ZERO
	$CollisionShape3D.disabled = _flying

func _physics_process(delta: float) -> void:
	if _flying:
		_process_fly(delta)
		_clamp_to_world_bounds()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := _get_input_dir()
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	_clamp_to_world_bounds()

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
