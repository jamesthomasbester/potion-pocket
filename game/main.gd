extends Control
const Economy = preload("res://game/economy.gd")
const Storage = preload("res://game/storage.gd")
const Room = preload("res://game/room.gd")
const Sound = preload("res://game/sound.gd")
const Art = preload("res://game/art_catalog.gd")
const ResearchTree = preload("res://game/research_tree.gd")
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
var herb_chips: Array = []
var herb_counts: Array = []
var herb_icons: Array = []
var bottle_count: Label
var bottle_icon: TextureRect
var primary: Button
var secondary: Button
var shop_tab: Button
var garden_tab: Button
var mute: Button
var upgrade_layer: PanelContainer
var upgrade_title: Label
var overlay_sub: Label
var upgrade_list: VBoxContainer
var purchase_buttons := {}
var purchase_cards := {}
var modal: AcceptDialog
var daily_button: Button
var daily_dot: Panel
var toast: PanelContainer
var toast_label: Label
var toast_queue: Array = []
var day_timer := 0.0
var catch_job: Dictionary = {}
var catch_layer: Control
var catch_bar: ProgressBar
var catch_label: Label
# Absences shorter than this catch up instantly; longer ones show progress.
const CATCH_UP_INSTANT := 3000
# Frame time spent on catch-up, so the screen keeps drawing and stays responsive.
const CATCH_UP_BUDGET_USEC := 25000
var welcome_layer: Control
var welcome_lines: VBoxContainer
var welcome_away: Label
var welcome_coins: Label
var reset_dialog: ConfirmationDialog
var branch_dialog: ConfirmationDialog
var ui: Control
var shop
var stage: Control
var settings_button: Button
var nav_buttons: Array = []
var settings_box: VBoxContainer
var card_icon: TextureRect
var card_title: Label
var card_detail: Label
var upgrade_button: Button
var card_milestone: Label
var selected_station := "cauldron"
# The Grimoire's Research tab: chapter shown, page selected and live widgets.
var grimoire_tabs: HBoxContainer
var grimoire_chapter := "herb"
var grimoire_page := ""
var research_ui := {}
var grimoire_dot: Panel
var purchase_labels := {}
var coin_tex: Texture2D
var harness := false
var perf_frames: Array[float] = []
var perf_clock := 0.0
var session_events_path := "user://events.jsonl"
# Palette taken from the shop art: night purple, warm wood, cream and gold.
const INK = Color("2b1a3d")
const MUTED = Color("5c4a6e")
const WOOD = Color("6b3f24")
const NIGHT = Color("2e1d52")
const CREAM = Color("fff3df")
const SAND = Color("f3e2c6")
const TEAL = Color("5fbf6a")
const LAVENDER = Color("c9b0f5")
const LILAC = Color("efe3ff")
const PURPLE = Color("8a5cd6")
const GOLD = Color("f2b632")
const DISABLED = Color("e2dbd2")
const STATION_ICONS = {"cauldron":"cauldron","counter":"counter","shelf":"potion_shelf"}
# The part of the shop scene the stage frames: the room from roof to doormat.
const SHOP_FRAME = Rect2(-6,-4,552,700)
# Purchase cards reuse the scene sprites so the menu reads like the shop.
const TALENT_ICONS = {"roots":"mint_t3","bubbles":"cauldron_t3","street":"customer0","patrons":"customer1","night":"owner","team":"gardener"}
const PURCHASE_ICONS = {"gardener":"gardener","brewer":"brewer","cashier":"cashier","recipe":"dream","grow":"bed","brew":"cauldron_t2","service":"counter_t2","capacity":"potion_shelf_t2","renovation":"rug_t3","offline_4":"owner","offline_8":"dream_t3"}

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

# Cream panel with the art's dark wood outline.
func framed(c: Color, radius := 18, border := 3) -> StyleBoxFlat:
	var st:=style(c,radius)
	st.border_color=WOOD
	st.set_border_width_all(border)
	st.anti_aliasing=true
	return st

# Gives a button from the scene the same face as code-built ones.
func style_button(b: Button, c: Color):
	b.add_theme_font_size_override("font_size",19)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(state,INK)
	b.add_theme_color_override("font_disabled_color",Color("8d8698"))
	b.add_theme_constant_override("icon_max_width",24)
	paint(b,c)
	squish(b)

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
		storage.load_into(model,-1.0,true)
	model.event("session_start")
	sound=Sound.new()
	add_child(sound)
	sound.set_muted(model.s.muted)
	build_ui()
	switch_tab("shop")
	fit_world.call_deferred()
	shown_coins=model.s.coins
	refresh()
	if storage.locked:
		modal.dialog_text=storage.error
		modal.popup_centered(Vector2i(460,180))
	elif not harness:
		start_catch_up(Time.get_unix_time_from_system())
	if "--qa" in OS.get_cmdline_user_args(): call_deferred("run_capture")

