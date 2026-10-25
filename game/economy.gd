extends RefCounted

var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
var s: Dictionary
var events: Array = []
var feedback: Array = []
var dirty := false
var last_visitor_pay := 0
# Running totals for the welcome-back report; not saved.
var tally := {"harvested":0,"brewed":0,"sold":0}
# Achievement names unlocked since the UI last showed them.
var new_achievements: Array = []
const BRANCHES := ["Little Lux","Seaside Lux","Snowpeak Lux","Night Market Lux","Sunflower Lux","Starfall Lux"]
const STAR_COINS := 50000.0
const STAR_BONUS := 0.1
const PRESTIGE_LEVEL := 25
const QUEST_TEXT := {"sold":"Serve %s customers","brewed":"Brew %s potions","harvested":"Harvest %s herbs","levels":"Level up stations %s times","specials":"Serve %s special visitors","earned":"Earn %s coins"}
const ACHIEVEMENTS := [
	["first_sale","First sale","Sell your first potion","sold",1],
	["sold_100","Regulars","Sell 100 potions","sold",100],
	["sold_1000","Local favourite","Sell 1,000 potions","sold",1000],
	["sold_10000","Famous shop","Sell 10,000 potions","sold",10000],
	["team","Full team","Hire Pip, Momo and Sol","team",3],
	["level_10","First milestone","Reach Lv. 10 on any station","top_level",10],
	["level_25","Master craft","Reach Lv. 25 on any station","top_level",25],
	["level_50","Legendary gear","Reach Lv. 50 on any station","top_level",50],
	["recipes_4","Apprentice alchemist","Unlock 4 recipes","recipes",4],
	["recipes_8","Grand alchemist","Unlock all 8 recipes","recipes",8],
	["beds_6","Green thumb","Grow six garden beds","plots",6],
	["specials_10","Made to order","Serve 10 special visitors","specials",10],
	["vips_10","Royal favour","Serve 10 VIPs","vips",10],
	["earned_1m","Millionaire","Earn 1,000,000 coins in total","earned",1000000],
	["glow_up","Grand glow-up","Renovate the shop","renovated",1]]
const VERSION := 4
const MAX_PLOTS := 6
const STATIONS := ["garden","cauldron","counter","shelf"]
# Hired helpers level like stations: Pip speeds growth, Momo brewing, Sol earns tips.
const WORKERS := ["gardener","brewer","cashier"]

func _init():
	fresh()

func fresh():
	s = fresh_state()
	events.clear()
	feedback.clear()
	dirty = true

func fresh_state() -> Dictionary:
	var state := {"version":VERSION,"levels":default_levels(),"decor":default_decor(),"coins":int(cfg.starting_coins),"herbs":zeros(cfg.crops.size()),"stock":zeros(cfg.recipes.size()),"plots":[{"crop":0,"progress":0.0},{"crop":0,"progress":0.0}],"recipe":0,"visitor":{},"visitor_timer":0.0,"pot":-1,"brew_progress":0.0,"ready":false,"queue":0,"arrival":0.0,"service":0.0,"serving":false,"owned":{},"flags":{},"elapsed":0.0,"timestamp":0.0,"muted":false,"offline_notice":{},"tutorial":0,"daily":{},"login":{},"stats":{},"achievements":{},"prestige":{"stars":0,"branches":0,"run_earned":0,"talents":{}}}
	state.stock[0] = int(cfg.starting_stock)
	return state

func zeros(n: int) -> Array:
	var a := []
	a.resize(n)
	a.fill(0)
	return a

