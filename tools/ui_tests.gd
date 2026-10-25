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
	for b in [app.primary,app.secondary,app.choice0,app.choice1,app.shop_tab,app.garden_tab]:
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
	app.model.s.herbs=[24,0]
	await app.tap(app.garden_tab)
	await app.tap(app.choice1)
	app.model.simulate(8)
	app.model.harvest()
	check(app.model.s.herbs[1]==4,"switching crop recovers from full old herb inventory")
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
	var press=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.position=counter_point
	app.room.gui_input.emit(press)
	check(app.selected_station=="counter" and "Counter" in app.card_title.text,"tapping the counter selects its station")
	check(app.coins_label.text=="0","coin header displays integer balance")
	check(app.room.clip_contents and app.room.size.y>=340,"scene stays clipped inside responsive scene area")
	app.sound.set_muted(true)
	await create_timer(0.4).timeout
	app.queue_free()
	await create_timer(0.2).timeout
	print("UI RESULT ",checks," checks / ",failures," failures")
	quit(1 if failures else 0)
