extends Node2D
## All visual decoration is disposable; gameplay never reads pixels or draw state.
var game: Node2D
var font: Font
var rock_atlas: ImageTexture
var glow: GradientTexture2D
var track_phase := 0.0
var last_rig := Vector2.ZERO
var observed_rig := false
var rig_moving := false
var view := Rect2()

func _ready() -> void:
	font = ThemeDB.fallback_font
	rock_atlas = _make_terrain_atlas()
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.35, Color(1, 1, 1, 0.38))
	glow = GradientTexture2D.new()
	glow.gradient = gradient
	glow.width = 64
	glow.height = 64
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1, 0.5)

func _process(_delta: float) -> void:
	if game == null:
		return
	var displacement: Vector2 = game.rig_pos - last_rig if observed_rig else Vector2.ZERO
	# Only physical travel drives links and rollers, so parked tracks remain still.
	rig_moving = displacement.length_squared() > 0.01 and displacement.length() < 32
	if rig_moving:
		track_phase = fposmod(track_phase + displacement.length() * (1 if displacement.x >= 0 else -1), 12.0)
	last_rig = game.rig_pos
	observed_rig = true

func _make_terrain_atlas() -> ImageTexture:
	# 128 baked tiles: four strata, four materials, eight deterministic variants.
	# This replaces many per-frame geometry commands with one texture region per tile.
	var pixels := Image.create(256, 512, false, Image.FORMAT_RGBA8)
	var palettes := [Color("454044"), Color("343d49"), Color("2c424e"), Color("453342")]
	for biome in 4:
		for material in 4:
			for variant in 8:
				var offset := Vector2i(variant * 32, (biome * 4 + material) * 32)
				var rng := RandomNumberGenerator.new()
				rng.seed = 10000 + biome * 1537 + material * 211 + variant * 79
				var base: Color = palettes[biome] if material != 3 else Color("202a33")
				for y in 32:
					for x in 32:
						var grain := rng.randf_range(-0.045, 0.035) + sin(float(y + variant * 3) * 0.38) * 0.018
						pixels.set_pixelv(offset + Vector2i(x, y), Color(base.r + grain, base.g + grain, base.b + grain))
				for chip in 12:
					var q := offset + Vector2i(rng.randi_range(1, 25), rng.randi_range(1, 27))
					var size := Vector2i(rng.randi_range(2, 5), rng.randi_range(1, 3))
					pixels.fill_rect(Rect2i(q, size), base.lightened(0.04 if chip % 3 else 0.1))
					pixels.fill_rect(Rect2i(q + Vector2i(1, size.y), Vector2i(size.x, 1)), base.darkened(0.32))
				var crack_y := rng.randi_range(6, 22)
				for x in range(3, 29):
					if x % 5 == 0:
						crack_y = clampi(crack_y + rng.randi_range(-1, 2), 3, 29)
					pixels.set_pixelv(offset + Vector2i(x, crack_y), base.darkened(0.48))
				if material == 1:
					for nugget in 5:
						var q := offset + Vector2i(rng.randi_range(3, 24), rng.randi_range(4, 24))
						pixels.fill_rect(Rect2i(q - Vector2i.ONE, Vector2i(8, 7)), Color("322827"))
						pixels.fill_rect(Rect2i(q + Vector2i(-1, 1), Vector2i(7, 4)), Color("955437"))
						pixels.fill_rect(Rect2i(q, Vector2i(6, 4)), Color("c5844b"))
						pixels.fill_rect(Rect2i(q + Vector2i(1, 0), Vector2i(4, 1)), Color("f2c580"))
				elif material == 2:
					for shard in 3:
						var x := 7 + shard * 9
						var height := rng.randi_range(11, 22)
						for y in height:
							var width := mini(4, y + 1) if y < height - 4 else maxi(1, height - y)
							pixels.fill_rect(Rect2i(offset + Vector2i(x - width, 28 - height + y), Vector2i(width * 2, 1)), Color("2a819f"))
							pixels.fill_rect(Rect2i(offset + Vector2i(x, 28 - height + y), Vector2i(width, 1)), Color("66c9e1"))
						pixels.fill_rect(Rect2i(offset + Vector2i(x, 29 - height), Vector2i(1, height - 4)), Color("b3f1ef"))
	return ImageTexture.create_from_image(pixels)

