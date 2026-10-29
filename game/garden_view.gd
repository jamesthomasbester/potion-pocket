extends "res://game/scene_view.gd"
# The garden tab in main.tscn: the painted yard, a planter per bought bed that
# shows its growth stage, props that arrive as the garden levels up, Pip and
# the owner, and the next plot to buy. Coordinates are the yard image's pixels;
# main.gd fits this node to the stage.

# The old drawn sprites, still used for crop icons and menu pictures.
var textures := {}
var gardener
var owner_actor
var tufts: Array = []
var stages := {}
# Bed slots in purchase order: three each side of the path.
const BEDS = [Vector2(185,560),Vector2(660,640),Vector2(180,745),Vector2(680,830),Vector2(190,930),Vector2(660,1010)]
const BED_BASE = .25
# Props by the garden level that brings them.
const PROP_LEVELS = {"WateringCan":1,"Barrel":1,"Wheelbarrow":3,"SoilSack":3,"Bench":7,"BirdBath":7,"Beehive":10,"PotStack":25}
# Crops that flower show the flowering planter; the rest show leaves.
const FLOWERING = [1,4]
# A tint and an ambient touch for each branch, in economy BRANCHES order.
const THEMES = [
	{"tint":"ffffff","extra":""},
	{"tint":"fff1d2","extra":"gulls"},
	{"tint":"e8f0ff","extra":"snow"},
	{"tint":"aebfcf","extra":"fireflies"},
	{"tint":"fff6c8","extra":""},
	{"tint":"d6d2ff","extra":"stars"}]

func _ready():
	super()
	selected="garden"
	ui_scale=1.5
	for name in ["cauldron","shelf","counter","leaves","flowers","bed","bush","plant","gate","owner","brewer","cashier","gardener","customer0","customer1","departing","energy","dream"]:
		var path="res://game/art/"+name+".png"
		if ResourceLoader.exists(path): textures[name]=load(path)
	for family in Art.FAMILIES:
		for tier in range(1,4):
			var name="%s_t%d" % [family,tier]
			textures[name]=load("res://game/art/"+name+".png")
	for stage in ["empty","sprouts","leafy","flowers"]: stages[stage]=load("res://game/art/garden/planter_%s.png" % stage)
	owner_actor=add_actor("owner",96)
	var rng:=RandomNumberGenerator.new()
	rng.seed=7
	for i in range(40): tufts.append(Vector2(rng.randf_range(0,832),rng.randf_range(0,1216)))

func theme() -> Dictionary:
	return THEMES[int(model.s.prestige.branches) % THEMES.size()]

func bed(i:int) -> Sprite2D:
	return props.get_node("Bed%d" % (i+1))

# Global canvas position of a bed slot, for taps and tests.
func bed_point(i:int) -> Vector2:
	return to_global(BEDS[i]-Vector2(0,60))

func stage_for(plot:Dictionary) -> String:
	var t:float=plot.progress/model.grow_time(int(plot.crop))
	if t<.2: return "empty"
	if t<.6: return "sprouts"
	return "flowers" if int(plot.crop) in FLOWERING else "leafy"

func _process(dt):
	if not model: return
	step_effects(dt)
	get_node("Yard").modulate=Color(theme().tint)
	var n:int=model.s.plots.size()
	for i in range(BEDS.size()):
		var sprite:=bed(i)
		sprite.visible=i<n
		if i>=n: continue
		var tex:Texture2D=stages[stage_for(model.s.plots[i])]
		if sprite.texture!=tex:
			sprite.texture=tex
			sprite.offset=Vector2(0,-tex.get_height()*(.5-BED_BASE))
		var t:float=bounce.get("bed"+str(i),0.0)
		var squash=sin(t*PI*3.0)*t*.12
		sprite.scale=Vector2(1+squash,1-squash)*.57
	for node in PROP_LEVELS: props.get_node(node).visible=model.level("garden")>=PROP_LEVELS[node]
	var lock:Sprite2D=get_node("Lock")
	lock.visible=n<BEDS.size()
	if lock.visible: lock.position=BEDS[n]-Vector2(0,40)
	var plot:Dictionary=model.s.plots[0]
	var ready:bool=plot.progress>=model.grow_time(int(plot.crop))
	var pip_spot:Vector2=BEDS[0]+Vector2(190,10)
	if model.owned("gardener"):
		if gardener==null: gardener=add_actor("gardener",92)
		gardener.position=pip_spot
		gardener.dir=0
		gardener.action=actor_action("gardener",not ready)
		owner_actor.position=Vector2(520,450)
		owner_actor.dir=1
		owner_actor.action=actor_action("owner")
	else:
		if gardener!=null:
			gardener.queue_free()
			gardener=null
		owner_actor.position=pip_spot
		owner_actor.dir=0
		owner_actor.action=actor_action("owner",not ready)

func station_at(global_point:Vector2) -> String:
	var n:int=model.s.plots.size()
	if n<BEDS.size() and to_local(global_point).distance_to(BEDS[n]-Vector2(0,40))<120: return "plot"
	for i in range(n):
		var sprite:=bed(i)
		if sprite.get_rect().has_point(sprite.to_local(global_point)): return "garden"
	return ""

