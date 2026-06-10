extends Node

enum Type {
	slash,
	blunt,
	pierce,
	sonic,
	heat,
	cold,
	jolt,
	toxic,
	acid,
	arcane,
	bleed,
	radiant
}

static func dmg_to_string(t:int) -> String:
	match t:
		Type.slash: return "Slash"
		Type.blunt: return "Blunt"
		Type.pierce: return "Pierce"
		Type.sonic: return "Sonic"
		Type.heat: return "Heat"
		Type.cold: return "Cold"
		Type.jolt: return "Jolt"
		Type.toxic: return "Toxic"
		Type.acid: return "Acid"
		Type.arcane: return "Arcane"
		Type.bleed: return "Bleed"
		Type.radiant: return "Radiant"
		_: return "Unknown"
