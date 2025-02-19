extends Node

@export var camera: Camera3D
@export var character: Character
@export var wall_controller: WallController

enum Mode { Wall, Ground, Lock }
var mode: Mode = Mode.Ground
var is_on_wall: bool = false
var wall_point: Vector3
var wall_normal: Vector3

func _process(delta: float) -> void:
	if mode == Mode.Ground:
		var target_position = character.to_global(Vector3(0, 1.5, -3))
		camera.global_position = lerp(camera.global_position, target_position, 0.05)
		var new_basis = camera.global_transform.looking_at(character.global_position, Vector3.UP).basis
		camera.global_basis = camera.global_basis.slerp(new_basis, 0.2)
		if can_enter_wall() and Input.is_action_just_pressed("enter_exit_wall"):
			enter_wall()

	if mode == Mode.Wall and wall_controller.attaching_object != null:
		var point = wall_controller.attaching_position
		var normal = wall_controller.first_ray_direction
		camera.global_position = lerp(camera.global_position, point + normal * 2 + Vector3.UP * 1, 0.02)
		var new_basis = camera.global_transform.looking_at(point, Vector3.UP).basis
		camera.global_basis = camera.global_basis.slerp(new_basis, 0.2)
		if can_exit_wall() and Input.is_action_just_pressed("enter_exit_wall"):
			exit_wall()
		
func can_enter_wall():
	var start = character.global_position - character.global_basis.z * 0.2 + Vector3.UP
	var end = character.global_position + character.global_basis.z + Vector3.UP
	var result = Utility.cast(character, start, end, Utility.MASK_WALL)

	if result.is_empty():
		return false
	
	wall_point = result["position"]
	wall_normal = result["normal"]
	return character.global_basis.z.dot(-result['normal']) > 0.9
	
func can_exit_wall() -> bool:
	return true

# BUG: 这是我写的代码么??? 这是啥啊? 好脏, 

func enter_wall():
	mode = Mode.Lock
	## basis
	wall_normal = wall_normal.normalized()
	var right = Vector3.UP.cross(wall_normal).normalized()
	var basis = Basis(right, Vector3.UP, right.cross(Vector3.UP).normalized())
		
	# tweener 数字都是临时凑的
	var tween_1 = get_tree().create_tween()
	character.enable_movement = false
	tween_1.tween_property(character.mesh, "global_basis", basis, 0.2)
	character.player.play("walk")
	await tween_1.finished
	
	var tween_2 = get_tree().create_tween()
	tween_2.tween_property(character.mesh, "scale", Vector3.ONE * 0.7, 0.1)
	tween_2.tween_property(character.mesh, "position", Vector3.UP * 0.3, 0.1)
	tween_2.tween_property(camera, "global_position", wall_point + wall_normal * 2 + Vector3.UP, 0.1)
	character.player.play("Idle")
	await tween_2.finished
	
	character.set_active(false)
	wall_controller.global_position = wall_point + wall_normal * 0.2
	wall_controller.look_at(wall_point)
	wall_controller.enable_movement = true
	wall_controller.visible = true
	mode = Mode.Wall
	
func exit_wall():
	var normal = wall_controller.wall_normal
	var point = wall_controller.attaching_position + normal * 0.5
	
	var result = Utility.cast(character, point, point + Vector3.DOWN * 2, Utility.MASK_GROUND)
	if not result: # 没满足下墙条件（应该更复杂的 swap 一下）
		return
		
	mode = Mode.Lock
	character.global_position = result["position"]
	var d = -normal
	var right = Vector3.UP.cross(d).normalized()
	d = right.cross(Vector3.UP).normalized()
	character.global_basis = Basis(right, Vector3.UP, d)

	var tween_0 = get_tree().create_tween()
	tween_0.tween_property(camera, "global_position", character.to_global(Vector3(0, 1.5, -3)), 0.2)
	await tween_0.finished
	
	wall_controller.attaching_object = null
	wall_controller.visible = false
	wall_controller.enable_movement = false
	character.set_active(true)
	
	# recover
	var tween = get_tree().create_tween()
	tween.tween_property(character.mesh, "scale", Vector3.ONE, 0.1)
	tween.tween_property(character.mesh, "position", Vector3.ZERO, 0.1)
	character.player.play("Idle")
	await tween.finished
	
	var tween2 = get_tree().create_tween()
	tween2.tween_property(character.mesh, "basis", Basis.IDENTITY, 0.25)
	character.player.play("walk")
	await tween2.finished
	character.player.play("Idle")

	mode = Mode.Ground
