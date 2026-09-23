extends Node2D

const MazeScript = preload("res://scripts/maze.gd")
const SoundScript = preload("res://scripts/soundscape.gd")
const SAVE_PATH := "user://active_run.json"
const SETTINGS_PATH := "user://settings.json"
const TILE := 40.0
const PLAYER_SPEED := 4.25
const GHOST_SPEED := 3.05
const POWER_SECONDS := 3.0

enum Screen { MENU, PLAY, PAUSE, DEAD, CLEAR, SETTINGS }

var screen: Screen = Screen.MENU
var maze: MazeData
var player: Dictionary = {}
var ghosts: Array[Dictionary] = []
var eaten: Array[Vector2i] = []
var direction_request := Vector2i.RIGHT
var health := 2
var score := 0
var best := 0
var power_left := 0.0
var power_chain := 0
var invulnerable := 0.0
var fruit_tile := Vector2i(-1, -1)
var fruit_taken := false
var save_clock := 0.0
var animation_time := 0.0
var camera_point := Vector2.ZERO
var shake := 0.0
var language := "en"
var music_level := 0.5
var effects_level := 0.8
var haptics_level := 1.0
var reduced_effects := false
var fps_mode := 60
var battery_mode := "balanced"
var sound: Soundscape
var finger_start := Vector2.ZERO
var finger_held := false
var mouse_held := false
var saved_run_exists := false
var font: Font
var button_regions: Dictionary = {}

const BACKGROUND := Color("090d22")
const PANEL := Color("111b35")
const CYAN := Color("43e8fb")
const GOLD := Color("ffe268")
const CORAL := Color("ff657f")
const PINK := Color("ff91d5")
const GHOST_COLORS := [Color("ff4964"), Color("ff9fe1"), Color("67d4fa"), Color("ffb76c")]

func _ready() -> void:
	font = ThemeDB.fallback_font
	sound = SoundScript.new()
	add_child(sound)
	_load_settings()
	saved_run_exists = FileAccess.file_exists(SAVE_PATH)
	_apply_settings()
	queue_redraw()

func _tr(en: String, de: String) -> String:
	return de if language == "de" else en

func _apply_settings() -> void:
	Engine.max_fps = 45 if battery_mode == "efficiency" else fps_mode
	if is_instance_valid(sound):
		sound.music_level = music_level
		sound.effects_level = effects_level

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	language = str(parsed.get("language", "en"))
	music_level = clampf(float(parsed.get("music", 0.5)), 0.0, 1.0)
	effects_level = clampf(float(parsed.get("effects", 0.8)), 0.0, 1.0)
	haptics_level = clampf(float(parsed.get("haptics", 1.0)), 0.0, 1.0)
	reduced_effects = bool(parsed.get("reduced_effects", false))
	fps_mode = 120 if int(parsed.get("fps", 60)) == 120 else 60
	battery_mode = str(parsed.get("battery", "balanced"))
	best = int(parsed.get("best", 0))

func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"language": language, "music": music_level, "effects": effects_level, "haptics": haptics_level, "reduced_effects": reduced_effects, "fps": fps_mode, "battery": battery_mode, "best": best}))
	_apply_settings()

func _new_run() -> void:
	health = 2
	score = 0
	power_left = 0.0
	power_chain = 0
	invulnerable = 0.0
	eaten.clear()
	fruit_tile = Vector2i(-1, -1)
	fruit_taken = false
	var seed := int(Time.get_unix_time_from_system() * 1000.0) ^ randi()
	maze = MazeScript.new()
	maze.generate(seed)
	player = _make_entity(MazeData.START, Vector2i.RIGHT)
	direction_request = Vector2i.RIGHT
	ghosts.clear()
	for i in 4:
		var ghost := _make_entity(MazeData.HOUSE + [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][i], Vector2i.UP)
		ghost["kind"] = i
		ghost["respawn"] = 0.4 + 0.45 * i
		ghosts.append(ghost)
	camera_point = _clamp_camera(_tile_pos(MazeData.START))
	screen = Screen.PLAY
	_save_run()

func _make_entity(tile: Vector2i, direction: Vector2i) -> Dictionary:
	return {"cell": tile, "target": tile, "progress": 0.0, "dir": direction, "respawn": 0.0}