func default_levels() -> Dictionary:
	var levels := {}
	for id in STATIONS + WORKERS: levels[id] = 1
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
	# Version 4 adds the Recipe Book: inventories grow to every crop and potion,
	# and beds choose their own seeds, so the global crop choice goes away.
	if v is Dictionary and (v.get("version") is float or v.get("version") is int) and int(v.version) == 3:
		v.version = VERSION
		for key in ["herbs","stock"]:
			var size: int = cfg.crops.size() if key == "herbs" else cfg.recipes.size()
			if v.get(key) is Array:
				while v[key].size() < size: v[key].append(0)
		v.erase("crop")
	# Later version 4 additions arrive with their fresh-game defaults.
	if v is Dictionary and (v.get("version") is float or v.get("version") is int) and int(v.version) == VERSION:
		var defaults := fresh_state()
		for key in defaults:
			if not v.has(key): v[key] = defaults[key]
		if v.prestige is Dictionary and not v.prestige.has("talents"): v.prestige.talents = {}
		if v.levels is Dictionary:
			for id in WORKERS:
				if not v.levels.has(id): v.levels[id] = 1
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
# Cached per level, since offline catch-up asks for it hundreds of thousands of times.
var _mult_cache := {}
func station_mult(id: String) -> float:
	var lv := level(id)
	var hit = _mult_cache.get(id)
	if hit != null and hit[0] == lv: return hit[1]
	var mult: float = (1.0 + cfg.level_speed * (lv - 1)) * pow(2.0, milestones_reached(id))
	_mult_cache[id] = [lv, mult]
	return mult

func level_cost(id: String) -> int:
	for st in cfg.stations + cfg.workers:
		if st.id == id: return int(round(st.cost * pow(cfg.level_growth, level(id) - 1)))
	return 0

func level_up(id: String) -> bool:
	if not (id in STATIONS or id in WORKERS and owned(id)) or level(id) >= int(cfg.max_level): return false
	var cost := level_cost(id)
	if s.coins < cost: return false
	s.coins -= cost
	s.levels[id] = level(id) + 1
	update_auto_decor()
	first("first_level")
	count("levels", 1)
	# Milestones load from JSON as floats, so compare the reached one as an int.
	if milestones_reached(id) > 0 and int(cfg.milestones[milestones_reached(id) - 1]) == level(id):
		event("milestone_%s_%d" % [id, level(id)])
		feedback.append("milestone")
	else:
		feedback.append("level")
	dirty = true
	return true

func herb_capacity() -> int:
	if _fast: return _d.herb_capacity
	return int(cfg.herb_capacity) + 2 * (level("garden") - 1)

func queue_capacity() -> int:
	if _fast: return _d.queue_capacity
	return 3 + milestones_reached("counter")

func arrival_time() -> float:
	if _fast: return _d.arrival_time
	return float(cfg.arrival_seconds) / station_mult("counter") / talent_mult("street")

func service_time() -> float:
	if _fast: return _d.service_time
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
	var n := 0
	for k in s.stock: n += int(k)
	return n

func recipe_key(r: int) -> String:
	return "recipe" if r == 1 else "recipe_%d" % r

func recipe_unlocked(r: int) -> bool:
	return r == 0 or owned(recipe_key(r))

func next_locked_recipe() -> int:
	for r in range(cfg.recipes.size()):
		if not recipe_unlocked(r): return r
	return -1

func unlock_recipe(r: int) -> bool:
	if r <= 0 or r >= cfg.recipes.size() or recipe_unlocked(r) or r != next_locked_recipe(): return false
	var cost := int(cfg.recipes[r].unlock)
	if s.coins < cost: return false
	s.coins -= cost
	s.owned[recipe_key(r)] = true
	first("first_upgrade")
	event("unlock_recipe_%d" % r)
	feedback.append("upgrade")
	select_recipe(r)
	return true

func needs(r: int) -> Array:
	return cfg.recipes[r].needs

func can_brew(r: int) -> bool:
	for n in needs(r):
		if s.herbs[int(n[0])] < int(n[1]): return false
	return true

func missing_herb(r: int) -> int:
	for n in needs(r):
		if s.herbs[int(n[0])] < int(n[1]): return int(n[0])
	return -1

func ingredient_text(r: int) -> String:
	var parts := []
	for n in needs(r): parts.append(("%d " % int(n[1]) if int(n[1]) > 1 else "") + cfg.crops[int(n[0])].name)
	return " + ".join(parts)

# A replanting bed picks the needed crop that is furthest behind, counting
# herbs in the bin and what the other beds are already growing.
func seed_for(index: int) -> int:
	var best := int(needs(int(s.recipe))[0][0])
	var low := INF
	for n in needs(int(s.recipe)):
		var c := int(n[0])
		var supply := float(s.herbs[c])
		for i in range(s.plots.size()):
			if i != index and int(s.plots[i].crop) == c: supply += float(cfg.crops[c].yield)
		var score := supply / float(n[1])
		if score < low:
			low = score
			best = c
	return best

