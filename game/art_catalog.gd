extends RefCounted

# Each station visibly changes at these affordable early levels. Later levels
# retain the masterwork sprite while their real economy bonuses keep growing.
const TIER_LEVELS = [1,3,7]
const FAMILIES = ["cauldron","shelf","counter","bed","mint","moonflower","energy","dream","bush","plant"]

const FLOORS = [
	{"name":"Cream checker","a":"fae7cb","b":"f6e1c2","line":"e5ceb0","motif":"plain","unlock":"Included"},
	{"name":"Moon mosaic","a":"eee1f7","b":"f8edfc","line":"d6bfed","motif":"diamond","unlock":"Grand glow-up"},
	{"name":"Botanical tile","a":"e4efd9","b":"f3f4dc","line":"bad19e","motif":"leaf","unlock":"Garden Lv. 7"}
]
const WALLS = [
	{"name":"Cream plaster","face":"ecd8c3","low":"d8c4b2","trim":"c98c62","motif":"plain","unlock":"Included"},
	{"name":"Lavender panels","face":"eee0f2","low":"d8c5e7","trim":"aa81cb","motif":"panel","unlock":"Grand glow-up"},
	{"name":"Ivy & gold","face":"e7ecd9","low":"c9d9bd","trim":"d1a65d","motif":"vine","unlock":"Counter or Shelf Lv. 7"}
]

static func tier(level: int) -> int:
	return 3 if level >= TIER_LEVELS[2] else 2 if level >= TIER_LEVELS[1] else 1

static func name_for(family: String, level: int) -> String:
	return "%s_t%d" % [family,tier(level)]