func _process(delta: float) -> void:
	animation_time += delta
	if screen == Screen.PLAY:
		save_clock += delta
		if save_clock >= 5.0:
			save_clock = 0.0
			_save_run()
		var closest := 9.0
		for ghost in ghosts:
			if float(ghost["respawn"]) <= 0.0:
				closest = minf(closest, _entity_pos(ghost).distance_to(_entity_pos(player)))
		sound.tension = clampf(1.0 - closest / 8.0, 0.0, 1.0)
		sound.powered = power_left > 0.0
	else:
		sound.tension = 0.0
	shake = maxf(0.0, shake - delta * 22.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if screen != Screen.PLAY:
		return
	power_left = maxf(0.0, power_left - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	_move_player(delta)
	if screen != Screen.PLAY:
		return
	for ghost in ghosts:
		if float(ghost["respawn"]) > 0.0:
			ghost["respawn"] = maxf(0.0, float(ghost["respawn"]) - delta)
		else:
			_move_ghost(ghost, delta)
	_check_collisions()
	var focus := _tile_pos_vec(_entity_pos(player)) + Vector2(float(player["dir"].x), float(player["dir"].y)) * TILE * 2.3
	camera_point = camera_point.lerp(_clamp_camera(focus), minf(1.0, delta * 5.5))

func _move_player(delta: float) -> void:
	var remaining := PLAYER_SPEED * delta
	while remaining > 0.0:
		if player["cell"] == player["target"]:
			var current: Vector2i = player["cell"]
			var direction: Vector2i = player["dir"]
			var candidates := maze.directions(current)
			if candidates.has(direction_request):
				var reverse: bool = direction_request == -direction
				if not reverse or candidates.size() == 1:
					direction = direction_request
			if not candidates.has(direction):
				if candidates.has(-direction):
					direction = -direction
				elif not candidates.is_empty():
					direction = candidates[0]
			if not candidates.has(direction):
				break
			player["dir"] = direction
			player["target"] = maze.step(current, direction)
			player["progress"] = 0.0
		var advance: float = minf(remaining, 1.0 - float(player["progress"]))
		player["progress"] = float(player["progress"]) + advance
		remaining -= advance
		if float(player["progress"]) >= 0.99999:
			player["cell"] = player["target"]
			player["progress"] = 0.0
			_player_arrived(player["cell"])
			if screen != Screen.PLAY:
				return
		else:
			break

func _player_arrived(tile: Vector2i) -> void:
	maze.reveal(tile, 3)
	if maze.pellets.has(tile):
		var kind: int = maze.pellets[tile]
		maze.pellets.erase(tile)
		eaten.append(tile)
		score += 50 if kind == 2 else 10
		if kind == 2:
			power_left = POWER_SECONDS
			power_chain = 0
			for ghost in ghosts:
				ghost["chain"] = 0
			sound.event("power")
			_vibrate(65)
		else:
			sound.event("pellet")
		if not fruit_taken and fruit_tile.x < 0 and maze.pellets.size() <= maze.initial_pellet_count / 2:
			_spawn_fruit(tile)
	if tile == fruit_tile:
		fruit_tile = Vector2i(-1, -1)
		fruit_taken = true
		score += 500
		if health < 2:
			health += 1
		sound.event("fruit")
		_vibrate(110)
	if maze.pellets.is_empty() and tile == MazeData.EXIT:
		_finish_floor()

func _spawn_fruit(player_tile: Vector2i) -> void:
	var farthest := Vector2i(-1, -1)
	var best := -1
	for candidate in maze.pellets:
		var distance: int = abs(candidate.x - player_tile.x) + abs(candidate.y - player_tile.y)
		if maze.pellets[candidate] == 1 and distance > best:
			farthest = candidate
			best = distance
	fruit_tile = farthest

func _move_ghost(ghost: Dictionary, delta: float) -> void:
	var remaining := (GHOST_SPEED * (0.82 if power_left > 0.0 else 1.0)) * delta
	while remaining > 0.0:
		if ghost["cell"] == ghost["target"]:
			var cell: Vector2i = ghost["cell"]
			var candidates := maze.directions(cell)
			if candidates.is_empty():
				return
			var forward: Array[Vector2i] = []
			for candidate in candidates:
				if candidate != -ghost["dir"]:
					forward.append(candidate)
			if not forward.is_empty():
				candidates = forward
			var prey: Vector2i = player["cell"]
			var target := _ghost_goal(int(ghost["kind"]), cell, prey)
			var selected: Vector2i = candidates[0]
			var best := -99999 if power_left > 0.0 else 99999
			for candidate in candidates:
				var next := maze.step(cell, candidate)
				var metric: int = abs(next.x - target.x) + abs(next.y - target.y)
				# A little stable variety keeps ghosts from forming one identical train.
				metric += (int(ghost["kind"]) + next.x * 3 + next.y * 7) % 3
				if (power_left > 0.0 and metric > best) or (power_left <= 0.0 and metric < best):
					selected = candidate
					best = metric
			ghost["dir"] = selected
			ghost["target"] = maze.step(cell, selected)
			ghost["progress"] = 0.0
		var advance: float = minf(remaining, 1.0 - float(ghost["progress"]))
		ghost["progress"] = float(ghost["progress"]) + advance
		remaining -= advance
		if float(ghost["progress"]) >= 0.99999:
			ghost["cell"] = ghost["target"]
			ghost["progress"] = 0.0
		else:
			break

func _ghost_goal(kind: int, cell: Vector2i, prey: Vector2i) -> Vector2i:
	var heading: Vector2i = player["dir"]
	match kind:
		0: return prey # Direct hunter.
		1: return prey + heading * 4 # Ambusher.
		2:
			var flank: Vector2i = ghosts[0]["cell"] if not ghosts.is_empty() else prey
			return prey + (prey - flank) + heading * 2 # Unstable flank.
		3:
			return Vector2i(1, MazeData.HEIGHT - 2) if cell.distance_to(prey) < 7.0 else prey
	return prey

func _entity_pos(entity: Dictionary) -> Vector2:
	var cell: Vector2i = entity["cell"]
	var target: Vector2i = entity["target"]
	if abs(cell.x - target.x) > 1:
		return Vector2(cell) if float(entity["progress"]) < 0.5 else Vector2(target)
	return Vector2(cell).lerp(Vector2(target), float(entity["progress"]))

func _check_collisions() -> void:
	for ghost in ghosts:
		if float(ghost["respawn"]) > 0.0:
			continue
		if _entity_pos(player).distance_to(_entity_pos(ghost)) > 0.56:
			continue
		if power_left > 0.0:
			score += 200 * (1 << mini(3, power_chain))
			power_chain += 1
			ghost["cell"] = MazeData.HOUSE
			ghost["target"] = MazeData.HOUSE
			ghost["progress"] = 0.0
			ghost["respawn"] = 2.0
			sound.event("ghost")
			_vibrate(110)
		elif invulnerable <= 0.0:
			health -= 1
			invulnerable = 1.0
			shake = 8.0
			_spill_pellets()
			sound.event("hurt")
			_vibrate(230)
			if health <= 0:
				_end_run()
			return

func _spill_pellets() -> void:
	for i in mini(5, eaten.size()):
		var tile: Vector2i = eaten.pop_back()
		if tile != player["cell"] and not maze.pellets.has(tile):
			maze.pellets[tile] = 1

func _finish_floor() -> void:
	screen = Screen.CLEAR
	best = maxi(best, score)
	_save_settings()
	_clear_run_save()
	sound.event("clear")
	_vibrate(250)

func _end_run() -> void:
	screen = Screen.DEAD
	best = maxi(best, score)
	_save_settings()
	_clear_run_save()

func _vibrate(duration: int) -> void:
	if haptics_level > 0.0:
		Input.vibrate_handheld(duration, haptics_level)

func _snap_entity(entity: Dictionary) -> Dictionary:
	return {"cell": [entity["cell"].x, entity["cell"].y], "target": [entity["target"].x, entity["target"].y], "dir": [entity["dir"].x, entity["dir"].y], "progress": entity["progress"], "respawn": entity.get("respawn", 0.0), "kind": entity.get("kind", -1), "chain": entity.get("chain", 0)}

func _from_snap(snapshot: Dictionary) -> Dictionary:
	var c: Array = snapshot.get("cell", [1, 1])
	var t: Array = snapshot.get("target", c)
	var d: Array = snapshot.get("dir", [1, 0])
	return {"cell": Vector2i(int(c[0]), int(c[1])), "target": Vector2i(int(t[0]), int(t[1])), "dir": Vector2i(int(d[0]), int(d[1])), "progress": clampf(float(snapshot.get("progress", 0.0)), 0.0, 0.999), "respawn": float(snapshot.get("respawn", 0.0)), "kind": int(snapshot.get("kind", -1)), "chain": int(snapshot.get("chain", 0))}

func _save_run() -> void:
	if screen != Screen.PLAY and screen != Screen.PAUSE:
		return
	var ghost_data: Array = []
	for ghost in ghosts:
		ghost_data.append(_snap_entity(ghost))
	var eaten_data: Array = []
	for tile in eaten:
		eaten_data.append([tile.x, tile.y])
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"version": 1, "maze": maze.data(), "player": _snap_entity(player), "ghosts": ghost_data, "eaten": eaten_data, "request": [direction_request.x, direction_request.y], "health": health, "score": score, "power": power_left, "power_chain": power_chain, "invulnerable": invulnerable, "fruit": [fruit_tile.x, fruit_tile.y], "fruit_taken": fruit_taken}))
	saved_run_exists = true

