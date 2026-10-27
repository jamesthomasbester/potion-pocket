extends Node2D
# The shop room in main.tscn. Furniture is authored in the scene; this script
# swaps each piece's art tier as the shop grows, places the team and the
# customers on the room's floor, and draws badges and effects on Overlay.
# Coordinates are the scene's design space; main.gd fits this node to the stage.
const Art = preload("res://game/art_catalog.gd")
const Actor = preload("res://game/actor.gd")

var model
var selected := "cauldron"
var clock := 0.0
var font := ThemeDB.fallback_font
var coin_tex: Texture2D = preload("res://game/art/ui/coin.png")
var tiers := {}
var textures := {}
var sheets := {}
var particles: Array = []
var floaters: Array = []
var customers: Array = []
var departures: Array = []
var next_customer := 0
var actor_timers := {}
var bounce := {}
var pulse := 0.0
var effect := ""
var last_sale_fx := -10.0
var owner_actor
var brewer
var cashier
var visitor
@onready var props: Node2D = $Props
@onready var overlay: Node2D = $Overlay

# Floor corners measured from the room art: the back corner, and the edges
# towards the right and left corners. floor_at(1,1) is the front corner.
const BACK = Vector2(270.8,369.6)
const FU = Vector2(292,144)
const FV = Vector2(-296,148)
# Art family per prop node, and where its footprint centre sits, as a
# fraction of its texture height above the bottom edge.
const PROPS = {"Cauldron":"cauldron","Counter":"counter","PotionShelf":"potion_shelf","Bookcase":"bookcase","Workbench":"workbench","Lectern":"lectern","Books":"books","Plant":"plant","Rug":"rug","DoorMat":"door_mat"}
const BASE = {"cauldron":.12,"workbench":.17,"bookcase":.06,"potion_shelf":.06,"lectern":.12,"books":.16,"plant":.07,"counter":.24,"rug":.5,"door_mat":.5}
# Spots on the floor, in (u,v) along the two back walls.
const DOOR = Vector2(.95,.95)
const OUTSIDE = Vector2(1.03,1.02)
const QUEUE = [Vector2(.8,.84),Vector2(.6,.9),Vector2(.4,.93)]
const BREWER_SPOT = Vector2(.27,.1)
const CASHIER_SPOT = Vector2(.72,.33)
const VISITOR_SPOT = Vector2(.14,.64)
const OWNER_LOOP = Vector2(.45,.62)
const STATIONS = {"Cauldron":"cauldron","PotionShelf":"shelf","Counter":"counter"}

func floor_at(g: Vector2) -> Vector2:
	return BACK+FU*g.x+FV*g.y

func _ready():
	for family in PROPS.values():
		for t in range(1,4): textures["%s_t%d" % [family,t]]=load("res://game/art/shop/%s_t%d.png" % [family,t])
	for name in ["owner","brewer","cashier","customer0","customer1","departing"]:
		sheets[name]=load("res://game/art/animations/"+name+".png")
	overlay.draw.connect(draw_overlay)
	owner_actor=add_actor("owner",88)

func add_actor(sheet:String,w:float):
	var a=Actor.new()
	a.sheet=sheets[sheet]
	a.w=w
	a.phase=randf()*3
	props.add_child(a)
	return a

func prop(name:String) -> Sprite2D:
	return props.get_node(name) if props.has_node(name) else get_node("Decals/"+name)

# Which art tier each piece shows: stations follow their level, the
# Recipe Book corner follows recipes unlocked, rugs and plants the décor.
func tier_for(family:String) -> int:
	match family:
		"cauldron": return Art.tier(model.level("cauldron"))
		"counter": return Art.tier(model.level("counter"))
		"potion_shelf": return Art.tier(model.level("shelf"))
		"workbench": return Art.tier(model.level("brewer"))
		"lectern","books","bookcase": return Art.tier(model.stat("recipes"))
		"rug","door_mat": return int(model.s.decor.floor)+1
		"plant": return int(model.s.decor.wall)+1
	return 1

func refresh_art():
	for node in PROPS:
		var family:String=PROPS[node]
		var t:=tier_for(family)
		if tiers.get(node,0)==t: continue
		tiers[node]=t
		var sprite:=prop(node)
		sprite.texture=textures["%s_t%d" % [family,t]]
		sprite.offset=Vector2(0,-sprite.texture.get_height()*(.5-BASE[family]))

