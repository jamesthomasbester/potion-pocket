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
var coin_pill: PanelContainer
var shown_coins := 0.0
var objective: Label
var goal_panel: PanelContainer
var goal_bar: ProgressBar
var last_objective := ""
var status: Label
var leaf_count: Label
var flower_count: Label
var flower_chip: Control
var bottle_count: Label
var primary: Button
var secondary: Button
var choice0: Button
var choice1: Button
var shop_tab: Button
var garden_tab: Button
var mute: Button
var upgrade_layer: PanelContainer
var upgrade_title: Label
var upgrade_list: VBoxContainer
var purchase_buttons := {}
var purchase_cards := {}
var modal: AcceptDialog
var reset_dialog: ConfirmationDialog
var root_box: VBoxContainer
var settings_box: VBoxContainer
var card_icon: TextureRect
var card_title: Label
var card_detail: Label
var upgrade_button: Button
var coin_tex: Texture2D
var harness := false
var perf_frames: Array[float] = []
var perf_clock := 0.0
var session_events_path := "user://events.jsonl"
const INK = Color("191b43")
const CREAM = Color("fff7eb")
const SAND = Color("f3e6d2")
const TEAL = Color("65bd85")
const MINT = Color("72c9a0")
const LAVENDER = Color("cdb3fa")
const LILAC = Color("e6d8fc")
const GOLD = Color("f2b632")
const DISABLED = Color("e4e2dc")
# Purchase cards reuse the scene sprites so the menu reads like the shop.
const PURCHASE_ICONS = {"gardener":"gardener","brewer":"brewer","cashier":"cashier","recipe":"dream","grow":"bed","brew":"cauldron","service":"counter","capacity":"shelf","renovation":"flowers"}

func style(c: Color, radius: int = 14) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color=c
	st.set_corner_radius_all(radius)
	st.content_margin_left=12
	st.content_margin_right=12
	st.content_margin_top=6
	st.content_margin_bottom=6
	return st

# Raised button face: a darker lip underneath that collapses when pressed.
func chunky(c: Color, pressed := false, radius := 18) -> StyleBoxFlat:
	var st:=style(c.darkened(0.06) if pressed else c,radius)
	st.border_color=c.darkened(0.24)
	st.border_width_bottom=1 if pressed else 5
	st.content_margin_top=10 if pressed else 6
	st.anti_aliasing=true
	return st

func label(value: String, font_size: int = 20) -> Label:
	var l:=Label.new()
	l.text=value
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",INK)
	return l

func paint(b: Button, c: Color, radius := 18):
	b.add_theme_stylebox_override("normal",chunky(c,false,radius))
	b.add_theme_stylebox_override("hover",chunky(c.lightened(0.1),false,radius))
	b.add_theme_stylebox_override("pressed",chunky(c,true,radius))
	b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled",chunky(DISABLED,false,radius))

func button(value: String, action: Callable, min_height: float = 64, c: Color = TEAL) -> Button:
	var b:=Button.new()
	b.text=value
	b.custom_minimum_size.y=min_height
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size",19)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(state,INK)
	b.add_theme_color_override("font_disabled_color",Color("8d8f9c"))
	b.add_theme_constant_override("icon_max_width",24)
	paint(b,c)
	b.pressed.connect(action)
	squish(b)
	return b

func squish(c: Control):
	c.resized.connect(func(): c.pivot_offset=c.size/2)
	if c is BaseButton:
		c.button_down.connect(func(): pop(c,0.94,0.06))
		c.button_up.connect(func(): pop(c,1.0,0.22))

