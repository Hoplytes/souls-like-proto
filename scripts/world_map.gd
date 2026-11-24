class_name WorldMap
extends RefCounted
## The geography of the open world, laid out once (always the same): four
## regions grown around their centres, highlands cut by valleys, a river
## running from the eastern heights into a lake and on to the south, roads
## between the bonfires, forests where a density field is high, and room
## kept for the village and its fields, the ruined city, the camps, the
## dungeon's cave and the wyvern's cirque. Pure data on cells (i, j); Game
## turns it into tiles and scenery.
##
## Cell (i, j) is drawn at ((i - j) * 48, (i + j) * 24): north (top of the
## screen) is toward (0, 0), east toward (W, 0), west toward (0, W), south
## toward (W, W).

const W := 128
const REGIONS := ["prairie", "ruins", "snow", "caves"]
## Region centres (the region of a cell is the nearest centre, with noise)
## and a weight (bigger = larger region).
const CENTRES := {
	"prairie": [Vector2(98, 104), 1.18], "ruins": [Vector2(32, 82), 1.0],
	"snow": [Vector2(102, 34), 1.0], "caves": [Vector2(42, 36), 0.95],
}
## Bonfires.
const PLACES := {"prairie": Vector2(96, 97), "ruins": Vector2(46, 86), "snow": Vector2(84, 50), "caves": Vector2(52, 44)}
const VILLAGE := Vector2(80, 110)  # centre of the village square
const CITY := Vector2(30, 76)  # centre of the ruined city
const LAKE := Vector2(112, 86)
const LAKE_RADIUS := Vector2(7.5, 5.5)
const CAMP := Vector2(74, 84)  # brigands, in the plain's woods
const GRAVEYARD := Vector2(60, 26)  # skeletons, in the dead lands
const PORTAL := Vector2(30.4, 19.5)  # in front of the dungeon's cave
const CAVE_FACE := Vector2i(29, 19)  # the plateau cell whose south-east face is the cave mouth
const WYVERN := Vector2(112, 20)  # centre of the cirque (boss arena)
const WYVERN_RADIUS := 5.0
const RIVER_IN := [Vector2(124, 30), Vector2(120, 46), Vector2(116, 62), Vector2(113, 76), Vector2(112, 84)]
const RIVER_OUT := [Vector2(113, 90), Vector2(116, 102), Vector2(120, 114), Vector2(123, 128)]
## Roads: waypoints, half-width.
const ROADS := [
	[[PLACES.prairie, Vector2(90, 103), VILLAGE], 1.25],  # to the village
	[[PLACES.prairie, Vector2(90, 84), Vector2(76, 70), Vector2(62, 56), PLACES.caves, Vector2(40, 30), PORTAL], 1.15],
	[[PLACES.prairie, Vector2(98, 84), Vector2(92, 66), PLACES.snow, Vector2(94, 38), Vector2(104, 28), WYVERN], 1.1],
	[[VILLAGE, Vector2(68, 103), Vector2(56, 94), PLACES.ruins, CITY], 1.15],
	[[PLACES.prairie, Vector2(103, 92), Vector2(106, 90)], 0.95],  # to the lake's landing
	[[PLACES.prairie, Vector2(106, 104), Vector2(117, 104), Vector2(122, 110)], 0.95],  # over the river to a farm
	[[Vector2(84, 88), CAMP], 0.8],  # a track to the brigands' camp
	[[PLACES.caves, Vector2(56, 34), GRAVEYARD], 0.8],
]
const LANDING := Vector2i(106, 90)  # where the landing's pier starts (going east, +i)

var cells := W * W
var region := PackedByteArray()  # index in REGIONS
var level := PackedByteArray()  # 0 ground, 1 highland
var water := PackedByteArray()
var road := PackedByteArray()  # 1 dirt road, 2 paved
var reserved := PackedByteArray()  # no scenery (clearings, village, fields...)
var forest := PackedFloat32Array()  # density 0..1
var ramps := {}  # Vector2i -> true: highland cells cut into a ramp going down toward +i
var bridges := {}  # Vector2i -> true: water crossed by a road
var pier: Array[Vector2i] = []
var fields: Array[Rect2i] = []
var houses := []  # [Vector2i first cell, length along j, look]
var ruins_rooms: Array[Rect2i] = []  # ruined buildings of the city
var farm_houses := []