func _process(dt):
	if not model: return
	clock+=dt
	pulse=maxf(0,pulse-dt)
	refresh_art()
	for key in actor_timers.keys(): actor_timers[key]=maxf(0,float(actor_timers[key])-dt)
	for k in bounce.keys(): bounce[k]=maxf(0,bounce[k]-dt*2.6)
	for node in ["Cauldron","PotionShelf","Counter"]:
		var t:float=bounce.get(STATIONS[node],0.0)
		var squash=sin(t*PI*3.0)*t*.12
		prop(node).scale=Vector2(1+squash,1-squash)*base_scale(node)
	sync_team()
	sync_customers(dt)
	for q in particles:
		q.p+=q.v*dt
		q.v.y+=q.g*dt
		q.v*=1.0-q.drag*dt
		q.life-=dt
	particles=particles.filter(func(q):return q.life>0)
	for f in floaters: f.t+=dt
	floaters=floaters.filter(func(f):return f.t<1.3)
	overlay.queue_redraw()

var _scales := {}
func base_scale(node:String) -> Vector2:
	if not _scales.has(node): _scales[node]=prop(node).scale
	return _scales[node]

func actor_action(name:String,working:=false) -> String:
	if float(actor_timers.get(name,0.0))>0: return "pickup"
	return "work" if working else "idle"

# Momo and Sol appear once hired; the owner brews by hand until then and
# otherwise strolls around the rug.
func sync_team():
	var brewing:bool=model.s.pot!=-1
	if model.owned("brewer") and brewer==null: brewer=add_actor("brewer",80)
	if not model.owned("brewer") and brewer!=null:
		brewer.queue_free()
		brewer=null
	if model.owned("cashier") and cashier==null: cashier=add_actor("cashier",74)
	if not model.owned("cashier") and cashier!=null:
		cashier.queue_free()
		cashier=null
	if brewer:
		brewer.position=floor_at(BREWER_SPOT)
		brewer.action=actor_action("brewer",brewing)
	if cashier:
		cashier.position=floor_at(CASHIER_SPOT)
		cashier.action=actor_action("cashier",model.s.serving)
	if not model.owned("brewer") and brewing:
		owner_actor.position=floor_at(BREWER_SPOT)
		owner_actor.dir=0
		owner_actor.action=actor_action("owner",not model.s.ready)
	else:
		var before:Vector2=owner_actor.position
		var g=OWNER_LOOP+Vector2(sin(clock*.6)*.07,cos(clock*.6)*.05)
		owner_actor.position=floor_at(g)
		var delta:Vector2=owner_actor.position-before
		if delta.length()>.05: owner_actor.dir=direction(delta)
		owner_actor.action="walk" if float(actor_timers.get("owner",0.0))<=0 else "pickup"
	if not model.s.visitor.is_empty() and visitor==null:
		visitor=add_actor("customer1" if model.s.visitor.kind=="vip" else "customer0",74)
		visitor.position=floor_at(VISITOR_SPOT)
	if model.s.visitor.is_empty() and visitor!=null:
		visitor.queue_free()
		visitor=null
	if visitor: visitor.action="work" if model.visitor_potion()>=0 else "idle"

func direction(delta:Vector2) -> int:
	if delta.y>=0: return 0 if delta.x<0 else 1
	return 2 if delta.x<0 else 3

# Customers walk in through the door to their queue spot; beyond the visible
# spots the rest wait outside and show as a count by the door.
func sync_customers(dt:float):
	var shown:=mini(int(model.s.queue),QUEUE.size())
	while customers.size()<shown:
		var c={"g":OUTSIDE,"path":[DOOR],"moving":true,"hold":0.0,"actor":add_actor(["customer0","customer1","departing"][next_customer%3],72)}
		next_customer+=1
		customers.append(c)
	while customers.size()>shown: leave_customer()
	for i in range(customers.size()): walk(customers[i],QUEUE[i],dt)
	for c in departures: walk(c,OUTSIDE,dt)
	for c in departures:
		if c.path.is_empty() and c.g.distance_to(OUTSIDE)<.01: c.actor.queue_free()
	departures=departures.filter(func(c):return is_instance_valid(c.actor) and not c.actor.is_queued_for_deletion())
	for c in customers+departures:
		var a=c.actor
		a.position=floor_at(c.g)
		# Fade in and out at the doorway rather than walking over the sky.
		a.modulate.a=clampf((OUTSIDE.distance_to(c.g))/.06,0,1)
		a.action="pickup" if float(c.hold)>0 else "walk" if c.moving else "work" if model.s.serving and not customers.is_empty() and c==customers[0] else "idle"

