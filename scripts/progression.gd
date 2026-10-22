class_name ColonyProgress
extends RefCounted

# JSON numbers are doubles. Keep balances exact and leave ample room for rewards.
const MAX_TOTAL := 1_000_000_000

var copper := 0
var crystal := 0
var credits := 0
var cargo_copper := 0
var cargo_crystal := 0
var drill_level := 0
var workshop := false
var quarters := false
var regulator := false
var archive := false
var research := false
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
				return "Living quarters complete. Maximum health: 125. Two field kits per expedition."
			if copper < 12 or crystal < 3:
				return "Requires 12 copper and 3 blue crystals from the depths."
			copper -= 12
			crystal -= 3
			quarters = true
			return "Living quarters constructed. Health: 125. Two field kits per expedition."
		"research":
			if research:
				return "Research lab operational. Hull 150. Boost duration +50%."
			if not workshop or not quarters:
				return "Build the workshop and living quarters before opening the research lab."
			if not archive:
				return "Recover the archive on foot in the fungal chamber, around 350m deep."
			if crystal < 8 or credits < 120:
				return "Research lab requires 8 crystals and 120 credits from banked hauls."
			crystal -= 8
			credits -= 120
			research = true
			return "Research lab online. Reinforced hull: 150. Explorer boost: +50%."
	return "Unknown project."

func objective() -> String:
	if drill_level == 0:
		return "Mine copper > upgrade your drill bay"
	if not regulator:
		return "Explore the old pumping station > recover its regulator on foot"
	if not workshop:
		return "Return with the regulator > construct your workshop"
	if not quarters:
		return "Find blue crystals below 200m > build living quarters"
	if not archive:
		return "Descend to the fungal chamber at 350m > recover the archive on foot"
	if not research:
		return "Bring home 8 crystals and 120 credits > open the research lab"
	return "Research complete. Reinforced hull and extended boost equipped."

func snapshot() -> Dictionary:
	return {"copper": copper, "crystal": crystal, "credits": credits,
		"cargo_copper": cargo_copper, "cargo_crystal": cargo_crystal,
		"drill_level": drill_level, "workshop": workshop, "quarters": quarters,
		"regulator": regulator, "archive": archive, "research": research, "expeditions": expeditions, "deepest": deepest}

func restore(data: Dictionary) -> void:
	copper = _safe_count(data.get("copper"), MAX_TOTAL)
	crystal = _safe_count(data.get("crystal"), MAX_TOTAL)
	credits = _safe_count(data.get("credits"), MAX_TOTAL)
	drill_level = _safe_count(data.get("drill_level"), 3)
	cargo_copper = _safe_count(data.get("cargo_copper"), capacity())
	cargo_crystal = _safe_count(data.get("cargo_crystal"), capacity() - cargo_copper)
	workshop = data.get("workshop") is bool and data.workshop
	quarters = data.get("quarters") is bool and data.quarters
	regulator = data.get("regulator") is bool and data.regulator
	archive = data.get("archive") is bool and data.archive
	research = data.get("research") is bool and data.research
	expeditions = _safe_count(data.get("expeditions"), MAX_TOTAL)
	deepest = _safe_count(data.get("deepest"), MAX_TOTAL)

func _safe_count(value: Variant, maximum: int) -> int:
	if not (value is int or value is float):
		return 0
	var number := float(value)
	if not is_finite(number) or number != floor(number):
		return 0
	# Clamp before conversion: converting an enormous double to int can overflow.
	return int(clampf(number, 0.0, float(maximum)))