func _load_run() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
		return
	maze = MazeScript.new()
	maze.restore(parsed.get("maze", {}))
	player = _from_snap(parsed.get("player", {}))
	ghosts.clear()
	for snapshot in parsed.get("ghosts", []):
		ghosts.append(_from_snap(snapshot))
	if ghosts.size() != 4:
		return
	eaten.clear()
	for entry in parsed.get("eaten", []):
		eaten.append(Vector2i(int(entry[0]), int(entry[1])))
	var request: Array = parsed.get("request", [1, 0])
	direction_request = Vector2i(int(request[0]), int(request[1]))
	health = int(parsed.get("health", 2))
	score = int(parsed.get("score", 0))
	power_left = float(parsed.get("power", 0.0))
	power_chain = int(parsed.get("power_chain", 0))
	invulnerable = float(parsed.get("invulnerable", 0.0))
	var fruit: Array = parsed.get("fruit", [-1, -1])
	fruit_tile = Vector2i(int(fruit[0]), int(fruit[1]))
	fruit_taken = bool(parsed.get("fruit_taken", false))
	camera_point = _clamp_camera(_tile_pos_vec(_entity_pos(player)))
	screen = Screen.PLAY

func _clear_run_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	saved_run_exists = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if screen == Screen.PLAY:
			screen = Screen.PAUSE
			_save_run()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			finger_start = event.position
			finger_held = true
		else:
			if finger_held:
				_handle_gesture(finger_start, event.position)
			finger_held = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			finger_start = event.position
			mouse_held = true
		elif mouse_held:
			_handle_gesture(finger_start, event.position)
			mouse_held = false
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if screen == Screen.PLAY:
				screen = Screen.PAUSE
				_save_run()
			elif screen == Screen.PAUSE:
				screen = Screen.PLAY
		elif screen == Screen.PLAY:
			match event.keycode:
				KEY_UP, KEY_W: direction_request = Vector2i.UP
				KEY_DOWN, KEY_S: direction_request = Vector2i.DOWN
				KEY_LEFT, KEY_A: direction_request = Vector2i.LEFT
				KEY_RIGHT, KEY_D: direction_request = Vector2i.RIGHT

