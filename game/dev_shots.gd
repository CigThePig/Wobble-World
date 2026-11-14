extends Node
# Developer aid: --shots=x:y:mode;x:y... teleports Bloop and saves real renderer frames.
var world: Node
var spec := ""
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("build/shots")
	var index := 0
	for item in spec.split(";"):
		var parts := item.split(":")
		world.teleport(Vector2(float(parts[0]), float(parts[1])))
		world.controls.started = parts.size() > 2
		if parts.size() > 2 and parts[2].contains("r"):
			world.bloop.set_rolling(true)
		if parts.size() > 2 and parts[2].contains("d"):
			world.ring_bell()
		var ticks := 400 if parts.size() > 2 and parts[2].contains("d") else 50
		for i in ticks:
			await get_tree().physics_frame
		if parts.size() > 2 and parts[2].contains("p"):
			world.controls.set_pause(true)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		print("DRAWS ", item, " ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		get_viewport().get_texture().get_image().save_png("build/shots/%02d.png" % index)
		if "--breakdown" in OS.get_cmdline_user_args():
			var groups := {"terrain": world.grounds, "flora": [world.flora, world.flowers], "seeds": [world.seeds], "backdrop": [world.backdrop], "hud": [world.controls], "bloop": [world.bloop], "tinted": get_tree().get_nodes_in_group("tinted")}
			for key in groups:
				for node in groups[key]:
					node.visible = false
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				print("  without ", key, " ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				for node in groups[key]:
					node.visible = true
		if world.controls.paused:
			world.controls.set_pause(false)
		index += 1
	get_tree().quit()