# Deterministic dice from the game clock keep offline catch-up identical to play.
func roll(salt: int) -> float:
	return float(absi(hash(int(s.elapsed * 10) * 31 + salt)) % 10000) / 10000.0

func spawn_visitor():
	var kinds := []
	if owned("recipe"): kinds.append("request")
	if owned("cashier"): kinds.append("vip")
	if kinds.is_empty() or roll(1) > cfg.visitors.chance: return
	var kind: String = kinds[0]
	if kinds.size() > 1 and roll(2) < cfg.visitors.vip_share: kind = "vip"
	var unlocked := []
	for r in range(cfg.recipes.size()):
		if recipe_unlocked(r): unlocked.append(r)
	var want: int = unlocked[int(roll(3) * unlocked.size()) % unlocked.size()]
	s.visitor = {"kind":kind,"recipe":want,"left":float(cfg.visitors.wait)}
	feedback.append("visitor")

# Which potion the special visitor would take right now, or -1.
func visitor_potion() -> int:
	if s.visitor.is_empty(): return -1
	if s.visitor.kind == "request": return int(s.visitor.recipe) if s.stock[int(s.visitor.recipe)] > 0 else -1
	for k in range(s.stock.size() - 1, -1, -1):
		if s.stock[k] > 0: return k
	return -1

func visitor_pay() -> int:
	var r := visitor_potion()
	if r < 0: r = int(s.visitor.get("recipe", 0))
	return int(price(r) * int(cfg.visitors.vip_pay if s.visitor.get("kind") == "vip" else cfg.visitors.request_pay) * talent_mult("patrons"))

func serve_visitor() -> bool:
	var r := visitor_potion()
	if r < 0: return false
	var pay := visitor_pay()
	s.stock[r] -= 1
	s.coins += pay
	event("served_" + s.visitor.kind)
	count("specials", 1)
	count("earned", pay)
	if s.visitor.kind == "vip": count("vips", 1)
	feedback.append("vip" if s.visitor.kind == "vip" else "request")
	last_visitor_pay = pay
	s.visitor = {}
	s.visitor_timer = 0.0
	dirty = true
	return true

func plot_cost() -> int:
	var i: int = s.plots.size() - 2
	return int(cfg.plot_costs[i]) if i < cfg.plot_costs.size() else 0

func buy_plot() -> bool:
	if s.plots.size() >= MAX_PLOTS or s.coins < plot_cost(): return false
	s.coins -= plot_cost()
	s.plots.append({"crop":0,"progress":0.0})
	s.plots.back().crop = seed_for(s.plots.size() - 1)
	event("buy_plot_%d" % s.plots.size())
	feedback.append("upgrade")
	dirty = true
	return true

func capacity() -> int:
	if _fast: return _d.capacity
	return int(cfg.shelf_capacity) * (2 if owned("capacity") else 1) + level("shelf") - 1

func grow_time(crop: int) -> float:
	if _fast: return _d.grow_time[crop]
	return float(cfg.crops[crop].grow) / (1.5 if owned("grow") else 1.0) / station_mult("garden") / station_mult("gardener") / talent_mult("roots")

func brew_time(recipe: int) -> float:
	if _fast: return _d.brew_time[recipe]
	return float(cfg.recipes[recipe].brew) / (1.5 if owned("brew") else 1.0) / station_mult("cauldron") / station_mult("brewer") / talent_mult("bubbles")

func price(recipe: int) -> int:
	if _fast: return _d.price[recipe]
	var shelf: float = (1.0 + cfg.shelf_price * (level("shelf") - 1)) * pow(2.0, milestones_reached("shelf"))
	var stars := 1.0 + STAR_BONUS * int(s.prestige.stars)
	return int(round(cfg.recipes[recipe].price * (1.25 if owned("renovation") else 1.0) * shelf * stars * station_mult("cashier")))

func harvest() -> bool:
	var did := false
	for i in range(s.plots.size()):
		var p: Dictionary = s.plots[i]
		var c := int(p.crop)
		var amount := int(cfg.crops[c].yield)
		if p.progress >= grow_time(c) and s.herbs[c] + amount <= herb_capacity():
			s.herbs[c] += amount
			count("harvested", amount)
			p.progress = 0.0
			p.crop = seed_for(i)
			did = true
	if did:
		first("first_harvest")
		feedback.append("harvest")
		dirty = true
	return did