func walk(c:Dictionary,spot:Vector2,dt:float):
	if float(c.hold)>0:
		c.hold=maxf(0,float(c.hold)-dt)
		c.moving=false
		return
	var from:Vector2=floor_at(c.g)
	var step:=dt*.38
	while step>0:
		var target:Vector2=c.path[0] if not c.path.is_empty() else spot
		var d:float=c.g.distance_to(target)
		if d<=step:
			c.g=target
			step-=d
			if c.path.is_empty(): break
			c.path.pop_front()
		else:
			c.g=c.g.move_toward(target,step)
			break
	var delta:Vector2=floor_at(c.g)-from
	c.moving=delta.length()>.1
	if c.moving: c.actor.dir=direction(delta)

func leave_customer():
	if customers.is_empty(): return
	var c=customers.pop_front()
	c.path=[DOOR]
	c.hold=.58
	departures.append(c)

func station_pos(id:String) -> Vector2:
	for node in STATIONS:
		if STATIONS[node]==id: return prop(node).position
	return prop("Cauldron").position

# The station or visitor under a point in global canvas coordinates.
func station_at(global_point:Vector2) -> String:
	if visitor and visitor.hit_rect().has_point(visitor.to_local(global_point)): return "visitor"
	for node in ["Counter","Cauldron","PotionShelf","Lectern"]:
		var sprite:=prop(node)
		if sprite.get_rect().has_point(sprite.to_local(global_point)):
			return "book" if node=="Lectern" else STATIONS[node]
	return ""

func spray(at:Vector2,count:int,kind:String,color:Color,speed:=160.0,up:=-120.0,g:=320.0,life:=0.9):
	for i in range(count):
		var dir=Vector2.from_angle(randf_range(-PI,0))*randf_range(.35,1)*speed+Vector2(0,up)
		particles.append({"p":at+Vector2(randf_range(-14,14),randf_range(-6,6)),"v":dir,"g":g,"drag":1.2,"life":life*randf_range(.7,1.1),"max":life,"kind":kind,"color":color,"r":randf_range(3,6)})

# Visual response to economy feedback.
func burst(kind:String):
	effect=kind
	pulse=1.2
	match kind:
		"brew":
			actor_timers["brewer" if model.owned("brewer") else "owner"]=.55
			spray(station_pos("cauldron")-Vector2(0,80),12,"dot",Color("b58af1"),120,-150,380,.8)
			bounce["cauldron"]=1.0
		"stock":
			actor_timers["brewer" if model.owned("brewer") else "owner"]=.75
			spray(station_pos("shelf")-Vector2(0,120),8,"star",Color("fff1af"),110,-60,60,.8)
			bounce["shelf"]=1.0
			bounce["cauldron"]=.6
		"sale","dream_sale":
			actor_timers["cashier" if model.owned("cashier") else "owner"]=.5
			var at=station_pos("counter")-Vector2(10,110)
			var amount=model.price(1 if kind=="dream_sale" else 0)
			# Fast checkouts merge into one rising total instead of a pile of labels.
			if clock-last_sale_fx<.35 and not floaters.is_empty() and floaters.back().has("amount"):
				var f=floaters.back()
				f.amount+=amount
				f.text="+"+model.short(f.amount)
				f.t=minf(f.t,.2)
			else:
				spray(at,7,"coin",Color.WHITE,170,-230,520,1.0)
				floaters.append({"p":at-Vector2(20,30),"t":0.0,"amount":amount,"text":"+"+model.short(amount),"dream":kind=="dream_sale","coin":true})
			last_sale_fx=clock
			bounce["counter"]=.7
		"request","vip":
			var at=floor_at(VISITOR_SPOT)-Vector2(0,110)
			spray(at,16 if kind=="vip" else 10,"coin",Color.WHITE,220,-260,520,1.1)
			spray(at,14,"star",Color("ffd765"),220,-140,140,1.0)
			floaters.append({"p":at-Vector2(30,20),"t":0.0,"text":"+"+model.short(model.last_visitor_pay),"dream":kind=="vip","coin":true})
		"level","milestone":
			if not selected in ["cauldron","shelf","counter"]: return
			var at=station_pos(selected)-Vector2(0,90)
			bounce[selected]=1.0
			if kind=="milestone":
				spray(at,30,"star",Color("ffd765"),320,-160,160,1.3)
				spray(at,16,"dot",Color("b58af1"),260,-180,260,1.1)
				floaters.append({"p":at-Vector2(30,10),"t":0.0,"text":"×2!","dream":true,"coin":false})
			else:
				spray(at,10,"star",Color("fff1af"),150,-110,120,.8)
		"upgrade":
			spray(Vector2(270,450),26,"star",Color("ffd765"),300,-120,140,1.2)
			spray(Vector2(270,450),14,"dot",Color("b58af1"),260,-160,260,1.0)