func _halo(p: Vector2, size: Vector2, color: Color) -> void:
	draw_texture_rect(glow, Rect2(p - size * 0.5, size), false, color)

func _draw_backdrop(origin: Vector2, viewport: Vector2) -> void:
	var depth: float = clampf((game.camera_pos.y - 500.0) / 1200.0, 0, 1)
	draw_rect(view, Color("101921").lerp(Color("170f25"), depth))
	# Three different travel rates give genuine depth behind the solid terrain.
	for layer in 3:
		var spacing := 210.0 - layer * 35
		var scroll: Vector2 = game.camera_pos * (0.16 + layer * 0.18)
		var color := Color("243a49").lerp(Color("3c294b"), depth).darkened(0.48 - layer * 0.12)
		for i in range(-1, ceili(viewport.x / spacing) + 3):
			var index := floori(scroll.x / spacing) + i
			var x := origin.x + i * spacing - fposmod(scroll.x, spacing)
			var height := 125.0 + sin(index * 2.37 + layer) * 80.0
			var top := origin.y - 80 - scroll.y * 0.1 + layer * 20
			draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + spacing + 3, top),
				Vector2(x + spacing, top + height * 0.6), Vector2(x + spacing * 0.8, top + height * 0.75),
				Vector2(x + spacing * 0.68, top + height + 80), Vector2(x + spacing * 0.56, top + height * 0.85),
				Vector2(x + spacing * 0.35, top + height), Vector2(x + spacing * 0.2, top + height * 0.5), Vector2(x, top + height * 0.8)]), color)
			var floor_y := origin.y + viewport.y + 130 - layer * 30 - scroll.y * 0.1
			draw_colored_polygon(PackedVector2Array([Vector2(x - 5, floor_y), Vector2(x + spacing, floor_y),
				Vector2(x + spacing, floor_y - 100), Vector2(x + spacing * 0.75, floor_y - height * 0.65),
				Vector2(x + spacing * 0.57, floor_y - height * 0.4), Vector2(x + spacing * 0.3, floor_y - height),
				Vector2(x + spacing * 0.17, floor_y - height * 0.8), Vector2(x, floor_y - 80)]), color)
			if layer == 0 and depth > 0.25:
				_crystal(Vector2(x + 90, floor_y - 80), 55, Color("356079").lerp(Color("674570"), depth))
	_halo(origin + viewport * Vector2(0.72, 0.48), Vector2(500, 420), Color(0.12, 0.36, 0.48, 0.20))
	if depth > 0.3:
		_halo(origin + viewport * Vector2(0.23, 0.72), Vector2(400, 340), Color(0.43, 0.14, 0.5, depth * 0.20))

func _draw() -> void:
	if game == null:
		return
	var viewport := get_viewport_rect().size
	# Actual render transform includes camera shake and keeps edge culling stable.
	var origin := -position
	view = Rect2(origin - Vector2.ONE * 64, viewport + Vector2.ONE * 128)
	_draw_backdrop(origin, viewport)
	if view.intersects(Rect2(96, 96, 704, 260)):
		_draw_station()
	if view.intersects(Rect2(576, 544, 608, 224)):
		_draw_facility()
	_draw_landmarks()
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
	# Fixed atmosphere budget; particles do not shine through foreground rock.
	for i in 28:
		var p := origin + Vector2(fposmod(i * 173.0 - game.camera_pos.x * 0.4 + game.elapsed * (2 + i % 3), viewport.x),
			fposmod(i * 79.0 - game.camera_pos.y * 0.4 - game.elapsed * (3 + i % 4), viewport.y))
		if not game.terrain.solid(p):
			draw_rect(Rect2(p.floor(), Vector2(1 if i % 3 else 2, 1)), Color(0.6, 0.78, 0.83, 0.12 + (sin(game.elapsed * 0.8 + i * 1.7) + 1) * 0.07))
	if view.grow(100).has_point(game.rig_pos):
		_draw_rig(game.rig_pos)
	if not game.mounted:
		_draw_miner(game.foot_pos, game.facing)
	for enemy in game.enemies:
		if enemy.pos.distance_to(game.camera_pos) < viewport.length() * 0.65:
			_draw_enemy(enemy)
	for bullet in game.bullets:
		if not view.has_point(bullet.pos):
			continue
		var color := Color("f77c81") if bullet.enemy else Color("ffe5a4")
		draw_line(bullet.pos, bullet.pos - bullet.vel.normalized() * 22, Color(color, 0.18), 7)
		draw_line(bullet.pos, bullet.pos - bullet.vel.normalized() * 16, color, 2)
	for particle in game.particles:
		draw_rect(Rect2(particle.pos, Vector2(3, 3)), particle.color)