func brew() -> bool:
	var r := int(s.recipe)
	if s.pot != -1 or stock_count() >= capacity() or not can_brew(r):
		return false
	for n in needs(r): s.herbs[int(n[0])] -= int(n[1])
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
	count("brewed", 1)
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

# Choosing a recipe rebalances the beds for free; a bed keeps its growth when
# its crop is still the one the balance wants.
func select_recipe(value: int):
	if value < 0 or value >= cfg.recipes.size() or not recipe_unlocked(value): return
	s.recipe = value
	for i in range(s.plots.size()):
		var want := seed_for(i)
		if int(s.plots[i].crop) != want:
			s.plots[i].crop = want
			s.plots[i].progress = 0.0
	dirty = true

func tick(dt: float):
	s.elapsed += dt
	# Hot loop: read cached numbers and worker flags once, and only call the
	# actions that could do something this tick. Rules are unchanged.
	var gardener: bool = _d.gardener if _fast else owned("gardener")
	var brewer: bool = _d.brewer if _fast else owned("brewer")
	var cashier: bool = _d.cashier if _fast else owned("cashier")
	var any_ready := false
	for p in s.plots:
		var grow: float = _d.grow_time[int(p.crop)] if _fast else grow_time(int(p.crop))
		p.progress = minf(p.progress + dt, grow)
		if p.progress + 0.00001 >= grow:
			p.progress = grow
			any_ready = true
	if gardener and any_ready: harvest()
	if s.pot != -1 and not s.ready:
		s.brew_progress += dt
		if s.brew_progress + 0.00001 >= brew_time(int(s.pot)):
			s.ready = true
	if brewer:
		if s.ready: stock()
		if s.pot == -1: brew()
	if s.visitor.is_empty():
		s.visitor_timer += dt
		if s.visitor_timer >= cfg.visitors.every:
			s.visitor_timer = 0.0
			spawn_visitor()
	else:
		s.visitor.left -= dt
		if s.visitor.left <= 0:
			event("missed_" + s.visitor.kind)
			s.visitor = {}
	s.arrival += dt
	if s.arrival >= (_d.arrival_time if _fast else arrival_time()):
		s.arrival = 0.0
		s.queue = min(queue_capacity(), s.queue + 1)
	if cashier and not s.serving and s.queue > 0: serve()
	if s.serving:
		s.service += dt
		if s.service + 0.00001 >= service_time():
			# Checkout is the only writer that removes stocked bottles.
			# Customers take the most valuable potion on the shelf.
			var r := 0
			for k in range(s.stock.size() - 1, -1, -1):
				if s.stock[k] > 0:
					r = k
					break
			if s.queue > 0 and s.stock[r] > 0:
				s.stock[r] -= 1
				s.coins += price(r)
				s.queue -= 1
				first("first_sale")
				feedback.append("dream_sale" if r >= 1 else "sale")
				count("sold", 1)
				count("earned", price(r))
				dirty = true
			s.serving = false
			s.service = 0.0
	if int(s.tutorial) < 8: update_tutorial()

func count(kind: String, n: int):
	if tally.has(kind): tally[kind] += n
	s.stats[kind] = int(s.stats.get(kind, 0)) + n
	if kind == "earned": s.prestige.run_earned = int(s.prestige.run_earned) + n
	for q in s.daily.get("quests", []):
		if q.kind == kind: q.progress = mini(int(q.target), int(q.progress) + n)

func stat(kind: String) -> int:
	match kind:
		"team": return int(owned("gardener")) + int(owned("brewer")) + int(owned("cashier"))
		"top_level":
			var top := 1
			for id in STATIONS: top = maxi(top, level(id))
			return top
		"recipes":
			var n := 0
			for r in range(cfg.recipes.size()): n += int(recipe_unlocked(r))
			return n
		"plots": return s.plots.size()
		"renovated": return int(owned("renovation"))
	return int(s.stats.get(kind, 0))

