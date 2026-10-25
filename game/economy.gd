extends RefCounted

var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
var s: Dictionary
var events: Array = []
var feedback: Array = []
var dirty := false
const VERSION := 3
const STATIONS := ["garden","cauldron","counter","shelf"]

func _init():
	fresh()

func fresh():
	s = {"version":VERSION,"levels":default_levels(),"decor":default_decor(),"coins":int(cfg.starting_coins),"herbs":[0,0],"stock":[int(cfg.starting_stock),0],"plots":[{"crop":0,"progress":0.0},{"crop":0,"progress":0.0}],"crop":0,"recipe":0,"pot":-1,"brew_progress":0.0,"ready":false,"queue":0,"arrival":0.0,"service":0.0,"serving":false,"owned":{},"flags":{},"elapsed":0.0,"timestamp":0.0,"muted":false,"offline_notice":{},"tutorial":0}
	events.clear()
	feedback.clear()
	dirty = true

func default_levels() -> Dictionary:
	var levels := {}
	for id in STATIONS: levels[id] = 1
	return levels

func default_decor() -> Dictionary:
	return {"floor":0,"wall":0,"manual_floor":false,"manual_wall":false}

# Preserve old level and economy data while adding selectable decoration.
func migrate(v: Variant) -> Variant:
	if v is Dictionary and (v.get("version") is float or v.get("version") is int) and int(v.version) == 1:
		v.version = 2
		v.levels = default_levels()
	if v is Dictionary and (v.get("version") is float or v.get("version") is int) and int(v.version) == 2:
		v.version = VERSION
		v.decor = default_decor()
		if v.owned.get("renovation",false):
			v.decor.floor = 1
			v.decor.wall = 1
	return v

func decor_unlocked(kind: String, variant: int) -> bool:
	if kind not in ["floor","wall"] or variant not in [0,1,2]: return false
	if variant == 0: return true
	if variant == 1: return owned("renovation")
	return level("garden") >= 7 if kind == "floor" else maxi(level("counter"),level("shelf")) >= 7

func select_decor(kind: String, variant: int) -> bool:
	if not decor_unlocked(kind,variant): return false
	s.decor[kind] = variant
	s.decor["manual_"+kind] = true
	dirty = true
	return true

func update_auto_decor():
	for kind in ["floor","wall"]:
		if s.decor["manual_"+kind]: continue
		if decor_unlocked(kind,2): s.decor[kind] = 2
		elif decor_unlocked(kind,1): s.decor[kind] = 1

func level(id: String) -> int:
	return int(s.levels.get(id, 1))

func milestones_reached(id: String) -> int:
	var n := 0
	for m in cfg.milestones:
		if level(id) >= m: n += 1
	return n

func next_milestone(id: String) -> int:
	for m in cfg.milestones:
		if level(id) < m: return int(m)
	return 0

# Each level adds a flat bonus; each milestone doubles that station's output.
func station_mult(id: String) -> float:
	return (1.0 + cfg.level_speed * (level(id) - 1)) * pow(2.0, milestones_reached(id))

func level_cost(id: String) -> int:
	for st in cfg.stations:
		if st.id == id: return int(round(st.cost * pow(cfg.level_growth, level(id) - 1)))
	return 0

func level_up(id: String) -> bool:
	if not id in STATIONS or level(id) >= int(cfg.max_level): return false
	var cost := level_cost(id)
	if s.coins < cost: return false
	s.coins -= cost
	s.levels[id] = level(id) + 1
	update_auto_decor()
	first("first_level")
	# Milestones load from JSON as floats, so compare the reached one as an int.
	if milestones_reached(id) > 0 and int(cfg.milestones[milestones_reached(id) - 1]) == level(id):
		event("milestone_%s_%d" % [id, level(id)])
		feedback.append("milestone")
	else:
		feedback.append("level")
	dirty = true
	return true

func herb_capacity() -> int:
	return int(cfg.herb_capacity) + 2 * (level("garden") - 1)

func queue_capacity() -> int:
	return 3 + milestones_reached("counter")

func arrival_time() -> float:
	return float(cfg.arrival_seconds) / station_mult("counter")

func service_time() -> float:
	return float(cfg.service_seconds) / (2.0 if owned("service") else 1.0) / station_mult("counter")

func short(n: float) -> String:
	if absf(n) < 10000: return str(int(n))
	var units := ["K","M","B","T","Qa","Qi"]
	var i := -1
	while absf(n) >= 1000 and i < units.size() - 1:
		n /= 1000.0
		i += 1
	return ("%.2f" % n if n < 10 else "%.1f" % n if n < 100 else "%d" % int(n)) + units[i]

func owned(id: String) -> bool:
	return s.owned.get(id, false)

func event(id: String):
	events.append({"event":id,"elapsed":snapped(s.elapsed,0.1)})
	dirty = true

func first(id: String):
	if not s.flags.has(id):
		s.flags[id] = true
		event(id)

