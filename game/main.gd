extends Control
const Economy = preload("res://game/economy.gd")
const Storage = preload("res://game/storage.gd")
const Room = preload("res://game/room.gd")
const Sound = preload("res://game/sound.gd")
var model = Economy.new()
var storage = Storage.new()
var room
var sound
var tab := "shop"
var accumulator := 0.0
var save_timer := 0.0
var ui_timer := 0.0
var styled_tab := ""
var header: Label
var coins_label: Label
var objective: Label
var status: Label
var inventory: Label
var primary: Button
var secondary: Button
var choice0: Button
var choice1: Button
var shop_tab: Button
var garden_tab: Button
var mute: Button
var upgrade_layer: PanelContainer
var upgrade_list: VBoxContainer
var purchase_buttons := {}
var modal: AcceptDialog
var reset_dialog: ConfirmationDialog
var root_box: VBoxContainer
var settings_box: VBoxContainer
var card_icon: TextureRect
var card_title: Label
var card_detail: Label
var upgrade_button: Button
var harness := false
var perf_frames: Array[float] = []
var perf_clock := 0.0
var session_events_path := "user://events.jsonl"
const INK = Color("191b43")
const CREAM = Color("fff7eb")
const TEAL = Color("65bd85")
const MINT = Color("72c9a0")

func style(c: Color, radius: int = 14) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color=c
	st.set_corner_radius_all(radius)
	st.content_margin_left=12
	st.content_margin_right=12
	st.content_margin_top=6
	st.content_margin_bottom=6
	return st

func label(value: String, font_size: int = 20) -> Label:
	var l:=Label.new()
	l.text=value
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",INK)
	return l

func button(value: String, action: Callable, min_height: float = 64) -> Button:
	var b:=Button.new()
	b.text=value
	b.custom_minimum_size.y=min_height
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size",18)
	b.add_theme_color_override("font_color",INK)
	b.add_theme_color_override("font_disabled_color",Color("607772"))
	b.add_theme_stylebox_override("normal",style(TEAL))
	b.add_theme_stylebox_override("hover",style(TEAL.lightened(0.12)))
	b.add_theme_stylebox_override("pressed",style(Color("b77c53")))
	b.add_theme_stylebox_override("disabled",style(Color("d8e1d7")))
	b.pressed.connect(action)
	return b

func row() -> HBoxContainer:
	var r:=HBoxContainer.new()
	r.add_theme_constant_override("separation",10)
	return r

func _ready():
	harness = "--qa" in OS.get_cmdline_user_args() or "--ui-test" in OS.get_cmdline_user_args()
	if harness:
		storage.path="user://qa_play.json"
		storage.reset(model)
	else:
		storage.load_into(model)
	model.event("session_start")
	sound=Sound.new()
	add_child(sound)
	sound.set_muted(model.s.muted)
	build_ui()
	refresh()
	if storage.locked:
		modal.dialog_text=storage.error
		modal.popup_centered(Vector2i(460,180))
	elif not model.s.offline_notice.is_empty():
		modal.dialog_text="Welcome back!\nAway for %d seconds. Your team earned %d coins.\nOffline work is limited to two hours." % [model.s.offline_notice.seconds,model.s.offline_notice.coins]
		modal.popup_centered(Vector2i(460,230))
		model.s.offline_notice={}
		persist()
	if "--qa" in OS.get_cmdline_user_args(): call_deferred("run_capture")