func pop(c: Control, to: float, seconds: float, from := -1.0):
	if from>0: c.scale=Vector2.ONE*from
	var tw:=c.create_tween()
	tw.tween_property(c,"scale",Vector2.ONE*to,seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func row() -> HBoxContainer:
	var r:=HBoxContainer.new()
	r.add_theme_constant_override("separation",10)
	return r

func margin(child: Control, h: int, v: int) -> MarginContainer:
	var m:=MarginContainer.new()
	m.add_theme_constant_override("margin_left",h)
	m.add_theme_constant_override("margin_right",h)
	m.add_theme_constant_override("margin_top",v)
	m.add_theme_constant_override("margin_bottom",v)
	m.add_child(child)
	return m

func picture(tex: Texture2D, side: float) -> TextureRect:
	var t:=TextureRect.new()
	t.texture=tex
	t.custom_minimum_size=Vector2(side,side)
	t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return t

func tile(tex: Texture2D, side: float) -> PanelContainer:
	var p:=PanelContainer.new()
	p.add_theme_stylebox_override("panel",style(SAND,16))
	p.add_child(picture(tex,side))
	p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return p

func chip(tex: Texture2D) -> Array:
	var p:=PanelContainer.new()
	var st:=style(SAND,14)
	st.content_margin_top=3
	st.content_margin_bottom=3
	p.add_theme_stylebox_override("panel",st)
	var r:=row()
	r.add_theme_constant_override("separation",4)
	p.add_child(r)
	r.add_child(picture(tex,24))
	var l:=label("0",16)
	r.add_child(l)
	return [p,l]

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
	shown_coins=model.s.coins
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
	coin_tex=load("res://game/art/coin.svg")
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
	var top=row()
	root_box.add_child(margin(top,16,8))
	header=label("",31)
	header.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(header)
	coin_pill=PanelContainer.new()
	coin_pill.add_theme_stylebox_override("panel",style(SAND,22))
	top.add_child(coin_pill)
	var coin_row=row()
	coin_row.add_theme_constant_override("separation",6)
	coin_pill.add_child(coin_row)
	coin_row.add_child(picture(coin_tex,32))
	coins_label=label("0",27)
	coins_label.custom_minimum_size.x=46
	coin_row.add_child(coins_label)
	squish(coin_pill)
	var gear=button("⚙",func():
		settings_box.visible=not settings_box.visible
		sound.play("tap"),52,SAND)
	gear.add_theme_font_size_override("font_size",28)
	gear.custom_minimum_size.x=52
	gear.size_flags_horizontal=Control.SIZE_SHRINK_END
	top.add_child(gear)
	goal_panel=PanelContainer.new()
	var goal_style:=style(LILAC,18)
	goal_style.content_margin_left=14
	goal_style.content_margin_top=8
	goal_style.content_margin_bottom=10
	goal_panel.add_theme_stylebox_override("panel",goal_style)
	root_box.add_child(margin(goal_panel,12,4))
	squish(goal_panel)
	var goal_stack=VBoxContainer.new()
	goal_stack.add_theme_constant_override("separation",6)
	goal_stack.mouse_filter=Control.MOUSE_FILTER_IGNORE
	goal_panel.add_child(goal_stack)
	var goal_row=row()
	goal_row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	goal_stack.add_child(goal_row)
	var star=label("★",26)
	star.add_theme_color_override("font_color",GOLD)
	star.add_theme_color_override("font_outline_color",Color("b9822a"))
	star.add_theme_constant_override("outline_size",3)
	goal_row.add_child(star)
	objective=label("",19)
	objective.custom_minimum_size.y=34
	objective.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	objective.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	goal_row.add_child(objective)
	goal_bar=ProgressBar.new()
	goal_bar.show_percentage=false
	goal_bar.custom_minimum_size.y=8
	goal_bar.add_theme_stylebox_override("background",style(Color("f7f0ff"),4))
	goal_bar.add_theme_stylebox_override("fill",style(Color("a77cf0"),4))
	goal_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	goal_stack.add_child(goal_bar)
	goal_panel.gui_input.connect(func(event):
		if event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed:
			if "Hire" in model.objective(): show_upgrades(true)
			elif "Improve" in model.objective() or "Upgrade" in model.objective() or "glow-up" in model.objective(): show_upgrades(false))
	room=Room.new()
	room.custom_minimum_size.y=340
	room.size_flags_vertical=Control.SIZE_EXPAND_FILL
	room.mouse_filter=Control.MOUSE_FILTER_IGNORE
	room.clip_contents=true
	room.model=model
	root_box.add_child(room)
	settings_box=VBoxContainer.new()
	settings_box.add_theme_constant_override("separation",8)
	var settings_panel=PanelContainer.new()
	settings_panel.add_theme_stylebox_override("panel",style(LILAC,0))
	settings_panel.add_child(margin(settings_box,12,8))
	root_box.add_child(settings_panel)
	var management=row()
	settings_box.add_child(management)
	management.add_child(button("Team",func(): show_upgrades(true),50,CREAM))
	management.add_child(button("Improve",func(): show_upgrades(false),50,CREAM))
	mute=button("Sound",toggle_mute,50,CREAM)
	management.add_child(mute)
	management.add_child(button("Reset",func(): reset_dialog.popup_centered(Vector2i(440,180)),50,Color("f4c6b8")))
	var choices=row()
	settings_box.add_child(choices)
	choice0=button("",func(): select(0),60,CREAM)
	choice1=button("",func(): select(1),60,CREAM)
	choices.add_child(choice0)
	choices.add_child(choice1)
	settings_panel.hide()
	# Tests and the QA run toggle settings_box directly; keep its panel in step.
	settings_box.visibility_changed.connect(func(): settings_panel.visible=settings_box.visible)
	settings_box.visible=false
	var card=PanelContainer.new()
	var card_style:=style(CREAM,0)
	card_style.corner_radius_top_left=26
	card_style.corner_radius_top_right=26
	card_style.shadow_color=Color(0.3,0.2,0.45,0.16)
	card_style.shadow_size=12
	card_style.shadow_offset=Vector2(0,-4)
	card_style.content_margin_left=16
	card_style.content_margin_right=16
	card_style.content_margin_top=14
	card_style.content_margin_bottom=10
	card.add_theme_stylebox_override("panel",card_style)
	root_box.add_child(card)
	var card_stack=VBoxContainer.new()
	card_stack.add_theme_constant_override("separation",8)
	card.add_child(card_stack)
	var info=row()
	info.add_theme_constant_override("separation",12)
	card_stack.add_child(info)
	var icon_tile=tile(load("res://game/art/cauldron.png"),62)
	card_icon=icon_tile.get_child(0)
	info.add_child(icon_tile)
	var copy=VBoxContainer.new()
	copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	copy.alignment=BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation",0)
	info.add_child(copy)
	card_title=label("Cauldron · Lv. 1",23)
	copy.add_child(card_title)
	card_detail=label("",16)
	card_detail.add_theme_color_override("font_color",Color("4b4e72"))
	copy.add_child(card_detail)
	upgrade_button=button("",func():
		var id="grow" if tab=="garden" else "brew"
		if model.owned(id): show_upgrades(false)
		else: buy(id),64)
	upgrade_button.custom_minimum_size.x=132
	upgrade_button.size_flags_horizontal=Control.SIZE_SHRINK_END
	info.add_child(upgrade_button)
	status=label("",16)
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	card_stack.add_child(status)
	var chips=row()
	chips.alignment=BoxContainer.ALIGNMENT_CENTER
	card_stack.add_child(chips)
	var c=chip(load("res://game/art/leaves.png"))
	chips.add_child(c[0])
	leaf_count=c[1]
	c=chip(load("res://game/art/flowers.png"))
	chips.add_child(c[0])
	flower_chip=c[0]
	flower_count=c[1]
	c=chip(load("res://game/art/energy.png"))
	chips.add_child(c[0])
	bottle_count=c[1]
	var actions=row()
	card_stack.add_child(actions)
	primary=button("",act_primary,64)
	secondary=button("",act_secondary,64)
	actions.add_child(primary)
	actions.add_child(secondary)
	var tabs=row()
	tabs.add_theme_constant_override("separation",0)
	var tab_bg=PanelContainer.new()
	tab_bg.add_theme_stylebox_override("panel",style(CREAM,0))
	tab_bg.add_child(tabs)
	root_box.add_child(tab_bg)
	shop_tab=button("Shop",func(): switch_tab("shop"),74)
	shop_tab.icon=load("res://game/art/cauldron.png")
	garden_tab=button("Garden",func(): switch_tab("garden"),74)
	garden_tab.icon=load("res://game/art/plant.png")
	for b in [shop_tab,garden_tab]:
		b.add_theme_font_size_override("font_size",24)
		b.add_theme_constant_override("icon_max_width",36)
		b.add_theme_constant_override("h_separation",10)
		tabs.add_child(b)
	upgrade_layer=PanelContainer.new()
	upgrade_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_layer.add_theme_stylebox_override("panel",style(Color(1.0,0.97,0.92,0.99),0))
	add_child(upgrade_layer)
	var content:=VBoxContainer.new()
	content.add_theme_constant_override("separation",12)
	upgrade_layer.add_child(margin(content,20,24))
	var title_row=row()
	content.add_child(title_row)
	upgrade_title=label("",30)
	upgrade_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title_row.add_child(upgrade_title)
	var close=button("✕",func(): close_upgrades(),52,SAND)
	close.custom_minimum_size.x=52
	close.size_flags_horizontal=Control.SIZE_SHRINK_END
	title_row.add_child(close)
	var sub=label("Earn coins by selling potions, then grow your little business.",17)
	sub.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_color_override("font_color",Color("4b4e72"))
	content.add_child(sub)
	var scroll:=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	upgrade_list=VBoxContainer.new()
	upgrade_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	upgrade_list.add_theme_constant_override("separation",12)
	scroll.add_child(upgrade_list)
	content.add_child(button("Back to the shop",func(): close_upgrades()))
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
		shown_coins=model.s.coins
		refresh())
	add_child(reset_dialog)
	for dialog in [modal,reset_dialog]:
		var dialog_theme:=Theme.new()
		dialog_theme.set_stylebox("panel","AcceptDialog",style(CREAM,18))
		var border:=style(LAVENDER,18)
		border.content_margin_top=34
		dialog_theme.set_stylebox("embedded_border","Window",border)
		dialog_theme.set_color("title_color","Window",INK)
		dialog.theme=dialog_theme
		dialog.get_label().add_theme_color_override("font_color",INK)
		dialog.get_label().add_theme_font_size_override("font_size",18)
		dialog.get_label().autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var buttons=[dialog.get_ok_button()]
		if dialog is ConfirmationDialog: buttons.append(dialog.get_cancel_button())
		for control in buttons:
			control.custom_minimum_size=Vector2(140,56)
			control.add_theme_font_size_override("font_size",20)
			control.add_theme_color_override("font_color",INK)
			control.add_theme_color_override("font_hover_color",INK)
			control.add_theme_color_override("font_pressed_color",INK)
			paint(control,TEAL if control==dialog.get_ok_button() else SAND)