func build_ui():
	coin_tex=load("res://game/art/ui/coin.png")
	ui=%Root
	# Respect the phone's notch and gesture bar.
	if OS.get_name()=="Android":
		var safe=DisplayServer.get_display_safe_area()
		var screen=DisplayServer.screen_get_size()
		var factor=get_viewport_rect().size.x/screen.x
		%Layout.offset_top=maxf(0,safe.position.y*factor)
		%Layout.offset_bottom=-maxf(0,(screen.y-safe.end.y)*factor)
	shop=$World
	shop.model=model
	# Top bar: coins, the shop's name, daily goals and settings.
	header=%Title
	header.add_theme_font_size_override("font_size",26)
	header.add_theme_color_override("font_color",CREAM)
	header.add_theme_color_override("font_outline_color",NIGHT)
	header.add_theme_constant_override("outline_size",8)
	coin_pill=%CoinPill
	coin_pill.add_theme_stylebox_override("panel",framed(CREAM,22,3))
	coins_label=%CoinLabel
	coins_label.add_theme_font_size_override("font_size",26)
	coins_label.add_theme_color_override("font_color",INK)
	squish(coin_pill)
	daily_button=%DailyButton
	settings_button=%SettingsButton
	for b in [daily_button,settings_button]:
		paint(b,CREAM,18)
		b.add_theme_constant_override("icon_max_width",34)
		squish(b)
	daily_button.pressed.connect(func(): show_daily())
	settings_button.pressed.connect(func():
		settings_box.visible=not settings_box.visible
		sound.play("tap"))
	daily_dot=Panel.new()
	var dot:=style(Color("e4574a"),8)
	dot.border_color=CREAM
	dot.set_border_width_all(2)
	daily_dot.add_theme_stylebox_override("panel",dot)
	daily_dot.size=Vector2(16,16)
	daily_dot.position=Vector2(42,-2)
	daily_dot.mouse_filter=Control.MOUSE_FILTER_IGNORE
	daily_button.add_child(daily_dot)
	# Goal banner: the current objective and its progress.
	goal_panel=%GoalPanel
	var goal_style:=framed(LILAC,18,3)
	goal_style.content_margin_left=14
	goal_style.content_margin_top=8
	goal_style.content_margin_bottom=10
	goal_panel.add_theme_stylebox_override("panel",goal_style)
	squish(goal_panel)
	var star:Label=%Star
	star.add_theme_font_size_override("font_size",24)
	star.add_theme_color_override("font_color",GOLD)
	star.add_theme_color_override("font_outline_color",Color("b9822a"))
	star.add_theme_constant_override("outline_size",3)
	objective=%Objective
	objective.add_theme_font_size_override("font_size",18)
	objective.add_theme_color_override("font_color",INK)
	goal_bar=%GoalBar
	goal_bar.add_theme_stylebox_override("background",style(Color("f7f0ff"),4))
	goal_bar.add_theme_stylebox_override("fill",style(PURPLE,4))
	goal_panel.gui_input.connect(func(event):
		if event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed:
			if "Hire" in model.objective(): show_upgrades(true)
			elif "Recipe Book" in model.objective(): show_book()
			elif "Garden" in model.objective(): switch_tab("garden")
			elif "Improve" in model.objective() or "Lv." in model.objective() or "glow-up" in model.objective(): show_upgrades(false))
	# The stage is the hole in the HUD where the shop (World) or garden shows.
	stage=%Stage
	stage.gui_input.connect(stage_input)
	stage.resized.connect(fit_world)
	room=Room.new()
	room.model=model
	room.clip_contents=true
	room.mouse_filter=Control.MOUSE_FILTER_STOP
	room.gui_input.connect(func(event):
		if event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed:
			var id:String=room.station_at(event.position)
			if id=="plot": buy_plot()
			elif id!="" and id!=selected_station:
				selected_station=id
				sound.play("tap")
				refresh())
	ui.add_child(room)
	ui.move_child(room,0)
	room.hide()
	# Settings drop down from the gear.
	var settings_panel:=PanelContainer.new()
	settings_panel.add_theme_stylebox_override("panel",framed(CREAM,20,3))
	settings_panel.anchor_left=1.0
	settings_panel.anchor_right=1.0
	settings_panel.offset_left=-232
	settings_panel.offset_right=-12
	settings_panel.offset_top=78
	settings_panel.grow_horizontal=Control.GROW_DIRECTION_BEGIN
	ui.add_child(settings_panel)
	settings_box=VBoxContainer.new()
	settings_box.add_theme_constant_override("separation",8)
	settings_panel.add_child(margin(settings_box,4,4))
	settings_box.add_child(button("Décor",func():
		settings_box.hide()
		show_decor(),52,LAVENDER))
	mute=button("Sound",toggle_mute,52,SAND)
	settings_box.add_child(mute)
	settings_box.add_child(button("Reset progress",func():
		settings_box.hide()
		reset_dialog.popup_centered(Vector2i(440,180)),52,Color("f4c6b8")))
	settings_panel.hide()
	settings_box.visibility_changed.connect(func(): settings_panel.visible=settings_box.visible)
	settings_box.visible=false
	# Station card: the selected station, its level-up, status and stock.
	var card:PanelContainer=%Card
	var card_style:=framed(CREAM,26,3)
	card_style.corner_radius_bottom_left=0
	card_style.corner_radius_bottom_right=0
	card_style.border_width_bottom=0
	card_style.content_margin_left=16
	card_style.content_margin_right=16
	card_style.content_margin_top=14
	card_style.content_margin_bottom=10
	card.add_theme_stylebox_override("panel",card_style)
	%CardTile.add_theme_stylebox_override("panel",framed(SAND,16,2))
	card_icon=%CardIcon
	card_title=%CardTitle
	card_title.add_theme_font_size_override("font_size",22)
	card_title.add_theme_color_override("font_color",INK)
	card_detail=%CardDetail
	card_detail.add_theme_font_size_override("font_size",16)
	card_detail.add_theme_color_override("font_color",MUTED)
	card_milestone=%CardMilestone
	card_milestone.add_theme_font_size_override("font_size",14)
	card_milestone.add_theme_color_override("font_color",Color("7b4fd0"))
	upgrade_button=%LevelButton
	style_button(upgrade_button,TEAL)
	upgrade_button.pressed.connect(func(): level_up(selected_station))
	status=%Status
	status.add_theme_font_size_override("font_size",16)
	status.add_theme_color_override("font_color",INK)
	var chips:HBoxContainer=%Chips
	for crop in range(model.cfg.crops.size()):
		var c=chip(load("res://game/art/%s_t1.png" % Art.CROPS[crop]))
		chips.add_child(c[0])
		herb_chips.append(c[0])
		herb_counts.append(c[1])
		herb_icons.append(c[0].get_child(0).get_child(0))
	var bottle=chip(load("res://game/art/energy_t1.png"))
	chips.add_child(bottle[0])
	bottle_count=bottle[1]
	bottle_icon=bottle[0].get_child(0).get_child(0)
	primary=%PrimaryButton
	secondary=%SecondaryButton
	for b in [primary,secondary]: style_button(b,TEAL)
	primary.pressed.connect(act_primary)
	secondary.pressed.connect(act_secondary)
	# Bottom navigation.
	var nav:PanelContainer=%BottomBar
	var nav_style:=style(NIGHT,0)
	nav_style.content_margin_top=6
	nav_style.content_margin_bottom=8
	nav_style.content_margin_left=6
	nav_style.content_margin_right=6
	nav.add_theme_stylebox_override("panel",nav_style)
	shop_tab=%ShopButton
	garden_tab=%GardenButton
	var team_tab:Button=%TeamButton
	var grimoire_tab:Button=%GrimoireButton
	var upgrades_tab:Button=%UpgradesButton
	shop_tab.pressed.connect(func(): switch_tab("shop"))
	garden_tab.pressed.connect(func(): switch_tab("garden"))
	team_tab.pressed.connect(func(): show_upgrades(true))
	grimoire_tab.pressed.connect(func(): show_research())
	upgrades_tab.pressed.connect(func(): show_upgrades(false))
	nav_buttons=[shop_tab,garden_tab,team_tab,grimoire_tab,upgrades_tab]
	# A dot on the Grimoire while the lectern is free and a page is affordable.
	grimoire_dot=daily_dot.duplicate()
	grimoire_dot.position=Vector2(62,4)
	grimoire_tab.add_child(grimoire_dot)
	for b in nav_buttons:
		b.add_theme_font_size_override("font_size",14)
		b.add_theme_constant_override("icon_max_width",40)
		b.add_theme_constant_override("h_separation",2)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: b.add_theme_color_override(state,CREAM)
		squish(b)
	upgrade_layer=PanelContainer.new()
	upgrade_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	upgrade_layer.add_theme_stylebox_override("panel",style(Color(1.0,0.97,0.92,0.99),0))
	ui.add_child(upgrade_layer)
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
	grimoire_tabs=row()
	grimoire_tabs.add_theme_constant_override("separation",8)
	for pair in [["Recipes",func(): show_book()],["Research",func(): show_research()]]:
		var b:=button(pair[0],pair[1],46,SAND)
		grimoire_tabs.add_child(b)
	content.add_child(grimoire_tabs)
	grimoire_tabs.hide()
	var sub=label("Earn coins by selling potions, then grow your little business.",17)
	overlay_sub=sub
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
	build_welcome()
	build_catch_up()
	toast=PanelContainer.new()
	var toast_style:=style(INK,18)
	toast_style.content_margin_left=16
	toast_style.content_margin_right=16
	toast_style.content_margin_top=10
	toast_style.content_margin_bottom=10
	toast.add_theme_stylebox_override("panel",toast_style)
	toast.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var toast_row:=row()
	toast.add_child(toast_row)
	toast_row.add_child(picture(load("res://game/art/trophy.svg"),32))
	toast_label=label("",18)
	toast_label.add_theme_color_override("font_color",CREAM)
	toast_row.add_child(toast_label)
	ui.add_child(toast)
	toast.hide()
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
	branch_dialog=ConfirmationDialog.new()
	branch_dialog.title="Open a new branch?"
	branch_dialog.ok_button_text="Open branch"
	branch_dialog.confirmed.connect(func():
		if model.open_branch():
			upgrade_layer.hide()
			shown_coins=model.s.coins
			switch_tab("shop")
			persist()
			show_toast("Welcome to %s! ★ %d Moon Stars" % [model.branch_name(),int(model.s.prestige.stars)])
		refresh())
	add_child(branch_dialog)
	for dialog in [modal,reset_dialog,branch_dialog]:
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