func _draw_tile(cell: Vector2i, material: int) -> void:
	var p := Vector2(cell * 32)
	var n := absi(cell.x * 73856093 ^ cell.y * 19349663)
	var biome := 0 if cell.y < 16 else (1 if cell.y < 29 else (2 if cell.y < 45 else 3))
	var atlas_material := 3 if material == MineTerrain.Tile.BEDROCK else material - 1
	var above: bool = game.terrain.at(cell + Vector2i.UP) == MineTerrain.Tile.AIR
	var below: bool = game.terrain.at(cell + Vector2i.DOWN) == MineTerrain.Tile.AIR
	var left: bool = game.terrain.at(cell + Vector2i.LEFT) == MineTerrain.Tile.AIR
	var right: bool = game.terrain.at(cell + Vector2i.RIGHT) == MineTerrain.Tile.AIR
	var exposed := above or below or left or right
	if material == MineTerrain.Tile.CRYSTAL and exposed:
		_halo(p + Vector2(16, 16), Vector2(65, 65), Color(0.15, 0.65, 0.9, 0.16))
	draw_texture_rect_region(rock_atlas, Rect2(p, Vector2.ONE * 32),
		Rect2((n % 8) * 32, (biome * 4 + atlas_material) * 32, 32, 32), Color.WHITE if exposed else Color("a4a9b2"))
	var rim := Color("8e8376") if biome < 2 else Color("659298")
	if biome == 3:
		rim = Color("8d6a90")
	if above:
		draw_rect(Rect2(p, Vector2(32, 2)), rim)
		draw_rect(Rect2(p + Vector2(3, 2), Vector2(24, 2)), rim.darkened(0.27))
		for i in 3:
			draw_rect(Rect2(p + Vector2(2 + i * 11, -1 - (n + i) % 3), Vector2(5 + (n + i) % 4, 3)), rim.darkened(0.25))
	if left:
		draw_rect(Rect2(p, Vector2(2, 32)), rim.darkened(0.23))
	if right:
		draw_rect(Rect2(p + Vector2(30, 0), Vector2(2, 32)), Color("111c27"))
	if below:
		draw_rect(Rect2(p + Vector2(0, 29), Vector2(32, 3)), Color("111b25"))
		if n % 3 == 0:
			draw_colored_polygon(PackedVector2Array([p + Vector2(5, 29), p + Vector2(18, 29), p + Vector2(12, 39 + n % 9)]), Color("2b303d"))
	var id := cell.y * MineTerrain.WIDTH + cell.x
	if game.terrain.damage.has(id):
		var fraction := clampf(float(game.terrain.damage[id]) / (0.26 if material == MineTerrain.Tile.ROCK else 0.48), 0, 1)
		var crack := Color("ffe1ac").lerp(Color("fff6dd"), fraction)
		draw_polyline(PackedVector2Array([p + Vector2(16, 1), p + Vector2(10, 10), p + Vector2(18, 17), p + Vector2(13, 31)]), Color(crack, fraction * 0.8), 1)
		draw_line(p + Vector2(18, 17), p + Vector2(29, 10), Color(crack, fraction * 0.6), 1)
		draw_line(p + Vector2(10, 10), p + Vector2(1, 15), Color(crack, fraction * 0.6), 1)

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
		_halo(Vector2(x + 29, 148), Vector2(90, 90), Color(0.9, 0.58, 0.25, 0.17))
		draw_line(Vector2(x + 12, 277), Vector2(x + 78, 171), Color("39474d"), 3)
		draw_rect(Rect2(x + 2, 143, 2, 195), Color("77776b"))
		for y in [173, 248, 319]:
			draw_rect(Rect2(x - 2, y, 12, 8), Color("333d44"))
			draw_rect(Rect2(x, y + 2, 2, 2), Color("a6a791"))
		for vent in 5:
			draw_rect(Rect2(x + 18, 287 + vent * 4, 45, 2), Color("101c26"))
	draw_rect(Rect2(111, 151, 646, 9), Color("111c26"))
	draw_rect(Rect2(111, 153, 646, 3), Color("6f7263"))
	draw_line(Vector2(118, 182), Vector2(118, 316), Color("b68b4d"), 5)
	draw_line(Vector2(118, 182), Vector2(310, 182), Color("b68b4d"), 5)
	for x in [270, 532, 746]:
		for y in range(155, 197, 6):
			draw_rect(Rect2(x, y, 2, 4), Color("77766a"))
		draw_rect(Rect2(x - 5, 194, 12, 8), Color("303c43"))
	# Freight elevator and warning stripes remain readable behind the rig.
	draw_rect(Rect2(330, 174, 164, 170), Color("333c41"))
	for x in range(338, 492, 17):
		draw_line(Vector2(x, 180), Vector2(x, 330), Color("566060"), 2)
	draw_rect(Rect2(329, 327, 170, 14), Color("bf9245"))
	for x in range(334, 490, 20):
		draw_line(Vector2(x, 330), Vector2(x + 9, 339), Color("343139"), 6)
	_halo(Vector2(415, 310), Vector2(220, 100), Color(0.9, 0.62, 0.24, 0.16))
	draw_rect(Rect2(330, 176, 164, 31), Color("192731"))
	for x in [324, 499]:
		draw_rect(Rect2(x, 173, 5, 167), Color("c49451"))
		for y in range(187, 333, 23):
			draw_rect(Rect2(x, y, 5, 9), Color("33322c"))
	draw_rect(Rect2(509, 252, 13, 28), Color("15222b"))
	draw_rect(Rect2(512, 255, 7, 11), Color("78bdb9"))
	draw_rect(Rect2(514, 272, 3, 3), Color("f5bc72"))
	draw_string(font, Vector2(356, 207), "COLONY LIFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f3d69e"))
	draw_string(font, Vector2(527, 234), "OUTPOST  /  07", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("c6d3cf"))
	draw_string(font, Vector2(527, 257), "WE BUILD BELOW.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("889b9c"))
	draw_rect(Rect2(566, 291, 46, 48), Color("79654b"))
	draw_rect(Rect2(572, 296, 34, 32), Color("a18154"), false, 3)
	draw_rect(Rect2(620, 307, 42, 32), Color("4f6568"))
	draw_line(Vector2(624, 311), Vector2(657, 334), Color("78918b"), 3)
	draw_rect(Rect2(638, 307, 6, 32), Color("354c57"))
	for x in [150, 176]:
		draw_rect(Rect2(x, 276, 18, 62), Color("465b63"))
		draw_rect(Rect2(x + 3, 280, 4, 53), Color("778b89"))
		draw_rect(Rect2(x + 6, 270, 6, 7), Color("af8d56"))
		draw_rect(Rect2(x - 1, 291, 20, 4), Color("26363f"))
		draw_rect(Rect2(x - 1, 321, 20, 4), Color("26363f"))
	draw_rect(Rect2(112, 339, 646, 10), Color("242a31"))
	draw_line(Vector2(112, 339), Vector2(758, 339), Color("a09174"), 2)

func _draw_facility() -> void:
	draw_rect(Rect2(612, 562, 548, 194), Color("17232b"))
	for x in range(618, 1160, 80):
		draw_rect(Rect2(x, 567, 6, 180), Color("4a595c"))
		draw_rect(Rect2(x + 10, 580, 44, 3), Color("a4b8af"))
		_halo(Vector2(x + 32, 582), Vector2(80, 80), Color(0.4, 0.8, 0.65, 0.13))
		draw_line(Vector2(x + 10, 735), Vector2(x + 68, 586), Color("2c424a"), 3)
	for x in [663, 712, 761]:
		draw_rect(Rect2(x, 651, 33, 96), Color("3b565d"))
		draw_rect(Rect2(x + 3, 655, 6, 87), Color("64817d"))
		draw_rect(Rect2(x - 3, 670, 39, 7), Color("253b45"))
		draw_rect(Rect2(x - 3, 727, 39, 7), Color("253b45"))
		draw_line(Vector2(x + 16, 653), Vector2(x + 16, 636), Color("5b7c7d"), 7)
	draw_line(Vector2(679, 636), Vector2(1085, 636), Color("526e73"), 8)
	draw_line(Vector2(679, 634), Vector2(1085, 634), Color("83a49c"), 2)
	draw_rect(Rect2(1074, 636, 11, 111), Color("40595f"))
	draw_string(font, Vector2(672, 610), "PUMPING STATION  /  AUXILIARY POWER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8fa9a5"))
	draw_rect(Rect2(1030, 660, 42, 93), Color("45585b"))
	draw_rect(Rect2(1037, 671, 27, 28), Color("7ccac7"))
	if not game.progress.regulator:
		var p: Vector2 = game.RELIC + Vector2(0, -8 + sin(game.elapsed * 3) * 4)
		draw_circle(p, 19, Color(0.25, 1, 0.9, 0.12))
		draw_rect(Rect2(p - Vector2(9, 11), Vector2(18, 22)), Color("abf7dc"), false, 2)
		draw_line(p + Vector2(0, -6), p + Vector2(0, 6), Color("e3fff1"), 4)
		draw_string(font, p + Vector2(-45, -29), "REGULATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9cebd7"))
		_halo(p, Vector2(85, 85), Color(0.3, 1, 0.8, 0.22))