func stock_count() -> int:
	return int(s.stock[0] + s.stock[1])

func capacity() -> int:
	return int(cfg.shelf_capacity) * (2 if owned("capacity") else 1) + level("shelf") - 1

func grow_time(crop: int) -> float:
	return float(cfg.crops[crop].grow) / (1.5 if owned("grow") else 1.0) / station_mult("garden")

func brew_time(recipe: int) -> float:
	return float(cfg.recipes[recipe].brew) / (1.5 if owned("brew") else 1.0) / station_mult("cauldron")

func price(recipe: int) -> int:
	var shelf: float = (1.0 + cfg.shelf_price * (level("shelf") - 1)) * pow(2.0, milestones_reached("shelf"))
	return int(round(cfg.recipes[recipe].price * (1.25 if owned("renovation") else 1.0) * shelf))

func harvest() -> bool:
	var did := false
	for p in s.plots:
		var c := int(p.crop)
		var amount := int(cfg.crops[c].yield)
		if p.progress >= grow_time(c) and s.herbs[c] + amount <= herb_capacity():
			s.herbs[c] += amount
			p.progress = 0.0
			p.crop = s.crop
			did = true
	if did:
		first("first_harvest")
		feedback.append("harvest")
		dirty = true
	return did

func brew() -> bool:
	var r := int(s.recipe)
	var rec: Dictionary = cfg.recipes[r]
	if s.pot != -1 or stock_count() >= capacity() or s.herbs[int(rec.herb)] < rec.consume:
		return false
	s.herbs[int(rec.herb)] -= int(rec.consume)
	s.pot = r
	s.brew_progress = 0.0
	s.ready = false
	feedback.append("brew")
	dirty = true
	return true

func stock() -> bool:
	if not s.ready or stock_count() + cfg.recipes[int(s.pot)].produce > capacity():
		return false
	s.stock[int(s.pot)] += int(cfg.recipes[int(s.pot)].produce)
	s.pot = -1
	s.ready = false
	s.brew_progress = 0.0
	first("first_brew")
	feedback.append("stock")
	dirty = true
	return true

func serve() -> bool:
	if s.serving or s.queue <= 0 or stock_count() == 0:
		return false
	s.serving = true
	s.service = 0.0
	dirty = true
	return true

func purchase(id: String) -> bool:
	for p in cfg.purchases:
		if p.id != id:
			continue
		if owned(id) or s.coins < p.cost:
			return false
		s.coins -= int(p.cost)
		s.owned[id] = true
		update_auto_decor()
		first("first_upgrade")
		event("hire_"+id if id in ["gardener","brewer","cashier"] else "unlock_"+id)
		if id == "renovation": event("renovation_purchase")
		feedback.append("upgrade")
		return true
	return false

func select_crop(value: int):
	if value == 0 or (value == 1 and owned("recipe")):
		s.crop = value
		for p in s.plots:
			if p.crop != value:
				p.crop = value
				p.progress = 0.0
		dirty = true

func select_recipe(value: int):
	if value == 0 or (value == 1 and owned("recipe")):
		s.recipe = value
		dirty = true

func tick(dt: float):
	s.elapsed += dt
	for p in s.plots:
		p.progress = min(p.progress + dt, grow_time(int(p.crop)))
		if p.progress + 0.00001 >= grow_time(int(p.crop)): p.progress = grow_time(int(p.crop))
	if owned("gardener"): harvest()
	if s.pot != -1 and not s.ready:
		s.brew_progress += dt
		if s.brew_progress + 0.00001 >= brew_time(int(s.pot)):
			s.ready = true
	if owned("brewer"):
		stock()
		brew()
	s.arrival += dt
	if s.arrival >= arrival_time():
		s.arrival = 0.0
		s.queue = min(queue_capacity(), s.queue + 1)
	if owned("cashier"): serve()
	if s.serving:
		s.service += dt
		if s.service + 0.00001 >= service_time():
			# Checkout is the only writer that removes stocked bottles.
			var r := 1 if s.stock[1] > 0 else 0
			if s.queue > 0 and s.stock[r] > 0:
				s.stock[r] -= 1
				s.coins += price(r)
				s.queue -= 1
				first("first_sale")
				feedback.append("dream_sale" if r == 1 else "sale")
				dirty = true
			s.serving = false
			s.service = 0.0
	update_tutorial()

func update_tutorial():
	var conditions := [s.flags.has("first_harvest"),s.flags.has("first_brew"),s.flags.has("first_sale"),owned("gardener"),owned("brewer"),owned("cashier"),owned("recipe"),owned("renovation")]
	var stage := 0
	while stage < conditions.size() and conditions[stage]: stage += 1
	s.tutorial = stage
	if stage == conditions.size(): first("tutorial_complete")

func objective() -> String:
	return ["Garden → harvest your first peppermint","Shop → brew, then stock your first potion","Shop → serve a customer to earn coins","Hire Pip in Team • 32 coins","Hire Momo in Team • 56 coins","Hire Sol in Team • 80 coins","Unlock Dreamdrop in Improve • 48 coins","Save 320 coins for the grand glow-up",milestone_goal()][int(s.tutorial)]