func build_ui():
	var bg:=ColorRect.new()
	bg.color=CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	root_box=VBoxContainer.new()
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("separation",0)
	if OS.get_name()=="Android":
		var safe=DisplayServer.get_display_safe_area()
		var screen=DisplayServer.screen_get_size()
		var factor=540.0/screen.x
		root_box.offset_top=maxf(0,safe.position.y*factor)
		root_box.offset_bottom=-maxf(0,(screen.y-safe.end.y)*factor)
	add_child(root_box)
	var top_panel=PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel",style(CREAM,0))
	root_box.add_child(top_panel)
	var top=row()
	top_panel.add_child(top)
	header=label("",31)
	header.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(header)
	var coin=TextureRect.new()
	coin.texture=load("res://game/art/coin.svg")
	coin.custom_minimum_size=Vector2(32,40)
	coin.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(coin)
	coins_label=label("0",28)
	top.add_child(coins_label)
	var gear=button("⚙",func(): settings_box.visible=not settings_box.visible,52)
	gear.add_theme_font_size_override("font_size",30)
	gear.custom_minimum_size.x=52
	gear.size_flags_horizontal=Control.SIZE_SHRINK_END
	gear.add_theme_stylebox_override("normal",style(CREAM))
	top.add_child(gear)
	var goal_panel=PanelContainer.new()
	goal_panel.add_theme_stylebox_override("panel",style(Color("ddc8fa"),17))
	root_box.add_child(goal_panel)
	objective=label("",19)
	objective.custom_minimum_size.y=48
	objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	goal_panel.add_child(objective)
	objective.mouse_filter=Control.MOUSE_FILTER_STOP
	objective.gui_input.connect(func(event):
		if event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed:
			if "Hire" in model.objective(): show_upgrades(true)
			elif "Improve" in model.objective() or "Upgrade" in model.objective() or "Renovate" in model.objective(): show_upgrades(false))
	room=Room.new()
	room.custom_minimum_size.y=340
	room.size_flags_vertical=Control.SIZE_EXPAND_FILL
	room.mouse_filter=Control.MOUSE_FILTER_IGNORE
	room.clip_contents=true
	room.model=model
	root_box.add_child(room)
	settings_box=VBoxContainer.new()
	root_box.add_child(settings_box)
	var management=row()
	settings_box.add_child(management)
	management.add_child(button("Team",func(): show_upgrades(true),48))
	management.add_child(button("Improve",func(): show_upgrades(false),48))
	mute=button("Sound",toggle_mute,48)
	management.add_child(mute)
	management.add_child(button("Reset",func(): reset_dialog.popup_centered(Vector2i(440,180)),48))
	var choices=row()
	settings_box.add_child(choices)
	choice0=button("",func(): select(0),64)
	choice1=button("",func(): select(1),64)
	choices.add_child(choice0)
	choices.add_child(choice1)
	settings_box.hide()
	var card=PanelContainer.new()
	card.add_theme_stylebox_override("panel",style(CREAM,22))
	root_box.add_child(card)
	var card_stack=VBoxContainer.new()
	card.add_child(card_stack)
	var info=row()
	card_stack.add_child(info)
	card_icon=TextureRect.new()
	var icon=card_icon
	icon.texture=load("res://game/art/cauldron.png")
	icon.custom_minimum_size=Vector2(72,72)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	info.add_child(icon)
	var copy=VBoxContainer.new()
	copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	info.add_child(copy)
	card_title=label("Cauldron · Lv. 1",23)
	copy.add_child(card_title)
	card_detail=label("",16)
	copy.add_child(card_detail)
	upgrade_button=button("",func():
		var id="grow" if tab=="garden" else "brew"
		if model.owned(id): show_upgrades(false)
		else: buy(id),64)
	upgrade_button.custom_minimum_size.x=132
	upgrade_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	info.add_child(upgrade_button)
	status=label("",15)
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	card_stack.add_child(status)
	inventory=label("",14)
	inventory.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	card_stack.add_child(inventory)
	var actions=row()
	card_stack.add_child(actions)
	primary=button("",act_primary,64)
	secondary=button("",act_secondary,64)
	actions.add_child(primary)
	actions.add_child(secondary)
	var tabs=row()
	tabs.add_theme_constant_override("separation",0)
	root_box.add_child(tabs)
	shop_tab=button("▣  Shop",func(): switch_tab("shop"),74)
	garden_tab=button("✿  Garden",func(): switch_tab("garden"),74)
	for b in [shop_tab,garden_tab]:b.add_theme_font_size_override("font_size",25)
	tabs.add_child(shop_tab)
	tabs.add_child(garden_tab)
	upgrade_layer=PanelContainer.new()
	upgrade_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_layer.add_theme_stylebox_override("panel",style(Color(0.94,0.94,0.89,0.98),0))
	add_child(upgrade_layer)
	var pad:=MarginContainer.new()
	for edge in ["left","right","top","bottom"]: pad.add_theme_constant_override("margin_"+edge,24)
	upgrade_layer.add_child(pad)
	var content:=VBoxContainer.new()
	content.add_theme_constant_override("separation",12)
	pad.add_child(content)
	content.add_child(label("GROW YOUR LITTLE BUSINESS",25))
	content.add_child(label("Earn coins by selling potions.",19))
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	upgrade_list=VBoxContainer.new()
	upgrade_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	upgrade_list.add_theme_constant_override("separation",14)
	scroll.add_child(upgrade_list)
	content.add_child(button("Back to the shop",func(): upgrade_layer.hide()))
	upgrade_layer.hide()
	modal=AcceptDialog.new()
	modal.title="Little Lux"
	add_child(modal)
	reset_dialog=ConfirmationDialog.new()
	reset_dialog.title="Reset this demo?"
	reset_dialog.dialog_text="This deletes only Little Lux's local progress.\nYour shop will start from the beginning."
	reset_dialog.ok_button_text="Reset progress"
	reset_dialog.confirmed.connect(func():
		storage.reset(model)
		sound.set_muted(model.s.muted)
		model.event("session_start")
		upgrade_layer.hide()
		refresh())
	add_child(reset_dialog)
	for dialog in [modal,reset_dialog]:
		var dialog_theme:=Theme.new()
		dialog_theme.set_stylebox("panel","AcceptDialog",style(CREAM))
		var border:=style(TEAL)
		border.content_margin_top=34
		dialog_theme.set_stylebox("embedded_border","Window",border)
		dialog_theme.set_color("title_color","Window",CREAM)
		dialog.theme=dialog_theme
		dialog.get_label().add_theme_color_override("font_color",INK)
		dialog.get_label().add_theme_font_size_override("font_size",18)
		dialog.get_label().autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		for control in [dialog.get_ok_button()]:
			control.custom_minimum_size=Vector2(140,56)
			control.add_theme_font_size_override("font_size",20)
			control.add_theme_stylebox_override("normal",style(TEAL))
			control.add_theme_color_override("font_color",CREAM)

