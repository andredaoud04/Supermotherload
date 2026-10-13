extends Node2D
## All visual decoration is disposable; gameplay never reads pixels or draw state.
var game: Node2D
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font

func _draw() -> void:
	if game == null:
		return
	var viewport := get_viewport_rect().size
	var origin: Vector2 = game.camera_pos - viewport * 0.5
	draw_rect(Rect2(origin - Vector2.ONE * 60, viewport + Vector2.ONE * 120), Color("0a1722"))
	# Far rock silhouettes move at a different rate from the foreground.
	for i in range(-2, 18):
		var x: float = floor(origin.x / 130) * 130 + i * 130
		var y: float = origin.y + 90 + sin(x * 0.031) * 40
		var points := PackedVector2Array([Vector2(x, origin.y - 20), Vector2(x + 150, origin.y - 20),
			Vector2(x + 90, y + 100), Vector2(x + 68, y + 20), Vector2(x + 30, y + 75)])
		draw_colored_polygon(points, Color("102633"))
		for j in 4:
			draw_rect(Rect2(x + j * 29, y + j * 69, 2, 3), Color(0.3, 0.61, 0.65, 0.22))
	_draw_station()
	_draw_facility()
	var first := Vector2i(floori(origin.x / 32) - 1, floori(origin.y / 32) - 1)
	var last := first + Vector2i(ceili(viewport.x / 32) + 3, ceili(viewport.y / 32) + 3)
	for y in range(maxi(0, first.y), mini(MineTerrain.HEIGHT, last.y + 1)):
		for x in range(maxi(0, first.x), mini(MineTerrain.WIDTH, last.x + 1)):
			var cell := Vector2i(x, y)
			var material: int = game.terrain.at(cell)
			if material != MineTerrain.Tile.AIR:
				_draw_tile(cell, material)
	# The permanent shaft receives illuminated rails and depth markers.
	for y in range(10, 52, 3):
		var point := Vector2(238, y * 32)
		if point.y > origin.y - 100 and point.y < origin.y + viewport.y + 100:
			draw_line(point, point + Vector2(0, 86), Color("48515b"), 4)
			draw_rect(Rect2(point + Vector2(-6, 0), Vector2(12, 5)), Color("d5a258"))
			draw_string(font, point + Vector2(10, 20), "%03d" % maxi(0, int((y * 32 - 272) / 4)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("89999b"))
	_draw_rig(game.rig_pos)
	if not game.mounted:
		_draw_miner(game.foot_pos, game.facing)
	for enemy in game.enemies:
		if enemy.pos.distance_to(game.camera_pos) < viewport.length() * 0.65:
			_draw_enemy(enemy)
	for bullet in game.bullets:
		var color := Color("f77c81") if bullet.enemy else Color("ffe5a4")
		draw_line(bullet.pos, bullet.pos - bullet.vel.normalized() * 16, color, 3)
	for particle in game.particles:
		draw_rect(Rect2(particle.pos, Vector2(3, 3)), particle.color)

func _draw_tile(cell: Vector2i, material: int) -> void:
	var p := Vector2(cell * 32)
	var n := absi(cell.x * 73856093 ^ cell.y * 19349663) % 17
	var base := Color("303643") if cell.y < 28 else Color("233943")
	if cell.y > 45:
		base = Color("3d303f")
	if material == MineTerrain.Tile.BEDROCK:
		base = Color("1c2833")
	base = base.lightened(float(n) * 0.006)
	draw_rect(Rect2(p, Vector2(32, 32)), base)
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, 0), p + Vector2(27, 0),
		p + Vector2(17, 9), p + Vector2(4, 15)]), base.lightened(0.035))
	draw_line(p + Vector2(3, 23), p + Vector2(21, 29), base.darkened(0.22), 2)
	if n < 9:
		draw_rect(Rect2(p + Vector2(5 + n, 7), Vector2(5, 3)), base.lightened(0.10))
	if game.terrain.at(cell + Vector2i.UP) == MineTerrain.Tile.AIR:
		draw_rect(Rect2(p, Vector2(32, 4)), Color("6b7175"))
		draw_rect(Rect2(p + Vector2(2, 4), Vector2(28, 2)), base.lightened(0.1))
	if game.terrain.at(cell + Vector2i.LEFT) == MineTerrain.Tile.AIR:
		draw_rect(Rect2(p, Vector2(3, 32)), base.lightened(0.15))
	if game.terrain.at(cell + Vector2i.DOWN) == MineTerrain.Tile.AIR:
		draw_colored_polygon(PackedVector2Array([p + Vector2(3, 29), p + Vector2(15, 29), p + Vector2(9, 40)]), base)
	if material == MineTerrain.Tile.COPPER:
		for i in 3:
			var q := p + Vector2(5 + i * 8, 11 + (i % 2) * 7)
			draw_rect(Rect2(q + Vector2(1, 2), Vector2(8, 8)), Color("714938"))
			draw_rect(Rect2(q, Vector2(7, 6)), Color("d18d4b"))
			draw_rect(Rect2(q, Vector2(5, 2)), Color("ffd38b"))
	elif material == MineTerrain.Tile.CRYSTAL:
		_crystal(p + Vector2(17, 27), 17, Color("5fd8e6"))
		_crystal(p + Vector2(7, 28), 11, Color("87acf7"))
	var id := cell.y * MineTerrain.WIDTH + cell.x
	if game.terrain.damage.has(id):
		var a := p + Vector2(16, 2)
		draw_polyline(PackedVector2Array([a, a + Vector2(-5, 11), a + Vector2(4, 16), a + Vector2(-2, 29)]), Color("e3c694"), 1)