func goal_station() -> String:
	# The station closest (in levels) to its next ×2 milestone.
	var best := ""
	var gap := 1000
	for id in STATIONS:
		var m := next_milestone(id)
		if m > 0 and m - level(id) < gap:
			gap = m - level(id)
			best = id
	return best

func milestone_goal() -> String:
	var id := goal_station()
	if id == "": return "Every station is maxed. Legendary!"
	var what: String = {"garden":"growth","cauldron":"brew speed","counter":"customers","shelf":"potion prices"}[id]
	var name: String = {"garden":"Garden beds","cauldron":"Cauldron","counter":"Counter","shelf":"Shelf"}[id]
	return "%s Lv. %d/%d → ×2 %s" % [name, level(id), next_milestone(id), what]

# Fraction toward the current objective, or -1 when it has no measurable target.
func goal_progress() -> float:
	var t := int(s.tutorial)
	var costs := {3:32,4:56,5:80,6:48,7:320}
	if costs.has(t): return clampf(float(s.coins) / costs[t], 0.0, 1.0)
	if t == 8:
		var id := goal_station()
		if id == "": return 1.0
		var prev := 1
		for m in cfg.milestones:
			if m <= level(id): prev = int(m)
		return clampf(float(level(id) - prev) / (next_milestone(id) - prev), 0.0, 1.0)
	return -1.0

func status() -> String:
	if s.ready: return "Shelf full" if stock_count() >= capacity() else "Potion ready • stock the shelf"
	if s.pot != -1: return "Brewing %s • %ds" % [cfg.recipes[int(s.pot)].name, ceili(brew_time(int(s.pot))-s.brew_progress)]
	if stock_count() >= capacity(): return "Shelf full • serve customers"
	if s.herbs[int(cfg.recipes[int(s.recipe)].herb)] < cfg.recipes[int(s.recipe)].consume: return "Waiting for herbs • visit Garden"
	return "Ready to brew • " + cfg.recipes[int(s.recipe)].name

func simulate(seconds: float):
	var count := int(floor(maxf(0.0, seconds) / cfg.step))
	for i in range(count): tick(cfg.step)
	feedback.clear()

func offline(now: float) -> Dictionary:
	var elapsed := clampf(now - s.timestamp,0.0,cfg.offline_cap) if s.timestamp > 0 else 0.0
	var before := int(s.coins)
	simulate(elapsed)
	# A high-water timestamp prevents replay after a backwards clock change.
	s.timestamp = maxf(now,s.timestamp)
	var report := {"seconds":int(elapsed),"coins":int(s.coins)-before}
	if elapsed >= 10:
		s.offline_notice = report
		event("offline_reward_claim")
	return report

func valid(v: Variant) -> bool:
	if not v is Dictionary or v.get("version") != VERSION: return false
	for key in s:
		if not v.has(key): return false
	for key in ["coins","elapsed","timestamp","brew_progress","service","arrival","tutorial","queue"]:
		if not (v[key] is float or v[key] is int) or not is_finite(float(v[key])) or v[key] < 0: return false
	for key in ["herbs","stock"]:
		if not v[key] is Array or v[key].size() != 2: return false
		for n in v[key]:
			if not (n is float or n is int) or n < 0 or n != floor(n): return false
	if not v.owned is Dictionary or not v.flags is Dictionary or not v.offline_notice is Dictionary: return false
	for key in v.owned:
		if not v.owned[key] is bool: return false
	for key in ["ready","serving","muted"]:
		if not v[key] is bool: return false
	for key in ["crop","recipe","pot"]:
		if not (v[key] is int or v[key] is float) or v[key] != floor(v[key]): return false
	if int(v.crop) not in [0,1] or int(v.recipe) not in [0,1] or int(v.pot) not in [-1,0,1] or v.tutorial > 8 or v.queue > 3 + cfg.milestones.size(): return false
	if not v.levels is Dictionary: return false
	if not v.decor is Dictionary: return false
	for kind in ["floor","wall"]:
		var variant = v.decor.get(kind)
		if not (variant is int or variant is float) or variant != floor(variant) or int(variant) not in [0,1,2]: return false
		if not v.decor.get("manual_"+kind) is bool: return false
	for id in STATIONS:
		var n = v.levels.get(id)
		if not (n is float or n is int) or n != floor(n) or n < 1 or n > cfg.max_level: return false
	if v.ready and v.pot == -1: return false
	if not v.plots is Array or v.plots.size() != 2: return false
	for p in v.plots:
		if not p is Dictionary or not (p.get("crop") is int or p.get("crop") is float): return false
		if p.crop != floor(p.crop) or int(p.crop) not in [0,1]: return false
		if not (p.get("progress") is float or p.get("progress") is int) or p.progress < 0 or not is_finite(float(p.progress)): return false
	return true
