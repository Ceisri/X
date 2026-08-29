extends ScrollContainer

onready var player = $"../../.."
onready var stats = $"../../../Stats"
onready var skill_tree = $".."

var skills = {
	"combo attack":1,
	"battlecry":0,
	"onslaught":0,
	"overhead_strike":0
}

# Dragging/panning moved to MoveThis.gd (the child that actually holds
# the skill buttons now). Keeping _gui_input here too would double-pan
# or fight it silently, so it's removed.