func _crystal(p: Vector2, height: float, color: Color) -> void:
	var points := PackedVector2Array([p, p + Vector2(-height * 0.3, -height * 0.62),
		p + Vector2(-height * 0.05, -height), p + Vector2(height * 0.28, -height * 0.48)])
	draw_colored_polygon(points, color.darkened(0.12))
	draw_line(points[2], p, color.lightened(0.32), 2)

func _draw_station() -> void:
	draw_rect(Rect2(110, 138, 650, 208), Color("17212a"))
	for x in range(128, 760, 96):
		draw_rect(Rect2(x, 142, 8, 200), Color("4b5051"))
		draw_rect(Rect2(x + 8, 165, 76, 120), Color("222f37"))
		draw_rect(Rect2(x + 16, 184, 58, 4), Color("635743"))
		draw_rect(Rect2(x + 12, 145, 34, 4), Color("fbd288"))
	# Freight elevator and warning stripes remain readable behind the rig.
	draw_rect(Rect2(330, 174, 164, 170), Color("333c41"))
	for x in range(338, 492, 17):
		draw_line(Vector2(x, 180), Vector2(x, 330), Color("566060"), 2)
	draw_rect(Rect2(329, 327, 170, 14), Color("bf9245"))
	for x in range(334, 490, 20):
		draw_line(Vector2(x, 330), Vector2(x + 9, 339), Color("343139"), 6)
	draw_string(font, Vector2(356, 207), "COLONY LIFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f3d69e"))
	draw_string(font, Vector2(527, 234), "OUTPOST  /  07", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("c6d3cf"))
	draw_string(font, Vector2(527, 257), "WE BUILD BELOW.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("889b9c"))
	draw_rect(Rect2(566, 291, 46, 48), Color("79654b"))
	draw_rect(Rect2(572, 296, 34, 32), Color("a18154"), false, 3)
	draw_rect(Rect2(620, 307, 42, 32), Color("4f6568"))

func _draw_facility() -> void:
	draw_rect(Rect2(612, 562, 548, 194), Color("17232b"))
	for x in range(618, 1160, 80):
		draw_rect(Rect2(x, 567, 6, 180), Color("4a595c"))
		draw_rect(Rect2(x + 10, 580, 44, 3), Color("a4b8af"))
	draw_string(font, Vector2(672, 610), "PUMPING STATION  /  AUXILIARY POWER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8fa9a5"))
	draw_rect(Rect2(1030, 660, 42, 93), Color("45585b"))
	draw_rect(Rect2(1037, 671, 27, 28), Color("7ccac7"))
	if not game.progress.regulator:
		var p: Vector2 = game.RELIC + Vector2(0, -8 + sin(game.elapsed * 3) * 4)
		draw_circle(p, 19, Color(0.25, 1, 0.9, 0.12))
		draw_rect(Rect2(p - Vector2(9, 11), Vector2(18, 22)), Color("abf7dc"), false, 2)
		draw_line(p + Vector2(0, -6), p + Vector2(0, 6), Color("e3fff1"), 4)
		draw_string(font, p + Vector2(-45, -29), "REGULATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9cebd7"))
	for i in 7:
		_crystal(Vector2(1230 + i * 80, 1214), 45 + (i % 3) * 18, Color("5dcce7"))
	for i in 5:
		var p := Vector2(670 + i * 77, 1694)
		draw_rect(Rect2(p + Vector2(-3, -37), Vector2(6, 37)), Color("6a688c"))
		draw_arc(p + Vector2(0, -32), 24, PI, TAU, 10, Color("bd94e8"), 8)

