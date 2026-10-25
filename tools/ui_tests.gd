extends SceneTree
var checks:=0
var failures:=0
func check(value: bool,name: String):
	checks+=1
	if not value: failures+=1
	print("PASS " if value else "FAIL ",name)
func _initialize():
	call_deferred("run")
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
	var counter_point=app.room.view_offset+app.room.station_pos("counter")*app.room.view_scale-Vector2(0,40*app.room.view_scale)
	press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.position=counter_point
	app.room.gui_input.emit(press)
	check(app.selected_station=="counter" and "Counter" in app.card_title.text,"tapping the counter selects its station")
	check(app.coins_label.text=="0","coin header displays integer balance")
	check(app.room.clip_contents and app.room.size.y>=340,"scene stays clipped inside responsive scene area")
	app.show_decor()
	check(app.purchase_buttons["decor_floor_1"].disabled and app.purchase_buttons["decor_floor_0"].disabled,"decor menu shows locked and selected floor choices")
	app.model.s.coins=320
	app.buy("renovation")
	app.refresh()
	check(app.model.s.decor.floor==1 and app.model.s.decor.wall==1,"renovation changes visible architecture selection")
	await process_frame
	await app.tap(app.purchase_buttons["decor_floor_0"])
	check(app.model.s.decor.floor==0 and app.model.s.decor.wall==1,"touch choice switches only the floor")
	check(app.room.textures.has("cauldron_t3") and app.room.textures.has("moonflower_t3"),"master furniture and plants are loaded into the playable scene")
	for name in ["owner","brewer","cashier","gardener","customer0","customer1","departing"]:
		var sheet:Texture2D=app.room.character_sheets.get(name)
		check(sheet!=null and sheet.get_width()==1024 and sheet.get_height()==1024,"16 aligned poses loaded: "+name)
	check(app.room.direction(Vector2(-1,1))==0 and app.room.direction(Vector2(1,1))==1 and app.room.direction(Vector2(-1,-1))==2 and app.room.direction(Vector2(1,-1))==3,"all four travel directions select distinct facing columns")
	app.room.clock=0
	check(app.room.pose_row("idle")==0 and app.room.pose_row("walk")==1 and app.room.pose_row("pickup")==2 and app.room.pose_row("work")==3,"idle, stride, pickup and work select real pose rows")
	app.room.clock=.2
	var walk_recovery=app.room.pose_row("walk")==0
	app.room.clock=.32
	check(walk_recovery and app.room.pose_row("work")==0,"walk and work progress to their second keyframe")
	var visitor={"g":app.room.DOOR,"path":[],"dir":2,"moving":false,"hold":.5,"variant":0}
	app.room.walk(visitor,app.room.DOOR+Vector2(1,0),.2)
	check(not visitor.moving and visitor.g==app.room.DOOR and app.room.customer_action(visitor)=="pickup","customer pauses to pick up a purchase")
	app.room.walk(visitor,app.room.DOOR+Vector2(1,0),.5)
	app.room.walk(visitor,app.room.DOOR+Vector2(1,0),.2)
	check(visitor.moving and visitor.dir==1 and app.room.customer_action(visitor)=="walk","customer resumes with direction-aware walking")
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
	app.model.s.prestige.stars=1
	app.show_upgrades(false)
	await process_frame
	sc.ensure_control_visible(app.purchase_buttons["tl_roots"])
	await process_frame
	await app.tap(app.purchase_buttons["tl_roots"])
	check(app.model.talent("roots")==1 and app.purchase_buttons["tl_roots"].disabled and app.purchase_buttons["tl_roots"].text=="★ 2","Improve card spends a Moon Star on a talent")
	app.upgrade_layer.hide()
	app.model.s.prestige.branches=1
	check(app.room.theme().extra=="sea","second branch draws the seaside theme")
	app.sound.set_muted(true)
	await create_timer(0.4).timeout
	app.queue_free()
	await create_timer(0.2).timeout
	print("UI RESULT ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