func check_achievements():
	for a in ACHIEVEMENTS:
		if not s.achievements.has(a[0]) and stat(a[3]) >= a[4]:
			s.achievements[a[0]] = true
			new_achievements.append(a[1])
			event("achievement_" + a[0])

func total_levels() -> int:
	var n := 0
	for id in STATIONS: n += level(id)
	return n

# Rewards follow progress: a few of the cheapest next level-ups.
func reward_base() -> int:
	var cheapest := level_cost(STATIONS[0])
	for id in STATIONS: cheapest = mini(cheapest, level_cost(id))
	return maxi(60, cheapest * 4)

# Starts a new day's goals and advances the login streak; false if already today.
func ensure_day(today: String) -> bool:
	if s.daily.get("day", "") == today: return false
	var kinds := ["sold","brewed","harvested","levels","earned"]
	if owned("recipe") or owned("cashier"): kinds.append("specials")
	var picked := []
	var h := absi(hash(today))
	while picked.size() < 3:
		var k: String = kinds[h % kinds.size()]
		if not k in picked: picked.append(k)
		h = absi(hash(h + 7))
	var scale := 1.0 + total_levels() / 12.0
	var base := reward_base()
	var quests := []
	for k in picked:
		var target: int = {"sold":int(40 * scale),"brewed":int(40 * scale),"harvested":int(80 * scale),"levels":3 + total_levels() / 15,"specials":2,"earned":int(price(int(s.recipe)) * 40 * scale)}[k]
		quests.append({"kind":k,"target":target,"progress":0,"claimed":false,"reward":base * (2 if k in ["levels","specials"] else 1)})
	s.daily = {"day":today,"quests":quests}
	var yesterday := Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(today) - 86400)
	var streak := int(s.login.get("streak", 0))
	streak = (streak % 7) + 1 if s.login.get("last", "") == yesterday else 1
	s.login = {"last":today,"streak":streak,"claimed":false,"reward":base * streak}
	dirty = true
	return true

func quest_text(q: Dictionary) -> String:
	return QUEST_TEXT[q.kind] % short(q.target)

func claim_quest(i: int) -> bool:
	var quests: Array = s.daily.get("quests", [])
	if i < 0 or i >= quests.size(): return false
	var q: Dictionary = quests[i]
	if q.claimed or int(q.progress) < int(q.target): return false
	q.claimed = true
	s.coins += int(q.reward)
	event("daily_claim_" + q.kind)
	feedback.append("upgrade")
	dirty = true
	return true

func claim_login() -> bool:
	if s.login.is_empty() or s.login.claimed: return false
	s.login.claimed = true
	s.coins += int(s.login.reward)
	event("login_day_%d" % int(s.login.streak))
	feedback.append("upgrade")
	dirty = true
	return true

func claimable() -> bool:
	if not s.login.is_empty() and not s.login.claimed: return true
	for q in s.daily.get("quests", []):
		if not q.claimed and int(q.progress) >= int(q.target): return true
	return false

func pending_stars() -> int:
	return int(floor(sqrt(float(s.prestige.run_earned) / STAR_COINS)))

func can_prestige() -> bool:
	return stat("top_level") >= PRESTIGE_LEVEL and pending_stars() >= 1

# Moon Star talents: rank n costs n stars, and spending never lowers the
# star price bonus, which counts every star earned.
func talent_info(id: String) -> Dictionary:
	for t in cfg.talents:
		if t.id == id: return t
	return {}

func talent(id: String) -> int:
	return int(s.prestige.get("talents", {}).get(id, 0))

func talent_mult(id: String) -> float:
	return 1.0 + float(talent_info(id).step) * talent(id)

func talent_cost(id: String) -> int:
	return talent(id) + 1

func stars_spent() -> int:
	var n := 0
	for id in s.prestige.get("talents", {}): n += talent(id) * (talent(id) + 1) / 2
	return n

func stars_free() -> int:
	return int(s.prestige.stars) - stars_spent()

func buy_talent(id: String) -> bool:
	var t := talent_info(id)
	if t.is_empty() or talent(id) >= int(t.ranks) or stars_free() < talent_cost(id): return false
	s.prestige.talents[id] = talent(id) + 1
	event("talent_%s_%d" % [id, talent(id)])
	feedback.append("upgrade")
	dirty = true
	return true

