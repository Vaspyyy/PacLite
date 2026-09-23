extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene = MainScene.instantiate()
	root.add_child(scene)
	scene._new_run()
	for ghost in scene.ghosts:
		ghost["respawn"] = 0.0
	for i in 12:
		await process_frame
	var image := root.get_texture().get_image()
	var result := image.save_png("res://build/first-floor.png")
	if result != OK:
		push_error("Could not save gameplay screenshot")
		quit(1)
		return
	print("Saved first-floor.png")
	quit(0)