func _draw_landmarks() -> void:
	for i in 7:
		var p := Vector2(1230 + i * 80, 1214)
		if not view.grow(100).has_point(p):
			continue
		var height := 45.0 + (i % 3) * 18
		_halo(p + Vector2(0, -height * 0.4), Vector2.ONE * height * 2, Color(0.15, 0.5, 0.7, 0.15))
		_crystal(p + Vector2(-12, 0), height * 0.65, Color("396c9a"))
		_crystal(p, height, Color("5dcce7"))
		_crystal(p + Vector2(14, 2), height * 0.49, Color("7281be"))
	for i in 5:
		var p := Vector2(670 + i * 77, 1694)
		if not view.grow(80).has_point(p):
			continue
		_halo(p + Vector2(0, -40), Vector2(110, 100), Color(0.48, 0.24, 0.72, 0.15))
		draw_rect(Rect2(p + Vector2(-3, -37), Vector2(6, 37)), Color("6a688c"))
		draw_colored_polygon(PackedVector2Array([p + Vector2(-28, -36), p + Vector2(-19, -48),
			p + Vector2(-4, -54), p + Vector2(16, -46), p + Vector2(27, -36), p + Vector2(8, -32), p + Vector2(-9, -32)]), Color("68508f"))
		draw_polyline(PackedVector2Array([p + Vector2(-28, -36), p + Vector2(-9, -32),
			p + Vector2(8, -32), p + Vector2(27, -36)]), Color("b084cf"), 2)
		for j in 5:
			draw_line(p + Vector2(-3, -35), p + Vector2(-20 + j * 10, -40), Color("9273ba"), 1)