func branch_name() -> String:
	return BRANCHES[int(s.prestige.branches) % BRANCHES.size()]

# Open a new branch: the shop starts over; stars, records and settings stay.
func open_branch() -> bool:
	if not can_prestige(): return false
	var stars := pending_stars()
	var keep := {}
	for key in ["stats","achievements","daily","login","muted","flags","elapsed","timestamp","prestige"]: keep[key] = s[key]
	s = fresh_state()
	for key in keep: s[key] = keep[key]
	s.prestige.stars = int(s.prestige.stars) + stars
	s.prestige.branches = int(s.prestige.branches) + 1
	s.prestige.run_earned = 0
	for i in range(talent("team")): s.owned[WORKERS[i]] = true
	_mult_cache.clear()
	update_tutorial()
	event("open_branch_%d" % int(s.prestige.branches))
	feedback.append("milestone")
	dirty = true
	return true

func update_tutorial():
	var conditions := [s.flags.has("first_harvest"),s.flags.has("first_brew"),s.flags.has("first_sale"),owned("gardener"),owned("brewer"),owned("cashier"),owned("recipe"),owned("renovation")]
	var stage := 0
	while stage < conditions.size() and conditions[stage]: stage += 1
	s.tutorial = stage
	if stage == conditions.size(): first("tutorial_complete")

func objective() -> String:
	return ["Garden → harvest your first peppermint","Shop → brew, then stock your first potion","Shop → serve a customer to earn coins","Hire Pip in Team • 32 coins","Hire Momo in Team • 56 coins","Hire Sol in Team • 80 coins","Unlock Dreamdrop in the Recipe Book • 48 coins","Save 320 coins for the grand glow-up",milestone_goal()][int(s.tutorial)]

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
	if not can_brew(int(s.recipe)): return "Waiting for %s • visit Garden" % cfg.crops[missing_herb(int(s.recipe))].name
	return "Ready to brew • " + cfg.recipes[int(s.recipe)].name

# Within a run of ticks nothing changes levels, upgrades or recipes, so the
# derived numbers are computed once and read from _d by the hot functions.
var _fast := false
var _d := {}
func begin_ticks():
	_fast = false
	_d = {"gardener":owned("gardener"),"brewer":owned("brewer"),"cashier":owned("cashier"),"herb_capacity":herb_capacity(),"queue_capacity":queue_capacity(),"arrival_time":arrival_time(),"service_time":service_time(),"capacity":capacity(),"grow_time":[],"brew_time":[],"price":[]}
	for c in range(cfg.crops.size()): _d.grow_time.append(grow_time(c))
	for r in range(cfg.recipes.size()):
		_d.brew_time.append(brew_time(r))
		_d.price.append(price(r))
	_fast = true

func end_ticks():
	_fast = false

# Runs n ticks, fast-forwarding stretches where only timers advance. Each
# skipped tick repeats tick()'s float arithmetic exactly, so results match.
func run_ticks(n: int):
	var i := 0
	while i < n:
		i += quiet_ticks(n - i)
		if i < n:
			tick(cfg.step)
			i += 1

# True when a worker would act on the very next tick.
func action_due() -> bool:
	var gardener: bool = _d.gardener if _fast else owned("gardener")
	var brewer: bool = _d.brewer if _fast else owned("brewer")
	var cashier: bool = _d.cashier if _fast else owned("cashier")
	if gardener:
		for p in s.plots:
			var c := int(p.crop)
			if p.progress + 0.00001 >= grow_time(c) and s.herbs[c] + int(cfg.crops[c].yield) <= herb_capacity(): return true
	if brewer:
		if s.ready and stock_count() + int(cfg.recipes[int(s.pot)].produce) <= capacity(): return true
		if s.pot == -1 and stock_count() < capacity() and can_brew(int(s.recipe)): return true
	if cashier and not s.serving and s.queue > 0 and stock_count() > 0: return true
	return false