func toggle_mute():
	model.s.muted=not model.s.muted
	sound.set_muted(model.s.muted)
	persist()
	refresh()

func switch_tab(value: String):
	tab=value
	room.garden=tab=="garden"
	card_icon.texture=room.textures["bed" if tab=="garden" else "cauldron"]
	refresh()

func select(value: int):
	if tab=="garden": model.select_crop(value)
	else: model.select_recipe(value)
	persist()
	refresh()

func act_primary():
	if storage.locked: return
	if tab=="garden": model.harvest()
	elif model.s.ready: model.stock()
	else: model.brew()
	after_action()

func act_secondary():
	if storage.locked: return
	if tab=="garden": switch_tab("shop")
	else: model.serve()
	after_action()

func after_action():
	model.update_tutorial()
	flush_feedback()
	persist()
	refresh()

func buy(id: String):
	if storage.locked: return
	model.purchase(id)
	after_action()

func show_upgrades(team: bool):
	for child in upgrade_list.get_children():
		upgrade_list.remove_child(child)
		child.queue_free()
	purchase_buttons.clear()
	for p in model.cfg.purchases:
		if (p.id in ["gardener","brewer","cashier"]) != team: continue
		var title:=label(p.name,23)
		upgrade_list.add_child(title)
		var benefit:=label(p.benefit,18)
		benefit.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		upgrade_list.add_child(benefit)
		var b:=button("",buy.bind(p.id),60)
		upgrade_list.add_child(b)
		purchase_buttons[p.id]=b
	upgrade_layer.show()
	refresh()