func toggle_mute():
	model.s.muted=not model.s.muted
	sound.set_muted(model.s.muted)
	persist()
	refresh()

func switch_tab(value: String):
	if value!=tab:
		sound.play("tap")
		room.particles.clear()
		room.floaters.clear()
		room.modulate=Color(1,1,1,0.35)
		room.create_tween().tween_property(room,"modulate",Color.WHITE,0.22)
	tab=value
	room.garden=tab=="garden"
	room.queue_redraw()
	card_icon.texture=room.textures["bed" if tab=="garden" else "cauldron"]
	refresh()

func select(value: int):
	if tab=="garden": model.select_crop(value)
	else: model.select_recipe(value)
	sound.play("tap")
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
	if model.purchase(id):
		if purchase_cards.has(id): pop(purchase_cards[id],1.0,0.35,1.06)
		if id in ["grow","brew"]: pop(upgrade_button,1.0,0.35,1.12)
	after_action()

func show_upgrades(team: bool):
	for child in upgrade_list.get_children():
		upgrade_list.remove_child(child)
		child.queue_free()
	purchase_buttons.clear()
	purchase_cards.clear()
	upgrade_title.text="Your team" if team else "Improve the shop"
	for p in model.cfg.purchases:
		if (p.id in ["gardener","brewer","cashier"]) != team: continue
		var card:=PanelContainer.new()
		var st:=style(Color("fffdf8"),20)
		st.border_color=Color("ead9c4")
		st.set_border_width_all(2)
		st.border_width_bottom=5
		st.content_margin_left=12
		st.content_margin_top=10
		st.content_margin_bottom=10
		card.add_theme_stylebox_override("panel",st)
		squish(card)
		upgrade_list.add_child(card)
		var r:=row()
		r.add_theme_constant_override("separation",12)
		card.add_child(r)
		r.add_child(tile(room.textures.get(PURCHASE_ICONS.get(p.id,"plant")),60))
		var copy:=VBoxContainer.new()
		copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		copy.alignment=BoxContainer.ALIGNMENT_CENTER
		copy.add_theme_constant_override("separation",2)
		r.add_child(copy)
		copy.add_child(label(p.name,21))
		var benefit:=label(p.benefit,16)
		benefit.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		benefit.add_theme_color_override("font_color",Color("4b4e72"))
		copy.add_child(benefit)
		var b:=button("",buy.bind(p.id),60)
		b.custom_minimum_size.x=112
		b.size_flags_horizontal=Control.SIZE_SHRINK_END
		b.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		r.add_child(b)
		purchase_buttons[p.id]=b
		purchase_cards[p.id]=card
	upgrade_layer.modulate=Color(1,1,1,0)
	upgrade_layer.show()
	upgrade_layer.create_tween().tween_property(upgrade_layer,"modulate",Color.WHITE,0.16)
	sound.play("tap")
	refresh()