func burst(kind:String):
	effect=kind
	pulse=1.2
	match kind:
		"harvest":
			actor_timers["gardener" if model.owned("gardener") else "owner"]=.7
			for i in range(model.s.plots.size()):
				spray(BEDS[i]-Vector2(0,80),9,"leaf",Color("8fd16a"),150,-180,300,1.0)
				bounce["bed"+str(i)]=1.0
		"sale","dream_sale":
			# Sales still count up by the cottage while you tend the garden.
			sale_floater(Vector2(700,300),kind)
		"level","milestone":
			var at:Vector2=BEDS[0]-Vector2(0,120)
			for i in range(model.s.plots.size()): bounce["bed"+str(i)]=1.0
			if kind=="milestone":
				spray(at,30,"star",Color("ffd765"),320,-160,160,1.3)
				spray(at,16,"dot",Color("b58af1"),260,-180,260,1.1)
				floaters.append({"p":at-Vector2(30,10),"t":0.0,"text":"×2!","dream":true,"coin":false})
			else:
				spray(at,10,"star",Color("fff1af"),150,-110,120,.8)
		"upgrade":
			spray(Vector2(420,700),26,"star",Color("ffd765"),300,-120,140,1.2)
			spray(Vector2(420,700),14,"dot",Color("b58af1"),260,-160,260,1.0)

func draw_overlay():
	if not model: return
	var o:=overlay
	var extra:String=theme().extra
	for i in range(tufts.size()):
		var q:Vector2=tufts[i]
		match extra:
			"snow": o.draw_circle(Vector2(q.x+sin(clock+i)*10,fmod(q.y+clock*40.0,1216.0)),4,Color(1,1,1,.9))
			"fireflies": if sin(clock*2+i)>.3: o.draw_circle(q+Vector2(sin(clock+i)*10,cos(clock*.7+i)*8),3,Color("fff4b0"))
			"stars": if i%2==0: twinkle(o,q,4+3*(.5+.5*sin(clock*1.6+i*1.7)),Color(1,.96,.75,.7))
			"gulls": if i<4: o.draw_arc(Vector2(fmod(q.x+clock*30.0,900.0)-40,q.y*.25+60),12,PI*1.15,PI*1.85,8,Color("f6f2e8"),3,true)
	var n:int=model.s.plots.size()
	for i in range(n):
		var plot:Dictionary=model.s.plots[i]
		var grow:float=model.grow_time(int(plot.crop))
		var ready:bool=plot.progress>=grow
		var c:Vector2=BEDS[i]
		if ready: glints(o,c-Vector2(0,70),Vector2(90,20),i*.7)
		# Which crop this bed is growing.
		var card:=StyleBoxFlat.new()
		card.bg_color=Color("fff3df")
		card.border_color=Color("6b3f24")
		card.set_border_width_all(3)
		card.set_corner_radius_all(10)
		o.draw_style_box(card,Rect2(c+Vector2(-160,-140),Vector2(68,68)))
		o.draw_texture_rect(textures[Art.CROPS[int(plot.crop)]+"_t1"],Rect2(c+Vector2(-154,-134),Vector2(56,56)),false)
		pill(o,c+Vector2(-60,36),"Ready" if ready else "Growing",plot.progress/grow,120,Color("5fbf6a"))
	badge(o,BEDS[0]+Vector2(150,60),"garden")
	if n<BEDS.size():
		# The next plot: a dashed outline, the padlock and its price.
		var c:Vector2=BEDS[n]-Vector2(0,40)
		var pts:=PackedVector2Array([c+Vector2(-130,0),c+Vector2(0,-64),c+Vector2(130,0),c+Vector2(0,64),c+Vector2(-130,0)])
		o.draw_colored_polygon(pts.slice(0,4),Color(1,1,1,.22))
		for k in range(4): o.draw_dashed_line(pts[k],pts[k+1],Color(1,1,1,.95),4,12,true)
		var cost:String=model.short(model.plot_cost())
		var w:=font.get_string_size(cost,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x+46
		var st:=StyleBoxFlat.new()
		st.bg_color=Color("fff3df")
		st.border_color=Color("6b3f24")
		st.set_border_width_all(2)
		st.set_corner_radius_all(14)
		o.draw_style_box(st,Rect2(c+Vector2(-w/2,18),Vector2(w,34)))
		o.draw_texture_rect(coin_tex,Rect2(c+Vector2(-w/2+7,22),Vector2(26,26)),false)
		text(o,c+Vector2(-w/2+38,43),cost,20)
	if gardener: bubble(o,gardener.position-Vector2(0,190),"Auto-harvest ON")
	draw_effects(o)

func bubble(o:CanvasItem,p:Vector2,title:String):
	var w:=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+28
	var st:=StyleBoxFlat.new()
	st.bg_color=Color("f1fbe9")
	st.border_color=Color("6b9f4a")
	st.set_border_width_all(2)
	st.set_corner_radius_all(16)
	o.draw_style_box(st,Rect2(p-Vector2(w/2,0),Vector2(w,36)))
	o.draw_colored_polygon(PackedVector2Array([p+Vector2(-8,34),p+Vector2(8,34),p+Vector2(0,46)]),Color("f1fbe9"))
	text(o,p+Vector2(-w/2+14,25),title,18)
