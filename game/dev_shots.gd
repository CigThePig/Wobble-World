extends Node
# Developer aid: --shots=x:y:flags;x:y... teleports Bloop and saves real renderer frames.
# Flags: r roll, d ring the bell and wait for the results card, b seed fake records, p pause,
# f close-up film strip (with w/a walk, j jump, k kick, t tuck).
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
		if parts.size() > 2 and parts[2].contains("b"):
			# Pretend an earlier run exists, so the results card shows its record notes.
			world.save.set_value("best", "seeds", 60)
			world.save.set_value("best", "snoozles", 2)
			world.save.set_value("best", "time", 12.0)
		if parts.size() > 2 and parts[2].contains("d"):
			world.ring_bell()
		var flags := parts[2] if parts.size() > 2 else ""
		if flags.contains("f"):
			# Film strip: settle, then act (w walk right, a walk left, j jump, k kick, t tuck)
			# while saving a frame every third tick, for checking animation up close.
			for i in 40:
				await get_tree().physics_frame
			var c: Control = world.controls
			if flags.contains("w") or flags.contains("a"):
				c.move_id = 99
				c.owners[99] = "move"
				c.analog = -1.0 if flags.contains("a") else 1.0
			for i in 20:
				if i == 3 and flags.contains("j"):
					c.jump_pending = true
					c.jump_held = true
				if i == 3 and flags.contains("k"):
					c.action_pending = true
				if i == 3 and flags.contains("t"):
					c.roll_pending = true
				for k in 3:
					await get_tree().physics_frame
				await RenderingServer.frame_post_draw
				var view := get_viewport().get_texture().get_image()
				var at: Vector2 = world.bloop.get_global_transform_with_canvas().origin * (Vector2(view.get_size()) / world.get_viewport_rect().size)
				var half := int(view.get_width() * 0.085)
				var box := Rect2i(int(at.x) - half, int(at.y) - half - half / 3, half * 2, half * 2).intersection(Rect2i(Vector2i.ZERO, view.get_size()))
				view.get_region(box).save_png("build/shots/%02d-%02d.png" % [index, i])
			c.cancel()
			index += 1
			continue
		var ticks := 470 if flags.contains("d") else 50
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