var road_dist := PackedInt32Array()  # cells to the nearest road (capped at 99)
var _n_region := FastNoiseLite.new()
var _n_height := FastNoiseLite.new()
var _n_forest := FastNoiseLite.new()
var _n_detail := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = 2024
	for k in 4:
		var n: FastNoiseLite = [_n_region, _n_height, _n_forest, _n_detail][k]
		n.seed = 17 + k * 31
	_n_region.frequency = 0.022
	_n_region.fractal_octaves = 3
	_n_height.frequency = 0.045
	_n_height.fractal_octaves = 3
	_n_forest.frequency = 0.03
	_n_forest.fractal_octaves = 3
	_n_detail.frequency = 0.16
	for arr in [region, level, water, road, reserved]:
		arr.resize(cells)
		arr.fill(0)
	forest.resize(cells)
	_regions()
	_water()
	_roads()
	_road_distances()
	_reserve()
	_highlands()
	_ramps_cut()
	_forests()
	_village()
	_ruined_city()

# --- helpers ---------------------------------------------------------------

static func idx(c: Vector2i) -> int:
	return c.x * W + c.y

static func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < W

func region_at(c: Vector2i) -> String:
	return REGIONS[region[idx(c)]] if inside(c) else "prairie"

func level_at(c: Vector2i) -> int:
	return level[idx(c)] if inside(c) else 0

func is_water(c: Vector2i) -> bool:
	return inside(c) and water[idx(c)] == 1

func is_road(c: Vector2i) -> bool:
	return inside(c) and road[idx(c)] > 0

func is_reserved(c: Vector2i) -> bool:
	return inside(c) and reserved[idx(c)] == 1

func forest_at(c: Vector2i) -> float:
	return forest[idx(c)] if inside(c) else 0.0

## Something stands on the cell or the way must stay open.
func is_free(c: Vector2i) -> bool:
	return inside(c) and water[idx(c)] == 0 and road[idx(c)] == 0 and reserved[idx(c)] == 0 \
		and not ramps.has(c)

func _disc(center: Vector2, radius: float, f: Callable) -> void:
	for i in range(floori(center.x - radius) - 1, ceili(center.x + radius) + 2):
		for j in range(floori(center.y - radius) - 1, ceili(center.y + radius) + 2):
			var c := Vector2i(i, j)
			if inside(c) and Vector2(i + 0.5, j + 0.5).distance_to(center) <= radius:
				f.call(c)

func _reserve_disc(center: Vector2, radius: float) -> void:
	_disc(center, radius, func(c): reserved[idx(c)] = 1)

func _reserve_rect(r: Rect2i, margin: int = 0) -> void:
	for i in range(r.position.x - margin, r.end.x + margin):
		for j in range(r.position.y - margin, r.end.y + margin):
			if inside(Vector2i(i, j)):
				reserved[idx(Vector2i(i, j))] = 1

## Distance (in cells, capped) to the nearest cell matching `f`.
func _near(c: Vector2i, radius: int, f: Callable) -> bool:
	for di in range(-radius, radius + 1):
		for dj in range(-radius, radius + 1):
			var n := c + Vector2i(di, dj)
			if inside(n) and f.call(n):
				return true
	return false

# --- regions -------------------------------------------------------------------

func _regions() -> void:
	for i in W:
		for j in W:
			var best := 0
			var best_d := INF
			for k in REGIONS.size():
				var ce: Array = CENTRES[REGIONS[k]]
				var d: float = Vector2(i, j).distance_to(ce[0]) / ce[1]
				d += _n_region.get_noise_2d(i + k * 97.0, j - k * 53.0) * 30.0
				if d < best_d:
					best_d = d
					best = k
			region[idx(Vector2i(i, j))] = best

# --- water: the lake and its river --------------------------------------------

