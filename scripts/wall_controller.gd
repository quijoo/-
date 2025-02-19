class_name WallController extends Node3D

# 常量
const MOVE_SPEED: float = 2.0
const CORNOR_CAST_INTERVAL: float = 0.1
const SPRITE_WIDTH: float = 1.21
const HALF_SPRITE_WIDTH = SPRITE_WIDTH / 2
const LOCAL_FORWARD: Vector3 = -Vector3.FORWARD
const OFFSET: float = 0.02
@export var model: Node3D
@export var left_camera: Camera3D
@export var right_camera: Camera3D
@export var idle_camera: Camera3D

# 外部信息
var immediate_mesh: ImmediateMesh = null

# 当前附着的物体以及相对位置
var attaching_object: Node3D = null
var attaching_local_position: Vector3
var attaching_position: Vector3:
	get:
		return global_position if attaching_object == null else attaching_object.to_global(attaching_local_position)
	set(value):
		attaching_local_position = attaching_object.to_local(value)

var first_ray_direction_local: Vector3
var first_ray_direction: Vector3:
	get:
		return Utility.to_global_dir(self, LOCAL_FORWARD) if attaching_object == null else Utility.to_global_dir(attaching_object, first_ray_direction_local)
	set(value):
		first_ray_direction_local = Utility.to_local_dir(attaching_object, value)

var wall_normal: Vector3
var enable_movement: bool = false
var sprite_player: AnimationPlayer

func _ready() -> void:
	var mesh_instance = get_node("MeshInstance3D") as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh is ImmediateMesh:
		immediate_mesh = mesh_instance.mesh as ImmediateMesh
	sprite_player = model.get_node("AnimationPlayer")

func setup_model_by_input(input: float):
	left_camera.current = input < 0
	right_camera.current = input > 0
	idle_camera.current = input == 0
	sprite_player.play("Idle" if input == 0 else "walk")
	
func _process(delta: float) -> void:
	if not enable_movement: 
		return

	## step 1: 初次射线检查, 检查附着物、附着点、附着点法线
	var start = attaching_position + first_ray_direction * CORNOR_CAST_INTERVAL
	var end = attaching_position - first_ray_direction * 2
	var first_hit = Utility.cast(self, start, end, Utility.MASK_WALL)
	if not first_hit: 
		return

	var hit_collider = first_hit["collider"] as Node3D
	var hit_position = first_hit["position"] as Vector3
	wall_normal = first_hit["normal"] as Vector3
	if hit_collider != attaching_object:
		attaching_object = hit_collider
		attaching_position = hit_position + wall_normal * OFFSET
		first_ray_direction = wall_normal

	## step 2: 检测拐角左侧和右侧墙壁的法线
	var origin = hit_position + wall_normal * CORNOR_CAST_INTERVAL / 2
	var hit_left = Utility.cast_wall_cornor(
		self, origin, wall_normal.rotated(Vector3.DOWN, PI / 2), 
		HALF_SPRITE_WIDTH, CORNOR_CAST_INTERVAL, Vector3.DOWN, Utility.MASK_WALL)
	
	var hit_right = Utility.cast_wall_cornor(
		self, origin, wall_normal.rotated(Vector3.UP, PI / 2), 
		HALF_SPRITE_WIDTH, CORNOR_CAST_INTERVAL, Vector3.UP, Utility.MASK_WALL) 
		
	if not hit_left or not hit_right: 
		return
	var left_normal = hit_left["normal"]
	var left_direction = left_normal.rotated(Vector3.DOWN, PI / 2)
	var left_point = hit_left["position"] + left_normal * OFFSET
	
	var right_normal = hit_right["normal"]
	var right_direction = right_normal.rotated(Vector3.UP, PI / 2)
	var right_point = hit_right["position"] + right_normal * OFFSET

	## step 3: 根据输出和射线检测信息处理在墙面移动
	var input = Input.get_axis("m_left", "m_right")
	setup_model_by_input(input)
	var result = Utility.xz_intersect(left_point, left_direction, right_point, right_direction)
	var corner = attaching_position if result == null else result as Vector3
	var polyline: Array[Vector3] = [
		corner + left_direction * SPRITE_WIDTH, 
		corner, 
		corner + right_direction * SPRITE_WIDTH
	]
	if not is_zero_approx(input):
		attaching_position = Utility.move_along_polyline(attaching_position, polyline, MOVE_SPEED * delta, input < 0)

	## step 4: 使用移动后的附着点信息更新 global_Position(能随着物体移动)
	global_position = attaching_position
	var right_edge = Utility.move_along_polyline(attaching_position, polyline, HALF_SPRITE_WIDTH, false)
	var left_edge = Utility.move_along_polyline(attaching_position, polyline, HALF_SPRITE_WIDTH, true)
	first_ray_direction = (left_normal * corner.distance_to(left_edge) + right_normal * corner.distance_to(right_edge)).normalized()

	## step 5: 更新 mesh 的顶点信息
	update_mesh(
		to_local(corner), 
		Utility.to_local_dir(self, left_normal), Utility.to_local_dir(self, right_normal),
		to_local(left_edge), to_local(right_edge)
	)	

func add_point(p: Array, normal:Vector3):
	# p[0]: 顶点位置, p[1]: 顶点 uv
	immediate_mesh.surface_set_normal(normal)
	immediate_mesh.surface_set_uv(p[1])
	immediate_mesh.surface_add_vertex(p[0])
	
func add_triangle(p1:Array, p2:Array, p3:Array, normal:Vector3):
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	add_point(p1, normal)
	add_point(p2, normal)
	add_point(p3, normal)
	immediate_mesh.surface_end()

func update_mesh(corner:Vector3, left_normal: Vector3, right_normal: Vector3, left_edge: Vector3, right_edge: Vector3) -> void:
	# left_edge ----- corner ----- right_edge
	var center_uv = clamp(corner.distance_to(left_edge) / (SPRITE_WIDTH), 0, 1)
	
	# p0 ----- p1 ----- p2
	# |					|
	# p5 ----- p4 ----- p3
	# 六个顶点(+uv)
	var p0 = [left_edge + Vector3.UP * HALF_SPRITE_WIDTH, Vector2(0, 0)]
	var p1 = [corner + Vector3.UP * HALF_SPRITE_WIDTH, Vector2(center_uv, 0)]
	var p2 = [right_edge + Vector3.UP * HALF_SPRITE_WIDTH, Vector2(1, 0)]
	var p3 = [right_edge + Vector3.DOWN * HALF_SPRITE_WIDTH, Vector2(1, 1)]
	var p4 = [corner + Vector3.DOWN * HALF_SPRITE_WIDTH, Vector2(center_uv, 1)]
	var p5 = [left_edge + Vector3.DOWN * HALF_SPRITE_WIDTH, Vector2(0, 1)]
	# 四个三角形
	immediate_mesh.clear_surfaces()
	add_triangle(p0, p1, p5, left_normal)
	add_triangle(p1, p4, p5, left_normal)
	add_triangle(p1, p2, p3, right_normal)
	add_triangle(p1, p3, p4, right_normal)
