extends SceneTree

func _initialize(): call_deferred("capture")

func capture():
	var app=load("res://game/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	for tier in range(1,4):
		var lv=[1,3,7][tier-1]
		for id in app.model.STATIONS: app.model.s.levels[id]=lv
		app.model.s.owned.recipe=tier>=2
		app.model.s.owned.renovation=tier>=2
		app.model.s.owned.gardener=tier>=2
		app.model.s.owned.brewer=tier>=2
		app.model.s.owned.cashier=tier>=2
		app.model.update_auto_decor()
		app.model.s.crop=1 if tier>=2 else 0
		app.model.s.recipe=1 if tier>=2 else 0
		app.model.s.stock=[1,0] if tier==1 else [2,1] if tier==2 else [3,3]
		for plot in app.model.s.plots:
			plot.crop=int(app.model.s.crop)
			plot.progress=app.model.grow_time(int(plot.crop))
		app.model.s.coins=0
		app.room.custom_minimum_size.y=340
		app.switch_tab("shop")
		app.refresh()
		app.room.queue_redraw()
		await process_frame
		await app.screenshot("shop-tier-%d" % tier)
		app.switch_tab("garden")
		app.refresh()
		app.room.queue_redraw()
		await process_frame
		await app.screenshot("garden-tier-%d" % tier)
	print("ART PREVIEW six tier scenes captured")
	app.queue_free()
	await create_timer(.2).timeout
	quit()