func _water() -> void:
	for i in W:
		for j in W:
			var d := Vector2(i + 0.5, j + 0.5) - LAKE
			var k := (d.x / LAKE_RADIUS.x) ** 2 + (d.y / LAKE_RADIUS.y) ** 2
			if k + _n_detail.get_noise_2d(i * 0.7, j * 0.7) * 0.35 < 1.0:
				water[idx(Vector2i(i, j))] = 1
	for path in [RIVER_IN, RIVER_OUT]:
		_trace(path, func(p: Vector2, along: float):
			var r := 1.05 + _n_detail.get_noise_1d(along * 3.0) * 0.35
			_disc(p, r, func(c): water[idx(c)] = 1))

## Walks along a polyline, wobbling sideways (but not at its two ends, so
## that roads meet their places exactly), calling f(point, distance along).
func _trace(points: Array, f: Callable, wobble: float = 1.4) -> void:
	var total := 0.0
	for s in points.size() - 1:
		total += (points[s] as Vector2).distance_to(points[s + 1])
	var along := 0.0
	for s in points.size() - 1:
		var a: Vector2 = points[s]
		var b: Vector2 = points[s + 1]
		var n := int(a.distance_to(b) / 0.3) + 1
		var side := (b - a).normalized().orthogonal()
		for k in n:
			var p := a.lerp(b, float(k) / n)
			var ends := clampf(along / 4.0, 0.0, 1.0) * clampf((total - along) / 4.0, 0.0, 1.0)
			f.call(p + side * _n_region.get_noise_1d(along * 2.0 + 500.0) * wobble * ends, along)
			along += a.distance_to(b) / n
	f.call(points[points.size() - 1], total)

# --- roads ---------------------------------------------------------------------

func _roads() -> void:
	for r in ROADS:
		var half: float = r[1]
		_trace(r[0], func(p: Vector2, _along: float):
			_disc(p, half, func(c):
				if water[idx(c)] == 1:
					bridges[c] = true
				road[idx(c)] = 1))
	# The bridges are planks over the water; the road stays a road.
	for c in bridges:
		water[idx(c)] = 0
		road[idx(c)] = 1
	# A pier from the landing, out over the lake.
	var c := LANDING
	for k in 6:
		if is_water(c) or k < 2:
			pier.append(c)
		c += Vector2i(1, 0)

## Breadth-first distances from every road cell.
func _road_distances() -> void:
	road_dist.resize(cells)
	road_dist.fill(99)
	var todo: Array[Vector2i] = []
	for i in W:
		for j in W:
			if road[idx(Vector2i(i, j))] > 0:
				road_dist[idx(Vector2i(i, j))] = 0
				todo.append(Vector2i(i, j))
	var k := 0
	while k < todo.size():
		var c := todo[k]
		k += 1
		var d := road_dist[idx(c)] + 1
		if d > 30:
			continue
		for n in [c + Vector2i(1, 0), c - Vector2i(1, 0), c + Vector2i(0, 1), c - Vector2i(0, 1)]:
			if inside(n) and road_dist[idx(n)] > d:
				road_dist[idx(n)] = d
				todo.append(n)

# --- clearings and places kept free ------------------------------------------------

func _reserve() -> void:
	for p in PLACES.values():
		_reserve_disc(p, 4.5)
	_reserve_disc(VILLAGE, 4.0)  # the square (the houses come later)
	_reserve_disc(CITY, 4.5)
	_reserve_disc(CAMP, 4.5)
	_reserve_disc(GRAVEYARD, 4.0)
	_reserve_disc(PORTAL, 3.0)
	_reserve_disc(WYVERN, WYVERN_RADIUS + 1.5)
	for c in pier:
		reserved[idx(c)] = 1

# --- highlands -------------------------------------------------------------------

## How high the ground tends to be, per region: the eastern forest is
## highland cut by valleys; the dead lands have mesas; the others a few hills.
const HIGH_THRESHOLD := {"snow": -0.02, "caves": 0.22, "ruins": 0.36, "prairie": 0.42}