# Advances up to limit ticks in which no timer crosses its threshold and no
# worker can act; returns how many were applied.
func quiet_ticks(limit: int) -> int:
	if limit <= 0 or not _fast or action_due(): return 0
	var dt: float = cfg.step
	var elapsed: float = s.elapsed
	var progress := []
	var grows := []
	for p in s.plots:
		progress.append(float(p.progress))
		grows.append(float(_d.grow_time[int(p.crop)]))
	var brewing: bool = s.pot != -1 and not s.ready
	var brew_progress: float = s.brew_progress
	var brew_at: float = _d.brew_time[int(s.pot)] if brewing else 0.0
	var has_visitor: bool = not s.visitor.is_empty()
	var visitor_timer: float = s.visitor_timer
	var visitor_left: float = s.visitor.left if has_visitor else 0.0
	var arrival: float = s.arrival
	var serving: bool = s.serving
	var service: float = s.service
	var every: float = cfg.visitors.every
	var arrive_at: float = _d.arrival_time
	var serve_at: float = _d.service_time
	var done := 0
	while done < limit:
		# Stop before any tick that would cross a threshold; tick() handles it.
		for k in range(progress.size()):
			if progress[k] < grows[k] and minf(progress[k] + dt, grows[k]) + 0.00001 >= grows[k]: return commit_quiet(done, elapsed, progress, brew_progress, visitor_timer, visitor_left, arrival, service)
		if brewing and brew_progress + dt + 0.00001 >= brew_at: break
		if has_visitor:
			if visitor_left - dt <= 0: break
		elif visitor_timer + dt >= every: break
		if arrival + dt >= arrive_at: break
		if serving and service + dt + 0.00001 >= serve_at: break
		elapsed += dt
		for k in range(progress.size()): progress[k] = minf(progress[k] + dt, grows[k])
		if brewing: brew_progress += dt
		if has_visitor: visitor_left -= dt
		else: visitor_timer += dt
		arrival += dt
		if serving: service += dt
		done += 1
	return commit_quiet(done, elapsed, progress, brew_progress, visitor_timer, visitor_left, arrival, service)

func commit_quiet(done: int, elapsed: float, progress: Array, brew_progress: float, visitor_timer: float, visitor_left: float, arrival: float, service: float) -> int:
	if done == 0: return 0
	s.elapsed = elapsed
	for k in range(progress.size()): s.plots[k].progress = progress[k]
	if s.pot != -1 and not s.ready: s.brew_progress = brew_progress
	if s.visitor.is_empty(): s.visitor_timer = visitor_timer
	else: s.visitor.left = visitor_left
	s.arrival = arrival
	if s.serving: s.service = service
	return done

func simulate(seconds: float):
	var count := int(floor(maxf(0.0, seconds) / cfg.step))
	begin_ticks()
	run_ticks(count)
	end_ticks()
	check_achievements()
	feedback.clear()

func offline_cap() -> float:
	var extra := float(talent_info("night").step) * talent("night")
	if owned("offline_8"): return 28800.0 + extra
	if owned("offline_4"): return 14400.0 + extra
	return float(cfg.offline_cap) + extra

func offline(now: float) -> Dictionary:
	var job := begin_offline(now)
	step_offline(job, int(job.steps))
	return finish_offline(job)

# Catch-up in three parts so the UI can spread long absences across frames.
func begin_offline(now: float) -> Dictionary:
	var away: float = now - s.timestamp if s.timestamp > 0 else 0.0
	var elapsed := clampf(away,0.0,offline_cap())
	return {"now":now,"away":away,"elapsed":elapsed,"steps":int(floor(elapsed / cfg.step)),"done":0,"before":int(s.coins),"counted":tally.duplicate()}

# Runs up to max_steps ticks; true once the whole absence is simulated.
func step_offline(job: Dictionary, max_steps: int) -> bool:
	var n := mini(max_steps, int(job.steps) - int(job.done))
	begin_ticks()
	run_ticks(n)
	end_ticks()
	job.done = int(job.done) + n
	return int(job.done) >= int(job.steps)

# Timestamp to save if the app pauses mid catch-up: only the simulated part
# counts as caught up, so the rest is neither lost nor credited twice.
func partial_timestamp(job: Dictionary) -> float:
	return float(job.now) - (int(job.steps) - int(job.done)) * float(cfg.step)