func _handle_gesture(start: Vector2, finish: Vector2) -> void:
	var delta := finish - start
	if screen == Screen.PLAY and delta.length() >= 24.0:
		if absf(delta.x) > absf(delta.y):
			direction_request = Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT
		else:
			direction_request = Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP
		return
	if delta.length() > 24.0:
		return
	for id in button_regions:
		if button_regions[id].has_point(finish):
			_press_button(str(id))
			return

func _press_button(id: String) -> void:
	match id:
		"new": _new_run()
		"resume":
			if screen == Screen.PAUSE:
				screen = Screen.PLAY
			elif saved_run_exists:
				_load_run()
		"pause":
			screen = Screen.PAUSE
			_save_run()
		"menu":
			if screen == Screen.PAUSE:
				_save_run()
			screen = Screen.MENU
		"settings": screen = Screen.SETTINGS
		"abandon":
			_clear_run_save()
			screen = Screen.MENU
		"language": language = "de" if language == "en" else "en"
		"music_less": music_level = maxf(0.0, music_level - 0.1)
		"music_more": music_level = minf(1.0, music_level + 0.1)
		"effects_less": effects_level = maxf(0.0, effects_level - 0.1)
		"effects_more": effects_level = minf(1.0, effects_level + 0.1)
		"haptics_less": haptics_level = maxf(0.0, haptics_level - 0.1)
		"haptics_more": haptics_level = minf(1.0, haptics_level + 0.1)
		"fps": fps_mode = 120 if fps_mode == 60 else 60
		"battery": battery_mode = "efficiency" if battery_mode == "balanced" else ("performance" if battery_mode == "efficiency" else "balanced")
		"effects": reduced_effects = not reduced_effects
	if screen == Screen.SETTINGS:
		_save_settings()