func _highlands() -> void:
	var low := PackedByteArray()  # cells that must stay low
	low.resize(cells)
	low.fill(0)
	for i in W:
		for j in W:
			var c := Vector2i(i, j)
			if i < 3 or j < 3 or i >= W - 3 or j >= W - 3:
				low[idx(c)] = 1
	for i in W:
		for j in W:
			var c := Vector2i(i, j)
			if water[idx(c)] == 1 or road[idx(c)] > 0 or reserved[idx(c)] == 1:
				for di in range(-2, 3):
					for dj in range(-2, 3):
						if inside(c + Vector2i(di, dj)):
							low[idx(c + Vector2i(di, dj))] = 1
	_disc(VILLAGE, 15.0, func(c): low[idx(c)] = 1)
	_disc(CITY, 17.0, func(c): low[idx(c)] = 1)
	_disc(LAKE, 11.0, func(c): low[idx(c)] = 1)
	for i in W:
		for j in W:
			var c := Vector2i(i, j)
			var h := _n_height.get_noise_2d(i, j)
			if low[idx(c)] == 0 and h > HIGH_THRESHOLD[region_at(c)]:
				level[idx(c)] = 1
	# The wyvern's cirque: a ring of heights, open toward its road.
	_disc(WYVERN, 13.0, func(c):
		var d := Vector2(c) + Vector2(0.5, 0.5) - WYVERN
		if d.length() > WYVERN_RADIUS + 2.5 and low[idx(c)] == 0 and not _near(c, 2, func(n): return road[idx(n)] > 0):
			level[idx(c)] = 1)
	# The dungeon's mesa, the cave in its south-east face.
	for i in range(CAVE_FACE.x - 5, CAVE_FACE.x + 1):
		for j in range(CAVE_FACE.y - 4, CAVE_FACE.y + 3):
			level[idx(Vector2i(i, j))] = 1
	_clean_highlands(low)

## Smooths the highlands so that every cliff can be drawn with the pack's
## pieces: no lone cells, no one-cell spurs or notches, no diagonal pinches,
## no tiny mesas.
func _clean_highlands(low: PackedByteArray) -> void:
	var keep := func(c: Vector2i) -> bool:  # forced shapes stay as they are
		return Vector2(c).distance_to(Vector2(CAVE_FACE)) < 3.0
	for pass_k in 4:
		for i in W:
			for j in W:
				var c := Vector2i(i, j)
				if keep.call(c):
					continue
				var nb := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					nb += level_at(c + d)
				if level[idx(c)] == 1 and nb < 2:
					level[idx(c)] = 0
				elif level[idx(c)] == 0 and nb >= 3 and low[idx(c)] == 0:
					level[idx(c)] = 1
				# a cell between two highland cells facing each other (a thin wall or a notch)
				if level[idx(c)] == 1 and ((level_at(c + Vector2i(1, 0)) == 0 and level_at(c - Vector2i(1, 0)) == 0)
						or (level_at(c + Vector2i(0, 1)) == 0 and level_at(c - Vector2i(0, 1)) == 0)):
					level[idx(c)] = 0
		# diagonal pinches
		for i in W - 1:
			for j in W - 1:
				var a := level_at(Vector2i(i, j))
				var b := level_at(Vector2i(i + 1, j + 1))
				var e := level_at(Vector2i(i + 1, j))
				var s := level_at(Vector2i(i, j + 1))
				if a == 1 and b == 1 and e == 0 and s == 0:
					level[idx(Vector2i(i + 1, j + 1))] = 0
				elif a == 0 and b == 0 and e == 1 and s == 1:
					level[idx(Vector2i(i, j + 1))] = 0
	# Small mesas go.
	var seen := {}
	for i in W:
		for j in W:
			var c := Vector2i(i, j)
			if level[idx(c)] == 1 and not seen.has(c):
				var comp := _component(c, seen)
				if comp.size() < 12:
					for k in comp:
						level[idx(k)] = 0

