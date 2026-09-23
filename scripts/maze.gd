class_name MazeData
extends RefCounted

const WIDTH := 27
const HEIGHT := 29
const HOUSE := Vector2i(13, 14)
const START := Vector2i(1, 1)
const EXIT := Vector2i(25, 27)

var cells: Array = []
var pellets: Dictionary = {}
var visited: Dictionary = {}
var initial_pellet_count := 0
var seed_value := 0

func generate(new_seed: int) -> void:
	seed_value = new_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = new_seed
	cells.clear()
	pellets.clear()
	visited.clear()
	for y in HEIGHT:
		var row: Array[int] = []
		for x in WIDTH:
			row.append(1)
		cells.append(row)
	var stack: Array[Vector2i] = [START]
	_carve(START)
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = current + direction * 2
			if next.x > 0 and next.x < WIDTH - 1 and next.y > 0 and next.y < HEIGHT - 1 and cells[next.y][next.x] == 1:
				options.append(next)
		if options.is_empty():
			stack.pop_back()
		else:
			var next: Vector2i = options[rng.randi_range(0, options.size() - 1)]
			_carve(Vector2i((next.x + current.x) / 2, (next.y + current.y) / 2))
			_carve(next)
			stack.append(next)
	# Open some connections in the spanning maze so routes feel like Pac-Man.
	for y in range(2, HEIGHT - 2):
		for x in range(2, WIDTH - 2):
			if cells[y][x] == 1 and rng.randf() < 0.19:
				if (cells[y - 1][x] == 0 and cells[y + 1][x] == 0) or (cells[y][x - 1] == 0 and cells[y][x + 1] == 0):
					cells[y][x] = 0
	# A central ghost house and a wrap tunnel are deliberately connected to the maze.
	for y in range(12, 17):
		for x in range(11, 16):
			_carve(Vector2i(x, y))
	for x in WIDTH:
		_carve(Vector2i(x, HOUSE.y))
	for y in range(13, 16):
		_carve(Vector2i(9, y))
		_carve(Vector2i(17, y))
	for y in HEIGHT:
		for x in WIDTH:
			var tile := Vector2i(x, y)
			if cells[y][x] == 0 and not is_house(tile) and tile != START and tile != EXIT and tile.x > 0 and tile.x < WIDTH - 1:
				pellets[tile] = 1
	# Power pellets belong to risky corners, but always on reachable floor tiles.
	for corner in [Vector2i(2, 2), Vector2i(WIDTH - 3, 2), Vector2i(2, HEIGHT - 3), Vector2i(WIDTH - 3, HEIGHT - 3)]:
		var nearest := Vector2i(-1, -1)
		var best := 999999
		for tile in pellets:
			var distance: int = absi(tile.x - corner.x) + absi(tile.y - corner.y)
			if distance < best:
				nearest = tile
				best = distance
		if nearest.x >= 0:
			pellets[nearest] = 2
	initial_pellet_count = pellets.size()
	reveal(START, 3)

func _carve(tile: Vector2i) -> void:
	cells[tile.y][tile.x] = 0

func is_house(tile: Vector2i) -> bool:
	return tile.x >= 11 and tile.x <= 15 and tile.y >= 12 and tile.y <= 16

func is_walkable(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < WIDTH and tile.y >= 0 and tile.y < HEIGHT and cells[tile.y][tile.x] == 0

func step(tile: Vector2i, direction: Vector2i) -> Vector2i:
	var next := tile + direction
	if tile.y == HOUSE.y and next.x < 0:
		next.x = WIDTH - 1
	elif tile.y == HOUSE.y and next.x >= WIDTH:
		next.x = 0
	return next if is_walkable(next) else tile

func directions(tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		if step(tile, direction) != tile:
			result.append(direction)
	return result

func reveal(center: Vector2i, radius: int) -> void:
	for y in range(maxi(0, center.y - radius), mini(HEIGHT, center.y + radius + 1)):
		for x in range(maxi(0, center.x - radius), mini(WIDTH, center.x + radius + 1)):
			if abs(x - center.x) + abs(y - center.y) <= radius + 1:
				visited[Vector2i(x, y)] = true

func data() -> Dictionary:
	var remaining: Array = []
	for tile in pellets:
		remaining.append([tile.x, tile.y, pellets[tile]])
	var seen: Array = []
	for tile in visited:
		seen.append([tile.x, tile.y])
	return {"seed": seed_value, "remaining": remaining, "seen": seen}

func restore(saved: Dictionary) -> void:
	generate(int(saved.get("seed", 1)))
	pellets.clear()
	for entry in saved.get("remaining", []):
		var tile := Vector2i(int(entry[0]), int(entry[1]))
		if is_walkable(tile) and not is_house(tile):
			pellets[tile] = int(entry[2])
	visited.clear()
	for entry in saved.get("seen", []):
		visited[Vector2i(int(entry[0]), int(entry[1]))] = true
