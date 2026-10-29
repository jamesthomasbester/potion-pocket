extends SceneTree
var checks:=0
var failures:=0
func check(value: bool,name: String):
	checks+=1
	if not value: failures+=1
	print("PASS " if value else "FAIL ",name)
func _initialize():
	call_deferred("run")
# A real touch at a point on screen, as a player's finger would make.
func tap_at(app,point:Vector2):
	for pressed in [true,false]:
		var e:=InputEventScreenTouch.new()
		e.index=0
		e.position=point
		e.pressed=pressed
		Input.parse_input_event(e)
		await process_frame
func run():
	var app=load("res://game/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	app.settings_box.show()
	await process_frame
	await process_frame
	await app.screenshot("layout-"+str(int(app.get_viewport_rect().size.y)))
	for b in [app.primary,app.secondary,app.shop_tab,app.garden_tab]:
		check(app.get_viewport_rect().encloses(b.get_global_rect()) and b.size.y>=48,"touch control within screen, >=48px: "+b.text)
	var before=app.model.s.duplicate(true)
	await app.tap(app.garden_tab)
	check(app.tab=="garden" and app.model.s==before,"touch tab switch preserves entire economy state")
	app.model.simulate(6)
	app.refresh()
	await app.tap(app.primary)
	check(app.model.s.herbs[0]==4,"touch harvest works")
	await app.tap(app.shop_tab)
	await app.tap(app.primary)
	check(app.model.s.pot==0 and app.model.s.herbs[0]==3,"touch brew works")
	app.model.simulate(3)
	app.refresh()
	await app.tap(app.primary)
	check(app.model.s.stock[0]==2,"touch stock works")
	await app.tap(app.secondary)
	app.model.simulate(1.8)
	check(app.model.s.coins==8,"touch sale completes valid loop")
	app.model.s.owned.recipe=true
	app.model.s.herbs=[24,0,0,0,0]
	app.settings_box.hide()
	app.show_book()
	await process_frame
	await app.tap(app.purchase_buttons["rc_1"])
	check(int(app.model.s.recipe)==1 and app.purchase_buttons["rc_1"].text=="Brewing","Recipe Book brew button selects Dreamdrop")
	check(app.purchase_labels["rc_3"][0].text=="???","recipes past the next unlock stay hidden")
	app.upgrade_layer.hide()
	app.model.simulate(8)
	app.model.harvest()
	check(app.model.s.herbs[1]==4,"switching recipe replants beds and recovers from a full old herb bin")
	await app.tap(app.garden_tab)
	var kept_coins=app.model.s.coins
	app.model.s.coins=150
	var plot_point=app.room.view_offset+app.room.bed_center(2)*app.room.view_scale
	var press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.position=plot_point
	app.room.gui_input.emit(press)
	check(app.model.s.plots.size()==3 and app.model.s.coins==0,"tapping the locked plot buys it")
	app.model.s.coins=kept_coins
	app.settings_box.show()
	app.storage.path="user://ui-lifecycle-test.json"
	app.harness=false
	app.notification(MainLoop.NOTIFICATION_APPLICATION_PAUSED)
	var recovered=load("res://game/economy.gd").new()
	check(app.storage.load_into(recovered,app.model.s.timestamp),"background notification saved recoverable state")
	check(recovered.s.herbs[1]==4 and recovered.s.flags.has("first_sale"),"background save retains inventory and tutorial flags")
	app.harness=true
	app.reset_dialog.popup_centered()
	await process_frame
	check(app.model.s.coins==8,"reset dialog does not reset before confirmation")
	app.reset_dialog.canceled.emit()
	app.reset_dialog.hide()
	check(app.model.s.coins==8,"cancel reset keeps progress")
	app.sound.set_muted(true)
	app.reset_dialog.confirmed.emit()
	check(app.model.s.coins==0 and app.model.s.owned.is_empty(),"confirmed reset clears only demo state")
	check(not app.sound.muted and not app.model.s.muted,"reset synchronizes sound and saved preference")
	app.settings_box.hide()
	await app.tap(app.shop_tab)
	app.model.s.coins=50
	app.refresh()
	await process_frame
	check(app.card_title.text=="Cauldron · Lv. 1","shop card defaults to the cauldron station")
	await app.tap(app.upgrade_button)
	check(app.model.level("cauldron")==2 and app.model.s.coins==0,"context card levels the cauldron for its listed cost")
	check(is_equal_approx(app.model.brew_time(0),3.0/1.06),"level up changes actual brew duration")
	check(app.card_title.text=="Cauldron · Lv. 2","card shows the new level")
	var counter=app.shop.prop("Counter")
	await tap_at(app,counter.to_global(Vector2(0,-90)))
	check(app.selected_station=="counter" and "Counter" in app.card_title.text,"tapping the counter selects its station")
	await tap_at(app,app.shop.prop("Lectern").to_global(Vector2(0,-200)))
	check(app.upgrade_layer.visible and app.upgrade_title.text=="Grimoire" and app.research_ui.has("tree"),"tapping the lectern opens the Grimoire's research")
	app.upgrade_layer.hide()
	check(app.coins_label.text=="0","coin header displays integer balance")
	var room_rect:Rect2=app.shop.get_node("Room").get_global_transform()*app.shop.get_node("Room").get_rect()
	var card_top:float=app.get_node("%Card").get_global_rect().position.y
	check(room_rect.end.y<=card_top+40 and room_rect.position.y>=app.stage.get_global_rect().position.y-40,"the stage frames the whole room above the card")
	app.show_decor()
	check(app.purchase_buttons["decor_floor_1"].disabled and app.purchase_buttons["decor_floor_0"].disabled,"decor menu shows locked and selected floor choices")
	app.model.s.coins=320
	app.buy("renovation")
	app.refresh()
	check(app.model.s.decor.floor==1 and app.model.s.decor.wall==1,"renovation changes visible architecture selection")
	await process_frame
	await app.tap(app.purchase_buttons["decor_floor_0"])
	check(app.model.s.decor.floor==0 and app.model.s.decor.wall==1,"touch choice switches only the floor")
	app.model.s.levels.cauldron=7
	app.shop.refresh_art()
	check(app.shop.prop("Cauldron").texture==app.shop.textures["cauldron_t3"],"cauldron art moves to its third tier at Lv. 7")
	check(app.shop.prop("Rug").texture==app.shop.textures["rug_t1"],"rug follows the chosen décor")
	for name in ["owner","brewer","cashier","customer0","customer1","departing"]:
		var sheet:Texture2D=app.shop.sheets.get(name)
		check(sheet!=null and sheet.get_width()==1024 and sheet.get_height()==1024,"16 aligned poses loaded: "+name)
	check(app.shop.direction(Vector2(-1,1))==0 and app.shop.direction(Vector2(1,1))==1 and app.shop.direction(Vector2(-1,-1))==2 and app.shop.direction(Vector2(1,-1))==3,"all four travel directions select distinct facing columns")
	var actor=app.shop.owner_actor
	actor.phase=0
	actor.clock=0
	var rows:=[]
	for action in ["idle","walk","pickup","work"]:
		actor.action=action
		rows.append(actor.pose_row())
	check(rows==[0,1,2,3],"idle, stride, pickup and work select real pose rows")
	actor.clock=.2
	actor.action="walk"
	var walk_recovery=actor.pose_row()==0
	actor.clock=.32
	actor.action="work"
	check(walk_recovery and actor.pose_row()==0,"walk and work progress to their second keyframe")
	app.model.s.queue=2
	app.shop._process(.1)
	check(app.shop.customers.size()==2 and app.shop.customers[0].actor.get_parent()==app.shop.props,"queued customers appear in the room, depth-sorted with furniture")
	for i in range(80): app.shop._process(.1)
	check(app.shop.customers[0].g==app.shop.QUEUE[0] and not app.shop.customers[0].moving,"the first customer walks in to the counter")
	app.model.s.queue=1
	app.shop._process(.1)
	check(app.shop.customers.size()==1 and app.shop.departures.size()==1 and app.shop.departures[0].hold>0,"a served customer pauses with their purchase, then leaves")
	app.model.s.queue=0
	for i in range(80): app.shop._process(.1)
	check(app.shop.departures.is_empty(),"departed customers are removed once outside")
	app.upgrade_layer.hide()
	app.model.s.owned.recipe=true
	app.model.s.stock[0]=1
	app.model.s.visitor={"kind":"request","recipe":0,"left":20.0}
	app.shop._process(.1)
	var coins_before=app.model.s.coins
	await tap_at(app,app.shop.visitor.to_global(Vector2(0,-60)))
	check(app.model.s.visitor.is_empty() and app.model.s.coins>coins_before,"tapping a special visitor serves them")
	app.shop._process(.1)
	check(app.shop.visitor==null,"served visitor leaves the room")
	app.model.s.coins=1000
	app.model.s.owned.gardener=true
	app.show_upgrades(true)
	await process_frame
	check(app.purchase_buttons["lv_brewer"].disabled and app.purchase_buttons["lv_brewer"].text=="Hire first","an unhired helper's training card is locked")
	var sc:ScrollContainer=app.upgrade_list.get_parent()
	sc.ensure_control_visible(app.purchase_buttons["lv_gardener"])
	await process_frame
	await app.tap(app.purchase_buttons["lv_gardener"])
	check(app.model.level("gardener")==2 and app.model.s.coins==900 and "Lv. 2" in app.purchase_labels["lv_gardener"][0].text,"Team card trains Pip for the listed cost")
	app.upgrade_layer.hide()
	# The Grimoire: open it from the nav bar, pick a page in the tree, study it.
	app.model.s.research.lore=10
	await app.tap(app.get_node("%GrimoireButton"))
	await process_frame
	check(app.upgrade_layer.visible and app.research_ui.has("tree") and app.grimoire_page=="rich_compost","the Grimoire opens on Herbology with the first ready page selected")
	var study_button:Button=app.research_ui.detail.button
	sc.ensure_control_visible(study_button)
	await process_frame
	await app.tap(study_button)
	check(app.model.s.research.lore==0 and app.model.page_state("rich_compost")=="studying" and study_button.text=="Studying…","the Study button starts the selected page at the lectern")
	app.model.simulate(31)
	app.refresh()
	check(app.model.rank("rich_compost")==1,"the page is learned once its study runs out")
	var tree=app.research_ui.tree
	sc.ensure_control_visible(tree)
	await process_frame
	var deep=tree.entries().filter(func(e): return e.id=="deep_bins")[0]
	await tap_at(app,tree.get_global_transform()*tree.spot(deep))
	check(app.grimoire_page=="deep_bins" and "Deep Bins" in app.research_ui.detail.title.text,"tapping a page in the tree selects it")
	app.model.s.prestige.stars=1
	await tap_at(app,app.research_ui.chips["star"].get_global_rect().get_center())
	check(app.grimoire_chapter=="star" and app.grimoire_page=="roots","the Celestial chapter holds the Moon Star talents")
	sc.ensure_control_visible(study_button)
	await process_frame
	await app.tap(study_button)
	check(app.model.talent("roots")==1 and study_button.disabled and study_button.text=="Learn • ★ 2","Celestial pages spend Moon Stars and are learned at once")
	app.show_upgrades(false)
	await process_frame
	check(not app.purchase_buttons.has("tl_roots"),"talents no longer appear in Improve")
	app.upgrade_layer.hide()
	app.model.s.prestige.branches=1
	check(app.room.theme().extra=="sea","second branch draws the seaside garden theme")
	app.sound.set_muted(true)
	await create_timer(0.4).timeout
	app.queue_free()
	await create_timer(0.2).timeout
	print("UI RESULT ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