func finish_offline(job: Dictionary) -> Dictionary:
	check_achievements()
	feedback.clear()
	var now: float = job.now
	# A high-water timestamp prevents replay after a backwards clock change.
	s.timestamp = maxf(now,s.timestamp)
	var report := {"seconds":int(job.elapsed),"coins":int(s.coins)-int(job.before),"capped":float(job.away) > offline_cap() + 1.0,"cap":int(offline_cap())}
	for key in tally: report[key] = tally[key] - job.counted[key]
	if float(job.elapsed) >= 10:
		s.offline_notice = report
		event("offline_reward_claim")
	return report

func valid(v: Variant) -> bool:
	if not v is Dictionary or v.get("version") != VERSION: return false
	for key in s:
		if not v.has(key): return false
	if not v.visitor is Dictionary: return false
	if not v.visitor.is_empty():
		if not v.visitor.get("kind") in ["request","vip"] or not (v.visitor.get("recipe") is float or v.visitor.get("recipe") is int) or not (v.visitor.get("left") is float or v.visitor.get("left") is int): return false
		if int(v.visitor.recipe) < 0 or int(v.visitor.recipe) >= cfg.recipes.size(): return false
	for key in ["coins","elapsed","timestamp","brew_progress","service","arrival","tutorial","queue","visitor_timer"]:
		if not (v[key] is float or v[key] is int) or not is_finite(float(v[key])) or v[key] < 0: return false
	for key in ["herbs","stock"]:
		if not v[key] is Array or v[key].size() != (cfg.crops.size() if key == "herbs" else cfg.recipes.size()): return false
		for n in v[key]:
			if not (n is float or n is int) or n < 0 or n != floor(n): return false
	if not v.owned is Dictionary or not v.flags is Dictionary or not v.offline_notice is Dictionary: return false
	for key in ["daily","login","stats","achievements","prestige"]:
		if not v[key] is Dictionary: return false
	for key in ["stars","branches","run_earned"]:
		var n = v.prestige.get(key)
		if not (n is float or n is int) or n < 0 or n != floor(n): return false
	if not v.prestige.get("talents") is Dictionary: return false
	var spent := 0
	for id in v.prestige.talents:
		var rank = v.prestige.talents[id]
		var info := talent_info(str(id))
		if info.is_empty() or not (rank is float or rank is int) or rank != floor(rank) or rank < 0 or rank > int(info.ranks): return false
		spent += int(rank) * (int(rank) + 1) / 2
	if spent > int(v.prestige.stars): return false
	if v.daily.has("quests"):
		if not v.daily.quests is Array: return false
		for q in v.daily.quests:
			if not q is Dictionary or not QUEST_TEXT.has(q.get("kind")): return false
	for key in v.owned:
		if not v.owned[key] is bool: return false
	for key in ["ready","serving","muted"]:
		if not v[key] is bool: return false
	for key in ["recipe","pot"]:
		if not (v[key] is int or v[key] is float) or v[key] != floor(v[key]): return false
	if int(v.recipe) < 0 or int(v.recipe) >= cfg.recipes.size() or int(v.pot) < -1 or int(v.pot) >= cfg.recipes.size() or v.tutorial > 8 or v.queue > 3 + cfg.milestones.size(): return false
	if not v.levels is Dictionary: return false
	if not v.decor is Dictionary: return false
	for kind in ["floor","wall"]:
		var variant = v.decor.get(kind)
		if not (variant is int or variant is float) or variant != floor(variant) or int(variant) not in [0,1,2]: return false
		if not v.decor.get("manual_"+kind) is bool: return false
	for id in STATIONS:
		var n = v.levels.get(id)
		if not (n is float or n is int) or n != floor(n) or n < 1 or n > cfg.max_level: return false
	# Saves from before worker levels have none; level() reads those as 1.
	for id in WORKERS:
		var n = v.levels.get(id, 1)
		if not (n is float or n is int) or n != floor(n) or n < 1 or n > cfg.max_level: return false
	if v.ready and v.pot == -1: return false
	if not v.plots is Array or v.plots.size() < 2 or v.plots.size() > MAX_PLOTS: return false
	for p in v.plots:
		if not p is Dictionary or not (p.get("crop") is int or p.get("crop") is float): return false
		if p.crop != floor(p.crop) or int(p.crop) < 0 or int(p.crop) >= cfg.crops.size(): return false
		if not (p.get("progress") is float or p.get("progress") is int) or p.progress < 0 or not is_finite(float(p.progress)): return false
	return true
