class_name Character extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const ROTATE_SPEED = 0.1
const WALL_MOVE_SPEED = 1.0

@export var mesh : Node3D
var player: AnimationPlayer = null
var accumulate_mouse_motion := Vector2.ZERO

var enable_movement: bool = true

func _ready() -> void:
	player = mesh.get_node("AnimationPlayer")
	player.play("walk")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not enable_movement:
		return
			
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	var input_dir := Input.get_vector("m_right", "m_left", "m_forward", "m_backward")
	var direction := (transform.basis * (Vector3.RIGHT * input_dir.x + Vector3.FORWARD * input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	if accumulate_mouse_motion:
		rotate_y(-accumulate_mouse_motion.x * ROTATE_SPEED * delta)
		accumulate_mouse_motion = Vector2.ZERO
	
	if input_dir.length_squared() > 0:
		player.play("walk")
	else:
		player.play("Idle")
	
	move_and_slide()
	
func can_enter_wall() -> bool:
	var start_point := to_global(Vector3.UP * 0.5)
	var end_point := to_global(Vector3.UP * 0.5 - Vector3.FORWARD * 0.8)
	var result = Utility.cast(self, start_point, end_point, Utility.MASK_WALL)
	return result and end_point.direction_to(start_point).dot(result["normal"].normalized()) > 0.2

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion = event as InputEventMouseMotion
		accumulate_mouse_motion += motion.relative

func set_active(value: bool):
	visible = value
	(get_node("CollisionShape3D") as CollisionShape3D).disabled = not value
	enable_movement = value