func _draw_rig(p: Vector2) -> void:
	var bounce: float = sin(game.elapsed * 45) * 0.7 if game.drilling else 0.0
	if rig_moving:
		bounce += sin(track_phase * 0.52) * 0.35
	p.y += bounce
	_shadow(p + Vector2(0, 23), Vector2(100, 13))
	# Chunky tracked chassis with layered armor and a lit cab.
	draw_rect(Rect2(p + Vector2(-45, 7), Vector2(88, 16)), Color("0b131b"))
	for i in 6:
		var wheel := p + Vector2(-34 + i * 13, 15)
		draw_circle(wheel, 7, Color("48525a"))
		draw_circle(wheel, 3, Color("18252d"))
		var spoke := Vector2.from_angle(track_phase * 0.55 + i) * 4
		draw_line(wheel - spoke, wheel + spoke, Color("929795"), 1)
	for i in 8:
		var x := -44.0 + fposmod(i * 12.0 + track_phase, 88.0)
		draw_rect(Rect2(p + Vector2(x, 7), Vector2(6, 3)), Color("818780"))
		draw_rect(Rect2(p + Vector2(-x - 4, 21), Vector2(6, 3)), Color("545f63"))
	draw_rect(Rect2(p + Vector2(-41, -21), Vector2(79, 34)), Color("795226"))
	draw_rect(Rect2(p + Vector2(-39, -24), Vector2(74, 28)), Color("d19b48"))
	draw_rect(Rect2(p + Vector2(-38, -24), Vector2(72, 3)), Color("e7be78"))
	draw_rect(Rect2(p + Vector2(-40, 2), Vector2(78, 5)), Color("37454c"))
	draw_rect(Rect2(p + Vector2(-35, -20), Vector2(25, 20)), Color("445a62"))
	draw_rect(Rect2(p + Vector2(-31, -18), Vector2(18, 13)), Color("93c8ce"))
	draw_rect(Rect2(p + Vector2(-31, -18), Vector2(18, 3)), Color("c5e8d9"))
	draw_rect(Rect2(p + Vector2(-23, -19), Vector2(2, 17)), Color("c39655"))
	draw_line(p + Vector2(-29, -17), p + Vector2(-20, -7), Color("d4ede0"), 2)
	if game.mounted:
		draw_rect(Rect2(p + Vector2(-19, -12), Vector2(4, 5)), Color("29414b"))
		draw_rect(Rect2(p + Vector2(-20, -13), Vector2(6, 2)), Color("e0b577"))
	draw_rect(Rect2(p + Vector2(-5, -22), Vector2(22, 26)), Color("bd8b45"))
	draw_rect(Rect2(p + Vector2(0, -18), Vector2(13, 18)), Color("34434c"))
	for i in 4:
		draw_line(p + Vector2(2, -14 + i * 4), p + Vector2(12, -14 + i * 4), Color("758486"), 1)
	draw_rect(Rect2(p + Vector2(-29, -30), Vector2(48, 6)), Color("444a49"))
	for x in [-24, -11, 2, 15]:
		draw_rect(Rect2(p + Vector2(x - 1, -33), Vector2(9, 7)), Color("67706a"))
		draw_rect(Rect2(p + Vector2(x, -32), Vector2(7, 5)), Color("ffe7a0"))
	draw_rect(Rect2(p + Vector2(29, -35), Vector2(4, 13)), Color("3d4c52"))
	draw_rect(Rect2(p + Vector2(28, -36), Vector2(6, 3)), Color("80918d"))
	draw_line(p + Vector2(-23, -29), p + Vector2(-25, -43), Color("829699"), 1)
	draw_rect(Rect2(p + Vector2(-26, -44), Vector2(3, 2)), Color("c57750"))
	for x in [-35, -8, 23]:
		draw_rect(Rect2(p + Vector2(x, 5), Vector2(3, 3)), Color("efdb9a"))
		draw_rect(Rect2(p + Vector2(x, -22), Vector2(2, 2)), Color("efdb9a"))
	draw_string(font, p + Vector2(17, -4), "07", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff1cd"))
	var direction: Vector2 = game.drill_direction
	var mount := p + Vector2(direction.x * 38, direction.y * 18)
	var side := Vector2(-direction.y, direction.x)
	var tip := mount + direction * 31
	draw_line(mount - direction * 5, mount + direction * 3, Color("2b3c48"), 26)
	draw_line(mount - side * 14, mount + side * 14, Color("bea36f"), 4)
	draw_colored_polygon(PackedVector2Array([mount + side * 18, tip + side * 3, tip + direction * 5, mount - side * 18]), Color("a2afb4"))
	draw_colored_polygon(PackedVector2Array([mount, mount + side * 18, tip + side * 3, tip + direction * 5]), Color("c4d0cb"))
	var spin: float = fposmod(game.elapsed * 36, 6) if game.drilling else 0.0
	for i in 5:
		var advance := fposmod(i * 6.0 + spin, 30.0)
		var at := mount + direction * advance
		var width := 17.0 - advance * 0.45
		draw_line(at + side * width, at - side * width + direction * 5, Color("46545f"), 3)
	if game.drilling:
		_halo(tip, Vector2(70, 70), Color(1, 0.57, 0.12, 0.28))
		for i in 7:
			var age: float = fposmod(game.elapsed * 5 + i * 0.143, 1.0)
			var scatter := side * sin(i * 3.71) - direction * 0.5
			var spark := tip + scatter * age * (15 + i * 4)
			draw_line(spark, spark - scatter * 4, Color(1, 0.7 + i % 2 * 0.2, 0.35, 1 - age), 2)
	draw_circle(p + Vector2(31, -14), 3, Color("fff2cf"))
	if rig_moving and game.rig_velocity.y < -10:
		for x in [-26, 23]:
			var q := p + Vector2(x, 24)
			_halo(q, Vector2(28, 38), Color(0.25, 0.66, 0.9, 0.25))
			draw_colored_polygon(PackedVector2Array([q + Vector2(-4, 0), q + Vector2(4, 0),
				q + Vector2(0, 9 + sin(game.elapsed * 47 + x) * 3)]), Color("83d7e4"))

func _shadow(p: Vector2, size: Vector2) -> void:
	draw_set_transform(p, 0, size * 0.5)
	draw_circle(Vector2.ZERO, 1, Color(0.015, 0.025, 0.035, 0.45))
	draw_set_transform(Vector2.ZERO)

func _draw_miner(p: Vector2, facing: int) -> void:
	var step: float = sin(game.elapsed * 15) * 4 if absf(game.foot_velocity.x) > 1 else 0
	_shadow(p + Vector2(0, 19), Vector2(30, 7))
	draw_line(p + Vector2(-5, 6), p + Vector2(-6 + step, 17), Color("799299"), 6)
	draw_line(p + Vector2(5, 6), p + Vector2(5 - step, 17), Color("425e6b"), 6)
	draw_rect(Rect2(p + Vector2(-8, -9), Vector2(16, 20)), Color("bc8747"))
	draw_rect(Rect2(p + Vector2(-5, -6), Vector2(10, 12)), Color("566975"))
	draw_rect(Rect2(p + Vector2(-8, 7), Vector2(16, 3)), Color("2a414b"))
	draw_rect(Rect2(p + Vector2(2, -5), Vector2(2, 4)), Color("a4d8c8"))
	draw_rect(Rect2(p + Vector2(-facing * 12 - 3, -8), Vector2(7, 17)), Color("536c76"))
	draw_rect(Rect2(p + Vector2(-9, -20), Vector2(18, 13)), Color("d8b16a"))
	draw_rect(Rect2(p + Vector2(-8, -22), Vector2(14, 3)), Color("edd39a"))
	draw_rect(Rect2(p + Vector2(-6, -16), Vector2(13, 6)), Color("203942"))
	draw_rect(Rect2(p + Vector2(-4, -16), Vector2(9, 2)), Color("8bb9bc"))
	draw_rect(Rect2(p + Vector2(facing * 7 - 2, -18), Vector2(5, 3)), Color("edffd5"))
	var aim: Vector2 = game.weapon_direction
	if aim.length_squared() < 0.01:
		aim = Vector2(facing, 0)
	var side := Vector2(-aim.y, aim.x)
	var shoulder := p + Vector2(0, -6)
	var grip := shoulder + aim * 10 + side * 3
	draw_line(shoulder, grip, Color("d8ae6d"), 5)
	draw_line(grip - aim * 2, grip + aim * 12, Color("192d39"), 7)
	draw_line(grip - aim * 2 - side * 2, grip + aim * 10 - side * 2, Color("9aadaf"), 3)
	draw_line(grip + aim * 11, grip + aim * 19, Color("506e7a"), 3)
	draw_line(grip + aim * 3, grip + aim * 2 + side * 7, Color("263f4d"), 4)
	if game.muzzle_flash > 0:
		var muzzle := grip + aim * 21
		_halo(muzzle, Vector2(70, 70), Color(1, 0.65, 0.24, 0.32))
		draw_colored_polygon(PackedVector2Array([muzzle - side * 3, muzzle + aim * 9 - side * 5,
			muzzle + aim * 18, muzzle + aim * 7 + side * 5, muzzle + side * 3]), Color("ffda86"))
		draw_line(muzzle, muzzle + aim * 10, Color("fff8d9"), 3)
	if game.foot_velocity.y < -30:
		var jet_p := p + Vector2(-facing * 10, 10)
		_halo(jet_p, Vector2(30, 42), Color(0.3, 0.7, 0.9, 0.25))
		draw_line(jet_p, jet_p + Vector2(0, 6 + sin(game.elapsed * 45) * 3), Color("9ae8eb"), 3)

func _draw_enemy(enemy: Dictionary) -> void:
	var p: Vector2 = enemy.pos
	_shadow(p + Vector2(0, 13), Vector2(48, 9))
	var facing := -1 if (game.rig_pos.x if game.mounted else game.foot_pos.x) < p.x else 1
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
	if int(enemy.type) == 1:
		# Rounded venom sacs and a proboscis distinguish the ranged enemy immediately.
		draw_colored_polygon(PackedVector2Array([p + Vector2(-18, 2), p + Vector2(-15, -12),
			p + Vector2(-6, -20), p + Vector2(7, -19), p + Vector2(17, -10), p + Vector2(17, 4), p + Vector2(2, 9)]), color.darkened(0.25))
		for i in 3:
			var sac := p + Vector2(-9 + i * 8, -8 - (i % 2) * 5)
			draw_circle(sac, 5, Color("65926c") if float(enemy.flash) <= 0 else color)
			draw_circle(sac + Vector2(-1, -2), 2, Color("b2d492"))
		draw_line(p + Vector2(facing * 10, -5), p + Vector2(facing * 23, -2), color, 7)
		draw_circle(p + Vector2(facing * 23, -2), 3, Color("d1ef9c"))
	else:
		draw_colored_polygon(PackedVector2Array([p + Vector2(-15, 2), p + Vector2(-8, -13), p + Vector2(8, -16), p + Vector2(17, 0), p + Vector2(6, 9), p + Vector2(-8, 8)]), color)
		for i in 3:
			var q := p + Vector2(-10 + i * 8, -9 + absi(i - 1) * 3)
			draw_polyline(PackedVector2Array([q + Vector2(-3, 8), q, q + Vector2(3, -2), q + Vector2(5, 7)]), color.lightened(0.2), 2)
			if int(enemy.type) == 2:
				draw_colored_polygon(PackedVector2Array([q + Vector2(-3, 1), q + Vector2(0, -12), q + Vector2(5, 2)]), Color("bc8875"))
		var head := p + Vector2(facing * 13, 2)
		draw_colored_polygon(PackedVector2Array([head + Vector2(facing * -7, -6), head + Vector2(facing * 6, -5),
			head + Vector2(facing * 10, 3), head + Vector2(facing * 2, 8), head + Vector2(facing * -6, 4)]), color.darkened(0.26))
		for i in 3:
			var tooth := head + Vector2(-3 + i * 4, 2)
			draw_line(tooth, tooth + Vector2(facing * 2, 4), Color("d7c6ad"), 1)
	for x in [-6, 1, 8]:
		draw_rect(Rect2(p + Vector2(x, -7), Vector2(3, 4)), Color("ffcb8a") if int(enemy.type) != 1 else Color("9ef2bc"))
	if int(enemy.type) == 2:
		draw_line(p + Vector2(-9, -12), p + Vector2(7, -17), Color("d39a88"), 4)
		if float(enemy.cooldown) < 0.9 and float(enemy.cooldown) > 0.65:
			_halo(p, Vector2(70, 55), Color(0.9, 0.2, 0.12, 0.15))
			draw_string(font, p + Vector2(-3, -26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffb080"))