func _draw_rig(p: Vector2) -> void:
	var bounce: float = sin(game.elapsed * 45) * 0.7 if game.drilling else sin(game.elapsed * 3) * 0.5
	p.y += bounce
	# Chunky tracked chassis with layered armor and a lit cab.
	draw_rect(Rect2(p + Vector2(-45, 7), Vector2(88, 16)), Color("0b131b"))
	for i in 6:
		var wheel := p + Vector2(-34 + i * 13, 15)
		draw_circle(wheel, 7, Color("48525a"))
		draw_circle(wheel, 3, Color("18252d"))
		draw_line(wheel + Vector2(-4, sin(game.elapsed * 10 + i) * 3), wheel + Vector2(4, -sin(game.elapsed * 10 + i) * 3), Color("929795"), 1)
	draw_rect(Rect2(p + Vector2(-41, -21), Vector2(79, 34)), Color("795226"))
	draw_rect(Rect2(p + Vector2(-39, -24), Vector2(74, 28)), Color("d19b48"))
	draw_rect(Rect2(p + Vector2(-35, -20), Vector2(25, 20)), Color("445a62"))
	draw_rect(Rect2(p + Vector2(-31, -18), Vector2(18, 13)), Color("93c8ce"))
	draw_line(p + Vector2(-29, -17), p + Vector2(-20, -7), Color("d4ede0"), 2)
	draw_rect(Rect2(p + Vector2(-5, -22), Vector2(22, 26)), Color("bd8b45"))
	draw_rect(Rect2(p + Vector2(0, -18), Vector2(13, 18)), Color("34434c"))
	for i in 4:
		draw_line(p + Vector2(2, -14 + i * 4), p + Vector2(12, -14 + i * 4), Color("758486"), 1)
	draw_rect(Rect2(p + Vector2(-29, -30), Vector2(48, 6)), Color("444a49"))
	for x in [-24, -11, 2, 15]:
		draw_rect(Rect2(p + Vector2(x, -32), Vector2(7, 5)), Color("ffe7a0"))
	for x in [-35, -8, 23]:
		draw_rect(Rect2(p + Vector2(x, 5), Vector2(3, 3)), Color("efdb9a"))
	draw_string(font, p + Vector2(17, -4), "07", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff1cd"))
	var direction: Vector2 = game.drill_direction
	var mount := p + Vector2(direction.x * 38, direction.y * 18)
	var side := Vector2(-direction.y, direction.x)
	var tip := mount + direction * 31
	draw_colored_polygon(PackedVector2Array([mount + side * 18, tip + side * 3, tip + direction * 5, mount - side * 18]), Color("a2afb4"))
	for i in 5:
		var at := mount + direction * (i * 6)
		var width := 17.0 - i * 2.5
		draw_line(at + side * width, at - side * width + direction * 5, Color("46545f"), 3)
	if game.drilling:
		for i in 4:
			var spark := tip + Vector2(sin(game.elapsed * 80 + i * 4), cos(game.elapsed * 70 + i)) * (8 + i * 3)
			draw_rect(Rect2(spark, Vector2(3, 3)), Color("ffcc72"))
	draw_circle(p + Vector2(31, -14), 3, Color("fff2cf"))

func _draw_miner(p: Vector2, facing: int) -> void:
	var step: float = sin(game.elapsed * 15) * 4 if absf(game.foot_velocity.x) > 1 else 0
	draw_line(p + Vector2(-5, 6), p + Vector2(-6 + step, 17), Color("799299"), 6)
	draw_line(p + Vector2(5, 6), p + Vector2(5 - step, 17), Color("425e6b"), 6)
	draw_rect(Rect2(p + Vector2(-8, -9), Vector2(16, 20)), Color("bc8747"))
	draw_rect(Rect2(p + Vector2(-facing * 12 - 3, -8), Vector2(7, 17)), Color("536c76"))
	draw_rect(Rect2(p + Vector2(-9, -20), Vector2(18, 13)), Color("d8b16a"))
	draw_rect(Rect2(p + Vector2(-6, -16), Vector2(13, 6)), Color("203942"))
	draw_rect(Rect2(p + Vector2(facing * 7 - 2, -18), Vector2(5, 3)), Color("edffd5"))
	draw_line(p + Vector2(0, -1), p + Vector2(facing * 15, 0), Color("d8b16a"), 5)
	draw_rect(Rect2(p + Vector2(4 if facing > 0 else -27, -6), Vector2(25, 6)), Color("9eabad"))
	draw_rect(Rect2(p + Vector2(6 if facing > 0 else -16, 0), Vector2(7, 6)), Color("34434d"))

func _draw_enemy(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.pos
	var color := Color("b8676c") if int(enemy.type) == 0 else Color("9580a8")
	if int(enemy.type) == 2:
		color = Color("956157")
	if float(enemy.flash) > 0:
		color = Color("fff0cc")
	for i in 3:
		var off := sin(game.elapsed * 11 + i * 2) * 3
		for side in [-1, 1]:
			draw_polyline(PackedVector2Array([p + Vector2(side * 6, -4 + i * 3),
				p + Vector2(side * (15 + i * 3), -4 + off), p + Vector2(side * (22 + i * 2), 12)]), color.darkened(0.2), 3)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-15, 2), p + Vector2(-8, -13), p + Vector2(8, -16), p + Vector2(17, 0), p + Vector2(6, 9), p + Vector2(-8, 8)]), color)
	for x in [-6, 1, 8]:
		draw_rect(Rect2(p + Vector2(x, -7), Vector2(3, 4)), Color("ffcb8a") if int(enemy.type) != 1 else Color("9ef2bc"))
	if int(enemy.type) == 2:
		draw_line(p + Vector2(-9, -12), p + Vector2(7, -17), Color("d39a88"), 4)
		if float(enemy.cooldown) < 0.9 and float(enemy.cooldown) > 0.65:
			draw_string(font, p + Vector2(-3, -26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffb080"))