# --- Overlay drawing: everything here sits above the room and its people. ---

func text(o:CanvasItem,p:Vector2,s:String,n:=16,c:=Color("2b1a3d")):
	o.draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,n,c)

func badge(o:CanvasItem,p:Vector2,id:String):
	var on:=id==selected
	var label:="Lv. %d" % model.level(id)
	var w:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+20
	var st:=StyleBoxFlat.new()
	st.bg_color=Color("7d52c9") if on else Color("fff3df")
	st.border_color=Color("4a2a7a") if on else Color("6b3f24")
	st.set_border_width_all(2)
	st.set_corner_radius_all(12)
	var r:=Rect2(p-Vector2(w/2,12),Vector2(w,25))
	o.draw_style_box(st,r)
	text(o,r.position+Vector2(10,18),label,15,Color("fff3df") if on else Color("2b1a3d"))

func pill(o:CanvasItem,p:Vector2,title:String,progress:float,w:=110.0):
	var st:=StyleBoxFlat.new()
	st.bg_color=Color("fff3df")
	st.border_color=Color("6b3f24")
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	o.draw_style_box(st,Rect2(p,Vector2(w,44)))
	text(o,p+Vector2(11,19),title,14)
	var bar:=StyleBoxFlat.new()
	bar.bg_color=Color("e6d9f2")
	bar.set_corner_radius_all(6)
	o.draw_style_box(bar,Rect2(p+Vector2(8,26),Vector2(w-16,10)))
	bar=bar.duplicate()
	bar.bg_color=Color("8a5cd6")
	o.draw_style_box(bar,Rect2(p+Vector2(8,26),Vector2(maxf(3,(w-16)*clampf(progress,0,1)),10)))

func twinkle(o:CanvasItem,p:Vector2,r:float,c:Color):
	o.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-r),p+Vector2(r*.28,-r*.28),p+Vector2(r,0),p+Vector2(r*.28,r*.28),p+Vector2(0,r),p+Vector2(-r*.28,r*.28),p+Vector2(-r,0),p+Vector2(-r*.28,-r*.28)]),c)

func glints(o:CanvasItem,center:Vector2,spread:Vector2,seed:float):
	for i in range(3):
		var t=fmod(clock*.8+i*.37+seed,1.0)
		var a=sin(t*PI)
		twinkle(o,center+Vector2(sin(i*2.1+seed)*spread.x,cos(i*1.7+seed)*spread.y),3+a*5,Color(1,.96,.7,a))