func build_welcome():
	welcome_layer=ColorRect.new()
	welcome_layer.color=Color(0.1,0.08,0.2,0.45)
	welcome_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(welcome_layer)
	var centre:=CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	welcome_layer.add_child(centre)
	var card:=PanelContainer.new()
	var st:=style(CREAM,26)
	st.content_margin_left=24
	st.content_margin_right=24
	st.content_margin_top=22
	st.content_margin_bottom=20
	card.add_theme_stylebox_override("panel",st)
	card.custom_minimum_size.x=440
	centre.add_child(card)
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",10)
	card.add_child(stack)
	var head:=row()
	stack.add_child(head)
	head.add_child(picture(load("res://game/art/owner.png"),72))
	var titles:=VBoxContainer.new()
	titles.alignment=BoxContainer.ALIGNMENT_CENTER
	head.add_child(titles)
	titles.add_child(label("Welcome back!",28))
	welcome_away=label("",17)
	welcome_away.add_theme_color_override("font_color",Color("4b4e72"))
	titles.add_child(welcome_away)
	var earned:=PanelContainer.new()
	earned.add_theme_stylebox_override("panel",style(SAND,18))
	stack.add_child(earned)
	var coins_row:=row()
	coins_row.alignment=BoxContainer.ALIGNMENT_CENTER
	earned.add_child(coins_row)
	coins_row.add_child(picture(coin_tex,40))
	welcome_coins=label("",34)
	coins_row.add_child(welcome_coins)
	welcome_lines=VBoxContainer.new()
	welcome_lines.add_theme_constant_override("separation",4)
	stack.add_child(welcome_lines)
	stack.add_child(button("Collect",func():
		welcome_layer.hide()
		sound.play("dream_sale"),60))
	welcome_layer.hide()

func today() -> String:
	return Time.get_date_string_from_system()

