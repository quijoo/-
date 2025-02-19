class_name Utility extends RefCounted

const MASK_GROUND: int = 1
const MASK_WALL: int = 2
const MASK_OBSTACLE: int = 4
const MASK_PLAYER: int = 8
const PI_HALF = PI / 2
const COLOR_RAY = Color.GREEN
const COLOR_CAST = Color.RED
const COLOR_NORMAL = Color.YELLOW

static var enable_gizmos: bool = true
static var debug_view_viewport: Viewport

static func cast(
	node: Node3D, from: Vector3, to: Vector3, 
	mask: int = 0xFFFFFFFF, exculde: Array[RID] = []
) -> Dictionary:
	#if not Engine.is_in_physics_frame():
		#printerr("不允许在物理帧外进行射线检测!!")
		#return {}
	var space_state = node.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to, mask, exculde)
	query.collide_with_areas = false
	query.hit_from_inside = false
	query.hit_back_faces = false
	var result = space_state.intersect_ray(query)
	
	if enable_gizmos:
		var _s = DebugDraw3D.new_scoped_config()
		_s.set_thickness(0)
		#_s.set_thickness(0.02)
		_s.set_center_brightness(0.1)
		_s.set_hd_sphere(true)
		_s.set_viewport(debug_view_viewport.get_viewport())
		if result:
			DebugDraw3D.draw_line(from, result["position"], COLOR_CAST)
		else:
			DebugDraw3D.draw_line(from, to, COLOR_RAY)
	return result

static func cast_cornor(
	node: Node3D, origin: Vector3, direction: Vector3, length:  float,
	axis: Vector3 = Vector3.UP, mask: int = 0xFFFFFFFF, exculde: Array[RID] = []
) -> Dictionary:

	direction = direction.normalized()
	for i in range(4):
		# compute current end point
		var end_point = origin + direction.rotated(axis, PI_HALF * i) * length

		# execute ray cast and return
		var result = cast(node, origin, end_point, mask, exculde)
		if result: return result

		# update node
		origin = end_point
	return {}

static func cast_wall_cornor(
	node: Node3D, point: Vector3, direction: Vector3, width: float, 
	delta: float = 0.2, axis: Vector3 = Vector3.UP, mask: int = 0xFFFFFFFF, exculde: Array[RID] = []
) -> Dictionary:
	direction = direction.normalized()
	var step_count: int = floori(width / delta)
	var result: Dictionary = {}
	for i in range(step_count):
		result = cast_cornor(node, point, direction, delta, axis, mask, exculde)
		if result.size() == 0:
			break
		direction = result["normal"]
		point = result["position"] + direction * delta * 0.5
		direction = direction.rotated(axis, PI_HALF)
		
	return result
	
static func to_vector2(origin: Vector3) -> Vector2:
	return Vector2(origin.x, origin.z)

static func xz_intersect(point_a: Vector3, direction_a: Vector3, point_b:Vector3, direction_b: Vector3) -> Variant:
	var from_a = to_vector2(point_a)
	var dir_a = to_vector2(direction_a)
	var from_b = to_vector2(point_b)
	var dir_b = to_vector2(direction_b)
	var result = Geometry2D.line_intersects_line(from_a, dir_a, from_b, dir_b)
	if result == null: 
		return null
	else:
		return Vector3(result.x, (point_a.y + point_b.y) / 2, result.y)

static func to_local_dir(node: Node3D, dir: Vector3):
	return (node.global_basis.inverse() * dir).normalized()

static func to_global_dir(node: Node3D,dir: Vector3):
	return (node.global_basis * dir).normalized()

static func move_along_polyline(current: Vector3, polyline: Array[Vector3], movement: float, inverse: bool) -> Vector3:
	var points = polyline.duplicate()
	if inverse: 
		points.reverse()
	var next_point_index:int = INF
	var min_distance_point = Vector3.INF
	for i in range(points.size() - 1):
		var closest = Geometry3D.get_closest_point_to_segment(current, points[i], points[i + 1])
		if current.distance_squared_to(closest) < current.distance_squared_to(min_distance_point):
			min_distance_point = closest
			next_point_index = i + 1
			
	current = min_distance_point
	for i in range(next_point_index, points.size()):
		var dis = current.distance_to(points[i])
		if movement <= dis:
			current = current.move_toward(points[i], movement)
			break
		movement -= dis
		current = points[i]
		
	return current
