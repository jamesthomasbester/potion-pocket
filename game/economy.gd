extends RefCounted

var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))
var s: Dictionary
var events: Array = []
var feedback: Array = []
var dirty := false

func _init():
	fresh()

func fresh():
	s = {"version":1,"coins":int(cfg.starting_coins),"herbs":[0,0],"stock":[int(cfg.starting_stock),0],"plots":[{"crop":0,"progress":0.0},{"crop":0,"progress":0.0}],"crop":0,"recipe":0,"pot":-1,"brew_progress":0.0,"ready":false,"queue":0,"arrival":0.0,"service":0.0,"serving":false,"owned":{},"flags":{},"elapsed":0.0,"timestamp":0.0,"muted":false,"offline_notice":{},"tutorial":0}
	events.clear()
	feedback.clear()
	dirty = true

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
	return int(cfg.shelf_capacity) * (2 if owned("capacity") else 1)

func grow_time(crop: int) -> float:
	return float(cfg.crops[crop].grow) / (1.5 if owned("grow") else 1.0)

func brew_time(recipe: int) -> float:
	return float(cfg.recipes[recipe].brew) / (1.5 if owned("brew") else 1.0)

func price(recipe: int) -> int:
	return int(round(cfg.recipes[recipe].price * (1.25 if owned("renovation") else 1.0)))

func harvest() -> bool:
	var did := false
	for p in s.plots:
		var c := int(p.crop)
		var amount := int(cfg.crops[c].yield)
		if p.progress >= grow_time(c) and s.herbs[c] + amount <= cfg.herb_capacity:
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
	if s.arrival >= cfg.arrival_seconds:
		s.arrival = 0.0
		s.queue = min(3, s.queue + 1)
	if owned("cashier"): serve()
	if s.serving:
		s.service += dt
		if s.service + 0.00001 >= cfg.service_seconds / (2.0 if owned("service") else 1.0):
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
	return ["Garden → harvest your first peppermint","Shop → brew, then stock your first potion","Shop → serve a customer to earn coins","Hire Pip in Team • 32 coins","Hire Momo in Team • 56 coins","Hire Sol in Team • 80 coins","Unlock Dreamdrop in Improve • 48 coins","Save 320 coins for the grand glow-up","Your shop runs itself. What will you improve next?"][int(s.tutorial)]

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
	if not v is Dictionary or v.get("version") != 1: return false
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
	if int(v.crop) not in [0,1] or int(v.recipe) not in [0,1] or int(v.pot) not in [-1,0,1] or v.tutorial > 8 or v.queue > 3: return false
	if v.ready and v.pot == -1: return false
	if not v.plots is Array or v.plots.size() != 2: return false
	for p in v.plots:
		if not p is Dictionary or not (p.get("crop") is int or p.get("crop") is float): return false
		if p.crop != floor(p.crop) or int(p.crop) not in [0,1]: return false
		if not (p.get("progress") is float or p.get("progress") is int) or p.progress < 0 or not is_finite(float(p.progress)): return false
	return true
