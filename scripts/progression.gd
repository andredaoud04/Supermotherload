class_name ColonyProgress
extends RefCounted

var copper := 0
var crystal := 0
var credits := 0
var cargo_copper := 0
var cargo_crystal := 0
var drill_level := 0
var workshop := false
var quarters := false
var regulator := false
var expeditions := 0
var deepest := 0

func capacity() -> int:
	return 24 + drill_level * 12

func cargo_count() -> int:
	return cargo_copper + cargo_crystal

func collect(material: int) -> bool:
	if cargo_count() >= capacity():
		return false
	if material == MineTerrain.Tile.COPPER:
		cargo_copper += 1
	elif material == MineTerrain.Tile.CRYSTAL:
		cargo_crystal += 1
	else:
		return false
	return true

func deposit() -> int:
	var value := cargo_copper * 3 + cargo_crystal * 8
	copper += cargo_copper
	crystal += cargo_crystal
	credits += value
	cargo_copper = 0
	cargo_crystal = 0
	expeditions += 1
	return value

func purchase(kind: String) -> String:
	match kind:
		"drill":
			if drill_level >= 3:
				return "Drill bay fully upgraded."
			var cost := 10 + drill_level * 10
			if copper < cost:
				return "Need %d copper. Mine the amber seam below the lift." % cost
			copper -= cost
			drill_level += 1
			return "Drill upgraded. Faster excavation. +12 cargo capacity."
		"workshop":
			if workshop:
				return "Workshop is operational. Rifle damage is doubled."
			if not regulator or copper < 8:
				return "Requires 8 copper and the regulator in the old pumping station."
			copper -= 8
			workshop = true
			return "Workshop constructed. High-impact rifle rounds unlocked."
		"quarters":
			if quarters:
				return "Living quarters are complete. Maximum health: 125."
			if copper < 12 or crystal < 3:
				return "Requires 12 copper and 3 blue crystals from the depths."
			copper -= 12
			crystal -= 3
			quarters = true
			return "Living quarters constructed. Maximum health increased to 125."
	return "Unknown project."

func snapshot() -> Dictionary:
	return {"copper": copper, "crystal": crystal, "credits": credits,
		"cargo_copper": cargo_copper, "cargo_crystal": cargo_crystal,
		"drill_level": drill_level, "workshop": workshop, "quarters": quarters,
		"regulator": regulator, "expeditions": expeditions, "deepest": deepest}

func restore(data: Dictionary) -> void:
	copper = maxi(0, int(data.get("copper", 0)))
	crystal = maxi(0, int(data.get("crystal", 0)))
	credits = maxi(0, int(data.get("credits", 0)))
	drill_level = clampi(int(data.get("drill_level", 0)), 0, 3)
	cargo_copper = clampi(int(data.get("cargo_copper", 0)), 0, capacity())
	cargo_crystal = clampi(int(data.get("cargo_crystal", 0)), 0, capacity() - cargo_copper)
	workshop = bool(data.get("workshop", false))
	quarters = bool(data.get("quarters", false))
	regulator = bool(data.get("regulator", false))
	expeditions = maxi(0, int(data.get("expeditions", 0)))
	deepest = maxi(0, int(data.get("deepest", 0)))