func draw_overlay():
	if not model: return
	var o:=overlay
	var cauldron:=station_pos("cauldron")
	var counter:=station_pos("counter")
	var shelf:=station_pos("shelf")
	if model.s.pot!=-1:
		for i in range(5):
			var t=fmod(clock*.5+i*.2,1.0)
			o.draw_circle(cauldron+Vector2(sin(i*3+clock)*22,-70-t*50),3+2*t,Color(.8,.6,1,1-t))
		pill(o,cauldron+Vector2(-150,-150),"Ready to stock" if model.s.ready else "Brewing",model.s.brew_progress/model.brew_time(model.s.pot))
	if model.s.ready: glints(o,cauldron-Vector2(0,80),Vector2(40,12),.2)
	# The newest bottles wait on the counter, most valuable first.
	var kinds:=[]
	for r in range(model.s.stock.size()-1,-1,-1):
		for n in range(int(model.s.stock[r])): kinds.append(r)
	for i in range(mini(kinds.size(),4)):
		var tex:Texture2D=load("res://game/art/%s.png" % Art.name_for(Art.POTIONS[kinds[i]],model.level("cauldron")))
		# A row along the counter top's front edge, clear of the register.
		var p:=counter+Vector2(-47,-95)+Vector2(15,5.7)*i
		o.draw_texture_rect(tex,Rect2(p-Vector2(11,28),Vector2(22,28)),false)
	if pulse>0 and effect=="stock":
		# Arc the new bottle from the cauldron to the shelf.
		var t=clampf((1.2-pulse)/.6,0,1)
		var p=cauldron.lerp(shelf,t)-Vector2(0,90+sin(t*PI)*70)
		if t<1: o.draw_texture_rect(load("res://game/art/%s.png" % Art.name_for(Art.POTIONS[int(model.s.recipe)],model.level("cauldron"))),Rect2(p-Vector2(14,36),Vector2(28,36)),false)
	badge(o,cauldron+Vector2(0,14),"cauldron")
	badge(o,shelf+Vector2(-6,-210),"shelf")
	badge(o,counter+Vector2(30,26),"counter")
	var waiting:=int(model.s.queue)-customers.size()
	if waiting>0:
		var p:=floor_at(DOOR)+Vector2(36,-6)
		var st:=StyleBoxFlat.new()
		st.bg_color=Color("fff3df")
		st.border_color=Color("6b3f24")
		st.set_border_width_all(2)
		st.set_corner_radius_all(12)
		o.draw_style_box(st,Rect2(p-Vector2(0,13),Vector2(44,26)))
		text(o,p+Vector2(8,6),"+%d" % waiting,16)
	if visitor: draw_visitor_bubble(o)
	for q in particles:
		var a=clampf(q.life/q.max*1.6,0,1)
		match q.kind:
			"coin": o.draw_texture_rect(coin_tex,Rect2(q.p-Vector2(10,10),Vector2(20,20)),false,Color(1,1,1,a))
			"star": twinkle(o,q.p,q.r+2,Color(q.color,a))
			_: o.draw_circle(q.p,q.r*(.5+a*.5),Color(q.color,a))
	for f in floaters:
		var e=1-pow(1-minf(f.t/1.3,1),3)
		var p=f.p-Vector2(0,e*70)
		var a=clampf((1.3-f.t)*2.5,0,1)
		var s=26+int(10*maxf(0,.25-f.t)/.25)
		var c=Color("7b3fd1") if f.dream else Color("2f7d4f")
		if not f.get("coin",true): s+=10
		o.draw_string_outline(font,p,f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,s,6,Color(1,1,1,a))
		o.draw_string(font,p,f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,s,Color(c,a))
		var w=font.get_string_size(f.text,HORIZONTAL_ALIGNMENT_LEFT,-1,s).x
		if f.get("coin",true): o.draw_texture_rect(coin_tex,Rect2(p+Vector2(w+4,-s*.85),Vector2(s*.9,s*.9)),false,Color(1,1,1,a))

# Speech bubble: wanted potion (or any, for a VIP), pay multiplier, countdown ring.
func draw_visitor_bubble(o:CanvasItem):
	var v:Dictionary=model.s.visitor
	var vip:bool=v.kind=="vip"
	var p:Vector2=visitor.position
	if vip:
		var c=p-Vector2(0,96)
		o.draw_colored_polygon(PackedVector2Array([c+Vector2(-15,8),c+Vector2(15,8),c+Vector2(18,-10),c+Vector2(8,-2),c+Vector2(0,-14),c+Vector2(-8,-2),c+Vector2(-18,-10)]),Color("f2c94c"))
	var ready:bool=model.visitor_potion()>=0
	var b=p-Vector2(0,150)+Vector2(0,sin(clock*3)*2)
	var st:=StyleBoxFlat.new()
	st.bg_color=Color("fff3df")
	st.border_color=Color("f2b632") if vip else Color("8a5cd6")
	st.set_border_width_all(3)
	st.set_corner_radius_all(16)
	o.draw_style_box(st,Rect2(b-Vector2(46,24),Vector2(92,44)))
	o.draw_colored_polygon(PackedVector2Array([b+Vector2(-7,19),b+Vector2(7,19),b+Vector2(0,30)]),Color("fff3df"))
	var icon:String=Art.name_for(Art.POTIONS[model.visitor_potion() if vip and ready else int(v.recipe)],model.level("cauldron"))
	if vip and not ready: icon="energy_t1"
	o.draw_texture_rect(load("res://game/art/%s.png" % icon),Rect2(b+Vector2(-36,-16),Vector2(26,32)),false,Color.WHITE if ready else Color(1,1,1,.45))
	text(o,b+Vector2(-6,7),"×%d" % int(model.cfg.visitors.vip_pay if vip else model.cfg.visitors.request_pay),20,Color("b9822a") if vip else Color("7b3fd1"))
	var left:float=clampf(v.left/float(model.cfg.visitors.wait),0,1)
	o.draw_arc(b+Vector2(36,-14),9,-PI/2,-PI/2+TAU*left,20,Color("e46b5a") if left<.3 else Color("5fbf6a"),4,true)
	if ready and fmod(clock,1.2)<.6: twinkle(o,b+Vector2(-40,-20),6,Color("fff1af"))
