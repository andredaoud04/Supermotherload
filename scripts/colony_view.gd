extends RefCounted
## Small cutaway interiors, drawn only by the colony HUD. No simulation state lives here.
const RIG = preload("res://assets/actors/starter-rig-v1.png")

static func box(c: CanvasItem, x: float, y: float, w: float, h: float, color: String) -> void:
	c.draw_rect(Rect2(x, y, w, h), Color(color))

static func resident(c: CanvasItem, x: float, y: float, coat: String, phase: float) -> void:
	var reach := sin(phase) * 2
	box(c, x - 4, y - 18, 8, 12, coat)
	box(c, x - 3, y - 25, 6, 7, "d4af89")
	box(c, x - 4, y - 26, 8, 3, "44332d")
	c.draw_line(Vector2(x - 2, y - 6), Vector2(x - 3, y), Color("354957"), 3)
	c.draw_line(Vector2(x + 2, y - 6), Vector2(x + 4, y), Color("354957"), 3)
	c.draw_line(Vector2(x + 3, y - 16), Vector2(x + 9, y - 12 + reach), Color(coat), 3)
	box(c, x - 5, y, 5, 2, "182831")
	box(c, x + 2, y, 6, 2, "182831")

static func draw_room(c: CanvasItem, rect: Rect2, kind: int, built: bool, time: float, level: int) -> void:
	c.draw_set_transform(rect.position, 0, rect.size / Vector2(360, 64))
	box(c, 0, 0, 360, 64, "17252c" if built else "101d25")
	for x in range(0, 361, 60):
		box(c, x, 0, 2, 59, "344249" if built else "253640")
	box(c, 0, 59, 360, 5, "65716c" if built else "2a3c45")
	box(c, 0, 3, 360, 3, "454d47" if built else "273740")
	if not built:
		for x in [16, 136, 256]:
			c.draw_line(Vector2(x, 8), Vector2(x + 85, 57), Color("30454d"), 3)
			c.draw_line(Vector2(x, 57), Vector2(x + 85, 8), Color("30454d"), 3)
		box(c, 156, 33, 45, 25, "293f49")
		c.draw_rect(Rect2(161, 37, 35, 16), Color("64858b"), false, 1)
		box(c, 30, 48, 44, 10, "394445")
		box(c, 33, 45, 38, 3, "62706a")
		c.draw_set_transform(Vector2.ZERO)
		return
	for lamp in [65, 205, 325]:
		c.draw_colored_polygon(PackedVector2Array([Vector2(lamp - 10, 8), Vector2(lamp + 10, 8), Vector2(lamp + 39, 59), Vector2(lamp - 39, 59)]), Color(1, 0.76, 0.38, 0.07))
		box(c, lamp - 13, 6, 26, 4, "d6b77a")
		box(c, lamp - 10, 10, 20, 2, "ffdda0")
	match kind:
		0:
			# Service crane, real starter rig, tool cabinet, and installed drill-tier lights.
			box(c, 15, 15, 190, 5, "bd8c4c")
			box(c, 21, 20, 4, 38, "7f7961")
			var trolley := 70.0 + sin(time * 0.4) * 22
			box(c, trolley, 12, 16, 9, "d4a058")
			box(c, trolley + 7, 21, 2, 12, "99a29a")
			c.draw_arc(Vector2(trolley + 9, 34), 4, 0, PI, 8, Color("c4c4a3"), 2)
			c.draw_texture_rect_region(RIG, Rect2(65, 24, 64, 33), Rect2(136, 143, 1370, 711))
			box(c, 63, 57, 70, 2, "b8a47c")
			box(c, 238, 28, 36, 30, "675846")
			for row in 3:
				box(c, 241, 32 + row * 8, 30, 5, "9a7350")
				box(c, 251, 33 + row * 8, 9, 1, "dbc19a")
			for tier in 3:
				box(c, 289 + tier * 13, 25, 8, 9, "e1bc69" if tier < level else "3e4d4d")
			resident(c, 185, 57, "ce9c54", time * 2)
		1:
			box(c, 25, 20, 140, 26, "414d4e")
			for gun in 5:
				var x := 39 + gun * 25
				box(c, x, 24, 3, 19, "afb3a2")
				box(c, x - 5, 32, 8, 4, "685647")
			box(c, 19, 46, 165, 5, "9b815c")
			box(c, 28, 51, 5, 8, "4f5b58")
			box(c, 169, 51, 5, 8, "4f5b58")
			for i in 3:
				box(c, 251 + i * 21, 43, 18, 15, "6d7451")
				box(c, 257 + i * 21, 46, 6, 8, "c3ac67")
			c.draw_circle(Vector2(318, 25), 12, Color("35454a"))
			for blade in 3:
				var direction := Vector2.from_angle(time * 1.2 + blade * TAU / 3)
				c.draw_line(Vector2(318, 25), Vector2(318, 25) + direction * 9, Color("7d8d86"), 3)
			resident(c, 204, 57, "86a7a1", time * 2.5)
		2:
			for bunk in 2:
				var y := 26 + bunk * 23
				box(c, 24, y, 78, 7, "b49b72")
				box(c, 29, y - 4, 65, 4, "758d88")
				box(c, 30, y - 5, 16, 5, "ded4b7")
			box(c, 21, 19, 3, 39, "776851")
			box(c, 102, 19, 3, 39, "776851")
			box(c, 144, 42, 64, 4, "b18d5b")
			box(c, 152, 46, 4, 13, "756449")
			box(c, 197, 46, 4, 13, "756449")
			box(c, 160, 38, 4, 4, "e4dac0")
			box(c, 184, 38, 4, 4, "e4dac0")
			box(c, 284, 39, 14, 19, "b08657")
			c.draw_line(Vector2(291, 42), Vector2(291, 22), Color("749362"), 2)
			for leaf in 3:
				c.draw_line(Vector2(291, 36 - leaf * 5), Vector2(280 + leaf % 2 * 20, 26 - leaf * 4), Color("95b17a"), 4)
			resident(c, 130, 57, "a56550", time)
			resident(c, 222, 57, "8d9d88", time + 2)
		3:
			box(c, 20, 18, 99, 25, "527078")
			box(c, 24, 21, 91, 19, "153640")
			for point in 15:
				box(c, 29 + point * 5, 28 + sin(point * 0.7 + time) * 4, 3, 2, "89c8b8")
			box(c, 16, 44, 111, 5, "9aafa4")
			box(c, 23, 49, 5, 10, "52676c")
			box(c, 116, 49, 5, 10, "52676c")
			box(c, 190, 23, 30, 34, "38525e")
			box(c, 194, 27, 22, 24, "203f4c")
			var core := Vector2(205, 39 + sin(time) * 2)
			c.draw_colored_polygon(PackedVector2Array([core + Vector2(0, -8), core + Vector2(5, 0), core + Vector2(0, 8), core + Vector2(-5, 0)]), Color("c4a0e7"))
			box(c, 187, 54, 36, 4, "829aa3")
			box(c, 277, 26, 42, 32, "526b6e")
			for row in 4:
				box(c, 281, 30 + row * 6, 23, 2, "253b47")
				box(c, 310, 30 + row * 6, 3, 2, "8bb9ad")
			resident(c, 148, 57, "b7c5b9", time * 1.4)
	c.draw_set_transform(Vector2.ZERO)
