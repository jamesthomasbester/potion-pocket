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
	m.s.herbs=[0,1]
	m.select_recipe(1)
	check(m.brew() and m.s.herbs==[0,0],"dream consumes moonflower only")
	m.simulate(4)
	check(m.stock() and m.s.stock==[1,1],"dream produces correct bottle")
	m=E.new()
	m.s.stock=[6,0]
	m.s.herbs=[2,0]
	check(not m.brew(),"full shelf blocks production without consuming")
	m.simulate(3)
	m.serve()
	m.simulate(1.8)
	check(m.brew(),"full shelf recovers when a sale frees space")
	m=E.new()
	check(not m.brew() and m.s.herbs==[0,0],"unavailable herb safe")
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
	for key in ["coins","herbs","stock","plots","pot","brew_progress","ready","queue","arrival","service","serving","tutorial"]:
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
	check(capped.s.herbs==[0,0],"offline no gardener means no harvesting")
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
	invalid.herbs=[-1,0]
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
	m.s.herbs=[2,0]
	m.simulate(8)
	check(m.s.stock[0]==3 and m.s.herbs[0]==0 and m.s.coins==0,"brewer only consumes brews and stocks")
	m=E.new()
	m.s.owned.cashier=true
	m.simulate(10)
	check(m.s.coins==8 and m.s.stock[0]==0 and m.s.herbs[0]==0,"cashier only sells valid inventory")

	m=E.new()
	m.s.owned={"gardener":true,"brewer":true,"cashier":true,"recipe":true}
	m.s.herbs=[24,0]
	m.select_crop(1)
	m.select_recipe(1)
	m.simulate(20)
	check(m.s.coins>0 and m.s.herbs[1]>0,"recipe switch recovers with saturated old ingredient bin")
	m=E.new()
	m.s.stock=[6,0]
	m.s.pot=1
	m.s.ready=true
	check(not m.stock() and m.s.ready,"completed potion waits intact at full shelf")
	m.simulate(3)
	m.serve()
	m.simulate(1.8)
	check(m.stock() and m.s.stock[1]==1,"waiting completed potion stocks after capacity clears")
	m=E.new()
	m.s.herbs=[1,0]
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
	print("RESULT ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
