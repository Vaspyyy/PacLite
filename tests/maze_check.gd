extends SceneTree

const MazeScript = preload("res://scripts/maze.gd")

func _initialize() -> void:
	for seed in range(1, 101):
		var maze: MazeData = MazeScript.new()
		maze.generate(seed)
		if not maze.is_walkable(MazeData.START) or not maze.is_walkable(MazeData.EXIT):
			_fail("start or exit is a wall", seed)
			return
		var reachable: Dictionary = {MazeData.START: true}
		var queue: Array[Vector2i] = [MazeData.START]
		var index := 0
		while index < queue.size():
			var cell := queue[index]
			index += 1
			for direction in maze.directions(cell):
				var next := maze.step(cell, direction)
				if not reachable.has(next):
					reachable[next] = true
					queue.append(next)
		if not reachable.has(MazeData.EXIT) or not reachable.has(MazeData.HOUSE):
			_fail("exit or house is unreachable", seed)
			return
		var power_count := 0
		for tile in maze.pellets:
			if not reachable.has(tile):
				_fail("unreachable pellet", seed)
				return
			if maze.pellets[tile] == 2:
				power_count += 1
		if power_count != 4:
			_fail("expected four power pellets", seed)
			return
		var state := maze.data()
		var restored: MazeData = MazeScript.new()
		restored.restore(state)
		if restored.pellets.size() != maze.pellets.size() or restored.visited.size() != maze.visited.size():
			_fail("maze save/restore mismatch", seed)
			return
	print("100 maze seeds: connected objectives, four power pellets, and save/restore passed")
	quit(0)

func _fail(message: String, seed: int) -> void:
	push_error("Seed %d: %s" % [seed, message])
	quit(1)