func refresh():
	if not is_instance_valid(header): return
	header.text="Potion Shop"
	coins_label.text=str(int(model.s.coins))
	objective.text="★  "+model.objective()
	mute.text="Muted" if model.s.muted else "Sound"
	var s: Dictionary=model.s
	var upgrade_id="grow" if tab=="garden" else "brew"
	var improved=model.owned(upgrade_id)
	card_title.text=("Garden" if tab=="garden" else "Cauldron")+" · Lv. "+("2" if improved else "1")
	var duration=model.grow_time(s.crop) if tab=="garden" else model.brew_time(s.recipe)
	card_detail.text=("Grow" if tab=="garden" else "Brew")+" time %.1fs" % duration+("" if improved else " → %.1fs" % (duration/1.5))
	var cost=48 if tab=="garden" else 64
	upgrade_button.text="Improve" if improved else "Upgrade\n● %d" % cost
	upgrade_button.disabled=not improved and s.coins<cost
	inventory.text="Leaf %d   •   Flower %d   |   Bottles %d / %d" % [s.herbs[0],s.herbs[1],model.stock_count(),model.capacity()]
	status.text=model.status()
	primary.visible=not model.owned("gardener" if tab=="garden" else "brewer")
	secondary.visible=tab=="garden" or not model.owned("cashier")
	var selected:=int(s.crop if tab=="garden" else s.recipe)
	choice0.text=("✓ " if selected==0 else "")+("Peppermint" if tab=="garden" else "Energy • %d coins" % model.price(0))
	choice1.text=("✓ " if selected==1 else "")+("Moonflower" if tab=="garden" else "Dream • %d coins" % model.price(1)) if model.owned("recipe") else "Unlock in Improve"
	choice1.disabled=not model.owned("recipe")
	if tab=="garden":
		status.text="Free replanting • replant selection: "+model.cfg.crops[int(s.crop)].name
		primary.text="Harvest + replant"
		var ready:=false
		for p in s.plots:
			if p.progress>=model.grow_time(p.crop) and s.herbs[int(p.crop)]+2<=model.cfg.herb_capacity: ready=true
		primary.disabled=not ready
		if not ready:
			for p in s.plots:
				if p.progress>=model.grow_time(p.crop) and s.herbs[int(p.crop)]+2>model.cfg.herb_capacity: status.text="Herb bin full • brew or switch crops"
		secondary.text="Go brew →"
		secondary.disabled=false
	else:
		primary.text="Stock potion" if s.ready else "Brewing…" if s.pot!=-1 else "Brew potion"
		primary.disabled=(not s.ready and (s.pot!=-1 or s.herbs[int(model.cfg.recipes[int(s.recipe)].herb)]<1)) or model.stock_count()>=model.capacity()
		secondary.text="Checkout busy" if s.serving else "Serve • %d waiting" % s.queue
		secondary.disabled=s.serving or s.queue==0 or model.stock_count()==0
	if styled_tab!=tab:
		styled_tab=tab
		for b in [shop_tab,garden_tab]:
			var tab_color=Color("cdb3fa") if (b==shop_tab)==(tab=="shop") else CREAM
			for state in ["normal","hover","pressed"]:b.add_theme_stylebox_override(state,style(tab_color))
			for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(state,INK)
	for p in model.cfg.purchases:
		if purchase_buttons.has(p.id):
			var b: Button=purchase_buttons[p.id]
			b.text="Hired" if model.owned(p.id) and p.id in ["gardener","brewer","cashier"] else "Purchased" if model.owned(p.id) else "%d coins  •  %d available" % [p.cost,s.coins]
			b.disabled=model.owned(p.id) or s.coins<p.cost
	if storage.locked:
		primary.disabled=true
		secondary.disabled=true
		status.text=storage.error

func flush_feedback():
	for kind in model.feedback:
		if kind in ["sale","dream_sale"]: room.leave_customer()
		room.effect=kind
		room.pulse=1.2
		sound.play(kind)
		if OS.get_name()=="Android" and kind in ["sale","dream_sale","upgrade"]: Input.vibrate_handheld(18,0.3)
	model.feedback.clear()

func persist():
	if harness: return
	if not storage.save(model):
		status.text=storage.error
	if not model.events.is_empty():
		var file:=FileAccess.open(session_events_path,FileAccess.READ_WRITE if FileAccess.file_exists(session_events_path) else FileAccess.WRITE)
		if file:
			file.seek_end()
			for entry in model.events: file.store_line(JSON.stringify(entry))
			file.close()
			model.events.clear()