func _component(start: Vector2i, seen: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var todo: Array[Vector2i] = [start]
	seen[start] = true
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		out.append(c)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if inside(n) and level[idx(n)] == 1 and not seen.has(n):
				seen[n] = true
				todo.append(n)
	return out

## Ramps, cut into straight stretches of the south-east cliffs, the nearest
## to the roads first: one per highland, more on the big ones.
func _ramps_cut() -> void:
	var seen := {}
	for i in W:
		for j in W:
			var start := Vector2i(i, j)
			if level[idx(start)] != 1 or seen.has(start):
				continue
			var comp := _component(start, seen)
			var candidates := []
			for c in comp:
				if c == CAVE_FACE or Vector2(c).distance_to(Vector2(CAVE_FACE)) < 3.0:
					continue
				var front := c + Vector2i(1, 0)
				if level_at(c - Vector2i(1, 0)) == 1 and level_at(c + Vector2i(0, 1)) == 1 and level_at(c - Vector2i(0, 1)) == 1 \
						and inside(front + Vector2i(1, 0)) and level_at(front) == 0 and level_at(front + Vector2i(1, 0)) == 0 \
						and not is_water(front) and not is_water(front + Vector2i(1, 0)):
					candidates.append([road_dist[idx(front)] + _rng.randf() * 2.0, c])
			candidates.sort_custom(func(a, b): return a[0] < b[0])
			var wanted := 1 + comp.size() / 90
			var chosen: Array[Vector2i] = []
			for cand in candidates:
				if chosen.size() >= wanted:
					break
				var ok := true
				for o in chosen:
					if Vector2(o).distance_to(Vector2(cand[1])) < 9.0:
						ok = false
				if ok:
					chosen.append(cand[1])
			for c in chosen:
				ramps[c] = true
				level[idx(c)] = 0
				for k in [1, 2]:  # its foot stays clear
					reserved[idx(c + Vector2i(k, 0))] = 1

# --- forests -----------------------------------------------------------------

## Density bias per region: the pines are thick, the plain has woods and
## open fields, the autumn ruins have groves, the dead lands only a few
## dead trees.
const FOREST_BIAS := {"snow": 0.2, "prairie": 0.05, "ruins": 0.05, "caves": -0.2}

func _forests() -> void:
	for i in W:
		for j in W:
			var c := Vector2i(i, j)
			var f := 0.5 + _n_forest.get_noise_2d(i, j) * 0.9 + _n_detail.get_noise_2d(i * 2.0, j * 2.0) * 0.12
			f += FOREST_BIAS[region_at(c)]
			# A great oak wood on the plain's western edge, and the world's rim is wooded.
			f += maxf(0.0, 1.0 - Vector2(i, j).distance_to(Vector2(64, 122)) / 26.0) * 0.45
			# Open ground around the village, the farm and the lake's landing.
			f -= maxf(0.0, 1.0 - Vector2(i, j).distance_to(VILLAGE) / 19.0) * 0.9
			f -= maxf(0.0, 1.0 - Vector2(i, j).distance_to(Vector2(120, 108)) / 10.0) * 0.7
			f -= maxf(0.0, 1.0 - Vector2(i, j).distance_to(Vector2(LANDING)) / 6.0) * 0.6
			var rim := mini(mini(i, j), mini(W - 1 - i, W - 1 - j))
			if rim < 4:
				f = maxf(f, 0.95 - rim * 0.08)
			if not is_free(c) and rim >= 3:
				f = 0.0
			forest[idx(c)] = clampf(f, 0.0, 1.0)
	# Thin the woods along the roads (no wall of trees on the verges).
	for i in W:
		for j in W:
			var c := Vector2i(i, j)
			if forest[idx(c)] > 0.0 and _near(c, 1, func(n): return road[idx(n)] > 0 or water[idx(n)] == 1):
				forest[idx(c)] = minf(forest[idx(c)], 0.45)

# --- the village and its fields -------------------------------------------------

## Houses lining the roads around the square (doors on their south-east
## side), fields fenced in around, a few more houses by the farm.
func _village() -> void:
	var v := Vector2i(VILLAGE)
	# Two straight streets crossing at the square.
	for k in range(-12, 13):
		for w in 2:
			for c in [v + Vector2i(w, k), v + Vector2i(k, w)]:
				if inside(c) and water[idx(c)] == 0:
					road[idx(c)] = 1
					forest[idx(c)] = 0.0
	# Houses on both sides of the streets (their doors are on their
	# south-east side: those west of the main street face it).
	var plan := []
	for j0 in range(v.y - 12, v.y + 11, 4):
		plan.append(Vector2i(v.x - 3, j0))
		plan.append(Vector2i(v.x + 3, j0))
	for i0 in range(v.x - 12, v.x + 11, 3):
		plan.append(Vector2i(i0, v.y - 4))
		plan.append(Vector2i(i0, v.y + 3))
	for k in range(plan.size() - 1, 0, -1):  # shuffled, always the same way
		var o := _rng.randi() % (k + 1)
		var t: Vector2i = plan[k]
		plan[k] = plan[o]
		plan[o] = t
	for first in plan:
		if houses.size() >= 14:
			break
		var length := 3 if _rng.randf() < 0.6 else 2
		var r := Rect2i(first, Vector2i(2, length))
		if _house_fits(r):
			houses.append([first, length, ["slate", "tiles", "timber", "grey"][_rng.randi() % 4]])
			_reserve_rect(r)
			var door := Vector2i(r.end.x, r.position.y + (length - 1) / 2)
			if inside(door):
				reserved[idx(door)] = 1  # the doorstep stays clear
	# The farm across the river.
	for h in [[Vector2i(122, 103), 3], [Vector2i(124, 109), 2]]:
		var r := Rect2i(h[0], Vector2i(2, h[1]))
		if _house_fits(r):
			farm_houses.append([h[0], h[1], "timber"])
			_reserve_rect(r)
	# Fields: big fenced rectangles near the village and the farm.
	var field_spots := [Vector2i(86, 116), Vector2i(66, 112), Vector2i(90, 120), Vector2i(72, 118), Vector2i(116, 116),
		Vector2i(60, 100), Vector2i(94, 110)]
	for s in field_spots:
		for attempt in 12:
			var size := Vector2i(_rng.randi_range(5, 8), _rng.randi_range(4, 6))
			var r := Rect2i(s + Vector2i(_rng.randi_range(-3, 3), _rng.randi_range(-3, 3)), size)
			if _field_fits(r):
				fields.append(r)
				_reserve_rect(r, 1)
				for i in range(r.position.x - 1, r.end.x + 1):
					for j in range(r.position.y - 1, r.end.y + 1):
						if inside(Vector2i(i, j)):
							forest[idx(Vector2i(i, j))] = 0.0
				break

## A house's cells must be free; around it, no water, cliff or ramp.
func _house_fits(r: Rect2i) -> bool:
	for i in range(r.position.x - 1, r.end.x + 1):
		for j in range(r.position.y - 1, r.end.y + 1):
			var c := Vector2i(i, j)
			if not inside(c) or level_at(c) == 1 or ramps.has(c) or is_water(c):
				return false
			if r.has_point(c) and (reserved[idx(c)] == 1 or road[idx(c)] > 0):
				return false
	return true

func _field_fits(r: Rect2i) -> bool:
	for i in range(r.position.x - 1, r.end.x + 1):
		for j in range(r.position.y - 1, r.end.y + 1):
			var c := Vector2i(i, j)
			if not inside(c) or level_at(c) == 1 or ramps.has(c) or is_water(c) or road[idx(c)] > 0 \
					or reserved[idx(c)] == 1 or region_at(c) != "prairie":
				return false
	return true

# --- the ruined city ---------------------------------------------------------------

## Paved streets in a grid, and the stumps of buildings between them.
func _ruined_city() -> void:
	var origin := Vector2i(CITY) - Vector2i(15, 15)
	for i in 31:
		for j in 31:
			var c := origin + Vector2i(i, j)
			if not inside(c) or level_at(c) == 1:
				continue
			var d := Vector2(c).distance_to(CITY)
			var street := (i % 6 == 3 or j % 6 == 3) and d < 14.5 + _n_detail.get_noise_2d(c.x, c.y) * 2.5
			if street and water[idx(c)] == 0:
				road[idx(c)] = 2
			if road[idx(c)] > 0 and d < 15.0:
				road[idx(c)] = 2  # the roads into the city are paved too
	for bi in 5:
		for bj in 5:
			var r := Rect2i(origin + Vector2i(bi * 6 + 4, bj * 6 + 4), Vector2i(_rng.randi_range(3, 5), _rng.randi_range(3, 5)))
			if Vector2(r.get_center()).distance_to(CITY) > 15.0 or _rng.randf() < 0.12:
				continue
			var ok := true
			for i in range(r.position.x, r.end.x):
				for j in range(r.position.y, r.end.y):
					var c := Vector2i(i, j)
					if not inside(c) or level_at(c) == 1 or road[idx(c)] > 0 or is_water(c) \
							or Vector2(c).distance_to(CITY) < 4.5:
						ok = false
			if ok:
				ruins_rooms.append(r)
				_reserve_rect(r)
