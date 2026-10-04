extends RefCounted
## Small visibility-graph router for wordless crop-to-basket hints.
## It keeps the route legible around pickable artwork without changing input.


static func avoid_rectangles(start: Vector2, finish: Vector2,
		obstacles: Array, clearance: float = 12.0,
		route_bounds: Rect2 = Rect2()) -> PackedVector2Array:
	if start.distance_to(finish) <= 0.001:
		return PackedVector2Array([start, finish])

	var blockers: Array[Rect2] = []
	var corners: Array[Rect2] = []
	var safe_clearance := maxf(clearance, 0.0)
	for value in obstacles:
		if not value is Rect2:
			continue
		var obstacle: Rect2 = value
		if obstacle.size.x <= 0.0 or obstacle.size.y <= 0.0:
			continue
		var blocker := obstacle.grow(safe_clearance)
		if _strictly_contains(blocker, start) or _strictly_contains(blocker, finish):
			continue
		blockers.append(blocker)
		# Keep graph nodes a few pixels outside the inflated obstacle so a route
		# never depends on a line grazing a fruit edge.
		corners.append(blocker.grow(4.0))

	var points: Array[Vector2] = [start, finish]
	for rect in corners:
		for corner in [
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		]:
			if _inside_route_bounds(corner, route_bounds):
				points.append(corner)

	var distances: Array[float] = []
	var previous: Array[int] = []
	var visited := PackedByteArray()
	for _index in range(points.size()):
		distances.append(INF)
		previous.append(-1)
		visited.append(0)
	distances[0] = 0.0

	while true:
		var current := -1
		var best_distance := INF
		for index in range(points.size()):
			if visited[index] == 0 and distances[index] < best_distance:
				current = index
				best_distance = distances[index]
		if current < 0 or current == 1:
			break
		visited[current] = 1
		for neighbor in range(points.size()):
			if neighbor == current or visited[neighbor] != 0:
				continue
			if not _segment_is_clear(points[current], points[neighbor], blockers):
				continue
			var candidate_distance := best_distance \
				+ points[current].distance_to(points[neighbor])
			if candidate_distance < distances[neighbor]:
				distances[neighbor] = candidate_distance
				previous[neighbor] = current

	if previous[1] < 0:
		# A sealed cluster can leave no clear route. The highlighted basket is
		# still the answer, so omit the line instead of drawing through crops.
		return PackedVector2Array([start])
	var reversed: Array[Vector2] = []
	var cursor := 1
	while cursor >= 0:
		reversed.append(points[cursor])
		if cursor == 0:
			break
		cursor = previous[cursor]
	if reversed.is_empty() or reversed[reversed.size() - 1] != start:
		return PackedVector2Array([start])
	reversed.reverse()
	return PackedVector2Array(reversed)


static func segment_is_clear_of_rectangles(start: Vector2, finish: Vector2,
		obstacles: Array, clearance: float = 0.0) -> bool:
	var blockers: Array[Rect2] = []
	for value in obstacles:
		if value is Rect2:
			var obstacle: Rect2 = value
			blockers.append(obstacle.grow(maxf(clearance, 0.0)))
	return _segment_is_clear(start, finish, blockers)


static func _strictly_contains(rect: Rect2, point: Vector2) -> bool:
	const EPSILON := 0.001
	return point.x > rect.position.x + EPSILON \
		and point.x < rect.end.x - EPSILON \
		and point.y > rect.position.y + EPSILON \
		and point.y < rect.end.y - EPSILON


static func _inside_route_bounds(point: Vector2, bounds: Rect2) -> bool:
	return bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.has_point(point)


static func _segment_is_clear(start: Vector2, finish: Vector2,
		blockers: Array[Rect2]) -> bool:
	for rect in blockers:
		if _segment_intersects_rect(start, finish, rect):
			return false
	return true


static func _segment_intersects_rect(start: Vector2, finish: Vector2,
		rect: Rect2) -> bool:
	var delta := finish - start
	var lower := 0.0
	var upper := 1.0
	for axis in 2:
		var origin := start.x if axis == 0 else start.y
		var direction := delta.x if axis == 0 else delta.y
		var minimum := rect.position.x if axis == 0 else rect.position.y
		var maximum := rect.end.x if axis == 0 else rect.end.y
		if absf(direction) < 0.000001:
			if origin < minimum or origin > maximum:
				return false
			continue
		var first := (minimum - origin) / direction
		var second := (maximum - origin) / direction
		if first > second:
			var swap := first
			first = second
			second = swap
		lower = maxf(lower, first)
		upper = minf(upper, second)
		if lower > upper:
			return false
	return upper >= 0.0 and lower <= 1.0 and upper - lower > 0.000001