func _process(dt):
	if storage.locked: return
	perf_frames.append(dt*1000.0)
	perf_clock += dt
	if perf_clock >= 30:
		perf_frames.sort()
		print("LUX_PERF fps=",snapped(perf_frames.size()/perf_clock,0.1)," p95_ms=",snapped(perf_frames[int(perf_frames.size()*0.95)],0.1)," process_ms=",snapped(Performance.get_monitor(Performance.TIME_PROCESS)*1000,0.01))
		perf_frames.clear()
		perf_clock=0.0
	accumulator+=minf(dt,1.0)
	while accumulator>=model.cfg.step:
		model.tick(model.cfg.step)
		accumulator-=model.cfg.step
	save_timer+=dt
	flush_feedback()
	if model.dirty or save_timer>=5:
		persist()
		save_timer=0
	ui_timer+=dt
	if ui_timer>=0.1:
		ui_timer=0
		refresh()

func _notification(what):
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_CLOSE_REQUEST]:
		if is_instance_valid(status): persist()
	if what==NOTIFICATION_APPLICATION_RESUMED and is_instance_valid(status) and not harness:
		model.offline(Time.get_unix_time_from_system())
		persist()
	if what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(upgrade_layer): upgrade_layer.hide()

func tap(b: Button):
	if b.disabled or not b.is_visible_in_tree(): return
	var e:=InputEventScreenTouch.new()
	e.index=0
	e.position=b.get_global_rect().get_center()
	e.pressed=true
	Input.parse_input_event(e)
	await get_tree().process_frame
	e=InputEventScreenTouch.new()
	e.index=0
	e.position=b.get_global_rect().get_center()
	e.pressed=false
	Input.parse_input_event(e)
	await get_tree().process_frame

func screenshot(name: String):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/evidence/redesign/"+("tall-" if "--tall" in OS.get_cmdline_user_args() else "")+name+".png")

func run_capture():
	await get_tree().create_timer(0.3).timeout
	print("UI viewport=",get_viewport_rect().size," primary=",primary.get_global_rect()," garden_tab=",garden_tab.get_global_rect())
	await screenshot("starting-shop")
	await tap(garden_tab)
	await screenshot("garden")
	# Accelerated test uses the real buttons and economy; no inventory or coin injection.
	var recorded_automation:=false
	var recorded_renovation:=false
	while model.s.elapsed < 300:
		model.simulate(1.0)
		room._process(1.0)
		refresh()
		if not model.owned("gardener"):
			await tap(garden_tab)
			await tap(primary)
		await tap(shop_tab)
		await tap(primary)
		await tap(secondary)
		for id in ["gardener","brewer","cashier","recipe","renovation","grow","brew","capacity","service"]:
			if model.owned(id): continue
			var p: Dictionary={}
			for candidate in model.cfg.purchases:
				if candidate.id==id: p=candidate
			if model.s.coins>=p.cost:
				show_upgrades(id in ["gardener","brewer","cashier"])
				await get_tree().process_frame
				var sc: ScrollContainer=upgrade_list.get_parent()
				sc.ensure_control_visible(purchase_buttons[id])
				await get_tree().process_frame
				await tap(purchase_buttons[id])
				upgrade_layer.hide()
				print("PLAY purchase ",id," at ",model.s.elapsed)
			break
		if model.owned("cashier") and not recorded_automation:
			await screenshot("automated-shop")
			recorded_automation=true
		if model.owned("renovation") and not recorded_renovation:
			await screenshot("renovated-shop")
			recorded_renovation=true
		if model.owned("recipe") and model.s.crop != 1:
			await tap(garden_tab)
			settings_box.show()
			await get_tree().process_frame
			await tap(choice1)
			settings_box.hide()
			await tap(shop_tab)
			settings_box.show()
			await get_tree().process_frame
			await tap(choice1)
			settings_box.hide()
	print("PLAY FINAL ",JSON.stringify(model.s))
	var file:=FileAccess.open("res://docs/evidence/playthrough-events.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(model.events,"  "))
	await screenshot("five-minute-shop")
	var code=0 if model.owned("renovation") and model.s.flags.has("tutorial_complete") else 1
	var tree=get_tree()
	sound.set_muted(true)
	tree.create_timer(.3).timeout.connect(tree.quit.bind(code))
	queue_free()