func _tile_pos(tile: Vector2i) -> Vector2:
	return Vector2(tile) * TILE + Vector2(TILE * 0.5, TILE * 0.5)

func _tile_pos_vec(tile: Vector2) -> Vector2:
	return tile * TILE + Vector2(TILE * 0.5, TILE * 0.5)

func _world_to_screen(world: Vector2) -> Vector2:
	var size := get_viewport_rect().size
	return world - camera_point + Vector2(size.x * 0.5, size.y * 0.53) + Vector2(sin(animation_time * 69.0), cos(animation_time * 55.0)) * shake

func _clamp_camera(point: Vector2) -> Vector2:
	var size := get_viewport_rect().size
	var center := Vector2(size.x * 0.5, size.y * 0.53)
	var world := Vector2(MazeData.WIDTH, MazeData.HEIGHT) * TILE
	var min_camera := center - Vector2(0.0, 81.0)
	var max_camera := world + center - size
	return Vector2(clampf(point.x, min_camera.x, maxf(min_camera.x, max_camera.x)), clampf(point.y, min_camera.y, maxf(min_camera.y, max_camera.y)))

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	button_regions.clear()
	if screen == Screen.MENU or screen == Screen.SETTINGS:
		_draw_title_screen(size)
		if screen == Screen.SETTINGS:
			_draw_settings(size)
		return
	if maze == null:
		return
	_draw_world(size)
	_draw_actors()
	_draw_hud(size)
	if screen == Screen.PAUSE:
		_draw_pause(size)
	elif screen == Screen.DEAD or screen == Screen.CLEAR:
		_draw_result(size)