func close_upgrades():
	upgrade_layer.hide()
	sound.play("tap")

func goal_cost() -> int:
	var found:=RegEx.create_from_string("(\\d+) coins").search(model.objective())
	return int(found.get_string(1)) if found else 0

# The control that completes the current onboarding step, so it can glow.
func tutorial_target() -> Button:
	var stage:=int(model.s.tutorial)
	if stage==0: return primary if tab=="garden" else garden_tab
	if stage<3 and tab=="garden": return shop_tab
	if stage==1: return primary
	if stage==2: return secondary
	return null

func refresh():
	if not is_instance_valid(header): return
	header.text="Potion Shop"
	if model.s.coins<shown_coins or not is_processing(): shown_coins=model.s.coins
	coins_label.text=str(int(shown_coins))
	var goal:String=model.objective()
	objective.text=goal
	if goal!=last_objective:
		if last_objective!="": pop(goal_panel,1.0,0.4,1.06)
		last_objective=goal
	var cost:=goal_cost()
	goal_bar.visible=cost>0
	goal_bar.value=clampf(model.s.coins/float(maxi(cost,1)),0,1)*100
	goal_bar.add_theme_stylebox_override("fill",style(TEAL if goal_bar.value>=100 else Color("a77cf0"),4))
	mute.text="Muted" if model.s.muted else "Sound"
	var s: Dictionary=model.s
	var upgrade_id="grow" if tab=="garden" else "brew"
	var improved=model.owned(upgrade_id)
	card_title.text=("Garden" if tab=="garden" else "Cauldron")+" · Lv. "+("2" if improved else "1")
	var duration=model.grow_time(s.crop) if tab=="garden" else model.brew_time(s.recipe)
	card_detail.text=("Grow" if tab=="garden" else "Brew")+" time %.1fs" % duration+("" if improved else " → %.1fs" % (duration/1.5))
	var upgrade_cost=48 if tab=="garden" else 64
	upgrade_button.text="Improve" if improved else "Upgrade\n%d" % upgrade_cost
	upgrade_button.icon=null if improved else coin_tex
	upgrade_button.disabled=not improved and s.coins<upgrade_cost
	leaf_count.text=str(s.herbs[0])
	flower_count.text=str(s.herbs[1])
	flower_chip.visible=model.owned("recipe") or s.herbs[1]>0
	bottle_count.text="%d / %d" % [model.stock_count(),model.capacity()]
	status.text=model.status()
	primary.visible=not model.owned("gardener" if tab=="garden" else "brewer")
	secondary.visible=tab=="garden" or not model.owned("cashier")
	var selected:=int(s.crop if tab=="garden" else s.recipe)
	choice0.text=("✓ " if selected==0 else "")+("Peppermint" if tab=="garden" else "Energy • %d coins" % model.price(0))
	choice1.text=("✓ " if selected==1 else "")+("Moonflower" if tab=="garden" else "Dream • %d coins" % model.price(1)) if model.owned("recipe") else "Unlock in Improve"
	choice1.disabled=not model.owned("recipe")
	for i in range(2):
		var chosen:=selected==i
		var b: Button=[choice0,choice1][i]
		if not b.has_meta("chosen") or b.get_meta("chosen")!=chosen:
			b.set_meta("chosen",chosen)
			paint(b,LAVENDER if chosen else CREAM)
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
			var active:bool=(b==shop_tab)==(tab=="shop")
			var st:=style(LAVENDER if active else CREAM,0)
			st.corner_radius_top_left=24
			st.corner_radius_top_right=24
			for state in ["normal","hover","pressed"]:b.add_theme_stylebox_override(state,st)
			b.modulate=Color.WHITE if active else Color(1,1,1,0.75)
	for p in model.cfg.purchases:
		if purchase_buttons.has(p.id):
			var b: Button=purchase_buttons[p.id]
			var owned:bool=model.owned(p.id)
			b.text=("Hired" if p.id in ["gardener","brewer","cashier"] else "Owned") if owned else "%d" % p.cost
			b.icon=null if owned else coin_tex
			b.disabled=owned or s.coins<p.cost
			purchase_cards[p.id].modulate=Color(1,1,1,0.62) if owned else Color.WHITE
	if storage.locked:
		primary.disabled=true
		secondary.disabled=true
		status.text=storage.error

func flush_feedback():
	for kind in model.feedback:
		if kind in ["sale","dream_sale"]: room.leave_customer()
		room.effect=kind
		room.pulse=1.2
		room.burst(kind)
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

func animate_ui(dt: float):
	# Count the balance up so sales read as income rather than a jump.
	if shown_coins<model.s.coins:
		var before:=int(shown_coins)
		shown_coins=move_toward(shown_coins,model.s.coins,maxf(12.0,(model.s.coins-shown_coins)*6.0)*dt)
		if int(shown_coins)!=before:
			coins_label.text=str(int(shown_coins))
			if coin_pill.scale.x<1.04: pop(coin_pill,1.0,0.25,1.12)
	var target:=tutorial_target()
	var glow:=0.5+0.5*sin(Time.get_ticks_msec()*0.006)
	for b in [primary,secondary,shop_tab,garden_tab]:
		b.self_modulate=Color.WHITE.lerp(Color(1.18,1.18,1.05),glow) if b==target and not b.disabled else Color.WHITE

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
	animate_ui(dt)
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
