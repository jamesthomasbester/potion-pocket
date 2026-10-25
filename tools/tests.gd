extends SceneTree
const E=preload("res://game/economy.gd")
const S=preload("res://game/storage.gd")
var checks:=0
var failures:=0
func check(condition: bool, name: String):
	checks+=1
	if not condition:
		failures+=1
		print("FAIL ",name)
	else: print("PASS ",name)
# Pad short literals to the full crop (5) and potion (8) inventories.
func H(a: Array) -> Array:
	var out:=a.duplicate()
	while out.size()<5: out.append(0)
	return out
func P(a: Array) -> Array:
	var out:=a.duplicate()
	while out.size()<8: out.append(0)
	return out
func _initialize():
	var m=E.new()
	m.simulate(6)
	check(m.harvest() and m.s.herbs[0]==4,"two beds yield four herbs")
	check(not m.harvest(),"rapid harvest cannot duplicate")
	check(m.brew() and m.s.herbs[0]==3,"energy consumes one peppermint")
	check(not m.brew(),"rapid brew cannot consume twice")
	m.simulate(3)
	check(m.stock() and m.s.stock[0]==2,"energy produces one bottle")
	check(not m.stock(),"rapid stock cannot duplicate")
	check(m.serve(),"customer can start checkout")
	check(not m.serve(),"rapid checkout cannot duplicate")
	m.simulate(1.8)
	check(m.s.coins==8 and m.s.stock[0]==1,"valid sale deducts bottle and grants price")
	m.s.coins=1000
	for p in m.cfg.purchases:
		var before=m.s.coins
		check(m.purchase(p.id) and m.s.coins==before-p.cost,"purchase charges once: "+p.id)
		check(not m.purchase(p.id) and m.s.coins==before-p.cost,"duplicate purchase rejected: "+p.id)
	check(is_equal_approx(m.grow_time(0),4.0) and is_equal_approx(m.brew_time(0),2.0) and m.capacity()==12 and m.price(0)==10,"displayed upgrade effects")
	m=E.new()
	m.s.owned.recipe=true
	m.s.herbs=H([0,1])
	m.select_recipe(1)
	check(m.brew() and m.s.herbs==H([]),"dream consumes moonflower only")
	m.simulate(4)
	check(m.stock() and m.s.stock==P([1,1]),"dream produces correct bottle")
	m=E.new()
	m.s.stock=P([6])
	m.s.herbs=H([2])
	check(not m.brew(),"full shelf blocks production without consuming")
	m.simulate(3)
	m.serve()
	m.simulate(1.8)
	check(m.brew(),"full shelf recovers when a sale frees space")
	m=E.new()
	check(not m.brew() and m.s.herbs==H([]),"unavailable herb safe")
	m.s.owned={"gardener":true,"brewer":true,"cashier":true}
	m.simulate(120)
	check(m.s.coins>150,"three helpers grow brew stock sell without manual work")
	check(m.s.herbs[0]>=0 and m.s.stock[0]>=0 and m.s.stock[0]<=m.capacity(),"automation respects inventory limits")
	var online=E.new()
	online.s=m.s.duplicate(true)
	var offline=E.new()
	offline.s=m.s.duplicate(true)
	online.simulate(60)
	offline.s.timestamp=1000.0
	offline.offline(1060)
	for key in ["coins","herbs","stock","plots","pot","brew_progress","ready","queue","arrival","service","serving","tutorial","visitor","visitor_timer"]:
		check(online.s[key]==offline.s[key],"online/offline same rules: "+key)
	var coins=offline.s.coins
	offline.offline(1060)
	check(offline.s.coins==coins,"same interval cannot credit twice")
	offline.offline(900)
	check(offline.s.coins==coins and offline.s.timestamp==1060,"negative clock preserves high-water mark")
	offline.offline(1050)
	check(offline.s.coins==coins,"clock recovery cannot replay elapsed time")
	var capped=E.new()
	capped.s.timestamp=1000
	var report=capped.offline(100000)
	check(report.seconds==7200 and capped.s.coins==0,"two-hour cap and no unattended manual sales")
	check(capped.s.herbs==H([]),"offline no gardener means no harvesting")
	var store=S.new()
	store.path="user://rules-test.json"
	store.reset(m)
	m.s.owned={"gardener":true,"brewer":true,"cashier":true}
	m.simulate(37)
	m.s.timestamp=2000
	check(store.save(m,2000),"atomic save succeeds")
	var restored=E.new()
	check(store.load_into(restored,2000),"load succeeds")
	check(JSON.parse_string(JSON.stringify(m.s))==restored.s,"all inventory progress tutorial workers selections round trip")
	check(store.save(restored,2000),"backup rotation succeeds")
	var f=FileAccess.open(store.path,FileAccess.WRITE)
	f.store_string("broken")
	f.close()
	var recovered=E.new()
	check(store.load_into(recovered,2000) and recovered.s.coins==m.s.coins,"corrupt main recovers backup")
	var invalid=m.s.duplicate(true)
	invalid.herbs=H([-1])
	check(not m.valid(invalid),"negative inventory rejected")
	invalid=m.s.duplicate(true)
	invalid.plots=[{"crop":99,"progress":0},{}]
	check(not m.valid(invalid),"invalid crop save rejected")
	# Independent gardener/brewer/cashier behavior.
	m=E.new()
	m.s.owned.gardener=true
	m.simulate(12)
	check(m.s.herbs[0]>0 and m.s.coins==0 and m.s.stock[0]==1,"gardener only removes harvesting work")
	m=E.new()
	m.s.owned.brewer=true
	m.s.herbs=H([2])
	m.simulate(8)
	check(m.s.stock[0]==3 and m.s.herbs[0]==0 and m.s.coins==0,"brewer only consumes brews and stocks")
	m=E.new()
	m.s.owned.cashier=true
	m.simulate(10)
	check(m.s.coins==8 and m.s.stock[0]==0 and m.s.herbs[0]==0,"cashier only sells valid inventory")

	m=E.new()
	m.s.owned={"gardener":true,"brewer":true,"cashier":true,"recipe":true}
	m.s.herbs=H([24])
	m.select_recipe(1)
	m.simulate(20)
	check(m.s.coins>0 and m.s.herbs[1]>0,"recipe switch recovers with saturated old ingredient bin")
	m=E.new()
	m.s.stock=P([6])
	m.s.pot=1
	m.s.ready=true
	check(not m.stock() and m.s.ready,"completed potion waits intact at full shelf")
	m.simulate(3)
	m.serve()
	m.simulate(1.8)
	check(m.stock() and m.s.stock[1]==1,"waiting completed potion stocks after capacity clears")
	m=E.new()
	m.s.herbs=H([1])
	m.brew()
	m.s.owned.recipe=true
	m.select_recipe(1)
	m.simulate(3)
	m.stock()
	check(m.s.stock[0]==2 and m.s.stock[1]==0,"switching recipe preserves in-flight potion identity")
	var cap_auto=E.new()
	cap_auto.s.owned={"gardener":true,"brewer":true,"cashier":true}
	cap_auto.s.timestamp=1000.0
	var cap_online=E.new()
	cap_online.s=cap_auto.s.duplicate(true)
	cap_online.simulate(7200)
	cap_auto.offline(100000)
	check(cap_auto.s.coins==cap_online.s.coins and cap_auto.s.stock==cap_online.s.stock,"fully automated offline production obeys two-hour cap")
	store.path="user://offline-repeat-test.json"
	store.reset(cap_auto)
	cap_auto.s.owned={"gardener":true,"brewer":true,"cashier":true}
	cap_auto.s.timestamp=1000.0
	store.save(cap_auto,1000)
	var first_load=E.new()
	store.load_into(first_load,1060)
	var second_load=E.new()
	store.load_into(second_load,1060)
	check(first_load.s.coins>0 and first_load.s.coins==second_load.s.coins,"offline credited once across repeated process loads")
	f=FileAccess.open(store.path,FileAccess.WRITE)
	f.store_string('{"version":999}')
	f.close()
	var future=E.new()
	check(not store.load_into(future,1060) and store.locked,"future save version never silently overwritten")
	check(not store.save(future,1060),"write blocked after future-schema refusal")
	# Station levels.
	m=E.new()
	check(m.level("cauldron")==1 and is_equal_approx(m.station_mult("cauldron"),1.0) and m.capacity()==6 and m.price(1)==13,"level 1 stations match original economy")
	check(m.level_cost("cauldron")==50 and not m.level_up("cauldron"),"level up needs its cost")
	m.s.coins=50
	check(m.level_up("cauldron") and m.s.coins==0 and m.level("cauldron")==2,"level up charges once and raises level")
	check(m.level_cost("cauldron")==59,"cost grows by level_growth")
	check(is_equal_approx(m.brew_time(0),3.0/1.06),"each level adds level_speed")
	m.s.levels.cauldron=9
	m.s.coins=1000000
	m.feedback.clear()
	m.level_up("cauldron")
	check(m.feedback.has("milestone") and is_equal_approx(m.station_mult("cauldron"),(1+0.06*9)*2.0),"level 10 milestone doubles the station")
	m.s.levels.shelf=10
	check(m.price(0)==int(round(8*1.9*2)) and m.capacity()==15,"shelf levels raise price and space")
	m.s.levels.counter=25
	check(m.queue_capacity()==5 and is_equal_approx(m.arrival_time(),3.0/((1+0.06*24)*4.0)),"counter milestones add customers and queue spots")
	m.s.levels.garden=100
	check(not m.level_up("garden") and m.level("garden")==100,"max level cannot be exceeded")
	check(m.short(999)=="999" and m.short(12345)=="12.3K" and m.short(2500000)=="2.50M","short number format")
	m=E.new()
	m.s.levels.counter=7
	check(m.milestone_goal().begins_with("Counter Lv. 7/10") or m.goal_station()=="counter","goal picks the station nearest a milestone")
	var legacy=JSON.parse_string(JSON.stringify(E.new().s))
	legacy.version=1
	legacy.erase("levels")
	check(m.valid(m.migrate(legacy)) and legacy.levels.cauldron==1,"version 1 save migrates with level 1 stations")
	store=S.new()
	store.path="user://migrate-test.json"
	f=FileAccess.open(store.path,FileAccess.WRITE)
	var old=JSON.parse_string(JSON.stringify(E.new().s))
	old.version=1
	old.erase("levels")
	old.coins=77
	f.store_string(JSON.stringify(old))
	f.close()
	var upgraded=E.new()
	check(store.load_into(upgraded,0) and upgraded.s.coins==77 and upgraded.s.version==4 and not store.locked,"old save file loads after the update")
	invalid=upgraded.s.duplicate(true)
	invalid.levels.shelf=0
	check(not m.valid(invalid),"invalid station level rejected")
	# Decorative choices survive saves and cannot be selected before unlocking.
	m=E.new()
	check(not m.select_decor("floor",1) and m.s.decor.floor==0,"renovation floor stays locked")
	m.s.coins=320
	check(m.purchase("renovation") and m.s.decor.floor==1 and m.s.decor.wall==1,"renovation applies its new floor and wall")
	check(m.select_decor("floor",0) and m.s.decor.manual_floor,"owned floor choices can be selected")
	m.s.levels.garden=6
	m.s.coins=100000
	check(m.level_up("garden") and m.decor_unlocked("floor",2) and m.s.decor.floor==0,"garden tier 3 unlocks botanical tile without overriding a manual choice")
	m.s.levels.counter=6
	check(m.level_up("counter") and m.decor_unlocked("wall",2) and m.s.decor.wall==2,"counter tier 3 unlocks and applies ivy wall")
	check(m.select_decor("wall",0) and m.valid(m.s),"selected architecture validates")
	invalid=m.s.duplicate(true)
	invalid.decor.floor=4
	check(not m.valid(invalid),"invalid decoration index rejected")
	store=S.new()
	store.path="user://decor-test.json"
	check(store.save(m,2000),"decorated game saves")
	var decor_restored=E.new()
	check(store.load_into(decor_restored,2000) and int(decor_restored.s.decor.floor)==int(m.s.decor.floor) and int(decor_restored.s.decor.wall)==int(m.s.decor.wall) and decor_restored.s.decor.manual_floor==m.s.decor.manual_floor and decor_restored.s.decor.manual_wall==m.s.decor.manual_wall,"floor and wall choices survive load")
	var version_two=JSON.parse_string(JSON.stringify(E.new().s))
	version_two.version=2
	version_two.erase("decor")
	version_two.owned.renovation=true
	check(m.valid(m.migrate(version_two)) and version_two.decor.floor==1 and version_two.decor.wall==1,"version 2 save migrates renovation appearance")
	# Recipe Book, crops and garden plots.
	m=E.new()
	check(m.s.herbs.size()==5 and m.s.stock.size()==8 and m.s.stock[0]==1,"inventories cover every crop and potion")
	m.s.coins=1000000
	check(not m.unlock_recipe(2) and not m.recipe_unlocked(2),"recipes unlock in book order")
	check(m.unlock_recipe(1) and m.s.coins==1000000-48 and m.owned("recipe") and int(m.s.recipe)==1,"unlocking Dreamdrop charges, keeps the old key and selects it")
	check(m.unlock_recipe(2) and int(m.s.recipe)==2,"Calm Tea unlocks next")
	m.s.herbs=H([1,1])
	m.s.stock=P([])
	check(m.brew() and m.s.herbs==H([]),"Calm Tea consumes one peppermint and one moonflower")
	m.s.herbs=H([1])
	m.s.pot=-1
	check(not m.brew() and m.missing_herb(2)==1,"two-herb recipe waits for the missing herb")
	var used=[]
	for plot in m.s.plots: used.append(int(plot.crop))
	check(0 in used and 1 in used,"beds split between the recipe's two crops")
	m=E.new()
	for r in range(1,8): m.s.owned[m.recipe_key(r)]=true
	m.s.owned.gardener=true
	m.select_recipe(7)
	m.simulate(120)
	check(m.s.herbs[1]>0 and m.s.herbs[3]>0 and m.s.herbs[4]>0,"two beds rotate through all three Aurora crops")
	m=E.new()
	m.s.stock=P([1,0,0,2])
	m.s.queue=1
	m.serve()
	m.simulate(1.8)
	check(m.s.stock==P([1,0,0,1]) and m.s.coins==45,"customers buy the most valuable potion first")
	m=E.new()
	check(m.plot_cost()==150 and not m.buy_plot(),"third plot costs 150")
	m.s.coins=10000000
	for i in range(4): m.buy_plot()
	check(m.s.plots.size()==6 and not m.buy_plot() and m.s.coins==10000000-150-1500-12000-90000,"four plots can be bought, up to six")
	check(m.valid(m.s),"six-plot save validates")
	invalid=m.s.duplicate(true)
	invalid.plots.append({"crop":0,"progress":0})
	check(not m.valid(invalid),"seven plots rejected")
	var v3=JSON.parse_string(JSON.stringify(E.new().s))
	v3.version=3
	v3.herbs=[3,4]
	v3.stock=[2,1]
	v3.crop=1
	v3=m.migrate(v3)
	check(m.valid(v3) and v3.herbs==H([3,4]) and v3.stock==P([2,1]) and not v3.has("crop"),"version 3 save migrates to the Recipe Book")
	# Special visitors.
	m=E.new()
	m.simulate(60)
	check(m.s.visitor.is_empty(),"no special visitors before Dreamdrop or Sol")
	m.s.owned.recipe=true
	m.s.visitor={"kind":"request","recipe":1,"left":30.0}
	m.s.stock=P([3])
	check(not m.serve_visitor() and m.visitor_potion()==-1,"request waits for its exact potion")
	m.s.stock=P([3,1])
	check(m.serve_visitor() and m.s.coins==39 and m.s.stock==P([3]) and m.s.visitor.is_empty(),"request pays three times the potion price")
	m.s.visitor={"kind":"vip","recipe":0,"left":30.0}
	m.s.stock=P([1,0,1])
	check(m.serve_visitor() and m.s.coins==39+300 and m.s.stock==P([1]),"VIP takes the best potion for ten times its price")
	m.s.visitor={"kind":"vip","recipe":0,"left":0.5}
	m.simulate(1)
	check(m.s.visitor.is_empty(),"unserved visitors leave when their wait ends")
	m=E.new()
	m.s.owned={"recipe":true,"cashier":true}
	m.simulate(600)
	check(m.events.any(func(e): return e.event.begins_with("missed_")),"visitors arrive on their own over time")
	invalid=m.s.duplicate(true)
	invalid.visitor={"kind":"dragon","recipe":0,"left":3}
	check(not m.valid(invalid),"unknown visitor kind rejected")
	var no_visitor=JSON.parse_string(JSON.stringify(E.new().s))
	no_visitor.erase("visitor")
	no_visitor.erase("visitor_timer")
	check(m.valid(m.migrate(no_visitor)) and no_visitor.visitor.is_empty(),"early version 4 saves gain visitor defaults")
	print("RESULT ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