func _label(value: String, position: Vector2, point_size: int, color: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(font, position, value, align, width, point_size, color)

func _glow(center: Vector2, radius: float, color: Color, strength: float = 1.0) -> void:
	if reduced_effects or battery_mode == "efficiency":
		return
	for i in range(3, 0, -1):
		var layer := color
		layer.a = 0.025 * strength * (4 - i)
		draw_circle(center, radius + float(i) * 7.0, layer)

func _draw_world(size: Vector2) -> void:
	for y in MazeData.HEIGHT:
		for x in MazeData.WIDTH:
			var tile := Vector2i(x, y)
			var center := _world_to_screen(_tile_pos(tile))
			if center.x < -TILE or center.x > size.x + TILE or center.y < -TILE or center.y > size.y + TILE:
				continue
			var box := Rect2(center - Vector2.ONE * TILE * 0.5, Vector2.ONE * TILE)
			if maze.cells[y][x] == 1:
				draw_rect(box, Color("15254c"))
				draw_rect(box.grow(-4.0), Color("243a74"))
				draw_rect(box.grow(-7.0), Color("1b2b5a"))
				draw_rect(box.grow(-3.0), Color("64a6fb", 0.29), false, 2.0)
			else:
				draw_rect(box, Color("0a1026") if (x + y) % 2 == 0 else Color("0c132b"))
				if maze.is_house(tile):
					draw_rect(box, Color("251b3c", 0.55))
				if maze.pellets.has(tile):
					var power: bool = maze.pellets[tile] == 2
					if power:
						_glow(center, 9.0, PINK, 1.5)
						draw_circle(center, 8.0 + sin(animation_time * 6.0) * 1.6, PINK)
					else:
						draw_circle(center, 2.9, Color("ffd4a9"))
				if tile == MazeData.EXIT:
					var open: bool = maze.pellets.is_empty()
					var exit_color := CYAN if open else Color("456379")
					if open:
						_glow(center, 12.0, CYAN)
					for i in 3:
						draw_arc(center, 11.0 + i * 4.0, PI * 0.9, PI * 2.1, 18, exit_color, 2.0, true)
				if tile == fruit_tile:
					_glow(center, 10.0, CORAL)
					draw_circle(center + Vector2(-5, 2), 6.0, CORAL)
					draw_circle(center + Vector2(5, 2), 6.0, CORAL)
					draw_line(center + Vector2(0, -2), center + Vector2(3, -11), Color("b3f6a0"), 2.0)

func _draw_actors() -> void:
	for ghost in ghosts:
		if float(ghost["respawn"]) > 0.0:
			continue
		_draw_ghost(_world_to_screen(_tile_pos_vec(_entity_pos(ghost))), int(ghost["kind"]), ghost["dir"])
	var center := _world_to_screen(_tile_pos_vec(_entity_pos(player)))
	if invulnerable > 0.0 and fmod(animation_time, 0.16) < 0.08:
		return
	_glow(center, 16.0, GOLD, 1.2 if power_left <= 0.0 else 2.2)
	if power_left > 0.0:
		var halo := PINK
		halo.a = 0.8
		draw_arc(center, 21.0, -PI * 0.5, -PI * 0.5 + TAU * power_left / POWER_SECONDS, 36, halo, 4.0, true)
	draw_circle(center, 16.0, GOLD)
	var heading: Vector2 = Vector2(player["dir"])
	var mouth := 0.16 + absf(sin(animation_time * 13.0)) * 0.36
	var angle := heading.angle()
	var cut := PackedVector2Array([center, center + Vector2.from_angle(angle - mouth) * 18.5, center + Vector2.from_angle(angle + mouth) * 18.5])
	draw_colored_polygon(cut, Color("0a1026"))
	if not reduced_effects:
		for i in 3:
			var trail := GOLD
			trail.a = 0.13 * (3 - i)
			draw_circle(center - heading * (21.0 + i * 10.0), 5.0 - i, trail)

func _draw_ghost(center: Vector2, kind: int, heading: Vector2i) -> void:
	var color: Color = Color("3d70ed") if power_left > 0.0 else GHOST_COLORS[kind % GHOST_COLORS.size()]
	if power_left > 0.0 and power_left < 1.0 and fmod(animation_time, 0.2) < 0.1:
		color = Color.WHITE
	_glow(center, 15.0, color, 0.85)
	var outline := PackedVector2Array()
	for i in 11:
		var angle := PI + PI * float(i) / 10.0
		outline.append(center + Vector2(cos(angle), sin(angle)) * 15.0)
	outline.append(center + Vector2(15, 13))
	for i in 5:
		outline.append(center + Vector2(12.0 - i * 6.0, 9.0 if i % 2 == 0 else 15.0))
	draw_colored_polygon(outline, color)
	var eye_dir := Vector2(heading) * 2.5
	for offset in [-6.0, 6.0]:
		draw_circle(center + Vector2(offset, -3), 5.6, Color.WHITE)
		draw_circle(center + Vector2(offset, -3) + eye_dir, 2.4, Color("172349"))

func _draw_hud(size: Vector2) -> void:
	draw_rect(Rect2(0, 0, size.x, 81), Color("091126", 0.97))
	draw_line(Vector2(0, 80), Vector2(size.x, 80), Color("4daacb", 0.55), 2.0)
	_label("PAC", Vector2(17, 32), 26, GOLD)
	for i in health:
		draw_circle(Vector2(28 + i * 27, 56), 8.0, GOLD)
	_label(_tr("SCORE", "PUNKTE") + "  %07d" % score, Vector2(128, 31), 18, Color.WHITE)
	_label(_tr("LEFT", "REST") + "  %d" % maze.pellets.size(), Vector2(128, 58), 15, CYAN)
	if power_left > 0.0:
		var width := minf(170.0, size.x * 0.36)
		draw_rect(Rect2(size.x - width - 17, 50, width, 9), Color("394568"))
		draw_rect(Rect2(size.x - width - 17, 50, width * power_left / POWER_SECONDS, 9), PINK)
	_draw_button("pause", "Ⅱ", Rect2(size.x - 62, 10, 48, 36), false, 19)
	_draw_minimap(size)
	if screen == Screen.PLAY and maze.pellets.is_empty():
		_label(_tr("EXIT OPEN", "AUSGANG OFFEN"), Vector2(0, size.y - 33), 19, CYAN, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_draw_ghost_warning(size)

func _draw_minimap(size: Vector2) -> void:
	var unit := 4.2
	var origin := Vector2(size.x - MazeData.WIDTH * unit - 16.0, 98.0)
	draw_rect(Rect2(origin - Vector2(7, 7), Vector2(MazeData.WIDTH * unit + 14, MazeData.HEIGHT * unit + 14)), Color("07101c", 0.87))
	draw_rect(Rect2(origin - Vector2(7, 7), Vector2(MazeData.WIDTH * unit + 14, MazeData.HEIGHT * unit + 14)), Color("63a9d5", 0.4), false, 1.0)
	for tile in maze.visited:
		var color := Color("405073") if maze.cells[tile.y][tile.x] == 1 else Color("1e3251")
		if maze.pellets.has(tile):
			color = PINK if maze.pellets[tile] == 2 else Color("b39c90")
		if tile == MazeData.EXIT:
			color = CYAN if maze.pellets.is_empty() else Color("597082")
		draw_rect(Rect2(origin + Vector2(tile) * unit, Vector2.ONE * (unit - 0.35)), color)
	for ghost in ghosts:
		if float(ghost["respawn"]) <= 0.0:
			var tile: Vector2i = ghost["cell"]
			if maze.visited.has(tile):
				draw_circle(origin + Vector2(tile) * unit + Vector2.ONE * 2.0, 2.6, GHOST_COLORS[int(ghost["kind"])])
	draw_circle(origin + _entity_pos(player) * unit + Vector2.ONE * 2.0, 3.4, GOLD)

func _draw_ghost_warning(size: Vector2) -> void:
	for ghost in ghosts:
		if float(ghost["respawn"]) > 0.0:
			continue
		var position := _world_to_screen(_tile_pos_vec(_entity_pos(ghost)))
		if position.x > 25.0 and position.x < size.x - 25.0 and position.y > 95.0 and position.y < size.y - 35.0:
			continue
		var marker := Vector2(clampf(position.x, 27.0, size.x - 27.0), clampf(position.y, 105.0, size.y - 30.0))
		var color: Color = GHOST_COLORS[int(ghost["kind"])]
		draw_circle(marker, 6.0, color)
		draw_circle(marker, 2.0, Color("0a1026"))

func _draw_title_screen(size: Vector2) -> void:
	for i in 16:
		var location := Vector2(fmod(i * 131.0 + animation_time * (7.0 + i % 3), size.x + 50.0) - 25.0, fmod(i * 89.0 + 123.0, size.y))
		var color := CYAN if i % 2 == 0 else PINK
		_glow(location, 3.0, color)
		draw_circle(location, 2.0, color)
	var center := Vector2(size.x * 0.5, size.y * 0.23)
	_glow(center, 58.0, GOLD, 2.2)
	draw_circle(center, 55.0, GOLD)
	var mouth := PackedVector2Array([center, center + Vector2(60, -31), center + Vector2(60, 31)])
	draw_colored_polygon(mouth, BACKGROUND)
	_label("PAC", Vector2(0, size.y * 0.40), 54, GOLD, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_label("L I T E", Vector2(0, size.y * 0.45), 25, CYAN, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_label(_tr("THE MAZE REMEMBERS", "DAS LABYRINTH ERINNERT SICH"), Vector2(0, size.y * 0.5), 15, Color("9ab4d6"), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if screen == Screen.MENU:
		var start := size.y * 0.58
		if saved_run_exists:
			_draw_button("resume", _tr("RESUME RUN", "LAUF FORTSETZEN"), Rect2(size.x * 0.13, start, size.x * 0.74, 60), true)
			start += 73.0
		_draw_button("new", _tr("NEW MAZE", "NEUES LABYRINTH"), Rect2(size.x * 0.13, start, size.x * 0.74, 60), not saved_run_exists)
		_draw_button("settings", _tr("SETTINGS", "EINSTELLUNGEN"), Rect2(size.x * 0.13, start + 75, size.x * 0.74, 53), false)
		_label(_tr("BEST", "REKORD") + "  %07d" % best, Vector2(0, size.y - 54), 17, Color("839abe"), HORIZONTAL_ALIGNMENT_CENTER, size.x)

func _draw_button(id: String, title: String, rect: Rect2, primary: bool, point_size: int = 18) -> void:
	button_regions[id] = rect
	var fill := Color("264675") if primary else PANEL
	draw_rect(rect, fill)
	draw_rect(rect.grow(-3), Color("1c3256") if primary else Color("142240"))
	draw_rect(rect, CYAN if primary else Color("4e668e"), false, 2.0)
	_label(title, Vector2(rect.position.x + 6, rect.position.y + rect.size.y * 0.5 + point_size * 0.37), point_size, Color.WHITE if primary else Color("c9d8f2"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12)

func _overlay(size: Vector2) -> Rect2:
	draw_rect(Rect2(Vector2.ZERO, size), Color("030713", 0.84))
	var rect := Rect2(size.x * 0.08, size.y * 0.27, size.x * 0.84, size.y * 0.47)
	draw_rect(rect, PANEL)
	draw_rect(rect, CYAN, false, 2.0)
	return rect

func _draw_pause(size: Vector2) -> void:
	var panel := _overlay(size)
	_label(_tr("PAUSED", "PAUSE"), Vector2(0, panel.position.y + 67), 33, GOLD, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_label(_tr("Your maze is saved", "Dein Labyrinth ist gespeichert"), Vector2(0, panel.position.y + 107), 16, Color("a8c3df"), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	var bx := panel.position.x + 28
	var bw := panel.size.x - 56
	_draw_button("resume", _tr("CONTINUE", "WEITER"), Rect2(bx, panel.position.y + 147, bw, 57), true)
	_draw_button("menu", _tr("SAVE & MENU", "SPEICHERN & MENÜ"), Rect2(bx, panel.position.y + 217, bw, 54), false)
	_draw_button("abandon", _tr("ABANDON RUN", "LAUF AUFGEBEN"), Rect2(bx, panel.position.y + 285, bw, 54), false)

func _draw_result(size: Vector2) -> void:
	var panel := _overlay(size)
	var won := screen == Screen.CLEAR
	_label(_tr("MAZE CLEARED", "LABYRINTH GESCHAFFT") if won else _tr("GAME OVER", "SPIEL VORBEI"), Vector2(0, panel.position.y + 75), 29, CYAN if won else CORAL, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_label(_tr("FINAL SCORE", "ENDPUNKTE"), Vector2(0, panel.position.y + 126), 16, Color("9eb8d6"), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_label("%07d" % score, Vector2(0, panel.position.y + 175), 37, GOLD, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_label(_tr("FIRST FLOOR COMPLETE", "ERSTE ETAGE GESCHAFFT") if won else _tr("THE GHOSTS CAUGHT YOU", "DIE GEISTER HABEN DICH ERWISCHT"), Vector2(0, panel.position.y + 216), 15, Color("b7c7e3"), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	var bx := panel.position.x + 28
	var bw := panel.size.x - 56
	_draw_button("new", _tr("TRY AGAIN", "NOCHMAL"), Rect2(bx, panel.position.y + 247, bw, 55), true)
	_draw_button("menu", _tr("MAIN MENU", "HAUPTMENÜ"), Rect2(bx, panel.position.y + 314, bw, 55), false)

func _draw_settings(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("030713", 0.95))
	_label(_tr("SETTINGS", "EINSTELLUNGEN"), Vector2(0, 100), 35, CYAN, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	var y := 148.0
	_settings_step(_tr("MUSIC", "MUSIK"), "music", music_level, size, y)
	y += 92
	_settings_step(_tr("EFFECTS", "EFFEKTE"), "effects", effects_level, size, y)
	y += 92
	_settings_step(_tr("HAPTICS", "VIBRATION"), "haptics", haptics_level, size, y)
	y += 96
	_draw_button("language", _tr("LANGUAGE: ENGLISH", "SPRACHE: DEUTSCH"), Rect2(45, y, size.x - 90, 51), false)
	y += 66
	_draw_button("fps", _tr("FRAME RATE", "BILDRATE") + ": %d" % fps_mode, Rect2(45, y, size.x - 90, 51), false)
	y += 66
	var battery_text := _tr("BALANCED", "AUSGEWOGEN") if battery_mode == "balanced" else (_tr("EFFICIENT", "SPARSAM") if battery_mode == "efficiency" else _tr("PERFORMANCE", "LEISTUNG"))
	_draw_button("battery", _tr("MODE", "MODUS") + ": " + battery_text, Rect2(45, y, size.x - 90, 51), false)
	y += 66
	_draw_button("effects", _tr("REDUCED FLASH: ", "WENIGER BLITZE: ") + (_tr("ON", "AN") if reduced_effects else _tr("OFF", "AUS")), Rect2(45, y, size.x - 90, 51), false)
	_draw_button("menu", _tr("BACK", "ZURÜCK"), Rect2(45, size.y - 91, size.x - 90, 53), true)

func _settings_step(title: String, id: String, value: float, size: Vector2, y: float) -> void:
	_label(title + "  %d%%" % int(value * 100), Vector2(45, y), 17, Color("bad0e9"))
	_draw_button(id + "_less", "−", Rect2(45, y + 15, 65, 46), false, 24)
	var bar := Rect2(123, y + 32, size.x - 246, 12)
	draw_rect(bar, Color("294064"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * value, bar.size.y)), CYAN)
	_draw_button(id + "_more", "+", Rect2(size.x - 110, y + 15, 65, 46), false, 24)
