extends SceneTree

func _initialize(): call_deferred("capture")

func shot(app, name: String):
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	app.get_viewport().get_texture().get_image().save_png("res://docs/evidence/branches/"+name+".png")

# Captures each branch's shop and garden, plus the Team and Improve panels.
func capture():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/evidence/branches"))
	var app=load("res://game/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	var m=app.model
	for id in ["gardener","brewer","cashier","recipe","renovation"]: m.s.owned[id]=true
	for id in m.STATIONS: m.s.levels[id]=7
	m.update_auto_decor()
	for b in range(m.BRANCHES.size()):
		m.s.prestige.branches=b
		app.switch_tab("shop")
		app.shop._process(0.5)
		await shot(app,"branch-%d-shop" % b)
		app.switch_tab("garden")
		app.garden._process(0.5)
		await shot(app,"branch-%d-garden" % b)
	app.switch_tab("shop")
	m.s.prestige.stars=6
	m.s.prestige.talents={"roots":2,"team":1}
	m.s.levels.gardener=12
	m.s.coins=5000
	app.show_upgrades(true)
	await shot(app,"team-training")
	app.show_upgrades(false)
	await shot(app,"improve-talents")
	print("BRANCH PREVIEW captured")
	app.queue_free()
	await create_timer(.2).timeout
	quit()