func show_toast(text_line: String):
	toast_queue.append(text_line)
	if toast.visible: return
	while not toast_queue.is_empty():
		toast_label.text=toast_queue.pop_front()
		toast.reset_size()
		toast.position=Vector2((get_viewport_rect().size.x-toast.size.x)/2,-toast.size.y)
		toast.show()
		sound.play("upgrade")
		var tw:=toast.create_tween()
		tw.tween_property(toast,"position:y",156.0,0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(2.2)
		tw.tween_property(toast,"position:y",-toast.size.y-10,0.25)
		await tw.finished
	toast.hide()

const QUEST_ICONS = {"sold":"counter","brewed":"cauldron","harvested":"mint","levels":"shelf","specials":"customer1","earned":"coin"}

func ask_branch():
	if not model.can_prestige(): return
	branch_dialog.dialog_text="Your shop starts over in %s with +%d Moon Stars (+%d%% potion prices, forever).\n\nKept: Moon Stars, talents, achievements, lifetime stats, daily goals and streak.\nReset: coins, stations, team, upgrades, recipes and beds." % [model.BRANCHES[(int(model.s.prestige.branches)+1)%model.BRANCHES.size()],model.pending_stars(),int(model.pending_stars()*model.STAR_BONUS*100)]
	branch_dialog.popup_centered(Vector2i(480,250))

func show_daily():
	clear_cards()
	upgrade_title.text="Daily goals"
	overlay_sub.text="New goals every day. Come back tomorrow to grow your streak."
	section("LOGIN STREAK")
	shop_card(load("res://game/art/owner.png"),"","",func():
		model.claim_login()
		after_action(),"login")
	section("TODAY")
	for i in range(model.s.daily.get("quests",[]).size()):
		var q:Dictionary=model.s.daily.quests[i]
		var icon_name:String=QUEST_ICONS[q.kind]
		var icon:Texture2D=coin_tex if icon_name=="coin" else room.textures.get(icon_name+"_t1",room.textures.get(icon_name))
		shop_card(icon,"","",func():
			model.claim_quest(i)
			after_action(),"quest_%d" % i)
	section("ACHIEVEMENTS • %d of %d" % [model.s.achievements.size(),model.ACHIEVEMENTS.size()])
	var trophy:=load("res://game/art/trophy.svg")
	for a in model.ACHIEVEMENTS:
		shop_card(trophy,a[1],a[2],func(): pass,"ach_"+a[0])
	open_cards()

func build_catch_up():
	catch_layer=ColorRect.new()
	catch_layer.color=Color(0.1,0.08,0.2,0.45)
	catch_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catch_layer.mouse_filter=Control.MOUSE_FILTER_STOP
	ui.add_child(catch_layer)
	var centre:=CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catch_layer.add_child(centre)
	var card:=PanelContainer.new()
	var st:=style(CREAM,26)
	st.content_margin_left=24
	st.content_margin_right=24
	st.content_margin_top=22
	st.content_margin_bottom=24
	card.add_theme_stylebox_override("panel",st)
	card.custom_minimum_size.x=420
	centre.add_child(card)
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	card.add_child(stack)
	var head:=row()
	stack.add_child(head)
	head.add_child(picture(load("res://game/art/gardener.png"),64))
	var titles:=VBoxContainer.new()
	titles.alignment=BoxContainer.ALIGNMENT_CENTER
	head.add_child(titles)
	titles.add_child(label("Your team is catching up…",23))
	catch_label=label("",16)
	catch_label.add_theme_color_override("font_color",Color("4b4e72"))
	titles.add_child(catch_label)
	catch_bar=ProgressBar.new()
	catch_bar.show_percentage=false
	catch_bar.custom_minimum_size.y=14
	catch_bar.add_theme_stylebox_override("background",style(SAND,7))
	catch_bar.add_theme_stylebox_override("fill",style(TEAL,7))
	stack.add_child(catch_bar)
	catch_layer.hide()

# Offline work since the last save: short gaps run at once, long ones a slice
# per frame behind the progress card.
func start_catch_up(now: float):
	var job:Dictionary=model.begin_offline(now)
	if int(job.steps)<=CATCH_UP_INSTANT:
		model.step_offline(job,int(job.steps))
		finish_catch_up(job)
		return
	catch_job=job
	catch_label.text="Finishing %s of work while you were away" % duration(job.elapsed)
	catch_bar.value=0
	catch_layer.show()
	# The scene stays drawn but stops animating, leaving the frame for catch-up.
	room.set_process(false)
	shop.set_process(false)

func step_catch_up():
	var start:=Time.get_ticks_usec()
	var done:=false
	while not done and Time.get_ticks_usec()-start<CATCH_UP_BUDGET_USEC:
		done=model.step_offline(catch_job,400)
	catch_bar.value=100.0*int(catch_job.done)/maxf(1,int(catch_job.steps))
	if done:
		var job:=catch_job
		catch_job={}
		catch_layer.hide()
		room.set_process(true)
		shop.set_process(true)
		finish_catch_up(job)

func finish_catch_up(job: Dictionary):
	var report:Dictionary=model.finish_offline(job)
	shown_coins=model.s.coins
	accumulator=0.0
	persist()
	refresh()
	# Skip the card for quick returns that earned nothing.
	if model.s.offline_notice.is_empty(): return
	if int(report.coins)>0 or int(report.seconds)>=180: show_welcome(report)
	else:
		model.s.offline_notice={}
		persist()

func duration(seconds: float) -> String:
	var t:=int(seconds)
	if t>=3600: return "%dh %dm" % [t/3600,(t%3600)/60]
	if t>=60: return "%dm %ds" % [t/60,t%60]
	return "%ds" % t

# Coins are already credited when this shows; Collect only closes it.
func show_welcome(report: Dictionary):
	welcome_away.text="You were away %s" % duration(report.seconds)
	welcome_coins.text="+"+model.short(report.coins)
	for child in welcome_lines.get_children(): child.queue_free()
	var lines:=[]
	if model.owned("gardener"): lines.append("Pip harvested %s herbs" % model.short(report.get("harvested",0)))
	if model.owned("brewer"): lines.append("Momo brewed %s potions" % model.short(report.get("brewed",0)))
	if model.owned("cashier"): lines.append("Sol served %s customers" % model.short(report.get("sold",0)))
	if lines.is_empty(): lines.append("Hire helpers in Team so the shop keeps working while you're away.")
	if report.get("capped",false):
		lines.append("Your team rested after %s. Improve → lanterns keep them working longer." % duration(report.get("cap",7200)))
	for text_line in lines:
		var l:=label(text_line,18)
		l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		welcome_lines.add_child(l)
	welcome_layer.show()
	pop(welcome_layer.get_child(0).get_child(0),1.0,0.35,0.9)
	model.s.offline_notice={}
	persist()

func toggle_mute():
	model.s.muted=not model.s.muted
	sound.set_muted(model.s.muted)
	persist()
	refresh()

func switch_tab(value: String):
	var view:CanvasItem=room if value=="garden" else shop
	if value!=tab:
		sound.play("tap")
		room.particles.clear()
		room.floaters.clear()
		shop.particles.clear()
		shop.floaters.clear()
		view.modulate=Color(1,1,1,0.35)
		view.create_tween().tween_property(view,"modulate",Color.WHITE,0.22)
	tab=value
	room.visible=tab=="garden"
	shop.visible=tab=="shop"
	# On the garden tab the stage lets taps through to the garden view.
	stage.mouse_filter=Control.MOUSE_FILTER_IGNORE if tab=="garden" else Control.MOUSE_FILTER_STOP
	selected_station="garden" if tab=="garden" else "cauldron"
	room.queue_redraw()
	refresh()

# Fit the shop room into the stage (the space between the top bar and the
# card), and lay the garden view over the same space.
func fit_world():
	if not is_instance_valid(stage): return
	var rect:=stage.get_global_rect()
	var s:=minf(rect.size.x/SHOP_FRAME.size.x,rect.size.y/SHOP_FRAME.size.y)
	shop.scale=Vector2.ONE*s
	shop.position=rect.position+(rect.size-SHOP_FRAME.size*s)/2-SHOP_FRAME.position*s
	room.position=rect.position
	room.size=rect.size

func stage_input(event: InputEvent):
	if not (event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed): return
	if settings_box.visible:
		settings_box.hide()
		return
	var id:String=shop.station_at(stage.get_global_transform()*event.position)
	if id=="visitor": serve_visitor()
	elif id=="book": show_research()
	elif id!="" and id!=selected_station:
		selected_station=id
		sound.play("tap")
		refresh()

func choose_recipe(r: int):
	if storage.locked: return
	if model.recipe_unlocked(r):
		model.select_recipe(r)
		sound.play("tap")
	elif model.unlock_recipe(r):
		if purchase_cards.has("rc_%d" % r): pop(purchase_cards["rc_%d" % r],1.0,0.35,1.06)
	after_action()

func serve_visitor():
	if storage.locked: return
	if not model.serve_visitor(): sound.play("tap")
	after_action()

func buy_plot():
	if storage.locked: return
	model.buy_plot()
	after_action()

func potion_icon(r: int) -> Texture2D:
	return room.textures[Art.name_for(Art.POTIONS[r],model.level("cauldron"))]

func show_book():
	clear_cards()
	show_grimoire_tabs(0)
	upgrade_title.text="Recipe Book"
	overlay_sub.text="Unlock potions, then choose what to brew. Your beds plant whatever it needs."
	var next:int=model.next_locked_recipe()
	for r in range(model.cfg.recipes.size()):
		shop_card(potion_icon(r),"","",choose_recipe.bind(r),"rc_%d" % r)
		# Recipes beyond the next unlock stay a mystery until you get there.
		if next!=-1 and r>next: purchase_cards["rc_%d" % r].get_child(0).get_child(0).get_child(0).modulate=Color(0.15,0.12,0.25,0.85)
	open_cards()

func show_grimoire_tabs(active: int):
	grimoire_tabs.show()
	for i in range(grimoire_tabs.get_child_count()):
		var b:Button=grimoire_tabs.get_child(i)
		paint(b,LAVENDER if i==active else SAND)

# The Grimoire's Research tab: what the lectern is studying, the chapters, the
# chapter's tree, and the selected page with its Study button.
func show_research():
	clear_cards()
	show_grimoire_tabs(1)
	upgrade_title.text="Grimoire"
	var desk:=PanelContainer.new()
	desk.add_theme_stylebox_override("panel",framed(SAND,18,2))
	upgrade_list.add_child(desk)
	var desk_rows:=VBoxContainer.new()
	desk_rows.add_theme_constant_override("separation",8)
	desk.add_child(desk_rows)
	research_ui={"desks":[]}
	for i in range(2):
		var r:=row()
		r.add_child(picture(shop.textures["lectern_t%d" % shop.tier_for("lectern")],44))
		var copy:=VBoxContainer.new()
		copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		copy.add_theme_constant_override("separation",2)
		r.add_child(copy)
		var l:=label("",17)
		copy.add_child(l)
		var bar:=ProgressBar.new()
		bar.show_percentage=false
		bar.custom_minimum_size.y=10
		bar.add_theme_stylebox_override("background",style(Color("e6d9f2"),5))
		bar.add_theme_stylebox_override("fill",style(PURPLE,5))
		copy.add_child(bar)
		var left:=label("",14)
		left.add_theme_color_override("font_color",MUTED)
		copy.add_child(left)
		desk_rows.add_child(r)
		research_ui.desks.append({"row":r,"label":l,"bar":bar,"left":left})
	var chips:=HFlowContainer.new()
	chips.add_theme_constant_override("h_separation",6)
	chips.add_theme_constant_override("v_separation",6)
	upgrade_list.add_child(chips)
	research_ui.chips={}
	for c in model.research.chapters:
		var b:=button(c.name,func():
			grimoire_chapter=c.id
			grimoire_page=""
			sound.play("tap")
			refresh(),44,CREAM)
		b.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
		b.custom_minimum_size.y=40
		b.add_theme_font_size_override("font_size",15)
		chips.add_child(b)
		research_ui.chips[c.id]=b
	var tree:=ResearchTree.new()
	tree.model=model
	tree.custom_minimum_size.y=310
	tree.icons=research_icons()
	tree.picked.connect(func(id):
		grimoire_page=id
		sound.play("tap")
		refresh())
	upgrade_list.add_child(tree)
	research_ui.tree=tree
	var card:=PanelContainer.new()
	card.add_theme_stylebox_override("panel",framed(Color("fffaf1"),20,2))
	upgrade_list.add_child(card)
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",4)
	card.add_child(stack)
	var title:=label("",21)
	var flavour:=label("",15)
	flavour.add_theme_color_override("font_color",MUTED)
	var effect:=label("",17)
	effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for l in [title,flavour,effect]: stack.add_child(l)
	var foot:=row()
	stack.add_child(foot)
	var cost:=label("",15)
	cost.add_theme_color_override("font_color",MUTED)
	cost.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	cost.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(cost)
	var study:=button("Study",study_selected,56)
	study.custom_minimum_size.x=150
	study.size_flags_horizontal=Control.SIZE_SHRINK_END
	foot.add_child(study)
	research_ui.detail={"card":card,"title":title,"flavour":flavour,"effect":effect,"cost":cost,"button":study}
	open_cards()

# Page and talent icons reuse the game's own sprites.
func research_icons() -> Dictionary:
	var icons:={}
	for page in model.research.pages: icons[page.id]=coin_tex if page.icon=="coin" else shop.textures.get(page.icon,room.textures.get(page.icon))
	for t in model.cfg.talents: icons[t.id]=shop.textures.get(TALENT_ICONS[t.id],room.textures.get(TALENT_ICONS[t.id]))
	return icons

func can_study_any() -> bool:
	for page in model.research.pages:
		if model.can_study(page.id): return true
	return false

# What a page does at a given rank, in the player's terms.
func effect_text(page: Dictionary, at_rank: int) -> String:
	var v:float=float(page.per_rank)*at_rank
	match page.effect:
		"double_harvest": return "%d%% chance a bed yields double" % roundi(v*100)
		"herb_capacity": return "+%d herb bin space" % int(v)
		"seed_library": return "New branches open with a third garden bed"
		"harvest_yield": return "+%d herb from every bed's harvest" % int(v)
		"moonlit": return "Beds grow twice as fast while you're away"
		"bonus_bottle": return "%d%% chance a brew makes a bonus bottle" % roundi(v*100)
		"herb_thrift": return "%d%% chance a brew uses no herbs" % roundi(v*100)
		"shelf_space": return "+%d shelf space" % int(v)
		"recipe_memory": return "Your first %d recipes after Energy Brew stay unlocked in a new branch" % int(v)
		"twin_brew": return "Every brew makes two bottles"
		"price": return "+%d%% potion prices" % roundi(v*100)
		"visitor_rate": return "Special visitors come %d%% more often" % roundi(v*100)
		"queue_spot": return "+%d queue spot" % int(v)
		"visitor_wait": return "Special visitors wait %ds longer" % int(v)
		"royal_warrant": return "VIPs pay ×15 instead of ×10 and wait twice as long"
		"study_speed": return "Studies finish %d%% faster" % roundi(v*100)
		"offline_hours": return "+%d h of work while you're away" % int(v/3600)
		"second_desk": return "Study two pages at once"
		"star_bonus": return "+%d%% Moon Stars from each branch" % roundi(v*100)
		"early_branch": return "Open a new branch at Lv. %d instead of Lv. %d" % [model.PRESTIGE_LEVEL-int(v),model.PRESTIGE_LEVEL]
	return ""

func study_selected():
	if storage.locked or grimoire_page=="": return
	if grimoire_chapter=="star": buy_talent(grimoire_page)
	elif model.start_study(grimoire_page): pop(research_ui.detail.card,1.0,0.35,1.06)
	after_action()

func refresh_research():
	if research_ui.is_empty() or not upgrade_layer.visible: return
	var s:Dictionary=model.s
	overlay_sub.text="✦ %s Lore • pages stay learned through every branch" % model.short(int(s.research.lore))
	for i in range(2):
		var d:Dictionary=research_ui.desks[i]
		d.row.visible=i<model.desks()
		if i<s.research.active.size():
			var a:Dictionary=s.research.active[i]
			var page:Dictionary=model.pages[a.id]
			var total:float=maxf(1.0,model.page_seconds(a.id))
			d.label.text="Studying: %s%s" % [page.name," "+["I","II","III","IV","V"][model.rank(a.id)] if int(page.ranks)>1 else ""]
			d.bar.value=100.0*(1.0-model.study_left(a)/total)
			d.bar.visible=true
			d.left.text="%s left • keeps going while you're away" % duration(model.study_left(a))
		else:
			d.label.text="The lectern is free"
			d.bar.visible=false
			d.left.text="Earn Lore by brewing, serving special visitors and reaching milestones"
			d.left.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for id in research_ui.chips:
		var chip:Button=research_ui.chips[id]
		paint(chip,LAVENDER if id==grimoire_chapter else CREAM,14)
		for state in ["normal","hover","pressed","disabled"]:
			var st:StyleBoxFlat=chip.get_theme_stylebox(state)
			st.content_margin_left=9
			st.content_margin_right=9
	var tree=research_ui.tree
	tree.chapter=grimoire_chapter
	# Default to the page being studied, then the first one ready.
	if grimoire_page=="" or not tree.entries().any(func(e): return e.id==grimoire_page):
		var list:Array=tree.entries()
		grimoire_page=list[0].id
		for e in list:
			if e.state=="studying":
				grimoire_page=e.id
				break
		if not list.any(func(e): return e.id==grimoire_page and e.state=="studying"):
			for e in list:
				if e.state=="ready":
					grimoire_page=e.id
					break
	tree.selected=grimoire_page
	var d:Dictionary=research_ui.detail
	var b:Button=d.button
	if grimoire_chapter=="star":
		var t:Dictionary=model.talent_info(grimoire_page)
		var r:int=model.talent(grimoire_page)
		var top:bool=r>=int(t.ranks)
		d.title.text="%s · %d/%d" % [t.name,r,int(t.ranks)]
		d.flavour.text="Celestial pages cost Moon Stars and are learned at once."
		d.effect.text=t.benefit
		d.cost.text="★ %d of %d free" % [model.stars_free(),int(s.prestige.stars)]
		b.text="Learned" if top else "Learn • ★ %d" % model.talent_cost(grimoire_page)
		b.icon=null
		b.disabled=top or model.stars_free()<model.talent_cost(grimoire_page)
		return
	var page:Dictionary=model.pages[grimoire_page]
	var rank:int=model.rank(grimoire_page)
	var state:String=model.page_state(grimoire_page)
	d.title.text=page.name+(" · %d/%d" % [rank,int(page.ranks)] if int(page.ranks)>1 else "")+(" ◆ Keystone" if int(page.tier)==3 else "")
	d.flavour.text=page.flavour
	if state=="learned": d.effect.text=effect_text(page,rank)
	elif rank>0: d.effect.text="Now: %s\nNext: %s" % [effect_text(page,rank),effect_text(page,rank+1)]
	else: d.effect.text=effect_text(page,1)
	match state:
		"learned":
			d.cost.text="Fully learned"
			b.text="Learned"
		"studying":
			d.cost.text="At the lectern now"
			b.text="Studying…"
		"locked":
			d.cost.text="Needs %d ranks in %s first" % [int(model.research.tier_needs[int(page.tier)-1]),"tier one" if int(page.tier)==2 else "tier two"]
			b.text="Locked"
		_:
			d.cost.text="✦ %s Lore • %s" % [model.short(model.page_cost(grimoire_page)),duration(model.page_seconds(grimoire_page))]
			b.text="Desk busy" if s.research.active.size()>=model.desks() else "Study"
	b.icon=null
	b.disabled=not model.can_study(grimoire_page)

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
	after_action()

func buy_talent(id: String):
	if storage.locked: return
	if model.buy_talent(id) and research_ui.has("detail"): pop(research_ui.detail.card,1.0,0.35,1.06)
	after_action()

func level_up(id: String):
	if storage.locked: return
	room.selected=id
	if model.level_up(id):
		pop(upgrade_button,1.0,0.3,1.1)
		if purchase_cards.has("lv_"+id): pop(purchase_cards["lv_"+id],1.0,0.3,1.05)
	after_action()

func seconds(v: float) -> String:
	return "%.2fs" % v if v<2 else "%.1fs" % v

# Current value of a station's headline stat, for "now → next" text.
func station_value(id: String) -> String:
	match id:
		"garden": return seconds(model.grow_time(int(model.s.plots[0].crop)))
		"cauldron": return seconds(model.brew_time(int(model.s.recipe)))
		"counter": return seconds(model.arrival_time())
		"gardener": return seconds(model.grow_time(int(model.s.plots[0].crop)))
		"brewer": return seconds(model.brew_time(int(model.s.recipe)))
	return model.short(model.price(int(model.s.recipe)))

func station_detail(id: String) -> String:
	var label_text:String={"garden":"Grow","cauldron":"Brew","counter":"Customer every","shelf":"Price","gardener":"Grow","brewer":"Brew","cashier":"Price with tips"}[id]
	var now:=station_value(id)
	if model.level(id)>=int(model.cfg.max_level): return "%s %s" % [label_text,now]
	model.s.levels[id]+=1
	var next:=station_value(id)
	model.s.levels[id]-=1
	return "%s %s → %s" % [label_text,now,next]

func station_milestone(id: String) -> String:
	var m:int=model.next_milestone(id)
	if m==0: return "★ Max level"
	var what:String={"garden":"growth","cauldron":"brew speed","counter":"customers","shelf":"prices","gardener":"growth","brewer":"brew speed","cashier":"tips"}[id]
	return "★ Lv. %d: ×2 %s" % [m,what]

func station_name(id: String) -> String:
	if id=="garden": return "Garden beds"
	for st in model.cfg.stations+model.cfg.workers:
		if st.id==id: return st.name
	return id

func station_icon(id: String) -> Texture2D:
	if id in model.WORKERS: return room.textures[id]
	if id=="garden":
		return room.textures[Art.name_for(Art.CROPS[int(model.s.plots[0].crop)],model.level("garden"))]
	return shop.textures[Art.name_for(STATION_ICONS[id],model.level(id))]

func shop_card(icon: Texture2D, title: String, benefit: String, action: Callable, key: String):
	var card:=PanelContainer.new()
	var st:=style(Color("fffaf1"),20)
	st.border_color=Color(WOOD,.35)
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
	r.add_child(tile(icon,60))
	var copy:=VBoxContainer.new()
	copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	copy.alignment=BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation",2)
	r.add_child(copy)
	var name_label:=label(title,21)
	copy.add_child(name_label)
	var benefit_label:=label(benefit,16)
	benefit_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	benefit_label.add_theme_color_override("font_color",Color("4b4e72"))
	copy.add_child(benefit_label)
	var b:=button("",action,60)
	b.custom_minimum_size.x=112
	b.size_flags_horizontal=Control.SIZE_SHRINK_END
	b.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	r.add_child(b)
	purchase_buttons[key]=b
	purchase_cards[key]=card
	purchase_labels[key]=[name_label,benefit_label]

func section(title: String) -> Label:
	var l:=label(title,16)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color",Color("7b4fd0"))
	upgrade_list.add_child(l)
	return l

func show_upgrades(team: bool):
	clear_cards()
	upgrade_title.text="Your team" if team else "Improve the shop"
	overlay_sub.text="Earn coins by selling potions, then grow your little business."
	if not team:
		section("NEW BRANCH • Moon Stars raise every potion price for good; spend them in the Grimoire's Celestial chapter")
		shop_card(room.textures["dream_t3"],"","",func(): ask_branch(),"branch")
		section("STATIONS • new furniture at levels 3 and 7; levels 10, 25, 50, 75 and 100 double output")
		for id in model.STATIONS: shop_card(station_icon(id),"","",level_up.bind(id),"lv_"+id)
		section("ONE-TIME UPGRADES")
	for p in model.cfg.purchases:
		if (p.id in ["gardener","brewer","cashier"]) != team: continue
		var icon_name:String=PURCHASE_ICONS.get(p.id,"plant")
		shop_card(shop.textures.get(icon_name,room.textures.get(icon_name)),p.name,p.benefit,buy.bind(p.id),p.id)
	if team:
		section("TRAIN YOUR TEAM • levels 10, 25, 50, 75 and 100 double each helper")
		for id in model.WORKERS: shop_card(station_icon(id),"","",level_up.bind(id),"lv_"+id)
	open_cards()

func clear_cards():
	grimoire_tabs.hide()
	research_ui={}
	for child in upgrade_list.get_children():
		upgrade_list.remove_child(child)
		child.queue_free()
	purchase_buttons.clear()
	purchase_cards.clear()
	purchase_labels.clear()

func show_decor():
	clear_cards()
	upgrade_title.text="Choose your décor"
	overlay_sub.text="Select an unlocked look. New finishes arrive as your shop grows."
	section("RUGS • the rug and doormat")
	for i in range(3): shop_card(shop.textures["rug_t%d" % (i+1)],Art.RUGS[i],Art.FLOORS[i].unlock,select_decor.bind("floor",i),"decor_floor_%d" % i)
	section("PLANTERS • the potted plant")
	for i in range(3): shop_card(shop.textures["plant_t%d" % (i+1)],Art.PLANTERS[i],Art.WALLS[i].unlock,select_decor.bind("wall",i),"decor_wall_%d" % i)
	open_cards()

func select_decor(kind: String,variant: int):
	if storage.locked: return
	if model.select_decor(kind,variant):
		sound.play("upgrade")
		room.queue_redraw()
		persist()
		refresh()

func open_cards():
	upgrade_layer.modulate=Color(1,1,1,0)
	upgrade_layer.show()
	upgrade_layer.create_tween().tween_property(upgrade_layer,"modulate",Color.WHITE,0.16)
	sound.play("tap")
	refresh()

func close_upgrades():
	upgrade_layer.hide()
	sound.play("tap")

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
	var stars:int=int(model.s.prestige.stars)
	header.text=("Herb Garden" if tab=="garden" else "Potion Shop" if int(model.s.prestige.branches)==0 else model.branch_name())+(" ★%d" % stars if stars>0 else "")
	if model.s.coins<shown_coins or not is_processing(): shown_coins=model.s.coins
	coins_label.text=model.short(shown_coins)
	var goal:String=model.objective()
	objective.text=goal
	if goal!=last_objective:
		if last_objective!="": pop(goal_panel,1.0,0.4,1.06)
		last_objective=goal
	var progress:float=model.goal_progress()
	goal_bar.visible=progress>=0
	goal_bar.value=progress*100
	goal_bar.add_theme_stylebox_override("fill",style(TEAL if goal_bar.value>=100 else Color("a77cf0"),4))
	mute.text="Muted" if model.s.muted else "Sound"
	var s: Dictionary=model.s
	var id:=selected_station
	var maxed:bool=model.level(id)>=int(model.cfg.max_level)
	room.selected=id
	shop.selected=id
	card_title.text="%s · Lv. %d" % [station_name(id),model.level(id)]
	card_icon.texture=station_icon(id)
	card_detail.text=station_detail(id)
	card_milestone.text=station_milestone(id)
	upgrade_button.text="Max" if maxed else "Level up\n"+model.short(model.level_cost(id))
	upgrade_button.icon=null if maxed else coin_tex
	upgrade_button.disabled=maxed or s.coins<model.level_cost(id)
	# Show a chip for each herb you hold or the current recipe needs.
	var wanted:=[]
	for n in model.needs(int(s.recipe)): wanted.append(int(n[0]))
	for crop in range(herb_chips.size()):
		herb_counts[crop].text=str(int(s.herbs[crop]))
		herb_chips[crop].visible=crop in wanted or s.herbs[crop]>0
	bottle_count.text="%d / %d" % [model.stock_count(),model.capacity()]
	bottle_icon.texture=potion_icon(int(s.recipe))
	status.text=model.status()
	primary.visible=not model.owned("gardener" if tab=="garden" else "brewer")
	secondary.visible=tab=="garden" or not model.owned("cashier")
	if tab=="garden":
		status.text="Beds plant for %s • %s" % [model.cfg.recipes[int(s.recipe)].name,model.ingredient_text(int(s.recipe))]
		primary.text="Harvest + replant"
		var ready:=false
		for p in s.plots:
			if p.progress>=model.grow_time(p.crop) and s.herbs[int(p.crop)]+2<=model.herb_capacity(): ready=true
		primary.disabled=not ready
		if not ready:
			for p in s.plots:
				if p.progress>=model.grow_time(p.crop) and s.herbs[int(p.crop)]+2>model.herb_capacity(): status.text="Herb bin full • brew or switch crops"
		secondary.text="Go brew →"
		secondary.disabled=false
	else:
		primary.text="Stock potion" if s.ready else "Brewing…" if s.pot!=-1 else "Brew potion"
		primary.disabled=(not s.ready and (s.pot!=-1 or not model.can_brew(int(s.recipe)))) or model.stock_count()>=model.capacity()
		if not s.visitor.is_empty():
			var vip:bool=s.visitor.kind=="vip"
			var wants:String="any potion" if vip else model.cfg.recipes[int(s.visitor.recipe)].name
			status.text=("★ VIP" if vip else "★ Special order")+" wants %s • tap them for %s" % [wants,model.short(model.visitor_pay())] if model.visitor_potion()>=0 else "%s wants %s • brew one before they leave" % ["A VIP" if vip else "A customer",wants]
		secondary.text="Checkout busy" if s.serving else "Serve • %d waiting" % s.queue
		secondary.disabled=s.serving or s.queue==0 or model.stock_count()==0
	%Actions.visible=primary.visible or secondary.visible
	if styled_tab!=tab:
		styled_tab=tab
		for b in nav_buttons:
			var active:bool=b==shop_tab and tab=="shop" or b==garden_tab and tab=="garden"
			var st:=style(Color(PURPLE,.85) if active else Color(1,1,1,0),16)
			st.content_margin_top=4
			st.content_margin_bottom=4
			for state in ["normal","hover","pressed","focus"]: b.add_theme_stylebox_override(state,st)
			b.modulate=Color.WHITE if active else Color(1,1,1,0.8)
	for sid in model.STATIONS+model.WORKERS:
		if purchase_buttons.has("lv_"+sid):
			var b: Button=purchase_buttons["lv_"+sid]
			var top:bool=model.level(sid)>=int(model.cfg.max_level)
			var hired:bool=not sid in model.WORKERS or model.owned(sid)
			b.text="Max" if top else model.short(model.level_cost(sid)) if hired else "Hire first"
			b.icon=coin_tex if hired and not top else null
			b.disabled=top or not hired or s.coins<model.level_cost(sid)
			purchase_cards["lv_"+sid].modulate=Color.WHITE if hired else Color(1,1,1,.62)
			purchase_labels["lv_"+sid][0].text="%s · Lv. %d" % [station_name(sid),model.level(sid)]
			purchase_labels["lv_"+sid][1].text=station_detail(sid)+"\n"+station_milestone(sid)
	refresh_research()
	grimoire_dot.visible=s.research.active.size()<model.desks() and can_study_any()
	for p in model.cfg.purchases:
		if purchase_buttons.has(p.id):
			var b: Button=purchase_buttons[p.id]
			var owned:bool=model.owned(p.id)
			b.text=("Hired" if p.id in ["gardener","brewer","cashier"] else "Owned") if owned else "%d" % p.cost
			b.icon=null if owned else coin_tex
			b.disabled=owned or s.coins<p.cost
			purchase_cards[p.id].modulate=Color(1,1,1,0.62) if owned else Color.WHITE
	daily_dot.visible=model.claimable()
	if purchase_buttons.has("branch"):
		var b:Button=purchase_buttons["branch"]
		var next_name:String=model.BRANCHES[(int(s.prestige.branches)+1)%model.BRANCHES.size()]
		purchase_labels["branch"][0].text="Open %s" % next_name
		if model.stat("top_level")<model.prestige_level():
			purchase_labels["branch"][1].text="Reach Lv. %d on any station to open a branch" % model.prestige_level()
		else:
			purchase_labels["branch"][1].text="+%d Moon Stars now • next star at %s earned this run" % [model.pending_stars(),model.short(pow(model.pending_stars()+1,2)*model.STAR_COINS)]
		b.text="Open" if model.can_prestige() else "Locked"
		b.disabled=not model.can_prestige()
	if purchase_buttons.has("login"):
		var login:Dictionary=s.login
		var b:Button=purchase_buttons["login"]
		purchase_labels["login"][0].text="Day %d of 7" % int(login.get("streak",1))
		purchase_labels["login"][1].text="Today's gift grows with your streak"
		b.text="Claimed" if login.get("claimed",true) else model.short(login.get("reward",0))
		b.icon=null if login.get("claimed",true) else coin_tex
		b.disabled=login.get("claimed",true)
	for i in range(s.daily.get("quests",[]).size()):
		var key="quest_%d" % i
		if not purchase_buttons.has(key): continue
		var q:Dictionary=s.daily.quests[i]
		var b:Button=purchase_buttons[key]
		var done:bool=int(q.progress)>=int(q.target)
		purchase_labels[key][0].text=model.quest_text(q)
		purchase_labels[key][1].text="%s / %s" % [model.short(q.progress),model.short(q.target)]
		b.text="Claimed" if q.claimed else model.short(q.reward)
		b.icon=null if q.claimed else coin_tex
		b.disabled=q.claimed or not done
		purchase_cards[key].modulate=Color(1,1,1,.62) if q.claimed else Color.WHITE
	for a in model.ACHIEVEMENTS:
		var key="ach_"+a[0]
		if not purchase_buttons.has(key): continue
		var got:bool=s.achievements.has(a[0])
		var b:Button=purchase_buttons[key]
		b.text="Done" if got else "%s/%s" % [model.short(mini(model.stat(a[3]),a[4])),model.short(a[4])]
		b.disabled=true
		purchase_cards[key].modulate=Color.WHITE if got else Color(1,1,1,.6)
	var next:int=model.next_locked_recipe()
	for r in range(model.cfg.recipes.size()):
		var key="rc_%d" % r
		if not purchase_buttons.has(key): continue
		var rec:Dictionary=model.cfg.recipes[r]
		var b:Button=purchase_buttons[key]
		var unlocked:bool=model.recipe_unlocked(r)
		var hidden:bool=next!=-1 and r>next
		purchase_labels[key][0].text="???" if hidden else rec.name
		purchase_labels[key][1].text="Unlock %s first" % model.cfg.recipes[next].name if hidden else "%s • sells %s • %s" % [model.ingredient_text(r),model.short(model.price(r)),seconds(model.brew_time(r))]
		b.icon=null if unlocked or hidden else coin_tex
		b.text="Brewing" if int(s.recipe)==r else "Brew" if unlocked else "Locked" if hidden else model.short(rec.unlock)
		b.disabled=int(s.recipe)==r or hidden or (not unlocked and s.coins<rec.unlock)
		purchase_cards[key].modulate=Color(1,1,1,.7) if hidden else Color.WHITE
	for kind in ["floor","wall"]:
		for i in range(3):
			var key="decor_%s_%d" % [kind,i]
			if purchase_buttons.has(key):
				var b:Button=purchase_buttons[key]
				var unlocked:bool=model.decor_unlocked(kind,i)
				var chosen:bool=int(s.decor[kind])==i
				b.text="Selected" if chosen else "Use" if unlocked else "Locked"
				b.disabled=not unlocked or chosen
				purchase_cards[key].modulate=Color.WHITE if unlocked else Color(1,1,1,.65)
	if storage.locked:
		primary.disabled=true
		secondary.disabled=true
		status.text=storage.error

func flush_feedback():
	for kind in model.feedback:
		if tab=="garden": room.burst(kind)
		else: shop.burst(kind)
		sound.play("upgrade" if kind in ["level","milestone","study"] else "dream_sale" if kind in ["vip","request"] else "tap" if kind in ["visitor","study_start"] else kind)
		if OS.get_name()=="Android" and kind in ["sale","dream_sale","upgrade","milestone","vip","request"]: Input.vibrate_handheld(40 if kind in ["milestone","vip"] else 18,0.3)
	model.feedback.clear()

func persist():
	if harness or not catch_job.is_empty(): return
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
	if not catch_job.is_empty():
		step_catch_up()
		return
	perf_frames.append(dt*1000.0)
	perf_clock += dt
	if perf_clock >= 30:
		perf_frames.sort()
		print("LUX_PERF fps=",snapped(perf_frames.size()/perf_clock,0.1)," p95_ms=",snapped(perf_frames[int(perf_frames.size()*0.95)],0.1)," process_ms=",snapped(Performance.get_monitor(Performance.TIME_PROCESS)*1000,0.01))
		perf_frames.clear()
		perf_clock=0.0
	accumulator+=minf(dt,1.0)
	model.begin_ticks()
	while accumulator>=model.cfg.step:
		model.tick(model.cfg.step)
		accumulator-=model.cfg.step
	model.end_ticks()
	save_timer+=dt
	flush_feedback()
	if model.dirty or save_timer>=5:
		persist()
		save_timer=0
	animate_ui(dt)
	day_timer-=dt
	if day_timer<=0:
		day_timer=30.0
		model.ensure_day(today())
	model.check_achievements()
	while not model.new_achievements.is_empty(): show_toast("Achievement: "+model.new_achievements.pop_front())
	while not model.finished_studies.is_empty(): show_toast("Research complete: "+model.finished_studies.pop_front())
	ui_timer+=dt
	if ui_timer>=0.1:
		ui_timer=0
		refresh()

func _notification(what):
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_CLOSE_REQUEST]:
		if not catch_job.is_empty():
			# Save only the simulated part; the rest catches up on return.
			var job:=catch_job
			catch_job={}
			catch_layer.hide()
			room.set_process(true)
			shop.set_process(true)
			if not harness: storage.save(model,model.partial_timestamp(job))
		elif is_instance_valid(status): persist()
	if what==NOTIFICATION_APPLICATION_RESUMED and is_instance_valid(status) and not harness and catch_job.is_empty():
		start_catch_up(Time.get_unix_time_from_system())
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
	# Let tab fades finish so evidence shows the settled scene.
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/evidence/tiered/"+("tall-" if "--tall" in OS.get_cmdline_user_args() else "")+name+".png")

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
		if not model.owned("recipe") and model.owned("cashier") and model.s.coins>=model.cfg.recipes[1].unlock:
			show_book()
			await get_tree().process_frame
			await tap(purchase_buttons["rc_1"])
			upgrade_layer.hide()
			print("PLAY purchase recipe at ",model.s.elapsed)
		for id in ["gardener","brewer","cashier","renovation","grow","brew","capacity","service"]:
			if id=="renovation" and not model.owned("recipe"): break
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
		if model.owned("service"):
			# After the one-time purchases, keep levelling the cheapest station via the card.
			var cheapest:="cauldron"
			for sid in model.STATIONS:
				if model.level_cost(sid)<model.level_cost(cheapest): cheapest=sid
			if model.s.coins>=model.level_cost(cheapest):
				selected_station=cheapest
				refresh()
				await tap(upgrade_button)
		if model.owned("cashier") and not recorded_automation:
			await screenshot("automated-shop")
			recorded_automation=true
		if model.owned("renovation") and not recorded_renovation:
			await screenshot("renovated-shop")
			recorded_renovation=true
		if model.owned("service") and model.s.plots.size()<3 and model.s.coins>=model.plot_cost():
			await tap(garden_tab)
			var point=room.view_offset+room.bed_center(model.s.plots.size())*room.view_scale
			var press=InputEventMouseButton.new()
			press.button_index=MOUSE_BUTTON_LEFT
			press.pressed=true
			press.position=point
			room.gui_input.emit(press)
			print("PLAY purchase plot at ",model.s.elapsed)
			await tap(shop_tab)
	print("PLAY FINAL ",JSON.stringify(model.s))
	var file:=FileAccess.open("res://docs/evidence/playthrough-events.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(model.events,"  "))
	await screenshot("five-minute-shop")
	var code=0 if model.owned("renovation") and model.s.flags.has("tutorial_complete") else 1
	var tree=get_tree()
	sound.set_muted(true)
	tree.create_timer(.3).timeout.connect(tree.quit.bind(code))
	queue_free()
