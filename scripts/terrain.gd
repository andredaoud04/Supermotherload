class_name MineTerrain
extends RefCounted
## material data is independent of rendering, input and actors. Mining emits cell edits.

const TILE := 32
const WIDTH := 84
const HEIGHT := 64
enum Tile { AIR, ROCK, COPPER, CRYSTAL, BEDROCK }
var cells := PackedByteArray()
var damage: Dictionary = {}
var edits: Dictionary = {}
var seed_value := 17041

func generate(world_seed: int = 17041) -> void:
	seed_value = world_seed
	cells.resize(WIDTH * HEIGHT)
	damage.clear()
	edits.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	for y in HEIGHT:
		for x in WIDTH:
			var tile := Tile.ROCK
			if x < 2 or x >= WIDTH - 2 or y < 2 or y >= HEIGHT - 2:
				tile = Tile.BEDROCK
			elif rng.randf() < 0.13:
				tile = Tile.COPPER if y < 26 or rng.randf() < 0.6 else Tile.CRYSTAL
			cells[y * WIDTH + x] = tile
	# Entry station and permanent return shaft. Encounter chambers have intact floors.
	carve(Rect2i(3, 3, 22, 8))
	carve(Rect2i(7, 7, 5, 45))
	carve(Rect2i(18, 17, 19, 7))
	carve(Rect2i(35, 30, 23, 8))
	carve(Rect2i(17, 47, 22, 6))
	# An immediately reachable seam teaches drilling without searching for ore.
	for y in range(11, 15):
		for x in range(13, 19):
			cells[y * WIDTH + x] = Tile.COPPER
	for x in range(38, 49):
		cells[38 * WIDTH + x] = Tile.CRYSTAL

func carve(area: Rect2i) -> void:
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			cells[y * WIDTH + x] = Tile.AIR

func at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= WIDTH or cell.y < 0 or cell.y >= HEIGHT:
		return Tile.BEDROCK
	return cells[cell.y * WIDTH + cell.x]

func world_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori(point.y / TILE))

func solid(point: Vector2) -> bool:
	return at(world_cell(point)) != Tile.AIR

func blocked(center: Vector2, half: Vector2) -> bool:
	var first := world_cell(center - half + Vector2.ONE * 0.1)
	var last := world_cell(center + half - Vector2.ONE * 0.1)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if at(Vector2i(x, y)) != Tile.AIR:
				return true
	return false

func move_body(center: Vector2, half: Vector2, displacement: Vector2) -> Vector2:
	# Substeps prevent tunnelling even after a slow browser frame.
	var steps := maxi(1, ceili(displacement.length() / 5.0))
	var step := displacement / steps
	for i in steps:
		if not blocked(center + Vector2(step.x, 0), half):
			center.x += step.x
		if not blocked(center + Vector2(0, step.y), half):
			center.y += step.y
	return center

func drill(center: Vector2, half: Vector2, direction: Vector2, power: float, available: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if direction == Vector2.ZERO:
		return result
	var target := center + direction * 9.0
	var first := world_cell(target - half)
	var last := world_cell(target + half)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			var material := at(cell)
			if material == Tile.AIR or material == Tile.BEDROCK:
				continue
			if material in [Tile.COPPER, Tile.CRYSTAL] and available <= 0:
				continue
			var id := y * WIDTH + x
			damage[id] = float(damage.get(id, 0.0)) + power
			var hardness := 0.26 if material == Tile.ROCK else 0.48
			if float(damage[id]) >= hardness:
				cells[id] = Tile.AIR
				edits[str(id)] = Tile.AIR
				damage.erase(id)
				if material != Tile.ROCK:
					available -= 1
				result.append({"cell": cell, "material": material})
	return result

func export_state() -> Dictionary:
	return {"seed": seed_value, "edits": edits.duplicate()}

func restore(data: Dictionary) -> void:
	generate(int(data.get("seed", 17041)))
	var stored: Dictionary = data.get("edits", {})
	for key in stored:
		var id := int(key)
		if id >= 0 and id < cells.size() and int(stored[key]) == Tile.AIR and cells[id] != Tile.BEDROCK:
			cells[id] = Tile.AIR
			edits[str(id)] = Tile.AIR
