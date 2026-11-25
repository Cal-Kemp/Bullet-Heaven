extends CharacterBody3D
## First-person walker with a look ray for interacting with benches and the ledger.

const WALK := 4.5
const SPRINT := 7.5
const SENS := 0.0025
const GRAVITY := 18.0
const JUMP := 5.5
const EYE := 1.62

var cam: Camera3D
var ray: RayCast3D
var yaw := 0.0
var pitch := 0.0
var enabled := true


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = EYE
	cam.fov = 75
	cam.near = 0.05
	cam.current = true
	add_child(cam)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -3.2)
	ray.collision_mask = 1 | 2
	ray.add_exception(self)
	cam.add_child(ray)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and enabled:
		yaw -= event.relative.x * SENS
		pitch = clampf(pitch - event.relative.y * SENS, -1.45, 1.45)
		_apply_view()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var input := Vector2.ZERO
	if enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var sp := SPRINT if Input.is_action_pressed("sprint") else WALK
	velocity.x = dir.x * sp
	velocity.z = dir.z * sp
	if enabled and is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP
	move_and_slide()


func _apply_view() -> void:
	rotation.y = yaw
	cam.rotation.x = pitch


func set_view(pos: Vector3, p_yaw: float, p_pitch: float) -> void:
	position = pos
	velocity = Vector3.ZERO
	yaw = p_yaw
	pitch = p_pitch
	_apply_view()


## Stand at `pos` and look at the point `target`.
func look_from(pos: Vector3, target: Vector3) -> void:
	var eye := pos + Vector3(0, EYE, 0)
	var d := target - eye
	var flat := Vector2(d.x, d.z).length()
	set_view(pos, atan2(-d.x, -d.z), atan2(d.y, flat))


func get_target() -> Object:
	ray.force_raycast_update()
	if ray.is_colliding():
		return ray.get_collider()
	return null
