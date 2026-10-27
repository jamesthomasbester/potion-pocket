extends SceneTree

func _initialize(): call_deferred("capture")

func capture():
	var app=load("res://game/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	app.model.s.owned.gardener=true
	app.model.s.owned.brewer=true
	app.model.s.owned.cashier=true
	app.model.s.owned.recipe=true
	app.model.s.stock=[3,1,0,0,0]
	app.model.s.queue=3
	app.model.s.pot=0
	app.model.s.brew_progress=1.0
	app.model.s.serving=true
	app.model.s.service=.5
	for plot in app.model.s.plots:
		plot.progress=app.model.grow_time(int(plot.crop))*.6
	app.settings_box.hide()
	app.switch_tab("shop")
	app.refresh()
	# Let the queue walk in, then freeze everyone mid-pose.
	for i in range(60): app.shop._process(.1)
	app.shop.clock=0
	await process_frame
	await app.screenshot("animation-shop-work")
	app.shop.actor_timers["brewer"]=.7
	app.shop.actor_timers["owner"]=.7
	app.shop.customers[0].hold=.6
	app.shop._process(.05)
	await process_frame
	await app.screenshot("animation-shop-pickup")
	app.switch_tab("garden")
	app.room.actor_timers["gardener"]=0
	app.room.clock=0
	app.room.queue_redraw()
	await process_frame
	await app.screenshot("animation-garden-work")
	app.room.actor_timers["gardener"]=.7
	app.room.queue_redraw()
	await process_frame
	await app.screenshot("animation-garden-pickup")
	print("ANIMATION PREVIEW four action scenes captured")
	app.queue_free()
	await create_timer(.2).timeout
	quit()
